import "CounterCallbackHandler"
import "FlowCallbackScheduler"

transaction() {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Save a handler resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: /storage/CounterCallbackHandler) == nil {
            let handler <- CounterCallbackHandler.createHandler()
            signer.storage.save(<-handler, to: /storage/CounterCallbackHandler)
        }

        // Issue a handler capability with correct entitlement for FlowCallbackScheduler
        let _ = signer.capabilities.storage
            .issue<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>(/storage/CounterCallbackHandler)
    }
}


