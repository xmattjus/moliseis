# Tasks

Implementation and regression verification use the isolated PR #31 branch and existing test fixtures. Checked tasks record completed work; unchecked tasks remain pending. Canonical spec sync, archive, merge and deployment require separate authorization.

## 1. Recheck the implementation baseline and error ownership

- [x] 1.1 Read current `main`/implementation branch diff against planning baseline `40c36e607adc34885e2df5e858178bc61bfe7660`; inspect Cloudinary client, cancellation token, public submission ViewModel/repository, Admin repository/editor, `AppLogger`/breadcrumb filter, current canonical specs and relevant tests. Report material drift without broadening this change.
- [x] 1.2 Map each current event to its actual owner, level, `error:` attachment and Sentry path. Reproduce or rule out duplicate `request.done`/`request.close()` reporting, including a request that fails before the main close await. Identify the smallest intervention preserving async error handling.

## 2. Correct Cloudinary client signal and privacy

- [x] 2.1 Keep intermediate HTTP 5xx and upload/response-body timeout retries as local diagnostic events below error severity. Report no terminal failure if a later attempt succeeds. Update targeted event contracts/tests without changing bounded retry or backoff decisions.
- [x] 2.2 Report exactly one safe terminal client non-success for admitted operations (including invalid response, preparation/preflight and file-read errors) where applicable. Keep failures prior to POST distinct from remote failures and preserve existing `Result` semantics; do not claim remote asset absence after ambiguous transport outcomes.
- [x] 2.3 Make intentional cancellation benign and non-duplicative for pre-start, in-flight, response-body and backoff cases. Preserve abort behavior, no late success, monotonic progress and disposal. Keep the passive async error listener or replace it only if deterministic tests establish equivalent safety.
- [x] 2.4 Distinguish new upload from both preparation reuse (no POST) and Cloudinary POST response reuse (`existing: true`, possibly following a previous ambiguous attempt). Preserve the successful functional result; never claim no POST for response-level reuse. Ensure remotely forwarded metadata does not include raw asset public IDs/digests, URLs, filenames, local paths, body text or contributor content. For remotely forwarded Cloudinary events, enforce the safe closed-set metadata policy in `design.md`: exclude Supabase row IDs, authorization headers, tokens/JWTs, credentials and other authentication context, as well as asset public IDs/digests, URLs, local paths, filenames, HTTP bodies and contributor content, including via `extra`, exception payloads and console breadcrumbs.
- [x] 2.5 Eliminate arbitrary/unbounded Cloudinary HTTP body and exception/stack transmission in affected logging paths. Use the existing logging/Sentry mechanisms with only the smallest necessary scoped reporting change; do not add a new logging framework or SDK lifecycle changes.

## 3. Identify post-upload association outcomes without changing persistence

- [x] 3.1 At the existing public `submit-content` response boundary, distinguish valid server confirmation/replay, explicitly rejected request and unconfirmed remote outcome, while preserving error normalization, `Result<void>`, identity/retry/finalization and zero-asset submissions. Reuse existing failure reporting rather than creating duplicate error captures. Limit forwarded association metadata to safe operation/outcome categories from `design.md`; exclude Supabase row IDs, authentication context (including authorization material), asset identifiers and contributor data, even from error exceptions.
- [x] 3.2 At the Admin `associateStagedAsset` boundary, distinguish confirmation/replay, explicit rejection and unconfirmed outcome without moving orchestration into local storage. Preserve staged upload receipts, partial-failure states, exact-receipt replay, authority guards and other Admin operation behavior. Apply the same remote metadata allowlist as task 3.1: exclude Supabase row IDs (submission and asset), authorization headers/tokens, credentials, account context, receipt identifiers and user content.
- [x] 3.3 Verify reporting remains truthful for multi-asset public submissions and Admin upload-then-association failures, with no inferred orphan count, cross-service rollback, newly persistent tracking ID or remote-protocol changes. Assert public and Admin diagnostics follow those safe remote metadata exclusions in confirmed, rejected and ambiguous cases; never forward Supabase row IDs or authentication/authorization context.

## 4. Execute deterministic regressions

