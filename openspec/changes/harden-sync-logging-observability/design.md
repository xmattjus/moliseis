# Design

## Context and evidence

Planning baseline: `xmattjus/moliseis` remote `main` at `f674d7e4e6771d7588c0f894d6f1768b14663851`, reviewed for TASK-41 on 2026-11-03/04. Recheck the implementation branch before apply; do not assume the commit equals an installed build.

- `SyncUseCase.sync()` runs cursor acquisition, four concurrent preparations, a single ObjectBox write transaction, then `setSyncState`. It currently returns early on `Result.error` and only finishes a Sentry transaction, without one structured local terminal outcome.
- `SupabaseSyncCursorSource` returns `Result.error` for RPC/format failures without recording the originating exception/stack. `ObjectBoxSyncTransactionCoordinator` uses `on Error<Object>`, which resolves to the generic `Result.Error<Object>`, **not** the runtime `dart:core.Error`: its apparent runtime-Error catch is ineffective. Caught `Exception` stack information is also lost. `SettingsLocalDataSource` serializes original errors/stacks into new `Exception` messages.
- `BaseSyncRepository.commitSync` logs `EntityInsertSuccess`, `EntityUpdateSuccess` and `EntityDeleteSuccess` **before** `putMany`. It logs `RepositorySyncFinished` **after** `putMany`, but still **before the outer ObjectBox transaction commits**; later rollback can invalidate any of these successes. `test/data/core/base_sync_repository_test.dart` expects those events; `test/domain/use_cases/sync_use_case_objectbox_test.dart` provides a real rollback foundation.
- `Result.error` accepts `Exception`, not arbitrary `Object`, and has no stack field. A global Result redesign is outside this change.
- `AppLogger` sends Talker events regardless of consent; enabled info+ events become Sentry breadcrumbs, while attached errors at error+ are captured as Sentry exceptions. A second terminal error log carrying the same throwable would duplicate remote reports.
- `pubspec.lock` pins `sentry`, `sentry_flutter`, `sentry_supabase` at 10.0.0-rc.2. Upstream `SentryOptions.traceLifecycle` defaults to `stream`; `Hub.startTransaction` returns a no-op span there. `Sentry.startSpan` uses an async callback, Zone propagation, and `SentrySpanStatusV2`. Unlike a thrown error, an ordinary `Result.error` does not mark that callback as failed automatically.
- `lib/main.dart` already reads persisted consent before initializing Sentry and has a dedicated Sentry HTTP client. The completed consent-and-replay work is a protected boundary, not an invitation to refactor.

## Goals / non-goals

**Goals:** reliable local sync phase/outcome diagnostics, no premature success logs, useful bounded counters, original throwable/stack retained for local diagnosis, zero app-initiated remote captures for classified expected failures and one sanitized capture per consented, reportable failure, effective streaming traces, and automated deterministic verification.

**Non-goals:** new analytics/backend tables, SDK upgrade, logging framework rewrite, database or wire contract changes, generalized `Result` or domain/data architecture migration, changing command lifecycles, Cloudinary logging cleanup, new user-facing switches/screens, universal telemetry privacy proof, and a general Sentry/HTTP consent refactor.

## Decisions

### D1. Local-first ownership and truthful terminal outcome

The sync orchestration owns one typed start event and exactly one terminal event per admitted `sync()` invocation, including error returns and unexpected thrown failures. Use a single terminal publication path (for example an orchestrator-level `try/finally` with recorded phase/outcome) so early returns cannot skip reporting. Log only after known state transitions; use canonical phase labels such as `cursor`, `prepare_city`/`prepare_place`/`prepare_event`/`prepare_media`, `commit` and `settings`. A completed content commit is not a completed sync until `setSyncState` succeeds.

Include only bounded context: bootstrap versus delta, where **C means the local persisted `SettingsRepository.contentSyncCursorAt` captured at sync entry, before `setSyncState`**; `C == null` means bootstrap. The independently fetched server cursor `U` does **not** classify sync mode. Include elapsed duration, fetched DTO totals or per-repository counts and an allowlisted failure category / phase. Fetched DTO counts MUST NOT be mislabeled as actual database insert/update/delete counts. Exclude arbitrary raw values, HTTP bodies, URLs, user identities, tokens and user-supplied strings; keep `eventNamePattern` valid and info-level summaries sparse.

Reporting ownership is **phase-specific**, rather than repeated at every layer:

