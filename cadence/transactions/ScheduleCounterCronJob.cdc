import "FlowCallbackScheduler"
import "FlowToken"
import "FungibleToken"
import "CronJobScheduler"

/// Transaction to schedule a counter cron job with specified interval and limits
/// @param jobId: Unique identifier for the cron job to schedule
/// @param intervalSeconds: How often to execute (in seconds)
/// @param maxExecutions: Maximum number of executions (nil for unlimited)
/// @param baseTimestamp: When to start (nil for now)
transaction(jobId: String, intervalSeconds: UFix64, maxExecutions: UInt64?, baseTimestamp: UFix64?) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        // Construct the public path for this specific job ID
        let jobPublicPath = PublicPath(identifier: "CounterIncrementJob_".concat(jobId))!
        
        // Verify the job exists by checking if the capability is available
        let jobCap = signer.capabilities.get<&{CronJobScheduler.CronJobPublic}>(jobPublicPath)
        if jobCap.borrow() == nil {
            panic("CounterCronJob with ID '".concat(jobId).concat("' not found. Initialize it first."))
        }
        
        // Create cron configuration
        let cronConfig = CronJobScheduler.createCronConfig(
            intervalSeconds: intervalSeconds,
            baseTimestamp: baseTimestamp,
            maxExecutions: maxExecutions,
            jobPublicPath: jobPublicPath,
            jobAccountAddress: signer.address
        )

        // Schedule the cron job (fees will be automatically withdrawn from user's vault via CronJob resource)
        CronJobScheduler.scheduleCronJob(config: cronConfig)

        log("Counter cron job '".concat(jobId).concat("' scheduled successfully!"))
        log("Interval: ".concat(intervalSeconds.toString()).concat(" seconds"))
        if let max = maxExecutions {
            log("Max executions: ".concat(max.toString()))
        } else {
            log("Max executions: unlimited")
        }
    }
}
