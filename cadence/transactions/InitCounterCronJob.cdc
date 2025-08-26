import "CounterCronJob"
import "CronJobScheduler"
import "FlowToken"
import "FungibleToken"

/// Transaction to initialize a CounterCronJob in the signer's account with auto-generated job ID
transaction {
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
        
        // Note: No need to check for conflicts since ID is guaranteed unique by timestamp + block height
        
        // Save it to the user's storage
        signer.storage.save(<-counterJob, to: storagePath)
        
        // Publish a capability for the CronJobScheduler to use
        let cap = signer.capabilities.storage.issue<&{CronJobScheduler.CronJobPublic}>(storagePath)
        signer.capabilities.publish(cap, at: publicPath)
        
        log("CounterCronJob created with auto-generated ID: ".concat(jobId))
        log("Storage path: ".concat(storagePath.toString()))
        log("Public path: ".concat(publicPath.toString()))
        log("Use this Job ID for scheduling: ".concat(jobId))
    }
}
