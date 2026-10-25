# Proposal

## Published checkpoint

This migration was published in Draft [PR #12](https://github.com/xmattjus/moliseis/pull/12) as commit [`52d4e448d010d2d13c13a4d3d665cdf5b1b0103b`](https://github.com/xmattjus/moliseis/commit/52d4e448d010d2d13c13a4d3d665cdf5b1b0103b), whose parent is `0cdb764a7586f85180a802fafcf2b485791cb5ff` (verified from Git history). All seven migrations are now published. The historical analyzer transition for this checkpoint was **37 → 0 INFO**; these are recorded checkpoint results, not analyzer runs performed during reconciliation. Planning assumptions, local-only authorization and uncommitted-work statements below describe their original phases. Subsequent publication supersedes those status statements without changing the historical evidence. Canonical synchronization, archival, legacy compatibility deletion and merge remain outside this reconciliation.

## Planning history — Why

Six of the seven legacy Command migrations are published in Draft PR #12. The route-scoped Admin Submission Editor owns the remaining eleven legacy commands and all 37 remaining analyzer INFO diagnostics; migrating it requires explicit admission and lifecycle rules because command_it defers action entry.

## What Changes

- Use private ordinary ResultCommand lanes, synchronous owner admission, immutable accepted requests, Result-aware cached snapshots and safe private settlement for all eleven editor operations.
- Preserve validation, create/update identity, moderation distinctions, backend source acknowledgements and opaque preview tokens, confirmed asset operations, Save-pop navigation and status-dialog coordination.
- Explicitly harden the observed Load/draft race, stale candidate/preview publication, Save dirty revision and deferred/reentrant admission windows. These limited concurrency changes are specified in design D1–D7; no implicit workflow redesign.
- Migrate direct and indirect editor consumers and remove the three documentation-only legacy references from test support. Target analyzer baseline 37 INFO → zero, without suppression.
- Add only missing deterministic admission, lifecycle, revision and route regressions, reusing existing support and functional coverage.

## Capabilities

### New Capabilities

None. The unimplemented stale `improve-admin-submission-editor-workflow` change and its proposed capability are not dependencies.

### Modified Capabilities

- `command-execution-concurrency`: add editor-specific synchronous admission, request publication, result and lifecycle requirements consistent with migrations 1–6.
- `external-event-provenance-moderation`: add editor execution safeguards preserving existing resolution, KeepCurrent, source-acknowledgement and token contracts.

## Impact

The authorized local apply is bounded to the editor ViewModel, editor screen, editor bootstrap in `lib/routing/router.dart`, the editor test suites, narrowly necessary real admin-route tests and reusable `test/support` extensions. Repository/backend code, SQL, dependencies, CI, command foundation and canonical specs remain unchanged. Existing repository/Edge contract tests are verification evidence, not planned rewrite targets.

The planning baseline is checkpoint `0cdb764a7586f85180a802fafcf2b485791cb5ff`, on `codex/plan-migrate-admin-editor-commands`. The user subsequently approved the remediated plan and explicitly authorized local implementation, tests and verification; see validation.md for actual evidence. Commit, push, PR update, merge, archive and canonical sync remain unauthorized. Keep `lib/utils/command.dart`; deletion belongs to later consolidation. Independent plan review and later apply require separate authorization.