- **Cursor:** `SupabaseSyncCursorSource` owns the original RPC/decode `Exception` and captured stack, including malformed responses, before returning `Result.error`.
- **Repository prepare/commit:** the existing `BaseSyncRepository` catch and `RepositorySyncFailed` own callback failures; a coordinator rollback must not cause another capture for that already-reported failure.
- **Transaction-native failure:** `ObjectBoxSyncTransactionCoordinator` owns newly raised ObjectBox errors/Exceptions (and otherwise unreported callback throws), preserving original cause/stack before any `Result`-compatible conversion.
- **Runtime sync-state persistence:** the catch in `SettingsLocalDataSource.update` has the original exception and stack and owns **cause reporting** for a failed `setSyncState`. `SettingsRepositoryImpl` passes it through, and `SyncUseCase` owns only the phase-tagged `settings` terminal result, with no recapture. The startup `handleSettingsRepositoryInitialization` hook reports initialization/`load` failures, **not** later `update` failures. Keep startup handling unchanged and prevent new reporting from duplicating other Settings callers.

`SyncUseCase` emits exactly one terminal event without attaching a throwable, on success, `Result.error`, or unexpected throw. It must identify the correct phase even when a fake/nonstandard repository implementation returns an unreported failure. Preserve original unexpected throws/stacks; do not silently convert them into a normal `Result.error`.

**Local cause versus remote payload:** use a small explicit classifier for the handled sync paths. Expected transient connectivity/timeouts are **local-only** (zero application-initiated Sentry exception captures); unexpected malformed data/cursor contracts and unexpected storage/transaction failures are **reportable** (exactly one sanitized, consent-gated application capture from the owner). Neither a returned `Result.error` nor its phase alone authorizes indiscriminate capture.

Keep the original `Object` and `StackTrace` accessible for local Talker diagnostics, but do not forward untrusted `error.toString()`/messages, raw stacks, HTTP bodies, URLs, credentials, tokens, or contributor details to Sentry. Use stable allowlisted failure categories and context; only reviewed-safe stack data may be transmitted. **`AppLogger.log(error: ...)` currently forwards the original throwable to `Sentry.captureException`**, so adding safe `LogEvent.data` fields alone is insufficient. Provide the smallest scoped local-only/sanitized-remote reporting boundary for these sync paths (including `RepositorySyncFailed`), without a general logging rewrite. Breadcrumbs and streaming-span attributes use the same safe-field rules. Consent off yields zero remote captures. This policy governs application-triggered captures for handled failures, not unrelated automatic SDK crash capture.

Local Talker events are the durable diagnostic source of truth independently of Sentry sampling and opt-out.

### D2. No success before durable commit

Eliminate `EntityInsertSuccess`, `EntityUpdateSuccess`, `EntityDeleteSuccess` and `RepositorySyncFinished` from the uncommitted `BaseSyncRepository.commitSync` path. Keep the underlying merge/batch write behavior unchanged. Simplest preferred implementation: remove the premature success emissions, then publish aggregate content-commit success from the orchestrator *after* the transaction coordinator reports success. Only restore per-entity debug events if their meaning and deferred emission are demonstrably sound; do not build a callback buffering framework for them.

If useful, retain a separate `content_commit_succeeded` diagnostic for the case where the later settings save fails: this describes the genuinely committed content, not a completed sync. Never emit a sync terminal success until durable cursor persistence succeeds. Preserve all existing transaction rollback and replay semantics.

### D3. Error identity without widening Result

`Result.error` remains `Exception`-typed. Retain the original `Exception` where possible; preserve the original `StackTrace` at its catch/reporting boundary, since `Result` carries no stack. The existing `on Error<Object>` in `ObjectBoxSyncTransactionCoordinator` resolves to `Result.Error<Object>` rather than Dart's non-generic `dart:core.Error`. Correct the collision explicitly (e.g. prefixed import for `core.Error` while retaining `Error<void>` for Result pattern matching). For a real runtime `core.Error`, report original identity/stack **locally** before any `Result.error(Exception)` compatibility wrapper. Do not call that wrapper the preserved original error.

The coordinator currently throws a callback's `Result.error` exception to force rollback, then catches it alongside genuine transaction exceptions. Use a private rollback sentinel/marker or equivalent explicit outcome to **distinguish callback Result failure** (preserve the same result and its existing reporting owner, with no new capture) from **native transaction failure or otherwise unreported callback throw** (the coordinator owns reporting). Verify both paths using a real store. The Settings `update` runtime owner is separate from startup `load`; avoid modifying unrelated Settings paths or duplicating the startup hook.

Do not add an application-wide error envelope or alter the shared Result API solely for this task.

### D4. Sentry 10 streaming adapter

Set `..traceLifecycle = SentryTraceLifecycle.stream` explicitly in the existing `main.dart` Sentry configuration. Keep `tracesSampleRate`, replay rates, SDK transport and persisted consent unchanged.

Add one minimal utility under `lib/utils/logging/`, provisionally `runTracedResult<T>(String name, Future<Result<T>> Function() action)`. Implement it with `Sentry.startSpan(name, (span) async { ... })`. A successful Result leaves status `ok`; a `Result.error` sets `span.status = SentrySpanStatusV2.error`; an unexpected thrown error propagates and is marked as failed by the SDK. Do not invoke `captureException` in this adapter. Under disabled or sampled-out SDK, the callback still executes and preserves the exact business result.

