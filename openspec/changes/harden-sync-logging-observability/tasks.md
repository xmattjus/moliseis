# Tasks

All verification work in this change is performed **automatically by Codex during apply**. Writing a test or listing a command is not task completion. Tests need observed execution results. Planning-only publication of this change does not execute these tasks.

## 1. Verify implementation preflight and safety boundaries

- [ ] 1.1 Recheck implementation branch HEAD against planning baseline `f674d7e4e6771d7588c0f894d6f1768b14663851`, read `AGENTS.md`, target OpenSpec specs, current SDK lockfile/source, sync/submission implementation and related tests. Record only material drift. Preserve unrelated active changes/worktrees.
- [ ] 1.2 Identify all catch-to-`Result.error` and duplicate-report paths for sync cursor, repository prepare/commit, ObjectBox coordinator, settings persistence and startup; identify actual reporting owners before adding events. Confirm `Result.error(Exception)` and existing ObjectBox rollback guarantees.

## 2. Make sync diagnostics meaningful

- [ ] 2.1 Introduce minimal typed sync events under `lib/utils/logging/events/` and connect the logger to the sync orchestration via existing composition. Provide one start and exactly one terminal outcome, accurate phase (including failing repository), bootstrap/delta mode, elapsed time, and clearly labeled fetched DTO counts when available.
- [ ] 2.2 Report cursor RPC/malformed responses, repository fetch, transaction, and settings persistence failures at appropriate owning boundaries with original exception/stack where available. Preserve upstream `Result` identity and return behavior. Do not capture the same exception twice or log arbitrary response/request data.
- [ ] 2.3 Replace info-level per-entity success noise with accurate aggregate reporting; ensure any optional per-entity debug events are not emitted before durable commit. Keep distinct events for completed content commit versus completed whole sync, with zero false successes during rollback or settings failure.
- [ ] 2.4 Correct avoidable exception-to-text conversions in affected settings/transaction paths without altering the global `Result` contract. For non-`Exception` ObjectBox `Error`, report original error/stack before a necessary Result-compatible wrapper, without duplicating repository-originated rollback errors or startup settings failures.

## 3. Adopt Sentry 10 stream tracing

- [ ] 3.1 Explicitly set `SentryTraceLifecycle.stream` in `main.dart`, preserving sampling, replay/PII options, SDK version, transport ownership and consent lifecycle.
- [ ] 3.2 Add the smallest reusable `Result`-aware `Sentry.startSpan` adapter under `lib/utils/logging/`; preserve `Success` and `Error` payloads, mark `Result.error` spans as `SentrySpanStatusV2.error`, rethrow unexpected errors unchanged, and never independently `captureException`.
- [ ] 3.3 Migrate `SyncUseCase.sync()` and `ContentSubmissionRepositoryImpl.submit()` away from `startTransaction`/`SpanStatus`/`finish`. Remove obsolete direct SDK imports, preserve each workflow's success, error mapping, logging and async ordering; add nested phase spans only if they materially aid the requirement and tests prove their semantics.
- [ ] 3.4 Add a narrow import/usage regression check for disallowed new direct Sentry logging/tracing in business layers. Explicitly allow authorized bootstrap, consent, privacy/replay and route-viewer/transport integrations. Do not mandate relocation of `SentryLoggingFlag`, `command_configuration.dart`, or `$talker` without a concrete benefit.

## 4. Add deterministic regression coverage

