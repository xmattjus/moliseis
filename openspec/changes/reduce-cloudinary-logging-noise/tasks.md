# Tasks

All tasks below describe future implementation and verification. None were performed by publishing this planning PR. Use the applicable `AGENTS.md`, existing test fixtures and an isolated branch/PR. Do not sync canonical specs, archive, merge or deploy without separate authorization.

## 1. Recheck the implementation baseline and error ownership

- [ ] 1.1 Read current `main`/implementation branch diff against planning baseline `40c36e607adc34885e2df5e858178bc61bfe7660`; inspect Cloudinary client, cancellation token, public submission ViewModel/repository, Admin repository/editor, `AppLogger`/breadcrumb filter, current canonical specs and relevant tests. Report material drift without broadening this change.
- [ ] 1.2 Map each current event to its actual owner, level, `error:` attachment and Sentry path. Reproduce or rule out duplicate `request.done`/`request.close()` reporting, including a request that fails before the main close await. Identify the smallest intervention preserving async error handling.

## 2. Correct Cloudinary client signal and privacy

- [ ] 2.1 Keep intermediate HTTP 5xx and upload/response-body timeout retries as local diagnostic events below error severity. Report no terminal failure if a later attempt succeeds. Update targeted event contracts/tests without changing bounded retry or backoff decisions.
- [ ] 2.2 Report exactly one safe terminal client non-success for admitted operations (including invalid response, preparation/preflight and file-read errors) where applicable. Keep failures prior to POST distinct from remote failures and preserve existing `Result` semantics; do not claim remote asset absence after ambiguous transport outcomes.
- [ ] 2.3 Make intentional cancellation benign and non-duplicative for pre-start, in-flight, response-body and backoff cases. Preserve abort behavior, no late success, monotonic progress and disposal. Keep the passive async error listener or replace it only if deterministic tests establish equivalent safety.
- [ ] 2.4 Preserve distinct successful new-upload and duplicate-reuse signals. Ensure remotely forwarded metadata does not include raw asset public IDs/digests, URLs, filenames, local paths, body text or contributor content.
- [ ] 2.5 Eliminate arbitrary/unbounded Cloudinary HTTP body and exception/stack transmission in affected logging paths. Use the existing logging/Sentry mechanisms with only the smallest necessary scoped reporting change; do not add a new logging framework or SDK lifecycle changes.

## 3. Identify post-upload association outcomes without changing persistence

- [ ] 3.1 At the existing public `submit-content` response boundary, distinguish valid server confirmation/replay, explicitly rejected request and unconfirmed remote outcome, while preserving error normalization, `Result<void>`, identity/retry/finalization and zero-asset submissions. Reuse existing failure reporting rather than creating duplicate error captures.
- [ ] 3.2 At the Admin `associateStagedAsset` boundary, distinguish confirmation/replay, explicit rejection and unconfirmed outcome without moving orchestration into local storage. Preserve staged upload receipts, partial-failure states, exact-receipt replay, authority guards and other Admin operation behavior.
- [ ] 3.3 Verify reporting remains truthful for multi-asset public submissions and Admin upload-then-association failures, with no inferred orphan count, cross-service rollback, newly persistent tracking ID or remote-protocol changes.

## 4. Execute deterministic regressions

- [ ] 4.1 Extend `test/data/services/api/cloudinary/cloudinary_upload_client_impl_test.dart` and `test/utils/logging/log_event_test.dart`: success, duplicate/no POST, HTTP 4xx/5xx, transient successful retry, exhausted timeout, body-timeout, file-read/preflight/invalid response, cancellation and `request.done` fault injection. Assert safe outcome event counts/severities, current `Result`, and progress invariants; remove obsolete assertions expecting error-level interim attempts.
- [ ] 4.2 Extend `test/data/repositories/content_submission_repository_impl_test.dart` and pertinent public ViewModel tests for confirmed/replayed, explicit rejection, ambiguous and zero-asset requests following uploaded media. Assert no wrong association-success log, duplicate capture or state/identity regression.
- [ ] 4.3 Extend `test/data/repositories/admin_content_submission_repository_impl_test.dart` and pertinent Admin editor tests for confirmed/replayed and failed/ambiguous staged association. Assert receipt survival, replay, correct reporting owner and no new false success.
- [ ] 4.4 Use the existing `test/utils/logging/app_logger_test.dart` and `test/utils/logging/talker_console_privacy_test.dart` (plus minimal focused fixtures) for a consent-enabled/disabled privacy matrix with synthetic HTTP-body/exception canaries. Inspect captured Sentry exception envelopes, typed breadcrumbs and real Talker console fragments; verify originals are not forwarded and expected retry/cancellation causes produce no remote captures.
- [ ] 4.5 **Run** focused Flutter tests for modified modules, then the relevant full `flutter test --no-pub` suite, `flutter analyze --no-pub`, Dart formatting and `git diff --check`. **Run** `openspec validate reduce-cloudinary-logging-noise --strict`. Report exact commands, exit codes, and actual failures by commit; compare pre-existing failures with evidence instead of accepting false-green skips. Add native tests only if native Sentry lifecycle or platform behavior is materially changed.

## 5. Independent review and handoff

- [ ] 5.1 Inspect the implementation diff against the delta spec and the unchanged canonical public/Admin persistence, SDK consent/tracing and Cloudinary contracts. Confirm no new dependency, schema/RPC/Edge Function change, importer work, automatic cleanup, unrelated refactor or generated test log in Git.
- [ ] 5.2 Publish implementation and any review fixes in the same cohesive change PR under `AGENTS.md`. Request explicit authorization separately before merge, canonical spec sync/archive or deployment.
