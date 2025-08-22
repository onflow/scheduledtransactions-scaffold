import "FlowCallbackScheduler"
import "FlowToken"
import "FungibleToken"
import "CounterCronCallbackHandler"

/// Schedule a counter increment using cron-like callback that executes at precise intervals
transaction(
    intervalSeconds: UFix64,
    priority: UInt8,
    executionEffort: UInt64,
    maxExecutions: UInt64?,
    baseTimestamp: UFix64?
) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Create counter cron configuration
        let cronConfig = CounterCronCallbackHandler.createCounterCronConfig(
            intervalSeconds: intervalSeconds,
            baseTimestamp: baseTimestamp,
            maxExecutions: maxExecutions
        )

        // Determine the first execution time
        let firstExecutionTime = cronConfig.getNextExecutionTime()

        let pr = priority == 0
            ? FlowCallbackScheduler.Priority.High
            : priority == 1
                ? FlowCallbackScheduler.Priority.Medium
                : FlowCallbackScheduler.Priority.Low

        let est = FlowCallbackScheduler.estimate(
            data: cronConfig,
            timestamp: firstExecutionTime,
            priority: pr,
            executionEffort: executionEffort
        )

        assert(
            est.timestamp != nil || pr == FlowCallbackScheduler.Priority.Low,
            message: est.error ?? "estimation failed"
        )

        let vaultRef = signer.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("missing FlowToken vault")
        let fees <- vaultRef.withdraw(amount: est.flowFee ?? 0.0) as! @FlowToken.Vault

        let handlerCap = signer.capabilities.storage
            .issue<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>(/storage/CounterCronCallbackHandler)

        let receipt = FlowCallbackScheduler.schedule(
            callback: handlerCap,
            data: cronConfig,
            timestamp: firstExecutionTime,
            priority: pr,
            executionEffort: executionEffort,
            fees: <-fees
        )

        log("Scheduled counter cron increment (id: ".concat(receipt.id.toString()).concat(") first execution at ").concat(receipt.timestamp.toString()).concat(" with ").concat(intervalSeconds.toString()).concat("s intervals"))
        
        if let max = maxExecutions {
            log("Counter cron job will run for a maximum of ".concat(max.toString()).concat(" executions"))
        } else {
            log("Counter cron job will run indefinitely until cancelled")
        }
    }
}