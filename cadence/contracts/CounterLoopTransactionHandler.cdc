import "FlowTransactionScheduler"
import "FlowToken"
import "FungibleToken"
import "Counter"

access(all) contract CounterLoopTransactionHandler {

    /// Handler resource that implements the Scheduled Transaction interface
    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            Counter.increment()
            let newCount = Counter.getCount()
            log("Transaction executed (id: ".concat(id.toString()).concat(") newCount: ").concat(newCount.toString()))

            // Determine delay for the next transaction (default 3 seconds if none provided)
            var delay: UFix64 = 3.0
            if data != nil {
                let t = data!.getType()
                if t.isSubtype(of: Type<UFix64>()) {
                    delay = data as! UFix64
                }
            }

            let future = getCurrentBlock().timestamp + delay
            let priority = FlowTransactionScheduler.Priority.Medium
            let executionEffort: UInt64 = 1000

            let estimate = FlowTransactionScheduler.estimate(
                data: data,
                timestamp: future,
                priority: priority,
                executionEffort: executionEffort
            )

            assert(
                estimate.timestamp != nil || priority == FlowTransactionScheduler.Priority.Low,
                message: estimate.error ?? "estimation failed"
            )

            // Ensure a handler resource exists in the contract account storage
            if CounterLoopTransactionHandler.account.storage.borrow<&AnyResource>(from: /storage/CounterLoopTransactionHandler) == nil {
                let handler <- CounterLoopTransactionHandler.createHandler()
                CounterLoopTransactionHandler.account.storage.save(<-handler, to: /storage/CounterLoopTransactionHandler)
            }

            // Withdraw FLOW fees from this contract's account vault
            let vaultRef = CounterLoopTransactionHandler.account.storage
                .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
                ?? panic("missing FlowToken vault on contract account")
            let fees <- vaultRef.withdraw(amount: estimate.flowFee ?? 0.0) as! @FlowToken.Vault

            // Issue a capability to the handler stored in this contract account
            let handlerCap = CounterLoopTransactionHandler.account.capabilities.storage
                .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(/storage/CounterLoopTransactionHandler)

            let receipt <- FlowTransactionScheduler.schedule(
                handlerCap: handlerCap,
                data: data,
                timestamp: future,
                priority: priority,
                executionEffort: executionEffort,
                fees: <-fees
            )

            log("Loop transaction id: ".concat(receipt.id.toString()).concat(" at ").concat(receipt.timestamp.toString()))
            
            destroy receipt
        }
    }

    /// Factory for the handler resource
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }
}


