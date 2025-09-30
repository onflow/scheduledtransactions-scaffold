import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"
import "CounterCronTransactionHandler"

/// Schedule a counter increment using cron-like transaction that executes at precise intervals
transaction(
    intervalSeconds: UFix64,
    priority: UInt8,
    executionEffort: UInt64,
    maxExecutions: UInt64?,
    baseTimestamp: UFix64?
) {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue, GetStorageCapabilityController, PublishCapability) &Account) {
        let pr = priority == 0
            ? FlowTransactionScheduler.Priority.High
            : priority == 1
                ? FlowTransactionScheduler.Priority.Medium
                : FlowTransactionScheduler.Priority.Low

        // Get the entitled capability that will be used to create the transaction
        // Need to check both controllers because the order of controllers is not guaranteed
        var handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>? = nil
        if let cap = signer.capabilities.storage
                            .getControllers(forPath: /storage/CounterCronTransactionHandler)[0]
                            .capability as? Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}> {
            handlerCap = cap
        } else {
            handlerCap = signer.capabilities.storage
                            .getControllers(forPath: /storage/CounterCronTransactionHandler)[1]
                            .capability as! Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>
        }

        // Save a manager resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: FlowTransactionSchedulerUtils.managerStoragePath) == nil {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)

            // Create a capability for the Manager
            let managerCapPublic = signer.capabilities.storage.issue<&{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath)
            signer.capabilities.publish(managerCapPublic, at: FlowTransactionSchedulerUtils.managerPublicPath)
        }
        // Borrow the manager
        let manager = signer.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(from: FlowTransactionSchedulerUtils.managerStoragePath)
            ?? panic("Could not borrow a Manager reference from \(FlowTransactionSchedulerUtils.managerStoragePath)")

        // Create manager capability
        let managerCap = signer.capabilities.storage
            .issue<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(
                FlowTransactionSchedulerUtils.managerStoragePath
            )

        // Create fee provider capability
        let feeProviderCap = signer.capabilities.storage
            .issue<auth(FungibleToken.Withdraw) &FlowToken.Vault>(/storage/flowTokenVault)

        // Create counter cron configuration
        let cronConfig = CounterCronTransactionHandler.createCronConfig(
            intervalSeconds: intervalSeconds,
            baseTimestamp: baseTimestamp,
            maxExecutions: maxExecutions,
            schedulerManagerCap: managerCap,
            feeProviderCap: feeProviderCap,
            priority: pr,
            executionEffort: executionEffort
        )

        // Determine the first execution time
        let firstExecutionTime = cronConfig.getNextExecutionTime()

        let est = FlowTransactionScheduler.estimate(
            data: cronConfig,
            timestamp: firstExecutionTime,
            priority: pr,
            executionEffort: executionEffort
        )

        assert(
            est.timestamp != nil || pr == FlowTransactionScheduler.Priority.Low,
            message: est.error ?? "estimation failed"
        )

        // Withdraw fees
        let vaultRef = signer.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("missing FlowToken vault")
        let fees <- vaultRef.withdraw(amount: est.flowFee ?? 0.0) as! @FlowToken.Vault

        // Schedule through the manager
        let transactionId = manager.schedule(
            handlerCap: handlerCap ?? panic("Could not borrow handler capability"),
            data: cronConfig,
            timestamp: firstExecutionTime,
            priority: pr,
            executionEffort: executionEffort,
            fees: <-fees
        )

        log("Scheduled counter cron increment (id: ".concat(transactionId.toString()).concat(") first execution at ").concat(firstExecutionTime.toString()).concat(" with ").concat(intervalSeconds.toString()).concat("s intervals"))
        
        if let max = maxExecutions {
            log("Counter cron job will run for a maximum of ".concat(max.toString()).concat(" executions"))
        } else {
            log("Counter cron job will run indefinitely until cancelled")
        }
    }
}