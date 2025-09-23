# Scheduled Transactions Demo: Counter Cron-like Increment

This example shows how to schedule a cron-like transaction that increments the `Counter` at precise intervals and verify it on the Flow Emulator using the scheduler manager.

Unlike the `CounterLoopTransactionHandler` which can drift over time, the `CounterCronTransactionHandler` calculates exact execution times to prevent drift.

## Files used

- `cadence/contracts/Counter.cdc`
- `cadence/contracts/CounterCronTransactionHandler.cdc`
- `cadence/transactions/InitSchedulerManager.cdc` (optional)
- `cadence/transactions/InitCounterCronTransactionHandler.cdc`
- `cadence/transactions/ScheduleIncrementInCron.cdc`
- `cadence/scripts/GetCounter.cdc`

## Prerequisites

```bash
flow deps install
```

## 1) Start the emulator with Scheduled Transactions

```bash
flow emulator --scheduled-transactions --block-time 1s
```

Keep this running. Open a new terminal for the next steps.

## 2) Deploy contracts

```bash
flow project deploy --network emulator
```

This deploys `Counter`, `CounterTransactionHandler`, `CounterLoopTransactionHandler`, and `CounterCronTransactionHandler` (see `flow.json`).

Expected output:

```
Counter -> 0xf8d6e0586b0a20c7
CounterTransactionHandler -> 0xf8d6e0586b0a20c7
CounterLoopTransactionHandler -> 0xf8d6e0586b0a20c7
CounterCronTransactionHandler -> 0xf8d6e0586b0a20c7

🎉 All contracts deployed successfully
```

## 3) Initialize the scheduler manager (if not already done)

The scheduler manager is now integrated into the scheduling transactions, so this step is optional. The manager will be created automatically when you schedule your first transaction.

If you want to initialize it separately:

```bash
flow transactions send cadence/transactions/InitSchedulerManager.cdc \
  --network emulator \
  --signer emulator-account
```

## 4) Initialize the counter cron handler capability

Saves a handler resource at `/storage/CounterCronTransactionHandler` and issues the correct capability for the scheduler.

```bash
flow transactions send cadence/transactions/InitCounterCronTransactionHandler.cdc \
  --network emulator \
  --signer emulator-account
```

Expected output:

```
Transaction ID: 2ee86605b4528dbff1e816a36b59e4e3d507a41c1979370f0cc87db0539f267a
Status          ✅ SEALED
```

## 5) Check the initial counter

```bash
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

Expected: `Result: 0`

## 6) Schedule a counter cron job to increment every 3 seconds (limited to 3 executions)

Uses `ScheduleIncrementInCron.cdc` to schedule transactions at precise 3-second intervals. The transaction will automatically create the scheduler manager if it doesn't exist.

```bash
flow transactions send cadence/transactions/ScheduleIncrementInCron.cdc \
  --network emulator \
  --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"3.0"},
    {"type":"UInt8","value":"1"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":{"type":"UInt64","value":"3"}},
    {"type":"Optional","value":null}
  ]'
```

Parameters explained:

- `intervalSeconds`: `3.0` - Execute every 3 seconds
- `priority`: `1` (Medium) - You can use `0` = High or `2` = Low
- `executionEffort`: `1000` - Must be >= 10 (1000 is a safe example value)
- `maxExecutions`: `3` - Run only 3 times (use `null` for unlimited)
- `baseTimestamp`: `null` - Use current time as base (or specify a UFix64 timestamp)

Expected output:

```
Transaction ID: e9cc49e5b0a29ade56c08aa60c45775ee852692ba48f313552a037d82a09026d
Status          ✅ SEALED
Events:
    - flow.StorageCapabilityControllerIssued (multiple for manager and handler capabilities)
    - A.f8d6e0586b0a20c7.FlowTransactionScheduler.Scheduled
```

## 7) Wait and verify the counter cron job executes

Wait a few seconds for the transactions to execute, then check the counter:

```bash
sleep 5
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

Expected: `Result: 3` (since we scheduled 3 executions)

The counter cron job automatically executed 3 times at precise 3-second intervals and then stopped because it reached the maximum execution limit. Each execution uses the scheduler manager to reschedule the next execution.

## 8) Schedule an unlimited counter cron job to increment every 10 seconds

```bash
flow transactions send cadence/transactions/ScheduleIncrementInCron.cdc \
  --network emulator \
  --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"10.0"},
    {"type":"UInt8","value":"1"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":null},
    {"type":"Optional","value":null}
  ]'
```

This will run indefinitely until manually cancelled. The scheduler manager handles all the transaction scheduling and tracking.

## 9) Monitor the counter over time

Check the counter value periodically to see it increment at precise intervals:

```bash
# Check current value
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator

# Wait 10 seconds and check again
sleep 10
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator

# Wait another 10 seconds
sleep 10
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

You should see the counter increment exactly at the scheduled intervals.

## 10) Schedule a counter cron job starting at a specific time (Advanced)

To start a counter cron job at a specific future timestamp, you can calculate a future time and use it as the base timestamp. This is useful for scheduling jobs to start at precise times.

**Note**: This example is more complex and mainly for advanced use cases. For most applications, using `null` for `baseTimestamp` (immediate start) is recommended.

**Multi-line version:**

```bash
# Create a temporary script to get current timestamp
echo 'access(all) fun main(): UFix64 { return getCurrentBlock().timestamp }' > temp_timestamp.cdc

