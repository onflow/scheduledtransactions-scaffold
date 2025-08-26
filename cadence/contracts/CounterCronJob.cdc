import "Counter"
import "CronJobScheduler"
import "FlowToken"
import "FungibleToken"

/// A concrete implementation of CronJob that increments the Counter
access(all) contract CounterCronJob {

    /// Generate a unique job ID using current block timestamp and height
    access(all) fun generateUniqueJobId(): String {
        let timestamp = getCurrentBlock().timestamp
        let height = getCurrentBlock().height
        return "cron_".concat(timestamp.toString()).concat("_").concat(height.toString())
    }

    /// CronJob implementation that increments the counter on each execution
    access(all) resource CounterIncrementJob: CronJobScheduler.CronJob, CronJobScheduler.CronJobPublic {
        /// Capability to withdraw fees from the user's vault
        access(self) let feePaymentCapability: Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>
        /// Unique identifier for this job instance
        access(self) let jobId: String
        
        init(feePaymentCapability: Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>, jobId: String) {
            self.feePaymentCapability = feePaymentCapability
            self.jobId = jobId
        }
        
        /// Custom logic to execute on each cron run
        access(all) fun executeCronJob(executionCount: UInt64) {
            Counter.increment()
            let newCount = Counter.getCount()
            log("CounterCronJob [".concat(self.jobId).concat("] executed (execution #").concat(executionCount.toString()).concat(") newCount: ").concat(newCount.toString()))
        }
        
        /// Withdraw fees for the next execution from the user's vault
        access(all) fun withdrawFeesForNextExecution(amount: UFix64): @FlowToken.Vault {
            let vaultRef = self.feePaymentCapability.borrow()
                ?? panic("Cannot borrow fee payment capability")
            return <- vaultRef.withdraw(amount: amount) as! @FlowToken.Vault
        }
        
        /// Return the unique job identifier
        access(all) fun getJobId(): String {
            return self.jobId
        }
        
        /// Return the storage path for this job (unique per job ID)
        access(all) fun getStoragePath(): StoragePath {
            return StoragePath(identifier: "CounterIncrementJob_".concat(self.jobId))!
        }
        
        /// Return the public path for capabilities (unique per job ID)
        access(all) fun getPublicPath(): PublicPath {
            return PublicPath(identifier: "CounterIncrementJob_".concat(self.jobId))!
        }
    }

    /// Factory function to create a new CounterIncrementJob
    access(all) fun createCounterIncrementJob(
        feePaymentCapability: Capability<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>,
        jobId: String
    ): @CounterIncrementJob {
        return <- create CounterIncrementJob(feePaymentCapability: feePaymentCapability, jobId: jobId)
    }
}
