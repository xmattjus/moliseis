# Proposal

## Why

PR #12 replaces legacy commands, but several new protocols make ordinary UI recovery depend on execution receipts, revision-aware drains and optimistic history reconciliation. Before merge, reduce those protocols where failure means stale, recoverable UI; retain protection for local drafts, accepted writes, identity and persistent mutations.

## What Changes

- Remove redundant GeoMap marker tickets/status storage and unused dashboard execution bookkeeping without changing observable behavior.
- Replace revision-tracked dashboard refresh obligations after editor return with one ordinary refresh request and explicit user recovery when busy or unsuccessful.
- Simplify Search history to ordered persistence with confirmed history presentation. Remove speculative optimistic projection/rebase and read-demand epochs; retain accepted FIFO writes across navigation and provide read-only recovery after failure. **BREAKING internal contract:** immediate optimistic history and per-demand freshness are deliberately relaxed.
- Remove editor physical-identity/observer/settlement test probes; reduce receipt lifecycle bookkeeping only with a demonstrably smaller local mechanism preserving the existing conflict matrix, captured requests, logical effect identity and safe late-error reporting.
- Keep Content Submission's durable draft/asset/finalization protocols, Auth identity correlation, Event day authority and existing Home coalescing. Do not replace the shared command foundation or add preventive hardening.
- Replace implementation-coupled acceptance with observable request, persistence, UI and recovery behavior. Historical migration artifacts remain unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `command-execution-concurrency`: supersede the pending Search history reconciliation/optimism and dashboard editor-refresh contracts; remove physical editor topology from normative lifecycle acceptance while retaining safe reporting and logical once-only effects. This delta is applied after the seven migration deltas, whose additions have not yet been synchronized into canonical specs; the explicit replacement ledger in design.md resolves that ordering.

Marker deduplication is a behavior-preserving refactor of the existing capability, so it introduces no additional requirement. No submission, authorization or backend contract is relaxed.

## Impact

Bounded edits to migrated Search, GeoMap and admin ViewModels, their existing consumers/tests, and effective OpenSpec contracts. The audit covers all fifteen migrated ViewModels across all seven changes. Existing Provider/ChangeNotifier, ResultCommand, RestartableCommand, repositories, RPCs, package versions and compatibility command.dart remain. No new dependency, framework, state system, shared asynchronous infrastructure or separate PR. Future authorized implementation belongs to Draft PR #12 before merge.

This execution writes planning artifacts only in the dedicated worktree at checkpoint c6e4a21b17f9d14299f7a159dd7bebe5b31d9af1. Implementation requires independent plan review and subsequent explicit authorization; no commit, push, PR mutation, sync or archive is authorized here.