# Get current Flow block timestamp and add 10 seconds
CURRENT_TIME=$(flow scripts execute temp_timestamp.cdc --network emulator | grep "Result:" | awk '{print $2}')
FUTURE_TIME=$(echo "$CURRENT_TIME + 10.0" | bc)

# Schedule with future timestamp (start in 10 seconds, then every 5 seconds for 2 executions)
flow transactions send cadence/transactions/ScheduleIncrementInCron.cdc \
  --network emulator \
  --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"5.0"},
    {"type":"UInt8","value":"1"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":{"type":"UInt64","value":"2"}},
    {"type":"Optional","value":{"type":"UFix64","value":"'$FUTURE_TIME'"}}
  ]'

# Clean up temp file
rm temp_timestamp.cdc
```

**Single-line version (copy and execute):**

```bash
echo 'access(all) fun main(): UFix64 { return getCurrentBlock().timestamp }' > temp_timestamp.cdc && CURRENT_TIME=$(flow scripts execute temp_timestamp.cdc --network emulator | grep "Result:" | awk '{print $2}') && FUTURE_TIME=$(echo "$CURRENT_TIME + 10.0" | bc) && flow transactions send cadence/transactions/ScheduleIncrementInCron.cdc --network emulator --signer emulator-account --args-json '[{"type":"UFix64","value":"5.0"},{"type":"UInt8","value":"1"},{"type":"UInt64","value":"1000"},{"type":"Optional","value":{"type":"UInt64","value":"2"}},{"type":"Optional","value":{"type":"UFix64","value":"'$FUTURE_TIME'"}}]' && rm temp_timestamp.cdc
```

This will wait 10 seconds before starting, then execute every 5 seconds for 2 times.

**Simpler Alternative**: For most use cases, just use `null` for `baseTimestamp`:

```bash
# Immediate start with 5-second intervals, 2 executions
flow transactions send cadence/transactions/ScheduleIncrementInCron.cdc \
  --network emulator \
  --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"5.0"},
    {"type":"UInt8","value":"1"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":{"type":"UInt64","value":"2"}},
    {"type":"Optional","value":null}
  ]'
```

## Key Differences from CounterLoopTransactionHandler

### CounterLoopTransactionHandler

- Schedules next transaction with simple delay from current time
- May drift over time due to execution delays
- Uses: `getCurrentBlock().timestamp + delay`
- Uses scheduler manager for transaction management

### CounterCronTransactionHandler

- Schedules transactions at precise intervals from a base timestamp
- Prevents drift by calculating exact next execution time
- Uses: `baseTimestamp + (intervals * intervalSeconds)`
- Supports limited executions with `maxExecutions`
- Supports custom base timestamps for precise scheduling
- Uses scheduler manager for transaction management

## Use Cases

1. **Every Minute**: `intervalSeconds: 60.0` for precise minute-based execution
2. **Every Hour**: `intervalSeconds: 3600.0` for hourly tasks
3. **Limited Runs**: Set `maxExecutions` for finite job sequences
4. **Precise Timing**: Use `baseTimestamp` to align with specific clock times

## Advanced Examples

### Every Minute (60 seconds)

```bash
flow transactions send cadence/transactions/ScheduleIncrementInCron.cdc \
  --network emulator \
  --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"60.0"},
    {"type":"UInt8","value":"1"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":null},
    {"type":"Optional","value":null}
  ]'
```

### Every Hour (3600 seconds) with limit

```bash
flow transactions send cadence/transactions/ScheduleIncrementInCron.cdc \
  --network emulator \
  --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"3600.0"},
    {"type":"UInt8","value":"2"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":{"type":"UInt64","value":"24"}},
    {"type":"Optional","value":null}
  ]'
```

This runs every hour for 24 hours (1 day) with low priority to save on fees.

## Troubleshooting

- **Invalid timestamp error**: Ensure `baseTimestamp` (if provided) is in the future
- **Missing FlowToken vault**: On emulator the default account has a vault; if you use a custom account, initialize it accordingly
- **Manager not found**: The scheduler manager is automatically created in the scheduling transactions. If you see this error, ensure you're using the latest transaction files
- **Transaction not executing**: Check that `intervalSeconds` is reasonable and the emulator is running with `--scheduled-transactions`
- **Drift concerns**: Unlike simple delay-based scheduling, counter cron transactions calculate exact times to prevent drift
- **Fee management**: Each transaction execution requires fees; ensure sufficient FLOW balance for long-running jobs
- **Cron not continuing**: Ensure the handler has access to the manager capability and fee provider capability, which are passed in the CronConfig
- **More docs**: see `/.cursor/rules/scheduledtransactions/index.md`, `agent-rules.mdc`, and `flip.md` in this repo

## Complete Test Sequence

Here's a complete test you can run to verify everything works:

```bash
# 1. Start emulator (in background)
flow emulator --scheduled-transactions --block-time 1s &

# 2. Wait for startup, then deploy
sleep 3
flow project deploy --network emulator

# 3. Initialize counter cron handler
flow transactions send cadence/transactions/InitCounterCronTransactionHandler.cdc \
  --network emulator --signer emulator-account

# 4. Check initial counter
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
# Expected: Result: 0

# 5. Schedule 3-second intervals, 3 executions
flow transactions send cadence/transactions/ScheduleIncrementInCron.cdc \
  --network emulator --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"3.0"},
    {"type":"UInt8","value":"1"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":{"type":"UInt64","value":"3"}},
    {"type":"Optional","value":null}
  ]'

# 6. Wait and verify
sleep 12
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
# Expected: Result: 3
```
