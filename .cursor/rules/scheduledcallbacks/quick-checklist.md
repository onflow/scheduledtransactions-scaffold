# Quick Checklist

## FlowCallbackScheduler Contract Reference

The **FlowCallbackScheduler** contract is located in [`../../../core-contracts/FlowCallbackScheduler.cdc`](../../../core-contracts/FlowCallbackScheduler.cdc) for easy reference.

## Imports

- Use `import "ContractName"` format only.
- Include all required contract imports.

## Preconditions/Postconditions

- Single boolean expression per pre/post block.
- Use `assert()` for multi-step validation in execute.

## Capabilities & Addresses

- Validate capabilities before use.
- Pass addresses as parameters only when you must resolve third-party capabilities directly.
- For scheduled callbacks: verify handler capability exists and is properly authorized.

## Test

- Zero amounts and `UFix64.max`
- Invalid capabilities
- For scheduled callbacks: invalid timestamps (past), insufficient fees, missing handlers

## Links

- Callback Handler Workflow: [`workflows/callback-handler-workflow.md`](./workflows/callback-handler-workflow.md)
- Callback Scheduling Workflow: [`workflows/callback-scheduling-workflow.md`](./workflows/callback-scheduling-workflow.md)
- Agent Rules: [`agent-rules.mdc`](./agent-rules.mdc)
- Scheduled Callbacks FLIP: [`flip.md`](./flip.md)
