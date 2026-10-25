# Proposal

## Why

Category originally retained four deprecated legacy Commands. A mechanical replacement with asynchronous factories would make bootstrap unsafe and preserve lost filter requests/mixed results. OpenSpec 2/7 therefore defines verifiable ownership, publication and lifecycle while reusing the existing foundation.

## Published checkpoint

Implementation and final GeoMap selector-owner remediation were published in `e3d9d891c5b560524e66b35f0bf70f9108cacb7e`, parent `9d17d224d5094c5b043128113d9aba6a1ce69f0a` (2026-10-20), included in [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12). Git history verifies these values. This is a later publication record; earlier local/uncommitted statements describe their original phases. All seven migrations are now published. Canonical synchronization, archival, compatibility deletion and merge remain separately authorized work.

## What Changes

- Initialize the validated route selection in the constructor before exposing the ViewModel; normalize empty direct inputs to all options, matching existing UI confirmation. Preserve slugs, `all`, error routing, Provider and route ownership.
- Replace the two selection Commands with synchronous ViewModel methods that update intent without nested Commands/fictitious waits.
- Use one restartable retrieval for categories/types with immutable input, separate retrieval/authoritative commit and current sorting at commit.
- Atomically publish complete successes only. A changed selection immediately clears previous content; same-selection refresh retains the previous complete collection internally, while loading/error govern UI. No partial collection is published.
- Keep `setSort` single-flight through a Result-aware factory, optimistic session order and existing persistence. Return the real write Result instead of legacy false success; no session-order rollback/new persistence guarantee.
- Expose neutral/loading/success/empty/error and retry. Revoke publication/notifications on disposal, with private cleanup after safe settlement.
- Correct shared selectors: semantic confirmed-set equality preserves drafts across harmless rebuilds; empty drafts have explicit labels. Restore all options only on normal modal close, with one callback if mounted/current. An observed confirmed-value change retires that open draft without republishing it. Keep confirmed snapshots, editing session and owner identity separate.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `command-execution-concurrency`: add distinct Category contracts for bootstrap, latest-intent filters, atomic commit, sorting, UI state and lifecycle. Do not duplicate/overwrite OpenSpec 1’s MODIFIED requirement. Future authorized canonical reconciliation must preserve both deltas; this reconciliation does not synchronize them.

## Impact

Implemented production surfaces: `category_view_model.dart`, `category_screen.dart`, Category initialization in `core_routes.dart`, and `category_content_and_type_selection.dart`; final remediation adds only selector ownership key in `geo_map_screen.dart`. Semantic equality/safe labels are needed for local draft state too. Apply tests cover Category, routing/ownership/restoration and focused real-GeoMap shared-selector compatibility, reusing `test/support/`. No UseCase/repository/backend/dependency/global-foundation change.

Verified planning baseline: `9d17d224d5094c5b043128113d9aba6a1ce69f0a`, matching fetched origin/codex/migrate-legacy-commands and Draft PR #12 then. Dedicated worktree/branch `codex/plan-migrate-category-view-model-commands`; provenance/ledger in design.md. Historical planning analyzer: **113 INFO, 8 Category**, no reduction in planning. Apply verified **105 identical remaining INFO**, eight target removals/zero new identities.

Excluded: Event, Post, Search, GeoMap Commands/orchestration, Sync, Submission, Admin, other Commands and global command.dart removal. Shared selector F1/F2 compatibility and final `ObjectKey(owner)` mounting correction in GeoMapScreen do not migrate GeoMap. Keep Provider/ChangeNotifier, Result and UI/domain/data boundaries; no generic factory/legacy adapter/concurrency infrastructure.

## Historical implementation status

Apply was authorized on 2026-10-20 after independent planning review and F1/F2/RF3 remediation. Implementation/regressions were completed in the dedicated worktree; completed tasks reflect actual verification. Earlier planning/remediation evidence remains in design.md. The original local closeout preceded commit/push/PR mutation/merge/archive/canonical sync; those historical statements do not describe current publication. Final code-review remediation and gate results are in the design closeout; the PR remains Draft.
