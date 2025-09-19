import Test
import "FlowTransactionScheduler"

// Use service account which has FLOW tokens in test environment
access(all) let testAccount = Test.serviceAccount()

access(all) fun setup() {
    // Deploy Counter contract
    var err = Test.deployContract(
        name: "Counter",
        path: "../contracts/Counter.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())

    // Deploy CounterTransactionHandler contract
    err = Test.deployContract(
        name: "CounterTransactionHandler",
        path: "../contracts/CounterTransactionHandler.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

access(all) fun testScheduleAndExecuteTransaction() {
    // Step 1: Initialize the handler capability
    let initResult = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/InitCounterTransactionHandler.cdc"),
            authorizers: [testAccount.address],
            signers: [testAccount],
            arguments: []
        )
    )
    Test.expect(initResult, Test.beSucceeded())

    // Step 2: Check initial counter value
    let initialCount = getCounterValue()
    Test.assertEqual(0, initialCount)

    // Step 3: Get initial timestamp and schedule an increment
    let initialTimestamp = getTimestamp()
    log("Initial timestamp: ".concat(initialTimestamp.toString()))
    // Schedule for 2 seconds in the future
    let delaySeconds = 2.0
    let scheduleResult = Test.executeTransaction(
        Test.Transaction(
            code: Test.readFile("../transactions/ScheduleIncrementIn.cdc"),
            authorizers: [testAccount.address],
            signers: [testAccount],
            arguments: [
                delaySeconds,     // delaySeconds
                1 as UInt8,       // priority (Medium)
                1000 as UInt64,   // executionEffort
                nil as AnyStruct? // transactionData
            ]
        )
    )
    Test.expect(scheduleResult, Test.beSucceeded())

    // Verify the transaction was scheduled
    let scheduledEvents = Test.eventsOfType(Type<FlowTransactionScheduler.Scheduled>())
    Test.assertEqual(1, scheduledEvents.length)
    let scheduledEvent = scheduledEvents[0] as! FlowTransactionScheduler.Scheduled
    let scheduledTimestamp = scheduledEvent.timestamp
    log("Scheduled timestamp: ".concat(scheduledTimestamp.toString()))

    // Step 4: Move time forward past the scheduled time
    Test.moveTime(by: Fix64(delaySeconds + 1.0))
    let advancedTimestamp = getTimestamp()
    log("Advanced timestamp: ".concat(advancedTimestamp.toString()))

    // Step 5: Verify the counter incremented
    let finalResult = getCounterValue()
    Test.assertEqual(1, finalResult)
}

// Helper function to get current timestamp
access(all) fun getTimestamp(): UFix64 {
    let code = "access(all) fun main(): UFix64 { return getCurrentBlock().timestamp }"
    let result = Test.executeScript(code, [])
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! UFix64
}

// Helper function to get counter value
access(all) fun getCounterValue(): Int {
    let result = Test.executeScript(
        Test.readFile("../scripts/GetCounter.cdc"),
        []
    )
    Test.expect(result, Test.beSucceeded())
    return result.returnValue! as! Int
}
