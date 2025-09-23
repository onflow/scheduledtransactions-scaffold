import "CounterLoopTransactionHandler"
import "FlowTransactionScheduler"

transaction() {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue) &Account) {
        // Save a handler resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: /storage/CounterLoopTransactionHandler) == nil {
            let handler <- CounterLoopTransactionHandler.createHandler()
            signer.storage.save(<-handler, to: /storage/CounterLoopTransactionHandler)
        }

        // Validation/example that we can create an issue a handler capability with correct entitlement for FlowTransactionScheduler
        let _ = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/CounterLoopTransactionHandler)
    }
}