- [ ] 4.1 Extend `test/data/core/supabase_sync_cursor_source_test.dart`, `test/domain/use_cases/sync_use_case_test.dart` and `test/data/core/base_sync_repository_test.dart` for malformed/failed cursor, all four prepare failures, terminal phase/outcome uniqueness, original error where applicable, bootstrap/delta/empty sync and precise fetched-count semantics. Update assertions that formerly expected premature successes.
- [ ] 4.2 Extend `test/domain/use_cases/sync_use_case_objectbox_test.dart` and coordinator/settings tests using the **real temporary ObjectBox store**: fail a later commit after prior staged writes; prove atomic rollback and *absence* of success events. Fail `setSyncState` after content commit; prove content persisted, previous cursor authority retained, and sync failure reported. Test transaction-native errors separately from already-logged rollback Result errors.
- [ ] 4.3 Replace the sync test's forced `SentryTraceLifecycle.static`/`beforeSendTransaction` with streaming verification at deterministic sampling `1.0` using `beforeSendSpan` or a controlled recording transport and awaited dispatch/flush. Assert real emitted span names/statuses for success, cursor/prepare/commit/settings errors; a `NoOpSentrySpan` alone is not acceptance.
- [ ] 4.4 Add equivalent streaming trace regression for `ContentSubmissionRepositoryImpl` success and normalized/transport/format failures; test the adapter's returned `Result.error`, `Success`, unexpected throw, and disabled/non-sampled callback execution. Assert no extra Sentry exception capture and parent-child span relationships only if nested spans were added.
- [ ] 4.5 Regress consent-protected local logging, original error/stack at the catch/report point, valid SDK-import exceptions, and relevant existing AppLogger, Settings/bootstrap and networking behavior.

## 5. Codex executes verification (mandatory)

- [ ] 5.1 **RUN**, do not merely prepare, focused Flutter tests for touched components: at minimum `test/domain/use_cases/sync_use_case_test.dart`, `test/domain/use_cases/sync_use_case_objectbox_test.dart`, `test/data/core/base_sync_repository_test.dart`, `test/data/core/supabase_sync_cursor_source_test.dart`, `test/data/core/objectbox_sync_transaction_coordinator_test.dart`, `test/data/sources/settings_local_data_source_test.dart`, `test/data/repositories/content_submission_repository_impl_test.dart`, `test/utils/logging/app_logger_test.dart`, `test/config/bootstrap_test.dart`, `test/domain/use_cases/set_crash_reporting_use_case_test.dart`, plus the new adapter/enforcement tests. Use `flutter test --no-pub` with the relevant paths. Record exact commands, exit codes, number of tests, and any failures in the final response, not generated repository logs.
- [ ] 5.2 **RUN** the entire `flutter test --no-pub` suite and `flutter analyze --no-pub` after focused tests. **RUN** Dart format checking on changed Dart sources, `git diff --check`, and strict `openspec validate harden-sync-logging-observability --strict`. Repair regressions and rerun affected suites; distinguish pre-existing failures with actual comparable baseline evidence. No false-green test disabling, undocumented skips, or relying on previous agent-reported passes.
- [ ] 5.3 Execute deterministic local test assertions for successful and failed sync with Sentry consent both enabled and disabled; local diagnostics SHALL remain available in both cases, remote capture SHALL honor consent. Use fake/loopback Sentry transport rather than production credentials; native Android/iOS tests are required only if SDK initialization, native shutdown, HTTP ownership, or Replay changes.
- [ ] 5.4 If any mandatory check cannot run because Flutter, ObjectBox native binaries, SDK tooling or required local resources are unavailable, explicitly report the exact blocker, command and partial evidence; leave its task unchecked and do not declare the change implementation-ready or verified.

## 6. Review and handoff

- [ ] 6.1 Independently inspect the whole diff against the agreed constraints: correct sync outcome and error ownership, no duplicate captures, accurate aggregate counts and rollback semantics, Sentry stream compatibility, no consent/HTTP regression, no new packages, no unrelated SQL/Cloudinary/UI edits. Keep only durable OpenSpec artifacts and genuine test fixtures in Git; never commit raw test logs, temporary analyzer dumps, recordings or generated operational evidence.
- [ ] 6.2 Once verification is complete, publish/review implementation on the same cohesive PR according to `AGENTS.md`. Do not merge, deploy, synchronize canonical specs or archive OpenSpec without separate explicit authorization.
