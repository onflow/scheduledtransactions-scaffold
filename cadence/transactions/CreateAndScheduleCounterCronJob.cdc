import "FlowCallbackScheduler"
import "FlowToken"
import "FungibleToken"
import "CronJobScheduler"
import "CounterCronJob"

/// Transaction to create and immediately schedule a CounterCronJob with auto-generated job ID
/// @param intervalSeconds: How often to execute (in seconds)
/// @param maxExecutions: Maximum number of executions (nil for unlimited)
/// @param baseTimestamp: When to start (nil for now)
transaction(intervalSeconds: UFix64, maxExecutions: UInt64?, baseTimestamp: UFix64?) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Generate a unique job ID automatically
        let jobId = CounterCronJob.generateUniqueJobId()
        
        // Create fee payment capability for the user's FlowToken vault
        let feePaymentCapability = signer.capabilities.storage
            .issue<auth(FungibleToken.Withdraw) &{FungibleToken.Provider}>(/storage/flowTokenVault)
        
        // Create a new CounterIncrementJob resource with fee payment capability and auto-generated job ID
        let counterJob <- CounterCronJob.createCounterIncrementJob(
            feePaymentCapability: feePaymentCapability,
            jobId: jobId
        )
        let storagePath = counterJob.getStoragePath()
        let publicPath = counterJob.getPublicPath()
        
        // Save it to the user's storage
        signer.storage.save(<-counterJob, to: storagePath)
        
        // Publish a capability for the CronJobScheduler to use
        let cap = signer.capabilities.storage.issue<&{CronJobScheduler.CronJobPublic}>(storagePath)
        signer.capabilities.publish(cap, at: publicPath)
        
        // Create cron configuration
        let cronConfig = CronJobScheduler.createCronConfig(
            intervalSeconds: intervalSeconds,
            baseTimestamp: baseTimestamp,
            maxExecutions: maxExecutions,
            jobPublicPath: publicPath,
            jobAccountAddress: signer.address
        )

        // Schedule the cron job immediately
        CronJobScheduler.scheduleCronJob(config: cronConfig)

        log("CounterCronJob created and scheduled with auto-generated ID: ".concat(jobId))
        log("Interval: ".concat(intervalSeconds.toString()).concat(" seconds"))
        if let max = maxExecutions {
            log("Max executions: ".concat(max.toString()))
        } else {
            log("Max executions: unlimited")
        }
        log("Storage path: ".concat(storagePath.toString()))
        log("Public path: ".concat(publicPath.toString()))
    }
}
