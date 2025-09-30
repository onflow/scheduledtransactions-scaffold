import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"
import "Counter"

access(all) contract CounterCronTransactionHandler {

    /// Struct to hold cron configuration data
    access(all) struct CronConfig {
        access(all) let intervalSeconds: UFix64
        access(all) let baseTimestamp: UFix64
        access(all) let maxExecutions: UInt64?
        access(all) let executionCount: UInt64
        access(all) let schedulerManagerCap: Capability<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>
        access(all) let feeProviderCap: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>
        access(all) let priority: FlowTransactionScheduler.Priority
        access(all) let executionEffort: UInt64

        init(
            intervalSeconds: UFix64, 
            baseTimestamp: UFix64, 
            maxExecutions: UInt64?, 
            executionCount: UInt64,
            schedulerManagerCap: Capability<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>,
            feeProviderCap: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>,
            priority: FlowTransactionScheduler.Priority,
            executionEffort: UInt64
        ) {
            self.intervalSeconds = intervalSeconds
            self.baseTimestamp = baseTimestamp
            self.maxExecutions = maxExecutions
            self.executionCount = executionCount
            self.schedulerManagerCap = schedulerManagerCap
            self.feeProviderCap = feeProviderCap
            self.priority = priority
            self.executionEffort = executionEffort
        }

        access(all) fun withIncrementedCount(): CronConfig {
            return CronConfig(
                intervalSeconds: self.intervalSeconds,
                baseTimestamp: self.baseTimestamp,
                maxExecutions: self.maxExecutions,
                executionCount: self.executionCount + 1,
                schedulerManagerCap: self.schedulerManagerCap,
                feeProviderCap: self.feeProviderCap,
                priority: self.priority,
                executionEffort: self.executionEffort
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

    /// Handler resource that implements the Scheduled Transaction interface
    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            Counter.increment()
            let newCount = Counter.getCount()
            log("Counter cron transaction executed (id: ".concat(id.toString()).concat(") newCount: ").concat(newCount.toString()))

            // Extract cron configuration from transaction data
            let cronConfig = data as! CronConfig? ?? panic("CronConfig data is required")
            let updatedConfig = cronConfig.withIncrementedCount()

            // Check if we should continue scheduling
            if !updatedConfig.shouldContinue() {
                log("Counter cron job completed after ".concat(updatedConfig.executionCount.toString()).concat(" executions"))
                return
            }

            // Calculate the next precise execution time
            let nextExecutionTime = cronConfig.getNextExecutionTime()

            let estimate = FlowTransactionScheduler.estimate(
                data: updatedConfig,
                timestamp: nextExecutionTime,
                priority: cronConfig.priority,
                executionEffort: cronConfig.executionEffort
            )

            assert(
                estimate.timestamp != nil || cronConfig.priority == FlowTransactionScheduler.Priority.Low,
                message: estimate.error ?? "estimation failed"
            )

            // Borrow fee provider and withdraw fees
            let feeVault = cronConfig.feeProviderCap.borrow()
                ?? panic("Cannot borrow fee provider capability")
            let fees <- feeVault.withdraw(amount: estimate.flowFee ?? 0.0)

            // Schedule next transaction through the manager
            let schedulerManager = cronConfig.schedulerManagerCap.borrow()
                ?? panic("Cannot borrow scheduler manager capability")
            
            // Use scheduleByHandler since this handler has already been used
            let transactionId = schedulerManager.scheduleByHandler(
                handlerTypeIdentifier: self.getType().identifier,
                handlerUUID: self.uuid,
                data: updatedConfig,
                timestamp: nextExecutionTime,
                priority: cronConfig.priority,
                executionEffort: cronConfig.executionEffort,
                fees: <-fees as! @FlowToken.Vault
            )

            log("Next counter cron transaction scheduled (id: ".concat(transactionId.toString()).concat(") at ").concat(nextExecutionTime.toString()).concat(" (execution #").concat(updatedConfig.executionCount.toString()).concat(")"))
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
        schedulerManagerCap: Capability<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>,
        feeProviderCap: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>,
        priority: FlowTransactionScheduler.Priority,
        executionEffort: UInt64
    ): CronConfig {
        let base = baseTimestamp ?? getCurrentBlock().timestamp
        return CronConfig(
            intervalSeconds: intervalSeconds, 
            baseTimestamp: base, 
            maxExecutions: maxExecutions, 
            executionCount: 0,
            schedulerManagerCap: schedulerManagerCap,
            feeProviderCap: feeProviderCap,
            priority: priority,
            executionEffort: executionEffort
        )
    }
}
