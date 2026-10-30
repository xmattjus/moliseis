# Proposal

## Why

Disabling error reporting currently changes only custom logger forwarding, leaving automatic Sentry integrations active; startup also initializes telemetry before reading consent. Sentry owns an HTTP client shared with application networking, so simply closing it would break application requests, while moderation screens expose contributor identity in otherwise intentionally useful Replay recordings.

## What Changes

- Establish independent Sentry/application HTTP resource ownership, including the underlying fallback client, before introducing runtime shutdown.
- Read existing ObjectBox settings before telemetry initialization. Retain the first-install default; keep telemetry off on an unreadable preference while preserving ordinary application settings fallback.
- Persist consent first; stop custom forwarding and close the SDK on committed opt-out. Opt-in takes effect only at the next full process start, without Flutter restart or runtime reinitialization.
- Coordinate committed consent and the single shutdown operation at application scope, independently of Settings presentation lifetime. Preserve ordinary command admission, optimistic rollback, committed-cache authority and existing write ordering.
- Use the existing Snackbar for both directions with accurate success copy and distinct saved-preference/shutdown-failure feedback.
- Preserve globally unmasked Replay text/images and existing public-form masks. Mask dashboard contributor name separately from its date, and the editor's `Proposto da` name/email. Preserve `Creato come` administrator account context.
- Require deterministic automated acceptance and separate Android/iOS native shutdown and synthetic Replay gates. Allow SDK draining of telemetry acquired before effective revocation; make no zero-network-after-tap claim.

## Capabilities

### New Capabilities

- `sentry-consent-lifecycle`: consent-aware startup, independently owned transport, one-way runtime shutdown, truthful Settings outcomes and native acceptance.
- `session-replay-privacy`: selective contributor-identity protection while retaining useful public/editorial Replay content.

### Modified Capabilities

- `command-execution-concurrency`: narrowly allow application-owned SDK shutdown after already-started consent persistence, superseding the existing no-new-I/O constraint only for telemetry reconciliation; retain all presentation and repository-phase restrictions and current persistence-order semantics.

## Impact

Verified planning baseline: `main` and fetched `origin/main` at `80223649dc09d94abc8d1558418ed257d4331906` (2026-10-30). Tracked `pubspec.lock` resolves Sentry Dart/Flutter/Supabase 10.0.0-rc.2 and HTTP 1.6.0; iOS uses Swift Package Manager with Cocoa 9.27.0. Exact code evidence, native limits and related archived contracts are recorded in design.md.

Affected implementation surfaces are `lib/main.dart`, HTTP factory, Provider composition, Settings ViewModel/screen, existing logging flag, a bounded application-owned consent operation, and two moderation widgets plus focused tests. No database/API/schema changes, dependency upgrades, general logging/networking refactor, new persistent storage, privacy framework, restart controls or global masking are intended. Historical command-migration artifacts remain unchanged; only delta specifications change the current contract.

This definition is planning only. Implementation tasks remain unchecked; no application changes, apply, implementation PR, merge, deployment, spec sync or archive are performed.
