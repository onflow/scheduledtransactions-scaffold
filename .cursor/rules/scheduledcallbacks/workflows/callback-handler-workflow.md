# Callback Handler Workflow

**Purpose**: Create callback handler contract for scheduled execution  
**Components**: CallbackHandler Interface → TestCallbackHandler Resource → Storage + Capability  
**Related**: [Scheduled Callbacks FLIP 330](../flip.md#tutorials-and-examples)

## Required Imports

```cadence
import "FlowCallbackScheduler"
```

## Component Flow

```
1. CallbackHandler Interface  → Defines contract interface for callback execution
2. TestCallbackHandler       → Implements callback execution logic
3. Storage                   → Saves handler resource to account storage
4. Capability                → Creates capability for scheduler access
```

## Contract Implementation

```cadence
import "FlowCallbackScheduler"

// Contract that implements a callback handler for scheduled execution
access(all) contract TestCallback {
    
    // Storage paths for the callback handler
    access(all) let HandlerStoragePath: StoragePath
    access(all) let HandlerPrivatePath: PrivatePath
    
    init() {
        self.HandlerStoragePath = /storage/TestCallbackHandler
        self.HandlerPrivatePath = /private/TestCallbackHandler
    }
    
    // Resource that implements the callback handler interface
    access(all) resource TestCallbackHandler: FlowCallbackScheduler.CallbackHandler {
        
        // Counter to track callback executions
        access(all) var executionCount: UInt64
        
        // Custom data for this handler instance
        access(all) let handlerID: String
        
        init(handlerID: String) {
            self.executionCount = 0
            self.handlerID = handlerID
        }
        
        // Main callback execution function - called by the scheduler
        access(FlowCallbackScheduler.Execute) fun executeCallback(id: UInt64, data: AnyStruct?) {
            self.executionCount = self.executionCount + 1
            
            log("Callback executed!")
            log("Handler ID: ".concat(self.handlerID))
            log("Callback ID: ".concat(id.toString()))
            log("Execution count: ".concat(self.executionCount.toString()))
            
            // Process custom data if provided
            if let callbackData = data {
                log("Received data: ".concat(callbackData.toString()))
                self.processCallbackData(callbackData)
            }
            
            // Emit event for execution tracking
            emit CallbackExecuted(
                handlerID: self.handlerID,
                callbackID: id,
                executionCount: self.executionCount,
                timestamp: getCurrentBlock().timestamp
            )
        }
        
        // Process callback-specific data
        access(self) fun processCallbackData(_ data: AnyStruct?) {
            // Add custom processing logic here
            // This could include:
            // - Updating contract state
            // - Triggering other actions
            // - Processing structured data
        }
        
        // Get handler execution statistics
        access(all) fun getExecutionStats(): {String: AnyStruct} {
            return {
                "handlerID": self.handlerID,
                "executionCount": self.executionCount,
                "lastExecution": getCurrentBlock().timestamp
            }
        }
    }
    
    // Event emitted when callback is executed
    access(all) event CallbackExecuted(
        handlerID: String,
        callbackID: UInt64,
        executionCount: UInt64,
        timestamp: UFix64
    )
    
    // Factory function to create a new callback handler
    access(all) fun createHandler(handlerID: String): @TestCallbackHandler {
        return <- create TestCallbackHandler(handlerID: handlerID)
    }
    
    // Get the storage path for handlers
    access(all) fun getHandlerStoragePath(): StoragePath {
        return self.HandlerStoragePath
    }
    
    // Get the private path for handler capabilities
    access(all) fun getHandlerPrivatePath(): PrivatePath {
        return self.HandlerPrivatePath
    }
}
```

## Setup Transaction Implementation

```cadence
import "FlowCallbackScheduler"
import "TestCallback"

transaction(
    handlerID: String,               // Unique identifier for this handler instance
    storagePath: StoragePath,        // Storage location for the handler
    privatePath: PrivatePath         // Private capability path for scheduler access
) {
    prepare(signer: auth(SaveValue, IssueStorageCapabilityController) &Account) {
        
        // Step 1: Validate storage path is available
        if signer.storage.check<@TestCallback.TestCallbackHandler>(from: storagePath) {
            panic("Storage path already occupied: ".concat(storagePath.toString()))
        }
        
        // Step 2: Create callback handler resource
        let handler <- TestCallback.createHandler(handlerID: handlerID)
        
        // Step 3: Save handler to storage
        signer.storage.save(<-handler, to: storagePath)
        
        // Step 4: Create capability for scheduler access
         let handlerCap = signer.capabilities.storage.issue<auth(FlowCallbackScheduler.Execute) &{FlowCallbackScheduler.CallbackHandler}>(storagePath)
        
        // Step 5: Publish capability for external access (optional)
        signer.capabilities.publish(handlerCap, at: privatePath)
        
        log("TestCallbackHandler created with ID: ".concat(handlerID))
        log("Stored at: ".concat(storagePath.toString()))
    }
    
    pre {
        handlerID.length > 0: "Handler ID cannot be empty"
    }
    
    post {
        getAccount(self.address).storage.check<@TestCallback.TestCallbackHandler>(from: storagePath):
            "Handler not saved correctly"
    }
}
```

## Component Details

### CallbackHandler Interface

- **Purpose**: Defines the contract interface for scheduled callback execution
- **Input**: Callback ID and optional data payload
- **Output**: Executes custom business logic when called by scheduler
- **Requirements**: Must implement `executeCallback` function with proper entitlements

### TestCallbackHandler Resource

- **Purpose**: Implements callback execution logic with state tracking
- **Input**: Handler ID for identification and callback data
- **Output**: Logs execution details and maintains execution count
- **Side Effects**: Emits events and updates internal state

### Storage and Capability

- **Purpose**: Stores handler and provides scheduler access
- **Input**: Handler resource, storage path, capability path
- **Output**: Persistent handler with proper access control

## Configuration Examples

### Basic Handler Setup

```cadence
setupCallbackHandler(
    handlerID: "my_basic_handler",
    storagePath: /storage/TestCallbackHandler,
    privatePath: /private/TestCallbackHandler
)
```

### Multiple Handler Setup

```cadence
// Handler for different purposes
setupCallbackHandler(
    handlerID: "payment_handler_001",
    storagePath: /storage/PaymentCallbackHandler,
    privatePath: /private/PaymentCallbackHandler
)

setupCallbackHandler(
    handlerID: "notification_handler_001", 
    storagePath: /storage/NotificationCallbackHandler,
    privatePath: /private/NotificationCallbackHandler
)
```

## Integration with Scheduler

### Creating Capability for Scheduling

```cadence
// Get handler capability for scheduling
let handlerCap = account.capabilities.storage.issue<auth(FlowCallbackScheduler.mayExecuteCallback) &{FlowCallbackScheduler.CallbackHandler}>(/storage/TestCallbackHandler)
```

### Preparing for Callback Scheduling

```cadence
// This capability can then be used in the schedule transaction
let scheduledCallback = FlowCallbackScheduler.schedule(
    callback: handlerCap,
    data: customData,
    timestamp: futureTimestamp,
    priority: FlowCallbackScheduler.Priority.High,
    executionEffort: 1000,
    fees: <-feesVault
)
```

## Error Handling

### Common Setup Failures

- **Empty handler ID**: Ensure handler ID is provided and non-empty
- **Storage conflicts**: Check if storage path is already occupied
- **Capability issues**: Verify account has required entitlements
- **Invalid paths**: Ensure storage and capability paths are valid

### Runtime Failures

- **Execution errors**: Handler logic throws runtime errors
- **Data processing**: Invalid or unexpected callback data format
- **State corruption**: Handler resource state becomes inconsistent
- **Access issues**: Scheduler cannot access handler capability
