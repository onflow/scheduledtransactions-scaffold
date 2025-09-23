import "FlowTransactionSchedulerUtils"

transaction() {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue) &Account) {
        // Save a manager resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: FlowTransactionSchedulerUtils.managerStoragePath) == nil {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)
        }

        // Validation/example that we can create an issue a manager capability with correct entitlement
        let _ = signer.capabilities.storage
            .issue<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(FlowTransactionSchedulerUtils.managerStoragePath)
    }
}