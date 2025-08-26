import "CounterCronJob"
import "CronJobScheduler"

/// Script to get information about a specific CounterCronJob
/// @param account: The account address to check
/// @param jobId: The job ID to get info for
access(all) fun main(account: Address, jobId: String): {String: String?} {
    let accountRef = getAccount(account)
    let result: {String: String?} = {}
    
    // Construct the paths for this specific job ID
    let storagePath = StoragePath(identifier: "CounterIncrementJob_".concat(jobId))!
    let publicPath = PublicPath(identifier: "CounterIncrementJob_".concat(jobId))!
    
    // Check if the job exists via public capability
    let jobCap = accountRef.capabilities.get<&{CronJobScheduler.CronJobPublic}>(publicPath)
    let jobRef = jobCap.borrow()
    
    if jobRef != nil {
        result["exists"] = "true"
        result["jobId"] = jobRef!.getJobId()
        result["storagePath"] = storagePath.toString()
        result["publicPath"] = publicPath.toString()
        result["account"] = account.toString()
    } else {
        result["exists"] = "false"
        result["jobId"] = nil
        result["storagePath"] = nil
        result["publicPath"] = nil
        result["account"] = account.toString()
    }
    
    return result
}
