# Callback Scheduling Workflow

**Purpose**: Schedule callbacks for autonomous smart contract execution  
**Components**: FeeEstimation → HandlerCapability → CallbackScheduling → Storage  
**Related**: [Scheduled Callbacks FLIP 330](../flip.md#tutorials-and-examples)

## Required Imports

```cadence
import "FlowCallbackScheduler"
import "FlowToken"
import "FungibleToken"
import "TestCallback"  // Replace with actual handler contract
```

## Component Flow

```
1. FeeEstimation      → Calculate required fees based on priority and execution effort
2. HandlerCapability  → Obtain capability to callback handler resource
3. FeeVault          → Withdraw required fees from user's FlowToken vault
4. CallbackScheduling → Schedule callback with scheduler contract
5. Storage           → Save ScheduledCallback receipt (optional)
```

## Transaction Implementation

```cadence
transaction(
    timestamp: UFix64,              // Target execution timestamp (0 = as soon as possible)
    priority: UInt8,                // Priority level (0=High, 1=Medium, 2=Low)
    executionEffort: UInt64,        // Maximum computation effort (minimum 10)
    handlerStoragePath: StoragePath, // Storage path of the callback handler
    callbackData: AnyStruct?,       // Optional data to pass to callback (max 100 bytes)
    receiptStoragePath: StoragePath? // Optional storage path for callback receipt
) {
    prepare(signer: auth(BorrowValue, SaveValue, IssueStorageCapabilityController) &Account) {
        
        // Step 1: Validate and convert priority
        let priorityEnum: FlowCallbackScheduler.Priority
        switch priority {
            case 0:
                priorityEnum = FlowCallbackScheduler.Priority.High
            case 1:
                priorityEnum = FlowCallbackScheduler.Priority.Medium
            case 2:
                priorityEnum = FlowCallbackScheduler.Priority.Low
            default:
                panic("Invalid priority value. Use 0=High, 1=Medium, 2=Low")
        }
        
        // Step 2: Validate timestamp (must be in future or 0 for immediate)
        let currentTime = getCurrentBlock().timestamp
        if timestamp != 0.0 && timestamp <= currentTime {
            panic("Timestamp must be in the future or 0 for immediate execution")
        }
        
        // Step 3: Estimate required fees
        let estimate = FlowCallbackScheduler.estimate(
            data: callbackData,
            timestamp: timestamp,
            priority: priorityEnum,
            executionEffort: executionEffort
        )
        if estimate.flowFee == nil {
            panic(estimate.error ?? "Could not estimate callback fee - invalid parameters")
        }
        let requiredFee = estimate.flowFee!
        
        log("Estimated fee: ".concat(requiredFee.toString()).concat(" FLOW"))
        if let scheduledAt = estimate.timestamp {
            log("Estimated execution time: ".concat(scheduledAt.toString()))
        }
        
        // Step 4: Prepare required fees
        let vaultRef = signer.storage.borrow<auth(FungibleToken.Withdraw) &FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Could not borrow FlowToken vault from /storage/flowTokenVault")
        
        // Check sufficient balance
        if vaultRef.balance < requiredFee {
            panic("Insufficient balance. Required: ".concat(estimate.flowFee.toString())
                .concat(", Available: ").concat(vaultRef.balance.toString()))
        }
        
        let feesVault <- vaultRef.withdraw(amount: requiredFee) as! @FlowToken.Vault
        
        // Step 5: Get callback handler capability
        let handlerCap = signer.capabilities.storage.issue<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>(handlerStoragePath)
        
        // Verify handler exists and is accessible
        let handlerRef = handlerCap.borrow()
            ?? panic("Could not borrow callback handler from ".concat(handlerStoragePath.toString()))
        
        // Step 6: Schedule the callback
        let scheduledCallback = FlowCallbackScheduler.schedule(
            callback: handlerCap,
            data: callbackData,
            timestamp: timestamp,
            priority: priorityEnum,
            executionEffort: executionEffort,
            fees: <-feesVault
        )
        
        // Step 7: Log scheduling details
        log("Callback scheduled successfully!")
        log("Callback ID: ".concat(scheduledCallback.id.toString()))
        log("Scheduled timestamp: ".concat(scheduledCallback.timestamp.toString()))
        log("Priority: ".concat(priorityEnum.rawValue.toString()))
        log("Execution effort: ".concat(executionEffort.toString()))
        
        // Step 8: Optionally save callback receipt for future reference
        if let storagePath = receiptStoragePath {
            // Save the ScheduledCallback struct for later reference/cancellation
            signer.storage.save(scheduledCallback, to: storagePath)
            log("Callback receipt saved to: ".concat(storagePath.toString()))
        }
    }
    
    pre {
        executionEffort >= 10: "Execution effort must be at least 10"
        priority <= 2: "Priority must be 0 (High), 1 (Medium), or 2 (Low)"
        // Note: callbackData size validation happens in the scheduler contract
    }
    
    post {
        // Verify transaction succeeded by checking emitted events
        // The scheduler contract should emit CallbackScheduled event
    }
}
```

## Component Details

### Fee Estimation

- **Purpose**: Calculate required fees based on priority and execution parameters
- **Input**: Callback data, timestamp, priority level, execution effort
- **Output**: Required Flow token amount and estimated execution time
- **Note**: Returns `nil` if parameters are invalid or scheduling impossible

### Handler Capability

- **Purpose**: Creates capability reference to callback handler resource
- **Input**: Storage path where handler resource is stored
- **Output**: Authorized capability for scheduler to execute callback
- **Requirements**: Handler must implement `CallbackHandler` interface

### Callback Scheduling

- **Purpose**: Submit callback to scheduler for future execution
- **Input**: Handler capability, data, timing, priority, effort, and fees
- **Output**: `ScheduledCallback` receipt with ID and cancellation capability
- **Side Effects**: Locks fees in escrow until execution or cancellation

## Configuration Examples

### High Priority Immediate Execution

```cadence
scheduleCallback(
    timestamp: 0.0,                    // Execute as soon as possible
    priority: 0,                       // High priority (10x fee multiplier)
    executionEffort: 1000,             // Moderate computation effort
    handlerStoragePath: /storage/TestCallbackHandler,
    callbackData: nil,                 // No custom data
    receiptStoragePath: /storage/CallbackReceipt_001
)
```

### Medium Priority Scheduled Execution

```cadence
// Schedule for execution in 1 hour
let futureTime = getCurrentBlock().timestamp + 3600.0
scheduleCallback(
    timestamp: futureTime,
    priority: 1,                       // Medium priority (5x fee multiplier)
    executionEffort: 500,              // Lower computation effort
    handlerStoragePath: /storage/PaymentHandler,
    callbackData: {"amount": 100.0, "recipient": 0x123456789abcdef0},
    receiptStoragePath: /storage/PaymentCallback_001
)
```

### Low Priority Opportunistic Execution

```cadence
// Schedule for next day with custom data
let tomorrow = getCurrentBlock().timestamp + 86400.0
scheduleCallback(
    timestamp: tomorrow,
    priority: 2,                       // Low priority (2x fee multiplier)
    executionEffort: 2000,             // Higher computation effort
    handlerStoragePath: /storage/BatchProcessor,
    callbackData: {"batchID": "batch_001", "items": 50},
    receiptStoragePath: /storage/BatchCallback_001
)
```

## Callback Management

### Check Callback Status

```cadence
access(all) fun getCallbackStatus(account: Address, receiptPath: StoragePath): String? {
    if let receipt = getAccount(account).storage.borrow<&FlowCallbackScheduler.ScheduledCallback>(from: receiptPath) {
        if let current = receipt.status() {
            return current.toString()
        }
    }
    return nil
}
```

### Cancel Scheduled Callback

```cadence
transaction(receiptStoragePath: StoragePath) {
    prepare(signer: auth(BorrowValue, SaveValue) &Account) {
        let receipt <- signer.storage.load<FlowCallbackScheduler.ScheduledCallback>(from: receiptStoragePath)
            ?? panic("Could not load callback receipt")
        
        let refundVault <- FlowCallbackScheduler.cancel(callback: receipt)
        
        let vaultRef = signer.storage.borrow<&FlowToken.Vault>(from: /storage/flowTokenVault)
            ?? panic("Missing /storage/flowTokenVault")
        vaultRef.deposit(from: <-refundVault)
        
        log("Callback canceled; refund deposited")
    }
}
```
