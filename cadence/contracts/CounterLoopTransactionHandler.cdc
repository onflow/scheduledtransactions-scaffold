import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"
import "FlowToken"
import "FungibleToken"
import "Counter"

access(all) contract CounterLoopTransactionHandler {

    /// Struct to hold loop configuration data
    access(all) struct LoopConfig {
        access(all) let delay: UFix64
        access(all) let schedulerManagerCap: Capability<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>
        access(all) let feeProviderCap: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>
        access(all) let priority: FlowTransactionScheduler.Priority
        access(all) let executionEffort: UInt64

        init(
            delay: UFix64,
            schedulerManagerCap: Capability<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>,
            feeProviderCap: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>,
            priority: FlowTransactionScheduler.Priority,
            executionEffort: UInt64
        ) {
            self.delay = delay
            self.schedulerManagerCap = schedulerManagerCap
            self.feeProviderCap = feeProviderCap
            self.priority = priority
            self.executionEffort = executionEffort
        }
    }

    /// Handler resource that implements the Scheduled Transaction interface
    access(all) resource Handler: FlowTransactionScheduler.TransactionHandler {
        access(FlowTransactionScheduler.Execute) fun executeTransaction(id: UInt64, data: AnyStruct?) {
            Counter.increment()
            let newCount = Counter.getCount()
            log("Transaction executed (id: ".concat(id.toString()).concat(") newCount: ").concat(newCount.toString()))

            // Extract loop configuration from transaction data
            let loopConfig = data as! LoopConfig? ?? panic("LoopConfig data is required")

            let future = getCurrentBlock().timestamp + loopConfig.delay

            let estimate = FlowTransactionScheduler.estimate(
                data: data,
                timestamp: future,
                priority: loopConfig.priority,
                executionEffort: loopConfig.executionEffort
            )

            assert(
                estimate.timestamp != nil || loopConfig.priority == FlowTransactionScheduler.Priority.Low,
                message: estimate.error ?? "estimation failed"
            )

            // Borrow fee provider and withdraw fees
            let feeVault = loopConfig.feeProviderCap.borrow()
                ?? panic("Cannot borrow fee provider capability")
            let fees <- feeVault.withdraw(amount: estimate.flowFee ?? 0.0)

            // Schedule next transaction through the manager
            let schedulerManager = loopConfig.schedulerManagerCap.borrow()
                ?? panic("Cannot borrow scheduler manager capability")
            
            // Use scheduleByHandler since this handler has already been used
            let transactionId = schedulerManager.scheduleByHandler(
                handlerTypeIdentifier: self.getType().identifier,
                handlerUUID: self.uuid,
                data: data,
                timestamp: future,
                priority: loopConfig.priority,
                executionEffort: loopConfig.executionEffort,
                fees: <-fees as! @FlowToken.Vault
            )

            log("Loop transaction id: ".concat(transactionId.toString()).concat(" scheduled at ").concat(future.toString()))
        }
    }

    /// Factory for the handler resource
    access(all) fun createHandler(): @Handler {
        return <- create Handler()
    }

    /// Helper function to create a loop configuration
    access(all) fun createLoopConfig(
        delay: UFix64,
        schedulerManagerCap: Capability<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>,
        feeProviderCap: Capability<auth(FungibleToken.Withdraw) &FlowToken.Vault>,
        priority: FlowTransactionScheduler.Priority,
        executionEffort: UInt64
    ): LoopConfig {
        return LoopConfig(
            delay: delay,
            schedulerManagerCap: schedulerManagerCap,
            feeProviderCap: feeProviderCap,
            priority: priority,
            executionEffort: executionEffort
        )
    }
}


