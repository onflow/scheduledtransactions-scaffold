import "CounterLoopCallbackHandler"
import "FlowCallbackScheduler"

transaction() {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Save a handler resource to storage if not already present
        if signer.storage.borrow<&AnyResource>(from: /storage/CounterLoopCallbackHandler) == nil {
            let handler <- CounterLoopCallbackHandler.createHandler()
            signer.storage.save(<-handler, to: /storage/CounterLoopCallbackHandler)
        }

        // Validation/example that we can create an issue a handler capability with correct entitlement for FlowCallbackScheduler
        let _ = signer.capabilities.storage
            .issue<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>(/storage/CounterLoopCallbackHandler)
    }
}


