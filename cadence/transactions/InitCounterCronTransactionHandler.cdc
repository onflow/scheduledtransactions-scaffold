import "CounterCronTransactionHandler"
import "FlowTransactionScheduler"

transaction() {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue) &Account) {
        // Save a handler resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: /storage/CounterCronTransactionHandler) == nil {
            let handler <- CounterCronTransactionHandler.createHandler()
            signer.storage.save(<-handler, to: /storage/CounterCronTransactionHandler)
        }

        // Validation/example that we can create an issue a handler capability with correct entitlement for FlowTransactionScheduler
        let _ = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/CounterCronTransactionHandler)
    }
}
