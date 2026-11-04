# Design

## Context and evidence

Planning baseline: `xmattjus/moliseis` remote `main` at `f674d7e4e6771d7588c0f894d6f1768b14663851`, reviewed for TASK-41 on 2026-11-03/04. Recheck the implementation branch before apply; do not assume the commit equals an installed build.

- `SyncUseCase.sync()` runs cursor acquisition, four concurrent preparations, a single ObjectBox write transaction, then `setSyncState`. It currently returns early on `Result.error` and only finishes a Sentry transaction, without one structured local terminal outcome.
- `SupabaseSyncCursorSource` returns `Result.error` for RPC/format failures without recording the originating exception/stack. `ObjectBoxSyncTransactionCoordinator` discards some original errors/stack by converting `Error` to a textual `Exception`. `SettingsLocalDataSource` wraps error/stack in an exception message.
- `BaseSyncRepository.commitSync` logs per-entity successes and `RepositorySyncFinished` *inside* the outer transaction, before `putMany` and before other repositories can fail. `test/data/core/base_sync_repository_test.dart` expects those events; `test/domain/use_cases/sync_use_case_objectbox_test.dart` already provides a real rollback foundation.
- `Result.error` accepts `Exception`, not arbitrary `Object`, and has no stack field. A global Result redesign is outside this change.
- `AppLogger` sends Talker events regardless of consent; enabled info+ events become Sentry breadcrumbs, while attached errors at error+ are captured as Sentry exceptions. A second terminal error log carrying the same throwable would duplicate remote reports.
- `pubspec.lock` pins `sentry`, `sentry_flutter`, `sentry_supabase` at 10.0.0-rc.2. Upstream `SentryOptions.traceLifecycle` defaults to `stream`; `Hub.startTransaction` returns a no-op span there. `Sentry.startSpan` uses an async callback, Zone propagation, and `SentrySpanStatusV2`. Unlike a thrown error, an ordinary `Result.error` does not mark that callback as failed automatically.
- `lib/main.dart` already reads persisted consent before initializing Sentry and has a dedicated Sentry HTTP client. The completed consent-and-replay work is a protected boundary, not an invitation to refactor.

## Goals / non-goals

**Goals:** reliable local sync phase/outcome diagnostics, no premature success logs, useful bounded counters, preserved error/stack at the reporting boundary, one remote exception capture per handled failure, effective stream-compatible traces for sync and content submission, automated deterministic verification.

**Non-goals:** new analytics/backend tables, SDK upgrade, logging framework rewrite, database or wire contract changes, generalized `Result` or domain/data architecture migration, changing command lifecycles, Cloudinary logging cleanup, new user-facing switches/screens, universal telemetry privacy proof, and a general Sentry/HTTP consent refactor.

## Decisions

### D1. Local-first ownership and truthful terminal outcome

The sync orchestration owns one typed start event and exactly one terminal event per admitted `sync()` invocation, including error returns and unexpected thrown failures. Use a single terminal publication path (for example an orchestrator-level `try/finally` with recorded phase/outcome) so early returns cannot skip reporting. Log only after known state transitions; use canonical phase labels such as `cursor`, `prepare_city`/`prepare_place`/`prepare_event`/`prepare_media`, `commit` and `settings`. A completed content commit is not a completed sync until `setSyncState` succeeds.

Include only bounded context: bootstrap versus delta (derived from whether C is null), elapsed duration, fetched DTO totals or per-repository counts and a non-sensitive error *class* / phase. Counts of fetched DTOs MUST NOT be labeled as actual database insert/update/delete counts. Avoid arbitrary raw values, payload bodies, URLs, user identities, tokens, or user-supplied strings. Keep default event names valid under `eventNamePattern` and keep useful info-level summaries sparse.

Each handled exception has exactly one owner that can attach `error` and `stackTrace` to the error-level log. The terminal event is independent and MUST NOT attach the same exception if it was already logged and captured downstream. Preserve existing `RepositorySyncFailed` reporting for repository prepare/commit failures without recapturing them. For cursor and transaction failures not already reported, add a focused reporting boundary; for settings failure, coordinate with existing startup/Settings reporting so the same caught exception is not captured twice. The orchestrator may add a phase-tagged terminal failure event without throwable; when there is no lower reporter it must ensure an owned reporting path. Unexpected exceptions should retain their original thrown identity/stack and not be converted to ordinary `Result.error` just to satisfy logging.

