import "CounterCronJob"
import "CronJobScheduler"

/// Transaction to remove a CounterCronJob from the signer's account
/// @param jobId: Unique identifier for the cron job to remove
transaction(jobId: String) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Construct the storage and public paths for this specific job ID
        let storagePath = StoragePath(identifier: "CounterIncrementJob_".concat(jobId))!
        let publicPath = PublicPath(identifier: "CounterIncrementJob_".concat(jobId))!
        
        // Remove the capability first
        let removedCap = signer.capabilities.unpublish(publicPath)
        log("Capability removed: ".concat(removedCap != nil ? "success" : "not found"))
        
        // Load and destroy the resource
        let cronJob <- signer.storage.load<@CounterCronJob.CounterIncrementJob>(from: storagePath)
        if cronJob == nil {
            panic("CounterCronJob with ID '".concat(jobId).concat("' not found"))
        }
        
        destroy cronJob
        
        log("CounterCronJob '".concat(jobId).concat("' removed successfully"))
        log("Storage path cleared: ".concat(storagePath.toString()))
        log("Public capability removed: ".concat(publicPath.toString()))
        log("Note: Any scheduled callbacks for this job will fail on next execution")
    }
}