- [x] 4.1 Extend `test/data/services/api/cloudinary/cloudinary_upload_client_impl_test.dart` and `test/utils/logging/log_event_test.dart`: success, preparation duplicate/no POST, first-attempt and retry-response `existing: true`, HTTP 4xx/5xx, transient successful retry, exhausted timeout, body-timeout, file-read/preflight/invalid response, cancellation and `request.done` fault injection. Assert safe outcome event counts/severities, current `Result`, and progress invariants; remove obsolete assertions expecting error-level interim attempts. For `request.done` faults test both a failure observed by the main `request.close()` path and one otherwise observed only by the passive listener (e.g., before the main close await); explicitly assert no unhandled asynchronous error escapes (guarded-zone verification), a genuine reportable failure is not silently discarded, and the listener plus main path produce at most one terminal event/remote exception capture for one fault. Assert both **event classification and POST provenance**: preparation reuse has zero POST requests, while response-level `existing: true` reuse has at least one actual POST, is not labeled no-POST and is not labeled a new upload.
- [x] 4.2 Extend `test/data/repositories/content_submission_repository_impl_test.dart` and pertinent public ViewModel tests for confirmed/replayed, explicit rejection, ambiguous and zero-asset requests following uploaded media. Assert no wrong association-success log, duplicate capture or state/identity regression.
- [x] 4.3 Extend `test/data/repositories/admin_content_submission_repository_impl_test.dart` and pertinent Admin editor tests for confirmed/replayed and failed/ambiguous staged association. Assert receipt survival, replay, correct reporting owner and no new false success.
- [x] 4.4 Use the existing `test/utils/logging/app_logger_test.dart` and `test/utils/logging/talker_console_privacy_test.dart` (plus minimal focused fixtures) for a consent-enabled/disabled privacy matrix with synthetic HTTP-body/exception canaries. Inspect captured Sentry exception envelopes, typed breadcrumbs and real Talker console fragments; verify originals are not forwarded and expected retry/cancellation causes produce no remote captures. Include synthetic Supabase row-ID and authorization header/token canaries in the affected Cloudinary/public/Admin metadata paths, verifying their absence from remote event data, exception envelopes and console breadcrumbs.
- [x] 4.5 **Run** focused Flutter tests for modified modules, then the relevant full `flutter test --no-pub` suite, `flutter analyze --no-pub`, Dart formatting and `git diff --check`. **Run** `openspec validate reduce-cloudinary-logging-noise --strict`. Report exact commands, exit codes, and actual failures by commit; compare pre-existing failures with evidence instead of accepting false-green skips. Add native tests only if native Sentry lifecycle or platform behavior is materially changed.

## 5. Independent review and handoff

- [x] 5.1 Inspect the implementation diff against the delta spec and the unchanged canonical public/Admin persistence, SDK consent/tracing and Cloudinary contracts. Confirm no new dependency, schema/RPC/Edge Function change, importer work, automatic cleanup, unrelated refactor or generated test log in Git.
- [x] 5.2 Publish implementation and any review fixes in the same cohesive change PR under `AGENTS.md`. Request explicit authorization separately before merge, canonical spec sync/archive or deployment.

## Verification evidence

Local checks ran on working trees while preparing the commits below; the commit column identifies the delivered change, not a claim that every local command ran after checking out that immutable commit. Intermediate failed trees had no recorded Git tree hash and are labeled WIP. CI runs identify the exact tested commit. Log redirections are omitted; no transient logs are committed.

