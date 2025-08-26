import "FlowCallbackScheduler"
import "FlowToken"
import "FungibleToken"

/// A reusable contract for scheduling and managing cron-like recurring callbacks
access(all) contract CronJobScheduler {

    /// Interface that users must implement to define their custom callback logic
    access(all) resource interface CronJob {
        /// Called on each cron execution - implement your custom logic here
        access(all) fun executeCronJob(executionCount: UInt64)
        
        /// Withdraw fees for the next execution from the user's account
        access(all) fun withdrawFeesForNextExecution(amount: UFix64): @FlowToken.Vault
        
        /// Return the unique job identifier
        access(all) fun getJobId(): String
        
        /// Return the storage path where this CronJob should be stored
        access(all) fun getStoragePath(): StoragePath
        
        /// Return the public path for capabilities
        access(all) fun getPublicPath(): PublicPath
    }

    /// Public interface for accessing CronJob functions
    access(all) resource interface CronJobPublic {
        access(all) fun executeCronJob(executionCount: UInt64)
        access(all) fun withdrawFeesForNextExecution(amount: UFix64): @FlowToken.Vault
        access(all) fun getJobId(): String
    }

    /// Configuration struct for cron scheduling (immutable for callback serialization)
    access(all) struct CronConfig {
        access(all) let intervalSeconds: UFix64
        access(all) let baseTimestamp: UFix64
        access(all) let maxExecutions: UInt64?
        access(all) let executionCount: UInt64
        access(all) let jobPublicPath: PublicPath
        access(all) let jobAccountAddress: Address

        init(
            intervalSeconds: UFix64, 
            baseTimestamp: UFix64, 
            maxExecutions: UInt64?, 
            executionCount: UInt64,
            jobPublicPath: PublicPath,
            jobAccountAddress: Address
        ) {
            self.intervalSeconds = intervalSeconds
            self.baseTimestamp = baseTimestamp
            self.maxExecutions = maxExecutions
            self.executionCount = executionCount
            self.jobPublicPath = jobPublicPath
            self.jobAccountAddress = jobAccountAddress
        }

        access(all) fun withIncrementedCount(): CronConfig {
            return CronConfig(
                intervalSeconds: self.intervalSeconds,
                baseTimestamp: self.baseTimestamp,
                maxExecutions: self.maxExecutions,
                executionCount: self.executionCount + 1,
                jobPublicPath: self.jobPublicPath,
                jobAccountAddress: self.jobAccountAddress
            )
        }

        access(all) fun shouldContinue(): Bool {
            if let max = self.maxExecutions {
                return self.executionCount < max
            }
            return true
        }

        access(all) fun getNextExecutionTime(): UFix64 {
            let currentTime = getCurrentBlock().timestamp
            
            // If baseTimestamp is in the future, use it as the first execution time
            if self.baseTimestamp > currentTime {
                return self.baseTimestamp
            }
            
            // Calculate next execution time based on elapsed intervals
            let elapsed = currentTime - self.baseTimestamp
            let intervals = UFix64(UInt64(elapsed / self.intervalSeconds)) + 1.0
            return self.baseTimestamp + (intervals * self.intervalSeconds)
        }
    }

    /// Generic handler resource that executes user-defined CronJobs
    access(all) resource Handler: FlowCallbackScheduler.CallbackHandler {
        access(FlowCallbackScheduler.Execute) fun executeCallback(id: UInt64, data: AnyStruct?) {
            // Extract cron configuration from callback data
            let cronConfig = data as! CronConfig? ?? panic("CronConfig data is required")
            
            log("CronJobScheduler callback executing (id: ".concat(id.toString()).concat(", execution #").concat(cronConfig.executionCount.toString()).concat(")"))

            // Get the user's account and their CronJob capability
            let jobAccount = getAccount(cronConfig.jobAccountAddress)
            let cronJobCap = jobAccount.capabilities.get<&{CronJobPublic}>(cronConfig.jobPublicPath)
            let cronJobRef = cronJobCap.borrow()
                ?? panic("CronJob capability not found at ".concat(cronConfig.jobPublicPath.toString()).concat(" in account ").concat(cronConfig.jobAccountAddress.toString()))

            // Execute the user's custom logic
            cronJobRef.executeCronJob(executionCount: cronConfig.executionCount)
            
            let updatedConfig = cronConfig.withIncrementedCount()

            // Check if we should continue scheduling
            if !updatedConfig.shouldContinue() {
                log("CronJob completed after ".concat(updatedConfig.executionCount.toString()).concat(" executions"))
                return
            }

            // Schedule the next execution
            self.scheduleNext(config: updatedConfig)
        }

        access(self) fun scheduleNext(config: CronConfig) {
            // Calculate the next precise execution time
            let nextExecutionTime = config.getNextExecutionTime()
            let priority = FlowCallbackScheduler.Priority.Medium
            let executionEffort: UInt64 = 1000

            let estimate = FlowCallbackScheduler.estimate(
                data: config,
                timestamp: nextExecutionTime,
                priority: priority,
                executionEffort: executionEffort
            )

            assert(
                estimate.timestamp != nil || priority == FlowCallbackScheduler.Priority.Low,
                message: estimate.error ?? "estimation failed"
            )

            // Get the user's account and their CronJob capability to withdraw fees
            let jobAccount = getAccount(config.jobAccountAddress)
            let cronJobCap = jobAccount.capabilities.get<&{CronJobPublic}>(config.jobPublicPath)
            let cronJobRef = cronJobCap.borrow()
                ?? panic("CronJob capability not found at ".concat(config.jobPublicPath.toString()).concat(" in account ").concat(config.jobAccountAddress.toString()))

            // Get fees for next execution from the user's CronJob resource
            let fees <- cronJobRef.withdrawFeesForNextExecution(amount: estimate.flowFee ?? 0.0)

            // Ensure a handler resource exists in the contract account storage
            if CronJobScheduler.account.storage.borrow<&AnyResource>(from: /storage/CronJobSchedulerHandler) == nil {
                let handler <- CronJobScheduler.createHandler()
                CronJobScheduler.account.storage.save(<-handler, to: /storage/CronJobSchedulerHandler)
            }

            // Issue a capability to the handler stored in this contract account
            let handlerCap = CronJobScheduler.account.capabilities.storage
                .issue<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>(/storage/CronJobSchedulerHandler)

            let receipt = FlowCallbackScheduler.schedule(
                callback: handlerCap,
                data: config,
                timestamp: nextExecutionTime,
                priority: priority,
                executionEffort: executionEffort,
                fees: <-fees
            )

            log("Next cron execution scheduled (id: ".concat(receipt.id.toString()).concat(") at ").concat(receipt.timestamp.toString()).concat(" (execution #").concat(config.executionCount.toString()).concat(")"))
        }
    }

    /// Factory for the handler resource
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }

    /// Helper function to create a cron configuration
    access(all) fun createCronConfig(
        intervalSeconds: UFix64, 
        baseTimestamp: UFix64?, 
        maxExecutions: UInt64?,
        jobPublicPath: PublicPath,
        jobAccountAddress: Address
    ): CronConfig {
        let base = baseTimestamp ?? getCurrentBlock().timestamp
        return CronConfig(
            intervalSeconds: intervalSeconds, 
            baseTimestamp: base, 
            maxExecutions: maxExecutions, 
            executionCount: 0,
            jobPublicPath: jobPublicPath,
            jobAccountAddress: jobAccountAddress
        )
    }

    /// Public function to schedule a new cron job
    access(all) fun scheduleCronJob(
        config: CronConfig
    ) {
        let nextExecutionTime = config.getNextExecutionTime()
        let priority = FlowCallbackScheduler.Priority.Medium
        let executionEffort: UInt64 = 1000

        // Estimate fees first
        let estimate = FlowCallbackScheduler.estimate(
            data: config,
            timestamp: nextExecutionTime,
            priority: priority,
            executionEffort: executionEffort
        )

        assert(
            estimate.timestamp != nil || priority == FlowCallbackScheduler.Priority.Low,
            message: estimate.error ?? "estimation failed"
        )

        // Get the user's CronJob to withdraw fees for initial execution
        let jobAccount = getAccount(config.jobAccountAddress)
        let cronJobCap = jobAccount.capabilities.get<&{CronJobPublic}>(config.jobPublicPath)
        let cronJobRef = cronJobCap.borrow()
            ?? panic("CronJob capability not found at ".concat(config.jobPublicPath.toString()).concat(" in account ").concat(config.jobAccountAddress.toString()))
        
        let fees <- cronJobRef.withdrawFeesForNextExecution(amount: estimate.flowFee ?? 0.0)

        // Ensure a handler resource exists in the contract account storage
        if CronJobScheduler.account.storage.borrow<&AnyResource>(from: /storage/CronJobSchedulerHandler) == nil {
            let handler <- CronJobScheduler.createHandler()
            CronJobScheduler.account.storage.save(<-handler, to: /storage/CronJobSchedulerHandler)
        }

        // Issue a capability to the handler stored in this contract account
        let handlerCap = CronJobScheduler.account.capabilities.storage
            .issue<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>(/storage/CronJobSchedulerHandler)

        let receipt = FlowCallbackScheduler.schedule(
            callback: handlerCap,
            data: config,
            timestamp: nextExecutionTime,
            priority: priority,
            executionEffort: executionEffort,
            fees: <-fees
        )

        log("Initial cron job scheduled (id: ".concat(receipt.id.toString()).concat(") at ").concat(receipt.timestamp.toString()))
    }
}
