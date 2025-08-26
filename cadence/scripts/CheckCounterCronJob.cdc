import "CounterCronJob"
import "CronJobScheduler"

/// Script to check if a specific CounterCronJob exists in an account
/// @param account: The account address to check
/// @param jobId: The job ID to check for
access(all) fun main(account: Address, jobId: String): Bool {
    let accountRef = getAccount(account)
    
    // Construct the storage path for this specific job ID
    let storagePath = StoragePath(identifier: "CounterIncrementJob_".concat(jobId))!
    
    // Check if the resource exists at this path by checking the public capability
    let publicPath = PublicPath(identifier: "CounterIncrementJob_".concat(jobId))!
    let jobCap = accountRef.capabilities.get<&{CronJobScheduler.CronJobPublic}>(publicPath)
    return jobCap.borrow() != nil
}