| Change / snapshot | Exact command | Exit | Observed result |
| --- | --- | --- | --- |
| WIP from `a061d49`, before `08900c7` | `flutter test --no-pub test/data/services/api/cloudinary/cloudinary_upload_client_impl_test.dart --plain-name 'request.done has one owner'` | 1 | Initial attempts failed compilation while the event/logger API was incomplete; these were not runtime reproductions. |
| WIP before `08900c7` | `flutter test --no-pub` | 1 | 3,982 passed, six skipped, one failed: malformed preparation was incorrectly labeled as an upload response. The stage guard was corrected. |
| WIP before `08900c7` | `flutter analyze --no-pub` | 1 | 12 introduced analyzer diagnostics; corrected before the successful rerun. |
| Implementation `08900c7` | `flutter test --no-pub test/data/services/api/cloudinary test/utils/logging/log_event_test.dart` | 0 | 117 passed, including corrected preparation/preflight stage assertions. |
| Implementation `08900c7` | `flutter test --no-pub test/utils/logging/app_logger_test.dart test/utils/logging/talker_console_privacy_test.dart` | 0 | 51 passed locally; the later Linux run exposed a capture-delivery race missed by this run. |
| Implementation `08900c7` | `flutter test --no-pub` | 0 | 3,989 passed, six unchanged pre-existing skips. |
| Implementation `08900c7` | `flutter analyze --no-pub` | 0 | No issues found. |
| Implementation `08900c7` | `git diff --check` | 0 | No whitespace errors. |
| Implementation `08900c7` | `openspec validate reduce-cloudinary-logging-noise --strict` | 0 | `Change 'reduce-cloudinary-logging-noise' is valid`. |
| Handoff `2dd1cfb`, Linux CI [42033207699](https://github.com/xmattjus/moliseis/actions/runs/42033207699) | Autonomous test command below | 1 | 3,984 passed, four skipped, five new privacy tests failed: envelope assertions ran before delivery because scope clearing removed scope-local capture observation. |
| Handoff `2dd1cfb`, same CI run | `flutter analyze --no-pub` | 0 | Analyzer check succeeded. |
| Capture-delivery correction `dff5d35` | `flutter test --no-pub test/data/services/api/cloudinary test/utils/logging` | 0 | 230 passed after registering the recording processor globally. |
| Capture-delivery correction `dff5d35` | `flutter test --no-pub` | 0 | 3,989 passed, the same six skips; capture-count and privacy assertions retained and strengthened. |
| Capture-delivery correction `dff5d35` | `flutter analyze --no-pub` | 0 | No issues found. |
| Published `dff5d35` | `git diff --name-only -z a061d49 HEAD -- '*.dart' \| xargs -0 dart format --output=none --set-exit-if-changed` | 0 | 19 Dart files checked, zero changes. |
| Published `dff5d35` | `git diff --check origin/main...HEAD` | 0 | No whitespace errors. |
| Published `dff5d35` | `openspec validate reduce-cloudinary-logging-noise --strict` | 0 | Change valid. |
| Published `dff5d35` | `openspec instructions apply --change reduce-cloudinary-logging-noise --json` | 0 | `all_done`, 17/17 tasks complete. |
| Exact `dff5d35`, Linux CI [42034910312](https://github.com/xmattjus/moliseis/actions/runs/42034910312) | Autonomous test command below | 0 | 3,989 passed, four existing skips; the five previously failing privacy tests passed. |
| Exact `dff5d35`, same CI run | `flutter analyze --no-pub` | 0 | Analyzer check succeeded. |

The autonomous-test command in both CI runs, from `.github/workflows/pull-request.yml`, was:

```bash
mapfile -d '' test_files < <(
  find test -type f -name '*_test.dart' \
    -not -path 'test/integration/*' -print0 | sort -z
)
flutter test --no-pub --reporter expanded "${test_files[@]}"
```

Local full-suite runs included the two environment-gated local-service tests as skips; CI explicitly excluded `test/integration/`, accounting for six local skips versus four CI skips. No test was disabled for this change.

The earlier 19-file formatter check before `08900c7` returned zero through a Python-expanded argument vector; its literal expanded command text was not retained and is not reconstructed here. The exact published-head formatter command and observed result are recorded above. Initial four-file repository/ViewModel runs also encountered ten missing-ObjectBox-runtime failures; their exact command text was not retained. Installing the normal ignored native test dependency resolved those setup failures, and the full local and Linux CI gates above supersede them.

Independent review rechecked stage classification, passive request-fault ownership and scoped command privacy. The Linux test-only correction preserved capture observation across privacy scope clearing; no production behavior or privacy assertion was weakened. No repository OpenSpec documentation-audit skill is installed, so artifact coherence was audited directly. Native tests were not added because SDK/native lifecycle is unchanged. Canonical sync, archive, merge and deployment remain separately authorized.
