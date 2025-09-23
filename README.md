# 👋 Welcome to the Scheduled Transactions Scaffold

This project is a starting point for you to test out Scheduled Transactions on the Flow Blockchain. It comes with example contracts, scripts, transactions, and tests to help you get started.

## What are Scheduled Transactions?

Scheduled Transactions let smart contracts execute code at (or after) a chosen time without an external transaction. You schedule work now; the network executes it later. This enables recurring jobs, deferred actions, and autonomous workflows.

Core pieces:

- Capability to a handler implementing `FlowTransactionScheduler.TransactionHandler`
- Parameters: `timestamp`, `priority`, `executionEffort`, `fees`, optional `transactionData`
- Estimate first (`FlowTransactionScheduler.estimate`), then schedule using the scheduler manager
- The scheduler manager (`FlowTransactionSchedulerUtils.Manager`) helps track and manage scheduled transactions

## 🔨 Getting Started

Here are some essential resources to help you hit the ground running:

- **[Flow Documentation](https://developers.flow.com/)** - The official Flow Documentation is a great starting point to start learning about about [building](https://developers.flow.com/build/flow) on Flow.
- **[Cadence Documentation](https://cadence-lang.org/docs/language)** - Cadence is the native language for the Flow Blockchain. It is a resource-oriented programming language that is designed for developing smart contracts. The documentation is a great place to start learning about the language.
- **[Visual Studio Code](https://code.visualstudio.com/)** and the **[Cadence Extension](https://marketplace.visualstudio.com/items?itemName=onflow.cadence)** - It is recommended to use the Visual Studio Code IDE with the Cadence extension installed. This will provide syntax highlighting, code completion, and other features to support Cadence development.
- **[Flow Clients](https://developers.flow.com/tools/clients)** - There are clients available in multiple languages to interact with the Flow Blockchain. You can use these clients to interact with your smart contracts, run transactions, and query data from the network.
- **[Block Explorers](https://developers.flow.com/ecosystem/block-explorers)** - Block explorers are tools that allow you to explore on-chain data. You can use them to view transactions, accounts, events, and other information. [Flowser](https://flowser.dev/) is a powerful block explorer for local development on the Flow Emulator.

## ▶️ Quick Start (Scheduled Transactions Example)

Follow this to run the demo that schedules a transaction to increment the `Counter`.

1. Ensure flow-cli 2.6.1

```bash
flow version
# If older than 2.6.1, update first: https://developers.flow.com/tools/flow-cli/install
```

2. Create `emulator-account.pkey`

- Generate a key pair and copy the private key hex

```bash
flow keys generate
# Copy the "Private Key" value from the output (hex string)
```

- Save the private key to `emulator-account.pkey` in the project root

```bash
printf "<PASTE_PRIVATE_KEY_HEX_HERE>" > emulator-account.pkey
```

3. Install deps and start emulator

```bash
flow deps install
flow emulator --scheduled-transactions --block-time 1s
```

4. In a new terminal, deploy, init, schedule, verify

```bash
flow project deploy --network emulator

# Initialize handler (scheduler manager will be created automatically)
flow transactions send cadence/transactions/InitCounterTransactionHandler.cdc \
  --network emulator --signer emulator-account

flow scripts execute cadence/scripts/GetCounter.cdc --network emulator

# Schedule increment (creates manager if needed)
flow transactions send cadence/transactions/ScheduleIncrementIn.cdc \
  --network emulator --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"2.0"},
    {"type":"UInt8","value":"1"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":null}
  ]'

# after ~3s
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

For full details see `EXAMPLE.md`. For the continuous loop variant, see `EXAMPLE-LOOP.md`.

Note: The scheduler manager is automatically created when you schedule your first transaction, or you can initialize it separately using `InitSchedulerManager.cdc`.

## ▶️ Quick Start (Scheduled Transactions Loop Example)

Follow this to run the demo that continuously increments the `Counter` by rescheduling on each transaction execution.

Repeat steps 1–3 above, then in a new terminal run:

```bash
flow project deploy --network emulator

flow transactions send cadence/transactions/InitCounterLoopTransactionHandler.cdc \
  --network emulator --signer emulator-account

flow scripts execute cadence/scripts/GetCounter.cdc --network emulator

flow transactions send cadence/transactions/ScheduleIncrementInLoop.cdc \
  --network emulator --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"2.0"},
    {"type":"UInt8","value":"1"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":null}
  ]'

# after ~3s, the transaction runs and schedules the next one automatically
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

For full details and troubleshooting, see `EXAMPLE-LOOP.md`.

## ▶️ Quick Start (Scheduled Transactions Cron Example)

Follow this to run the demo that increments the `Counter` at precise intervals using cron-like scheduling (prevents drift).

Repeat steps 1–3 above, then in a new terminal run:

```bash
flow project deploy --network emulator

flow transactions send cadence/transactions/InitCounterCronTransactionHandler.cdc \
  --network emulator --signer emulator-account

flow scripts execute cadence/scripts/GetCounter.cdc --network emulator

flow transactions send cadence/transactions/ScheduleIncrementInCron.cdc \
  --network emulator --signer emulator-account \
  --args-json '[
    {"type":"UFix64","value":"3.0"},
    {"type":"UInt8","value":"1"},
    {"type":"UInt64","value":"1000"},
    {"type":"Optional","value":{"type":"UInt64","value":"3"}},
    {"type":"Optional","value":null}
  ]'

# after ~12s, check that it ran exactly 3 times at precise 3-second intervals
flow scripts execute cadence/scripts/GetCounter.cdc --network emulator
```

For full details and troubleshooting, see `EXAMPLE-CRON.md`.

## 📦 Project Structure

Your project has been set up with the following structure:

- `flow.json` – Project configuration and dependency aliases (string-imports)
- `/cadence` – Your Cadence code
- `/.cursor/rules/scheduledtransactions` – Local documentation and agent guidance.

Inside the `cadence` folder you will find:

- `/contracts` - This folder contains your Cadence contracts (these are deployed to the network and contain the business logic for your application)
  - `Counter.cdc`
  - `CounterTransactionHandler.cdc`
  - `CounterLoopTransactionHandler.cdc`
  - `CounterCronTransactionHandler.cdc`
- `/scripts` - This folder contains your Cadence scripts (read-only operations)
  - `GetCounter.cdc`
- `/transactions` - This folder contains your Cadence transactions (state-changing operations)
  - `IncrementCounter.cdc`
  - `InitSchedulerManager.cdc` - Initialize the scheduler manager
  - `InitCounterTransactionHandler.cdc`
  - `InitCounterLoopTransactionHandler.cdc`
  - `InitCounterCronTransactionHandler.cdc`
  - `ScheduleIncrementIn.cdc` - Schedule single increment
  - `ScheduleIncrementInLoop.cdc` - Schedule looping increment
  - `ScheduleIncrementInCron.cdc` - Schedule cron-like increment
- `/tests` - This folder contains your Cadence tests (integration tests for your contracts, scripts, and transactions to verify they behave as expected)
  - `Counter_test.cdc`

Docs and rules live under `/.cursor/rules/scheduledtransactions`:

- `index.md` – Navigation and references
- `agent-rules.mdc` – Agent guidance for composing safe transaction transactions
- `quick-checklist.md` – Essential checklist
- `flip.md` – FLIP-330: Scheduled Transactions

Other folders/files:

- `EXAMPLE.md` – Step-by-step walkthrough to run the scheduled transactions demo
- `EXAMPLE-LOOP.md` – Step-by-step walkthrough for the continuous loop scheduled transactions demo
- `EXAMPLE-CRON.md` – Step-by-step walkthrough for the cron-like scheduled transactions demo (precise intervals)

## 👨‍💻 Start Developing

### Create `emulator-account.pkey` (required)

If your `flow.json` references a key file for the `emulator-account`, create one and run the emulator with that same key so signing matches the service account. This is required; starting the emulator without the same private key will cause deploys/signing to fail.

1. Generate a key pair and copy the private key hex

```bash
flow keys generate --sig-algo ECDSA_P256 --hash-algo SHA3_256
# Copy the "Private Key" value from the output (hex string)
```

2. Save the private key to `emulator-account.pkey` in the project root

```bash
printf "<PASTE_PRIVATE_KEY_HEX_HERE>" > emulator-account.pkey
```

### Creating a New Contract

To add a new contract to your project, run the following command:

```shell
flow generate contract
```

This command will create a new contract file and add it to the `flow.json` configuration file.

### Creating a New Script

To add a new script to your project, run the following command:

```shell
flow generate script
```

This command will create a new script file. Scripts are used to read data from the blockchain and do not modify state (i.e. get the current balance of an account, get a user's NFTs, etc).

You can import any of your own contracts or installed dependencies in your script file using the `import` keyword. For example:

```cadence
import "Counter"
```

### Creating a New Transaction

To add a new transaction to your project you can use the following command:

```shell
flow generate transaction
```

This command will create a new transaction file. Transactions are used to modify the state of the blockchain (i.e purchase an NFT, transfer tokens, etc).

You can import any dependencies as you would in a script file.

## ⏰ Scheduled Transactions – Quick Reference

- Imports (string imports): `import "FlowTransactionScheduler"`, `import "FlowTransactionSchedulerUtils"`, `import "FlowToken"`, `import "FungibleToken"`
- Required params when scheduling:
  - `timestamp: UFix64` (must be in the future; on emulator prefer `getCurrentBlock().timestamp + smallDelta`)
  - `priority: UInt8` (0 = High, 1 = Medium, 2 = Low)
  - `executionEffort: UInt64` (minimum 10)
  - `handlerCap: Capability<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>`
  - `transactionData: AnyStruct?`
- Flow: Initialize/borrow manager → Estimate → withdraw fees → schedule through manager

Minimal scheduling skeleton with manager:

```cadence
import "FlowToken"
import "FungibleToken"
import "FlowTransactionScheduler"
import "FlowTransactionSchedulerUtils"

transaction(
    timestamp: UFix64,
    priority: UInt8,
    executionEffort: UInt64,
    handlerStoragePath: StoragePath,
    transactionData: AnyStruct?
) {
    prepare(signer: auth(BorrowValue, IssueStorageCapabilityController, SaveValue) &Account) {
        let p = priority == 0
            ? FlowTransactionScheduler.Priority.High
            : priority == 1
                ? FlowTransactionScheduler.Priority.Medium
                : FlowTransactionScheduler.Priority.Low

        // Get handler capability
        let handlerCap = signer.capabilities.storage
            .issue<auth(FlowTransactionScheduler.Execute) &{FlowTransactionScheduler.TransactionHandler}>(handlerStoragePath)

        // Initialize manager if needed
        if signer.storage.borrow<&AnyResource>(from: FlowTransactionSchedulerUtils.managerStoragePath) == nil {
            let manager <- FlowTransactionSchedulerUtils.createManager()
            signer.storage.save(<-manager, to: FlowTransactionSchedulerUtils.managerStoragePath)
        }

        // Borrow manager
        let manager = signer.storage.borrow<auth(FlowTransactionSchedulerUtils.Owner) &{FlowTransactionSchedulerUtils.Manager}>(
            from: FlowTransactionSchedulerUtils.managerStoragePath
        ) ?? panic("Could not borrow Manager")

        let est = FlowTransactionScheduler.estimate(
            data: transactionData,
            timestamp: timestamp,
            priority: p,
            executionEffort: executionEffort
        )

        assert(
            est.timestamp != nil || p == FlowTransactionScheduler.Priority.Low,
            message: est.error ?? "estimation failed"
        )

        let vaultRef = signer.storage
            .borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("missing FlowToken vault")
        let fees <- vaultRef.withdraw(amount: est.flowFee ?? 0.0) as! @FlowToken.Vault

        // Schedule through manager
        let transactionId = manager.schedule(
            handlerCap: handlerCap,
            data: transactionData,
            timestamp: timestamp,
            priority: p,
            executionEffort: executionEffort,
            fees: <-fees
        )
        
        log("Scheduled transaction id: ".concat(transactionId.toString()))
    }
}
```

### 📦 Installing External Dependencies

If you want to use external contract dependencies (such as NonFungibleToken, FlowToken, FungibleToken, etc.) you can install them using [Flow CLI Dependency Manager](https://developers.flow.com/tools/flow-cli/dependency-manager).

For example, to install the NonFungibleToken contract you can use the following command:

```shell
flow deps add mainnet://1d7e57aa55817448.NonFungibleToken
```

Contracts can be found using [ContractBrowser](https://contractbrowser.com/), but be sure to verify the authenticity before using third-party contracts in your project.

## 🧪 Testing

To verify that your project is working as expected you can run the tests using the following command:

```shell
flow test
```

This command will run all tests with the `_test.cdc` suffix (these can be found in the `cadence/tests` folder). You can add more tests here using the `flow generate test` command (or by creating them manually).

To learn more about testing in Cadence, check out the [Cadence Test Framework Documentation](https://cadence-lang.org/docs/testing-framework).

## 🚀 Deploying Your Project

To deploy your project to the Flow network, you must first have a Flow account and have configured your deployment targets in the `flow.json` configuration file.

You can create a new Flow account using the following command:

```shell
flow accounts create
```

Learn more about setting up deployment targets in the [Flow CLI documentation](https://developers.flow.com/tools/flow-cli/deployment/project-contracts).

### Deploying to the Flow Emulator

To deploy your project to the Flow Emulator, start the emulator with Scheduled Transactions enabled:

```shell
flow emulator --scheduled-transactions --block-time 1s
```

To deploy your project, run the following command:

```shell
flow project deploy --network=emulator
```

This command will start the Flow Emulator and deploy your project to it. You can now interact with your project using the Flow CLI or alternate [client](https://developers.flow.com/tools/clients).

## 📚 Other Resources

- [Cadence Design Patterns](https://cadence-lang.org/docs/design-patterns)
- [Cadence Anti-Patterns](https://cadence-lang.org/docs/anti-patterns)

## 🤝 Community

- [Flow Community Forum](https://forum.flow.com/)
- [Flow Discord](https://discord.gg/flow)
- [Flow Twitter](https://x.com/flow_blockchain)
