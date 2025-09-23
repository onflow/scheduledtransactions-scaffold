import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"
import "CounterLoopTransactionHandler"

/// Schedule a looping increment of the Counter with a delay between each execution
transaction(
    delaySeconds: UFix64,
    priority: UInt8,
    executionEffort: UInt64,
    transactionData: AnyStruct?
) {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue) &Account) {
        let future = getCurrentBlock().timestamp + delaySeconds

        let pr = priority == 0
            ? FlowTransactionScheduler.Priority.High
            : priority == 1
                ? FlowTransactionScheduler.Priority.Medium
                : FlowTransactionScheduler.Priority.Low

        // Get handler capability
        let handlerCap = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/CounterLoopTransactionHandler)

        // Save a manager resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: FlowTransactionSchedulerUtils.managerStoragePath) == nil {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)
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

        // Create loop configuration
        let loopConfig = CounterLoopTransactionHandler.createLoopConfig(
            delay: delaySeconds,
            schedulerManagerCap: managerCap,
            feeProviderCap: feeProviderCap,
            priority: pr,
            executionEffort: executionEffort
        )

        let est = FlowTransactionScheduler.estimate(
            data: loopConfig,
            timestamp: future,
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
            handlerCap: handlerCap,
            data: loopConfig,
            timestamp: future,
            priority: pr,
            executionEffort: executionEffort,
            fees: <-fees
        )

        log("Scheduled loop transaction id: ".concat(transactionId.toString()).concat(" at ").concat(future.toString()).concat(" with delay: ").concat(delaySeconds.toString()))
    }
}