Do not assume the Sentry event itself is diagnostic truth: sampling and opt-out mean local Talker events must be sufficient on their own.

### D2. No success before durable commit

Eliminate `EntityInsertSuccess`, `EntityUpdateSuccess`, `EntityDeleteSuccess` and `RepositorySyncFinished` from the uncommitted `BaseSyncRepository.commitSync` path. Keep the underlying merge/batch write behavior unchanged. Simplest preferred implementation: remove the premature success emissions, then publish aggregate content-commit success from the orchestrator *after* the transaction coordinator reports success. Only restore per-entity debug events if their meaning and deferred emission are demonstrably sound; do not build a callback buffering framework for them.

If useful, retain a separate `content_commit_succeeded` diagnostic for the case where the later settings save fails: this describes the genuinely committed content, not a completed sync. Never emit a sync terminal success until durable cursor persistence succeeds. Preserve all existing transaction rollback and replay semantics.

### D3. Error identity without widening Result

`Result.error` remains `Exception`-typed. Retain the actual `Exception` object where possible instead of serializing it into a new string exception. Log the original exception and captured `StackTrace` where it is caught; downstream `Result` may not contain a stack. For a caught non-`Exception` `Error` at the ObjectBox boundary, log the original `Error` and stack at its source, and translate only if the existing recoverable `Result` contract requires an `Exception`. Distinguish this compatibility wrapper from the original error and avoid a misleading string-only "preserved" claim.

The coordinator must not double-report errors that originate as `Result.error` from a repository callback and were already logged there. Verify whether an exception originated from the callback or ObjectBox transaction machinery rather than blindly logging every caught rollback exception. Reconcile any new settings-source logging with the existing `handleSettingsRepositoryInitialization` hook to avoid duplicate reporting during startup.

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
- Cursor invalid scalar and RPC/transport failures; failure of each prepare; late commit rollback; settings failure after committed content; bootstrap/delta success and zero-DTO sync; one and only one phase-tagged terminal event and no false success events; no duplicate exception forwarding.
- `Result` tracing adapter success, returned error, thrown error; actual recorded streaming span (not just a callback invocation); correct status for both business workflows with trace sampling 1.0 and reliable observation/flush, not `beforeSendTransaction` in static mode. Cover non-consenting/no-op paths without changing consent handling.
- Logging imports and existing AppLogger behavior; no unapproved direct Sentry usage, existing bootstrap/Settings consent and HTTP ownership regression tests where affected.

Codex must execute focused suites, full `flutter test --no-pub`, `flutter analyze --no-pub`, formatting and strict OpenSpec validation, recording commands and observed exit codes in its completion report. A failed/blocked test remains open, not "passed" by assertion; distinguish pre-existing failures with reproducible baseline evidence. Test output and generated reports stay outside version control unless a specific permanent regression fixture is truly necessary. Do not commit analyzer dumps, run logs, temporary manifest files or synthetic telemetry recordings.

## Risks and mitigations

- **Double remote exception capture:** report once at the originating catch and publish terminal lifecycle events without reattaching an already-captured throwable; assert capture counts.
- **Misleading success after rollback:** no entity/repository success while transaction is open; verify with actual ObjectBox rollback.
- **False green tracing test:** no static lifecycle override; use streaming callback/transport with deterministic sampling and assert a real emitted span. Debug production config samples traces at zero.
- **Unrelated settings/consent regression:** preserve persisted preference and client ownership, cover affected tests, and avoid widening settings handling beyond necessary error fidelity.
- **Scope expansion:** this is operational reporting only; do not touch SQL, sync protocol, Cloudinary cleanup or broad architecture.
- **Environment unavailable during apply:** Codex must report exact unavailable commands and leave verification tasks incomplete. Native Android/iOS testing is not mandatory unless SDK initialization, native lifecycle/HTTP ownership or Replay are changed.

## Handoff and rollback

All edits remain on a task-specific PR. Do not merge, sync delta specifications into canonical specs, archive, or deploy without a separate user request and completed verification. Reverting implementation should restore original logging/tracing without touching persisted content; no data migration is expected. The existing unrelated active imported-asset OpenSpec change must remain untouched.
