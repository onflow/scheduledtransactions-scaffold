# Multiple Cron Jobs Example

This example shows how to create and manage multiple cron jobs of the same type using automatic job ID generation.

## Scenario: Multiple Counter Jobs

Let's create three different counter cron jobs with different schedules:

1. **Fast Counter**: Increments every 5 seconds, max 10 times
2. **Slow Counter**: Increments every 30 seconds, max 5 times  
3. **Hourly Counter**: Increments every hour, unlimited

## Option A: One-Step Create & Schedule (Recommended)

```bash
# Create and schedule fast counter: every 5 seconds, max 10 executions
flow transactions send cadence/transactions/CreateAndScheduleCounterCronJob.cdc 5.0 10 nil

# Create and schedule slow counter: every 30 seconds, max 5 executions
flow transactions send cadence/transactions/CreateAndScheduleCounterCronJob.cdc 30.0 5 nil

# Create and schedule hourly counter: every 3600 seconds (1 hour), unlimited
flow transactions send cadence/transactions/CreateAndScheduleCounterCronJob.cdc 3600.0 nil nil
```

## Option B: Two-Step Process (For Advanced Use Cases)

### Step 1: Initialize Jobs (Auto-Generated IDs)

```bash
# Initialize jobs - each gets a unique auto-generated ID like "cron_1698765432_12345"
flow transactions send cadence/transactions/InitCounterCronJob.cdc
flow transactions send cadence/transactions/InitCounterCronJob.cdc  
flow transactions send cadence/transactions/InitCounterCronJob.cdc
```

### Step 2: Schedule Using Generated IDs

```bash
# Use the job IDs from the transaction logs in Step 1
flow transactions send cadence/transactions/ScheduleCounterCronJob.cdc "cron_1698765432_12345" 5.0 10 nil
flow transactions send cadence/transactions/ScheduleCounterCronJob.cdc "cron_1698765433_12346" 30.0 5 nil
flow transactions send cadence/transactions/ScheduleCounterCronJob.cdc "cron_1698765434_12347" 3600.0 nil nil
```

## Monitor Jobs

```bash
# Check if a specific job exists (using the auto-generated ID)
flow scripts execute cadence/scripts/CheckCounterCronJob.cdc 0xf8d6e0586b0a20c7 "cron_1698765432_12345"

# Get detailed job information
flow scripts execute cadence/scripts/GetCounterCronJobInfo.cdc 0xf8d6e0586b0a20c7 "cron_1698765432_12345"

# Check counter value
flow scripts execute cadence/scripts/GetCounter.cdc
```

## Clean Up (Optional)

```bash
# Remove specific jobs when done (using auto-generated IDs)
flow transactions send cadence/transactions/RemoveCounterCronJob.cdc "cron_1698765432_12345"
flow transactions send cadence/transactions/RemoveCounterCronJob.cdc "cron_1698765433_12346"
flow transactions send cadence/transactions/RemoveCounterCronJob.cdc "cron_1698765434_12347"
```

## Storage Layout

Each job gets unique storage paths with auto-generated IDs:

```
/storage/CounterIncrementJob_cron_1698765432_12345     -> Job resource
/storage/CounterIncrementJob_cron_1698765433_12346     -> Job resource  
/storage/CounterIncrementJob_cron_1698765434_12347     -> Job resource

/public/CounterIncrementJob_cron_1698765432_12345      -> Job capability
/public/CounterIncrementJob_cron_1698765433_12346      -> Job capability
/public/CounterIncrementJob_cron_1698765434_12347      -> Job capability
```

## Expected Behavior

When running simultaneously:

- **Fast job** executes every 5 seconds (10 times total, then stops)
- **Slow job** executes every 30 seconds (5 times total, then stops)  
- **Hourly job** executes every hour (continues indefinitely)

All jobs increment the same counter, so you'll see rapid increments from the fast job, periodic increments from the slow job, and occasional increments from the hourly job.

## Log Output Examples

```
CounterCronJob [cron_1698765432_12345] executed (execution #1) newCount: 1
CounterCronJob [cron_1698765432_12345] executed (execution #2) newCount: 2
CounterCronJob [cron_1698765433_12346] executed (execution #1) newCount: 3
CounterCronJob [cron_1698765432_12345] executed (execution #3) newCount: 4
...
CounterCronJob [cron_1698765434_12347] executed (execution #1) newCount: 25
```

## Job ID Format

Auto-generated job IDs follow the pattern: `cron_{timestamp}_{blockHeight}`

- **cron_**: Prefix to identify the job type
- **timestamp**: Current block timestamp for uniqueness
- **blockHeight**: Current block height for additional uniqueness

Example: `cron_1698765432_12345`
- Created at timestamp 1698765432
- At block height 12345

## Real-World Use Cases

This pattern enables:

- **Monitoring**: Fast health checks + slow detailed reports
- **Backup Systems**: Primary backup every hour + quick incremental every 5 minutes
- **Data Processing**: Real-time processing + batch processing + archival processing
- **Notifications**: Urgent alerts + daily summaries + weekly reports

The job ID system makes it easy to manage different schedules for the same type of work!
