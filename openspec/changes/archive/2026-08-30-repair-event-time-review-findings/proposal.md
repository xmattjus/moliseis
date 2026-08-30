## Why

The staged event-time migration has a sound Europe/Rome civil-time architecture, but its current patch is not self-contained and still permits nullable-end synchronization loss, stale event-day state, event-target promotion attempts without target-specific temporal readiness validation, and wall-clock-dependent tests. These correctness gaps must be repaired and proven by the established event-time verification gates plus a scoped clean-baseline patch reconstruction before the temporal migration can be merged.

## What Changes

- Declare the required `timezone` runtime dependency without carrying the unrelated local application-version bump into this change.
- Make event synchronization able to explicitly clear a previously stored nullable end instant while preserving copy-on-omission semantics.
- Keep the selected-day event list coherent whenever the current-year event set loads or reloads, including unfavorable asynchronous completion order.
- After the existing moderation guard passes, prevalidate the requested `event` promotion target even when the clean loaded submission is not currently an event, so missing temporal data is shown locally and does not invoke the repository, while retaining the PostgreSQL transaction as the authoritative defense.
- Replace wall-clock-dependent event/search repository tests with one fixed UTC clock per temporal scenario.
- **BREAKING**: Remove the unused internal nullable `DateTime` editor adapters and legacy draft projections, migrate tests to semantic civil-date/clock APIs, and make picker callbacks non-nullable because the UI has explicit event disabling rather than component-clearing picker actions.
- While the event calendar suite is already being changed for cache regressions, remove its production test-only renderer injection and keep pure day-filtering scenarios in the owning ViewModel suite rather than duplicating them in widget tests.
- Target only the current canonical date contract: persisted `start_date` and `end_date` values are assumed to satisfy the authoritative backend constraints, and this change introduces no compatibility parser, fallback, coercion, normalization, repair, or migration path for historical contract violations.

## Capabilities

### New Capabilities

- `event-temporal-integrity`: Covers lossless canonical event synchronization, coherent selected-day loading, and local admin event-promotion readiness.

### Modified Capabilities

None. The repository has no existing main OpenSpec capability specifications.

## Impact

- Flutter/Dart domain policy, ObjectBox event entity copying and DTO merging, public/admin editor APIs and widgets, event-screen ViewModel/calendar state, and their focused tests.
- `pubspec.yaml` gains the already-used direct `timezone` dependency; generated ObjectBox output is not expected to change.
- No Supabase migration, Edge Function date-compatibility change, RLS/RPC authorization change, or promotion transaction change is required; the corrected backend constraints and stored data are authoritative.
- Verification includes focused and full Flutter tests, targeted and baseline-aware analysis, the local PostgreSQL promotion suite, generated-diff inspection, and a clean-baseline patch reconstruction. Because the application lockfile is ignored, fresh dependency resolution is not a canonical repository dependency state and is not an unrelated dependency-upgrade compatibility gate for this change. Tracking a canonical application dependency resolution is a separate reproducibility follow-up.