Replace both `SyncUseCase.sync()` and `ContentSubmissionRepositoryImpl.submit()` `startTransaction`/`SpanStatus`/`finish` with the utility. Factor an existing operation body into a private method if that simplifies the change. Retain function exception normalization, content-submission log events and all business behavior; remove `unawaited(transaction.finish(...))` only when it no longer serves another purpose.

Optional nested spans for cursor, concurrent repository fetch, content commit, and cursor persistence must be justified by measurable phase questions and tested for parent/child behavior. They are not necessary merely to satisfy a span-count target. Stream tracing names/attributes must avoid PII.

### D5. Logging boundary, not infrastructure relocation

Keep `Logger` / `AppLogger` / typed `LogEvent` as the sole application logging pattern; implement the new events and Sentry stream adapter under `lib/utils/logging`. Remove Sentry SDK imports from the two migrated business call sites.

A small import/ownership regression check may enforce no direct `startTransaction` from application business layers and prohibit unreviewed direct SDK-reporting calls outside the logging adapter. Explicit legitimate exceptions include `main.dart` SDK bootstrap, `SentryMask` UI, consent/Replay integration, Sentry transport, and the Talker route observer/viewer. `SentryLoggingFlag` is also a consent-to-forwarding state bridge; `command_configuration.dart` is a global command handler; and the existing `$talker` in composition intentionally serves a route observer. Do not relocate these solely for folder purity. Move a specific component only when an identified correctness/ownership advantage outweighs churn, and do not broaden to a repository-wide move.

### D6. Automated verification owned by Codex

During apply, Codex must add or adapt deterministic tests **and execute them itself** on the implementation branch. Use existing `test/support/mock_logger.dart` and ObjectBox test-store infrastructure; do not manufacture success by mocking the transaction boundary in the rollback acceptance test.

Required surfaces:
- Cursor invalid scalar and RPC/transport failures; failure of each prepare; late commit rollback; settings failure after committed content; bootstrap/delta success and zero-DTO sync; one and only one phase-tagged terminal event and no false success events. With consent enabled, assert **zero remote captures** for expected failures and **exactly one sanitized capture** per reportable cursor/prepare/commit/settings failure, without terminal recapture.
- `Result` tracing adapter success, returned error, thrown error; actual recorded streaming span (not just a callback invocation); correct status for both business workflows with trace sampling 1.0 and reliable observation/flush, not `beforeSendTransaction` in static mode. Cover non-consenting/no-op paths without changing consent handling.
- Scoped AppLogger local/remote forwarding behavior; synthetic sensitive values in throwable text, stack/context, URL/headers, HTTP bodies and contributor fields absent from remote exceptions, breadcrumbs and spans while original diagnostics remain local; no unapproved Sentry imports, and regression coverage of existing bootstrap/Settings consent and HTTP ownership where affected.

Codex must execute focused suites, full `flutter test --no-pub`, `flutter analyze --no-pub`, formatting and strict OpenSpec validation, recording commands and observed exit codes in its completion report. A failed/blocked test remains open, not "passed" by assertion; distinguish pre-existing failures with reproducible baseline evidence. Test output and generated reports stay outside version control unless a specific permanent regression fixture is truly necessary. Do not commit analyzer dumps, run logs, temporary manifest files or synthetic telemetry recordings.

## Risks and mitigations

- **Excessive, duplicated or unsafe remote capture:** report the original cause locally at its owner; emit terminal events without throwable. Test zero captures for expected failures, exactly one sanitized application capture for reportable handled failures with consent, and no sensitive payload leakage.
- **Misleading success after rollback:** no entity/repository success while transaction is open; verify with actual ObjectBox rollback.
- **False green tracing test:** no static lifecycle override; use streaming callback/transport with deterministic sampling and assert a real emitted span. Debug production config samples traces at zero.
- **Unrelated settings/consent regression:** preserve persisted preference and client ownership, cover affected tests, and avoid widening settings handling beyond necessary error fidelity.
- **Scope expansion:** this is operational reporting only; do not touch SQL, sync protocol, Cloudinary cleanup or broad architecture.
- **Environment unavailable during apply:** Codex must report exact unavailable commands and leave verification tasks incomplete. Native Android/iOS testing is not mandatory unless SDK initialization, native lifecycle/HTTP ownership or Replay are changed.

## Handoff and rollback

All edits remain on a task-specific PR. Do not merge, sync delta specifications into canonical specs, archive, or deploy without a separate user request and completed verification. Reverting implementation should restore original logging/tracing without touching persisted content; no data migration is expected. The existing unrelated active imported-asset OpenSpec change must remain untouched.
