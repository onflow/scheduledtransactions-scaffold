# Scheduled Transactions Demo: Increment the Counter Continuously

This example shows how to schedule a transaction that increments the `Counter` in the near future and verify it on the Flow Emulator. It starts an infinite loop incrementing the counter by rescheduling a new one in the transaction handler using the scheduler manager.

## Files used

- `cadence/contracts/Counter.cdc`
- `cadence/contracts/CounterLoopTransactionHandler.cdc`
- `cadence/transactions/InitSchedulerManager.cdc` (optional)
- `cadence/transactions/InitCounterLoopTransactionHandler.cdc`
- `cadence/transactions/ScheduleIncrementInLoop.cdc`
- `cadence/scripts/GetCounter.cdc`

## Prerequisites

```bash
flow deps install
```

## 1) Start the emulator with Scheduled Transactions

```bash
flow emulator --block-time 1s
```

Keep this running. Open a new terminal for the next steps.

## 2) Deploy contracts

```bash
flow project deploy --network emulator
```

This deploys `Counter` and `CounterLoopTransactionHandler` (see `flow.json`).

## 3) Initialize the scheduler manager (if not already done)

The scheduler manager is now integrated into the scheduling transactions, so this step is optional. The manager will be created automatically when you schedule your first transaction.

If you want to initialize it separately:

```bash
flow transactions send cadence/transactions/InitSchedulerManager.cdc \
  --network emulator \
  --signer emulator-account
```

## 4) Initialize the handler capability

Saves a handler resource at `/storage/CounterLoopTransactionHandler` and issues the correct capability for the scheduler.

```bash
flow transactions send cadence/transactions/InitCounterLoopTransactionHandler.cdc \
  --network emulator \
  --signer emulator-account
```

## 5) Check the initial counter

```bash
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

Expected: `Result: 0`

## 6) Schedule a looping increment starting in ~2 seconds

Uses `ScheduleIncrementInLoop.cdc` to compute a future timestamp relative to the current block. The loop handler will automatically reschedule itself using the scheduler manager.

```bash
flow transactions send cadence/transactions/ScheduleIncrementInLoop.cdc \
  --network emulator \
  --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"2.0"},
    {"type":"UInt8","value":"1"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":null}
  ]'
```

Notes:

- Priority `1` = Medium. You can use `0` = High or `2` = Low.
- `executionEffort` must be >= 10 (1000 is a safe example value).
- With `--block-time 1s`, blocks seal automatically; after ~3 seconds your scheduled transaction should execute.
- The delay parameter (2.0) controls both the initial delay and the delay between subsequent executions.
- The handler uses the scheduler manager to reschedule itself after each execution.

Now when the transaction is executed, it automatically schedules another transaction with the same delay.

## 7) Verify the counter keeps incrementing

Due to the fact that each time we run the scheduled transaction we are rescheduling the transaction in the future, we can see that the counter is automatically updated each 2 seconds (as specified in the delay parameter).

```bash
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

Expected: `Result: >= 1`

## Troubleshooting

- Invalid timestamp error: use `ScheduleIncrementInLoop.cdc` with a small delay (e.g., 2.0) so the timestamp is in the future.
- Missing FlowToken vault: on emulator the default account has a vault; if you use a custom account, initialize it accordingly.
- Manager not found: The scheduler manager is automatically created in the scheduling transactions. If you see this error, ensure you're using the latest transaction files.
- Loop not continuing: Ensure the handler has access to the manager capability and fee provider capability, which are passed in the LoopConfig.
- More docs: see `/.cursor/rules/scheduledtransactions/index.md`, `agent-rules.mdc`, and `flip.md` in this repo.
