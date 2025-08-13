import "FlowCallbackScheduler"
import "FlowToken"
import "FungibleToken"

/// Schedule an increment of the Counter with a relative delay in seconds
transaction(
    delaySeconds: UFix64,
    priority: UInt8,
    executionEffort: UInt64,
    callbackData: AnyStruct?
) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        let future = getCurrentBlock().timestamp + delaySeconds

        let pr = priority == 0
            ? FlowCallbackScheduler.Priority.High
            : priority == 1
                ? FlowCallbackScheduler.Priority.Medium
                : FlowCallbackScheduler.Priority.Low

        let est = FlowCallbackScheduler.estimate(
            data: callbackData,
            timestamp: future,
            priority: pr,
            executionEffort: executionEffort
        )

        assert(
            est.timestamp != nil || pr == FlowCallbackScheduler.Priority.Low,
            message: est.error ?? "estimation failed"
        )

        let vaultRef = signer.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("missing FlowToken vault")
        let fees <- vaultRef.withdraw(amount: est.flowFee ?? 0.0) as! @FlowToken.Vault

        let handlerCap = signer.capabilities.storage
            .issue<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>(/storage/CounterLoopCallbackHandler)

        let receipt = FlowCallbackScheduler.schedule(
            callback: handlerCap,
            data: callbackData,
            timestamp: future,
            priority: pr,
            executionEffort: executionEffort,
            fees: <-fees
        )

        log("Scheduled callback id: ".concat(receipt.id.toString()).concat(" at ").concat(receipt.timestamp.toString()))
    }
}


