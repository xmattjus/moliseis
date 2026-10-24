# Proposal

## Why

Five legacy admin Commands remain at the authorized fifth-migration checkpoint. Migrating them requires explicit cross-command admission, credential privacy and post-commit refresh ownership; replacing their types alone would retain credentials and risk losing refreshes.

## What Changes

- Migrate AdminAuthViewModel login/logout to private ordinary Result Commands with credential-free snapshots and a synchronous shared admission gate.
- Migrate AdminSubmissionsViewModel load/loadIgnored/unIgnore as one coordinated unit with independent read lanes and an exclusive mutation/refresh phase.
- Adapt AdminLoginScreen, AdminDashboardScreen and dashboard route initialization to intent-only ViewModel APIs, Result-aware projections and lifecycle-safe listeners.
- Preserve GoTrue session authority, Admin authorization, Settings Back navigation, data retention and mutation success distinct from refresh failure. Harden rejected-login cleanup with response/session correlation; withhold the returned pending editor link until post-commit refresh settlement, including read failures (intentional change from reachable legacy early navigation).
- Keep accepted refresh Future settlement independent of public owner disposal, and visually disable Logout from the same shared admission predicate used by its callback.
- Specify deterministic race, privacy, runtime-reporting and disposal regressions. Planning only: implementation requires separate authorization after independent plan review.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `command-execution-concurrency`: Admin credential-free admission, cross-operation session policy, dashboard read/mutation ordering, settlement and owner revocation.

Existing `external-event-provenance-moderation` already owns ignored-source authorization, explicit unIgnore and pending navigation. Its requirements remain unchanged. `canonical-app-routing` governs canonical content URIs, not a new admin routing contract; no redundant navigation/auth capability is introduced for this migration.

## Impact

Five production surfaces: two admin ViewModels, two admin screens, and the dashboard initialization in router.dart. Auth remains application-scoped and Dashboard route-scoped. Relevant VM/widget/routing/lifecycle tests and existing test/support may be adapted during an authorized apply. Repository, anonymous-session helper, dependency composition, backend, command foundation/global reporting and dependency versions remain unchanged. AdminSubmissionEditorViewModel and its legacy Commands belong to OpenSpec 7; improve-admin-submission-editor-workflow is excluded.

B0 at e80dfbaf472ef1cc15b220a48df966509a9ee8a1 is 52 INFO / 0 WARNING / 0 ERROR; the target set is exactly 15 deprecations (Auth 6, Dashboard 9). An eventual B1 must remove those identities only, leaving 37 INFO with no new diagnostics. Counts alone are insufficient; see analyzer-baseline.md and design.md.
