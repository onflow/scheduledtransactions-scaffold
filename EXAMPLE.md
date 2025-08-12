# Scheduled Callbacks Demo: Increment the Counter
This example shows how to schedule a callback that increments the `Counter` in the near future and verify it on the Flow Emulator.
## Files used

- `cadence/contracts/Counter.cdc`
- `cadence/contracts/CounterCallbackHandler.cdc`
- `cadence/transactions/InitCounterCallbackHandler.cdc`
- `cadence/transactions/ScheduleIncrementIn.cdc`
- `cadence/scripts/GetCounter.cdc`

## Prerequisites

```bash
flow deps install
```

## 1) Start the emulator with Scheduled Callbacks

```bash
flow emulator --scheduled-callbacks --block-time 1s
```

Keep this running. Open a new terminal for the next steps.

## 2) Deploy contracts

```bash
flow project deploy --network emulator
```

This deploys `Counter` and `CounterCallbackHandler` (see `flow.json`).

## 3) Initialize the handler capability

Saves a handler resource at `/storage/CounterCallbackHandler` and issues the correct capability for the scheduler.

```bash
flow transactions send cadence/transactions/InitCounterCallbackHandler.cdc \
  --network emulator \
  --signer emulator-account
```

## 4) Check the initial counter

```bash
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

Expected: `Result: 0`

## 5) Schedule an increment in ~2 seconds

Uses `ScheduleIncrementIn.cdc` to compute a future timestamp relative to the current block.

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
- With `--block-time 1s`, blocks seal automatically; after ~3 seconds your scheduled callback should execute.

## 6) Verify the counter incremented

```bash
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

Expected: `Result: 1`

## Troubleshooting

- Invalid timestamp error: use `ScheduleIncrementIn.cdc` with a small delay (e.g., 2.0) so the timestamp is in the future.
- Missing FlowToken vault: on emulator the default account has a vault; if you use a custom account, initialize it accordingly.
- More docs: see `/.cursor/rules/scheduledcallbacks/index.md`, `agent-rules.mdc`, and `flip.md` in this repo.
