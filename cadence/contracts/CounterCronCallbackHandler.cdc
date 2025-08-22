import "FlowCallbackScheduler"
import "FlowToken"
import "FungibleToken"
import "Counter"

access(all) contract CounterCronCallbackHandler {

    /// Struct to hold cron configuration data (immutable for callback serialization)
    access(all) struct CounterCronConfig {
        access(all) let intervalSeconds: UFix64
        access(all) let baseTimestamp: UFix64
        access(all) let maxExecutions: UInt64?
        access(all) let executionCount: UInt64

        init(intervalSeconds: UFix64, baseTimestamp: UFix64, maxExecutions: UInt64?, executionCount: UInt64) {
            self.intervalSeconds = intervalSeconds
            self.baseTimestamp = baseTimestamp
            self.maxExecutions = maxExecutions
            self.executionCount = executionCount
        }

        access(all) fun withIncrementedCount(): CounterCronConfig {
            return CounterCronConfig(
                intervalSeconds: self.intervalSeconds,
                baseTimestamp: self.baseTimestamp,
                maxExecutions: self.maxExecutions,
                executionCount: self.executionCount + 1
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

    /// Handler resource that implements the Scheduled Callback interface
    access(all) resource Handler: FlowCallbackScheduler.CallbackHandler {
        access(FlowCallbackScheduler.Execute) fun executeCallback(id: UInt64, data: AnyStruct?) {
            Counter.increment()
            let newCount = Counter.getCount()
            log("Counter cron callback executed (id: ".concat(id.toString()).concat(") newCount: ").concat(newCount.toString()))

            // Extract cron configuration from callback data
            let cronConfig = data as! CounterCronConfig? ?? panic("CounterCronConfig data is required")
            let updatedConfig = cronConfig.withIncrementedCount()

            // Check if we should continue scheduling
            if !updatedConfig.shouldContinue() {
                log("Counter cron job completed after ".concat(updatedConfig.executionCount.toString()).concat(" executions"))
                return
            }

            // Calculate the next precise execution time
            let nextExecutionTime = cronConfig.getNextExecutionTime()
            let priority = FlowCallbackScheduler.Priority.Medium
            let executionEffort: UInt64 = 1000

            let estimate = FlowCallbackScheduler.estimate(
                data: updatedConfig,
                timestamp: nextExecutionTime,
                priority: priority,
                executionEffort: executionEffort
            )

            assert(
                estimate.timestamp != nil || priority == FlowCallbackScheduler.Priority.Low,
                message: estimate.error ?? "estimation failed"
            )

            // Ensure a handler resource exists in the contract account storage
            if CounterCronCallbackHandler.account.storage.borrow<&AnyResource>(from: /storage/CounterCronCallbackHandler) == nil {
                let handler <- CounterCronCallbackHandler.createHandler()
                CounterCronCallbackHandler.account.storage.save(<-handler, to: /storage/CounterCronCallbackHandler)
            }

            // Withdraw FLOW fees from this contract's account vault
            let vaultRef = CounterCronCallbackHandler.account.storage
                .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("missing FlowToken vault on contract account")
            let fees <- vaultRef.withdraw(amount: estimate.flowFee ?? 0.0) as! @FlowToken.Vault

            // Issue a capability to the handler stored in this contract account
            let handlerCap = CounterCronCallbackHandler.account.capabilities.storage
                .issue<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>(/storage/CounterCronCallbackHandler)

            let receipt = FlowCallbackScheduler.schedule(
                callback: handlerCap,
                data: updatedConfig,
                timestamp: nextExecutionTime,
                priority: priority,
                executionEffort: executionEffort,
                fees: <-fees
            )

            log("Next counter cron callback scheduled (id: ".concat(receipt.id.toString()).concat(") at ").concat(receipt.timestamp.toString()).concat(" (execution #").concat(updatedConfig.executionCount.toString()).concat(")"))
        }
    }

    /// Factory for the handler resource
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }

    /// Helper function to create a cron configuration
    access(all) fun createCounterCronConfig(intervalSeconds: UFix64, baseTimestamp: UFix64?, maxExecutions: UInt64?): CounterCronConfig {
        let base = baseTimestamp ?? getCurrentBlock().timestamp
        return CounterCronConfig(intervalSeconds: intervalSeconds, baseTimestamp: base, maxExecutions: maxExecutions, executionCount: 0)
    }
}
