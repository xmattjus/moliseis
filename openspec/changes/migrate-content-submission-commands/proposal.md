# Proposal

## Why

The fifth change in Draft PR #12's cumulative migration replaces five Content Submission legacy Commands and removes 14 target diagnostics. The migration must preserve drafts, staged assets, ownership and finalization while preventing deferred command_it action entry from interpreting a request against a later session or asset.

## What Changes

- Migrate `addAsset`, `removeAssetAt`, `submit`, `clear` and `retrieveLostAssets` to existing ResultCommand factories, synchronous admission, immutable requests and the single local `_serialize` arbiter.
- Make initialization, request, preparation, acknowledgement and finalization boundaries explicit; retain same-session mutations, sequential submission and local-only retry after confirmed acknowledgement.
- Distinguish domain Results, runtime throws, reporting and assertions; revoke new phases/UI effects after disposal while preserving private settlement and safe cleanup of all five Commands.
- Adapt form, asset list, progress and routing callbacks to current terminal state and ViewModel rebinding; preserve process-restored idle and Back/Home policies.
- **BREAKING** (internal Dart APIs): the five executable Commands become private. Consumers use `requestAddAsset`, `requestRemoveAssetAt`, `requestSubmit`, `requestClear`, `requestRetrieveLostAssets` and Result-aware observables without run/runAsync access. Remote and persisted contracts do not change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `command-execution-concurrency`: admission and ordinary lifecycle for the five Commands, distinct runtime failures and post-disposal settlement.
- `content-submission-local-asset-staging`: request/initialization binding, removal identity, arbitration and obsolete Android recovery.
- `content-submission-submit-orchestration`: request snapshots, session checks before effects, failure release and finalization disposal boundaries.
- `content-submission-navigation-lifecycle`: Result-aware states, derived retry, synchronous handoff and replaceable consumers without obsolete callbacks.

## Planning history

The authorized baseline was `f48a08946c9ac40146104a0157556243ad433c92`, direct child of `da7c426fb799a26094f043319b47e63b98728f92`; that advance only reconciled OpenSpec 4 documentation. PR #12 was reconfirmed open/Draft at that baseline. The design records the dedicated historical branch/worktree.

Planning and F1–F3 remediation were approved after two independent reviews. The subsequent implementation authorization initially covered local work only; independent code review and publication were separate later steps. Statements about uncommitted/unpublished work in the historical design describe that earlier phase.

## Implementation evidence

Implementation covered the ViewModel, three primary consumers, Content Submission router callbacks and relevant tests/support, including the necessary integration-test API adaptation. Foundation, dependencies, Provider composition, repositories, ObjectBox, Cloudinary, RPCs, Edge Functions, schema and draft persistence were unchanged.

Historical local verification completed all five Command migrations and functional gates: full Flutter suite **2,862 passed / 0 failures / 6 pre-existing skips (exit 0)**. Analyzer B0/B1 was **66→52 INFO**, zero WARNING/ERROR: exactly 14 target identities removed, no non-target changes after line mapping. These are checkpoint-5 measurements, not results rerun during reconciliation. Detailed evidence and limitations remain in `design.md`.

## Published checkpoint and current cumulative status

Git records checkpoint 5 as `e80dfbaf472ef1cc15b220a48df966509a9ee8a1`, parent `f48a08946c9ac40146104a0157556243ad433c92`. It is published in [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12); local-only implementation status is historical. The cumulative PR now contains **seven published migrations**. The retained legacy `command.dart` compatibility implementation, canonical synchronization, archival and merge remain separate authorized work. PR #12 remains Draft; merge is not authorized.
