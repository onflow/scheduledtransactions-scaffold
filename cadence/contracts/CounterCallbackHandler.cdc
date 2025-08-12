import "FlowCallbackScheduler"
import "Counter"

access(all) contract CounterCallbackHandler {

    /// Handler resource that implements the Scheduled Callback interface
    access(all) resource Handler: FlowCallbackScheduler.CallbackHandler {
        access(FlowCallbackScheduler.Execute) fun executeCallback(id: UInt64, data: AnyStruct?) {
            Counter.increment()
            let newCount = Counter.getCount()
            log("Callback executed (id: ".concat(id.toString()).concat(") newCount: ").concat(newCount.toString()))
        }
    }

    /// Factory for the handler resource
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }
}


