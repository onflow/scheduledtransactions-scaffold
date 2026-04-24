# AGENTS.md

Guidance for AI coding agents (Claude Code, Codex, Cursor, Copilot, others) working in this repo.
Loaded into agent context — kept concise.

## Overview

Cadence-only Flow starter for **Forte Scheduled Transactions** (FLIP-330). Ships a `Counter`
contract plus three example transaction handlers (one-shot, self-rescheduling loop, cron-style
precise-interval) and the transactions/scripts/tests to drive them on the Flow emulator. Intended
as a template — not a deployed production project (no `mainnet` / `testnet` deployments in
`flow.json`).

## Build and Test Commands

Prerequisite: **flow-cli 2.7.2** (required for Scheduled Transactions — see
`.cursor/rules/scheduledtransactions/agent-rules.mdc`). Verify with `flow version`.

```bash
# One-time setup
flow deps install                                # fetch Cadence dependencies per flow.json
printf "<HEX>" > emulator-account.pkey           # key file referenced by flow.json accounts.emulator-account

# Run
flow emulator --block-time 1s                    # scheduled txs require --block-time; 1s recommended
flow project deploy --network emulator           # deploys Counter + 3 handler contracts
flow test                                        # runs cadence/tests/*_test.cdc
```

Demo flows (full details in `EXAMPLE.md`, `EXAMPLE-LOOP.md`, `EXAMPLE-CRON.md`):

```bash
flow transactions send cadence/transactions/InitCounterTransactionHandler.cdc \
  --network emulator --signer emulator-account
flow transactions send cadence/transactions/ScheduleIncrementIn.cdc \
  --network emulator --signer emulator-account \
  --args-json '[{"type":"UFix64","value":"2.0"},{"type":"UInt8","value":"1"},{"type":"UInt64","value":"1000"},{"type":"Optional","value":null}]'
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

Loop and cron variants use `InitCounterLoop*` / `ScheduleIncrementInLoop.cdc` and
`InitCounterCron*` / `ScheduleIncrementInCron.cdc`. The cron variant replaces `delaySeconds` /
`transactionData` with `intervalSeconds: UFix64`, `maxExecutions: UInt64?` (nil = run forever),
and `baseTimestamp: UFix64?` (nil = anchor to now) — see `ScheduleIncrementInCron.cdc` lines 8–14.

## Architecture

```
flow.json                                     # string-import aliases + emulator deployments
cadence/
  contracts/
    Counter.cdc                               # access(all) contract with count: Int, increment/decrement
    CounterTransactionHandler.cdc             # Handler resource: FlowTransactionScheduler.TransactionHandler
    CounterLoopTransactionHandler.cdc         # reschedules itself on each execute
    CounterCronTransactionHandler.cdc         # fixed-interval, drift-free
  transactions/
    InitSchedulerManager.cdc                  # optional: pre-create FlowTransactionSchedulerUtils.Manager
    InitCounter{,Loop,Cron}TransactionHandler.cdc
    ScheduleIncrementIn{,Loop,Cron}.cdc       # estimate -> withdraw FlowToken fee -> manager.schedule
    IncrementCounter.cdc                      # manual increment (non-scheduled)
  scripts/GetCounter.cdc
  tests/
    Counter_test.cdc                          # deploys Counter only
    CounterTransactionHandler_test.cdc        # uses Test.serviceAccount(), Test.moveTime, asserts Scheduled event
.cursor/rules/scheduledtransactions/
  index.md agent-rules.mdc quick-checklist.md flip.md   # FLIP-330 spec + agent guidance
EXAMPLE.md EXAMPLE-LOOP.md EXAMPLE-CRON.md
```

Dependencies pinned in `flow.json` (string imports): `FlowTransactionScheduler`,
`FlowTransactionSchedulerUtils`, `FlowToken`, `FungibleToken`, `FlowFees`, `FlowStorageFees`,
`Burner`, `NonFungibleToken`, `MetadataViews`, `ViewResolver`, `FungibleTokenMetadataViews`.
Contract `testing` alias is `0x0000000000000007`; emulator account is `0xf8d6e0586b0a20c7`.

## Conventions and Gotchas

- **String imports only** — `import "FlowTransactionScheduler"`, never address imports
  (enforced by `.cursor/rules/scheduledtransactions/agent-rules.mdc` and visible across
  every `.cdc` file here).
- **Scheduling flow (see any `ScheduleIncrementIn*.cdc`)**: borrow-or-create
  `FlowTransactionSchedulerUtils.Manager` at `managerStoragePath` → issue handler capability
  with `auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}`
  entitlement → `FlowTransactionScheduler.estimate(...)` → withdraw `FlowToken.Vault` for
  `est.flowFee` → `manager.schedule(...)`.
- **Priority encoding**: user-facing `UInt8` — `0=High, 1=Medium, 2=Low` — converted to
  `FlowTransactionScheduler.Priority` enum inside transactions.
- **executionEffort**: minimum `10` (agent-rules.mdc); examples use `1000`.
- **`timestamp` must be in the future**; emulator examples use
  `getCurrentBlock().timestamp + delta`. `Low` priority may return `nil` timestamp from
  `estimate` and is tolerated via the `est.timestamp != nil || p == .Low` assertion.
- **`transactionData: AnyStruct?`** has a 100-byte cap (agent-rules.mdc). The cron variant
  does not take `transactionData`; instead it passes a `CronConfig` struct built via
  `CounterCronTransactionHandler.createCronConfig(...)`.
- **Emulator key must match**: `flow.json` points `emulator-account` at
  `emulator-account.pkey` (file-type key). Missing or mismatched file fails deploy/sign.
  The file is gitignored (`.gitignore`: `*.pkey`).
- **Manager auto-creates**: `ScheduleIncrementIn*.cdc` creates the manager on first use;
  `InitSchedulerManager.cdc` is only needed if you want to pre-publish the manager capability.
- **Tests use `Test.serviceAccount()`** (it has FLOW for fees) and `Test.moveTime(by:)`
  to advance past scheduled timestamps; assert on `FlowTransactionScheduler.Scheduled` events.
- **Emulator must be started with `--block-time`** for scheduled executions to fire
  (README + EXAMPLE*.md use `--block-time 1s`).

## Files Not to Modify

- `emulator-account.pkey` — local secret, gitignored; never commit.
- `imports/` — Cadence dependency cache populated by `flow deps install` (gitignored via
  `.gitignore`, but excluded from `.cursorignore`).
- `.cursor/rules/scheduledtransactions/flip.md` — vendored FLIP-330 spec; treat as reference.
