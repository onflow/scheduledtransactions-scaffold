import "CounterCronTransactionHandler"
import "FlowTransactionScheduler"

transaction() {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue, PublishCapability) &Account) {
        // Save a handler resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: /storage/CounterCronTransactionHandler) == nil {
            let handler <- CounterCronTransactionHandler.createHandler()
            signer.storage.save(<-handler, to: /storage/CounterCronTransactionHandler)
        }

        // Validation/example that we can create an issue a handler capability with correct entitlement for FlowTransactionScheduler
        let _ = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/CounterCronTransactionHandler)
    
        // Issue a non-entitled public capability for the handler that is publicly accessible
        let publicCap = signer.capabilities.storage
            .issue<&{FlowTransactionScheduler.TransactionHandler}>(/storage/CounterCronTransactionHandler)
        // publish the capability
        signer.capabilities.publish(publicCap, at: /public/CounterCronTransactionHandler)
    }
}
