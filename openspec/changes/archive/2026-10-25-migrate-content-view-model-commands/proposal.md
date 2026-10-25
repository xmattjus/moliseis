# Proposal

## Published checkpoint

Migration 3 was published in [Draft PR #12](https://github.com/xmattjus/moliseis/pull/12) as `1f3753b10c18061c6655cb32d078bf93aff1b05e`, parent `e3d9d891c5b560524e66b35f0bf70f9108cacb7e`, verified from Git history. All seven migrations are now published. Planning and local-apply statements below describe their original phases; they are superseded as current publication status, not rewritten as if implementation already existed during planning. Legacy compatibility removal, canonical synchronization, archival and merge remain separately authorized work.

## Why — planning history

The third cumulative migration in Draft PR #12 replaces eight legacy Commands in EventViewModel (4), PostViewModel (3) and SyncViewModel (1) using existing command_it foundation. Calendar selection, route bootstrap, terminal errors and Sync redirects require explicit contracts: legacy execute and run/runAsync are not equivalent.

## What Changes — approved implementation intent

- Seven ordinary ResultCommand lanes and one RestartableCommand lane only for calendar day, with synchronous VM selection/authoritative commit.
- Preserve annual bootstrap/cache/revisions/Europe/Rome temporal policy and single-flight coalesced Home coordination with one UTC snapshot per pass. Same-day/revision cache hit retains committed fallback, including empty, before any _all derivation. Event day receives full terminal projection, stale-snapshot admission barrier, directly observed calendar selection and explicit current-date retry after failure.
- Preserve Post (id,type) identity/owner replacement/Weather binding/Nearby events→places, partial data/first error; expose terminal detail failure without premature late-content reads/new navigation/retry UI.
- Preserve pre-frame auto-sync/force/concurrency exclusion/validated URI return. Classify fatalError from current outcome, including runtime failure without Result.error conversion, original global reporting once. Authorize nonfatal feedback with live context before normal return; global messenger retains it after redirect. Reactive Provider dependency rebinds SyncScreen locally, with no stale feedback. This does not replace router-captured owner: app router/Provider share owner; new session requires coherent new router lifecycle. No dynamic router rebind.
- Adapt real consumers to results/ResultCommandSnapshot, distinguishing synchronous admission/deferred entry/notification; deterministic idempotent local cleanup per OpenSpec 1/2.
- During apply, targeted/routing/ownership/restoration/full Flutter gates; remove exactly 18 target identities (105→87 INFO, zero warnings/errors/new identities).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `command-execution-concurrency`: add observable Event day/annual, Post detail/Nearby and Sync admission/outcome/navigation/lifecycle contracts, without rewriting first plan's MODIFIED or weakening Search/Map.
- `home-ongoing-events`: independent two-lane settlement/external-request coordination/waiter teardown; classification/shared snapshot/coordinated retry unchanged.

## Impact and original baseline

Authorized baseline `e3d9d891c5b560524e66b35f0bf70f9108cacb7e` (OpenSpec 2), parent `9d17d224d5094c5b043128113d9aba6a1ce69f0a`. PR #12 then open/Draft at same SHA, origin `https://github.com/xmattjus/moliseis.git`; main `ee60777c7fdfc5c16daa1151050c134fbb7cde29` was not substitute baseline. Historical preflight used detached `<temporary-worktree>`, initially clean/empty index. F4 moved same worktree using `git worktree move` into persistent `<worktree>` on local `codex/plan-migrate-content-view-model-commands`: HEAD unchanged/six artifact hashes identical across move/empty index. That became phase's operating worktree. Audit/ledger repeated 2026-10-21; design records procedures and unavailable ephemeral evidence limits.

Apply scope: three VMs/router/core_routes/Event/Explore/Post/Sync widgets/strictly relevant tests/support. Shared Nearby/WeatherViewModel/Provider scope/foundation/SyncUseCase/repositories/persistence/backend/dependencies/analyzer configuration unchanged. Material contradiction requires plan review before execution.

Original planning edited only new-change artifacts. F1–F4 remediation edited existing artifacts and performed authorized local worktree move/branch association only: no Dart/test implementation/commit/push/merge/PR update/canonical sync/archive. Independent adversarial plan review preceded separate apply authorization; first two plans' historical successes were not new verification of this change.

## Implementation evidence — historical apply, 2026-10-23

Apply authorized after independent plan review and executed in persistent worktree. Design separates actual results from planning provenance: full suite 2.619 passed/six pre-existing skips; analyzer B1 105→87 INFO, exactly 18 target identities removed/zero new diagnostics. Checklist/strict OpenSpec reconciled at closeout. Implementation was local at that moment and requested independent code review without merge-readiness claim; later publication is recorded above. These counts are historical checkpoint results, not new reconciliation measurements.

Historical remote [Actions run 39938327443](https://github.com/xmattjus/moliseis/actions/runs/39938327443) for exact implementation SHA `1f3753b10c18061c6655cb32d078bf93aff1b05e` concluded failure. The local Dart analyzer exit 0 with 87 residual INFO did not mean remote CI was green. Latest-head CI must be checked separately.
