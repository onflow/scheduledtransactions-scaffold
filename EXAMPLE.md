# Scheduled Transactions Demo: Increment the Counter

This example shows how to schedule a transaction that increments the `Counter` in the near future and verify it on the Flow Emulator using the scheduler manager.

## Files used

- `cadence/contracts/Counter.cdc`
- `cadence/contracts/CounterTransactionHandler.cdc`
- `cadence/transactions/InitSchedulerManager.cdc`
- `cadence/transactions/InitCounterTransactionHandler.cdc`
- `cadence/transactions/ScheduleIncrementIn.cdc`
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

This deploys `Counter` and `CounterTransactionHandler` (see `flow.json`).

## 3) Initialize the scheduler manager (if not already done)

The scheduler manager is now integrated into the scheduling transactions, so this step is optional. The manager will be created automatically when you schedule your first transaction.

If you want to initialize it separately:

```bash
flow transactions send cadence/transactions/InitSchedulerManager.cdc \
  --network emulator \
  --signer emulator-account
```

## 4) Initialize the handler capability

Saves a handler resource at `/storage/CounterTransactionHandler` and issues the correct capability for the scheduler.

```bash
flow transactions send cadence/transactions/InitCounterTransactionHandler.cdc \
  --network emulator \
  --signer emulator-account
```

## 5) Check the initial counter

```bash
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

Expected: `Result: 0`

## 6) Schedule an increment in ~2 seconds

Uses `ScheduleIncrementIn.cdc` to compute a future timestamp relative to the current block. This transaction will automatically create the scheduler manager if it doesn't exist.

```bash
flow transactions send cadence/transactions/ScheduleIncrementIn.cdc \
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
- The transaction uses the scheduler manager to track and manage the scheduled transaction.

## 7) Verify the counter incremented

```bash
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

Expected: `Result: 1`

## Troubleshooting

- Invalid timestamp error: use `ScheduleIncrementIn.cdc` with a small delay (e.g., 2.0) so the timestamp is in the future.
- Missing FlowToken vault: on emulator the default account has a vault; if you use a custom account, initialize it accordingly.
- Manager not found: The scheduler manager is automatically created in the scheduling transactions. If you see this error, ensure you're using the latest transaction files.
- More docs: see `/.cursor/rules/scheduledtransactions/index.md`, `agent-rules.mdc`, and `flip.md` in this repo.
