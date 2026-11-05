# Design: reduce-cloudinary-logging-noise

## Baseline and existing contracts

Reviewed committed `xmattjus/moliseis` `main` at `40c36e607adc34885e2df5e858178bc61bfe7660` (2026-11-05). The review covers the shared Flutter Cloudinary client/cancellation token/preparation client; typed service, content-submission, and Admin events; `AppLogger` and production breadcrumb filtering; `ContentSubmissionRepositoryImpl.submit`; the public submission ViewModel; `AdminContentSubmissionRepositoryImpl.associateStagedAsset`; the Admin editor's upload -> local receipt -> association flow; and existing focused tests. No production logs, deployment, or tests were independently executed at planning time.

The canonical specs already guarantee sequential public asset uploads followed by an idempotent `submit-content` acknowledgement and prohibit Cloudinary rollback on later failure (`content-submission-submit-orchestration`). Admin Save retains upload receipts across association ambiguity and uses exact-receipt replay (`admin-submission-save-idempotency`, `admin-local-asset-staging`, `admin-submission-editor`). `application-observability` owns typed events, local diagnostics, Sentry consent and constrained remote telemetry. Its historical "Content-submission reporting SHALL remain unchanged" clause protected TASK-41's tracing migration; this change includes a full `MODIFIED` requirement that permits only the new scoped diagnostics while retaining reporting ownership, exception-capture policy, consent, sampling and business results. This change does not modify those functional invariants.

## Diagnostic semantics and ownership

Keep each event attached to the boundary that knows the fact. Do **not** add a second lifecycle orchestrator or a new per-image correlation store.

| Boundary | Evidence it can report | Evidence it cannot report |
| --- | --- | --- |
| Cloudinary client | Validated upload response (including its `existing` indicator); existing asset returned by preparation; client cancellation; terminal client result or lack of confirmation | Final Supabase association; guaranteed absence of an asset after timeout/transport failure |
| Public `submit-content` response boundary | Positive valid submission acknowledgement / replay; explicit API rejection; request outcome not confirmed | Cloudinary upload success from only a submitted URL; an orphan's existence |
| Admin `associateStagedAsset` response boundary | Valid associated asset returned (including replay); explicit server rejection; confirmation unavailable | Whether Cloudinary created the asset this attempt; cross-service atomicity |

Proposed event policy (names are illustrative where new; prefer existing event classes when their meaning remains truthful):

- `CloudinaryRequestStarted`: demote routine start to `debug` or remove if redundant. Do not remove the existing progress signal.
- Retryable 5xx/timeout attempts: one `debug` event with only controlled reason and attempt ordinal, never `CloudinaryRequestFailed`/remote exception capture for a retry that remains in progress.
- `CloudinaryUploadCompleted`: one info-level event only after a validated POST success that **does not** indicate `existing: true`, **not** after DB persistence. Distinguish two reuse cases: preparation may return an existing asset **without any POST**, whereas a successful POST response may return `existing: true` after a prior ambiguous attempt or concurrent writer. A reuse event in the latter case must **not** claim that no POST happened. Preserve `Result.success` in both cases.
- `CloudinaryRequestFailed`: retain one terminal **client-side non-success** event for an admitted operation, with controlled phase/category and optional numeric HTTP status; do not describe ambiguous transport/5xx/timeouts as proof of remote asset absence. Preflight errors (size/unsupported option/file-read failure) are not misrepresented as HTTP attempts.
- `CloudinaryUploadCancelled`: optional single benign cancellation event; intentional cancellation never emits a corresponding terminal error or remote exception capture. Cancellation before start may emit no event.
- Post-upload association reporting: at the **existing repository response boundaries**, add only the minimal safe confirmation signal and differentiate explicit rejection from unconfirmed outcome in existing failure reporting where practical. Public final-submission acknowledgement may cover multiple assets and must not be called per-asset association. Admin confirmation applies to one `associateStagedAsset` call, including safe replay. Avoid adding a second error for the same response in a ViewModel. No new submit result or persisted state.

Keep safe category values from a closed set; do not include contributor IDs, submitted content, draft, filenames, file paths, image URLs, Cloudinary `publicId`/digest, Supabase row IDs, raw request/response text, or authentication context in remotely forwarded diagnostic payloads. Drop unnecessary public IDs from emitted info-level event metadata instead of inventing an identifier sanitizer; asset inventory can use Cloudinary and DB directly (TASK-9).

A request that times out or loses a response is **unconfirmed** unless an authoritative server response proves rejection. Use the current error taxonomy/status where reliable; do not infer a remote rollback or a safe retry from diagnostics. Logging must not change the `Result.error` values, retry eligibility, server replay, or Admin receipt recovery.

## Error ownership and privacy

The current `AppLogger` forwards error-level events with `error:` to Sentry and forwards info+ event data as breadcrumbs when enabled. `_UploadHttpException.toString()` currently embeds an arbitrary unbounded response body. Merely sanitizing `LogEvent.data` does **not** sanitize attached exception text/stack or console output.

At the Cloudinary terminal boundary, log safe, bounded classifications and numeric HTTP status without forwarding raw HTTP bodies or arbitrary error objects. Prefer a local correction to the private Cloudinary error representation plus safe event data. Use the existing logger boundary rather than a generic new reporting API; if untrusted original causes must be kept locally, explicitly separate them from remotely captured payloads with the smallest established safe-reporting mechanism. Verify the actual Talker -> Sentry console filter rather than relying solely on a typed breadcrumb test.

For affected public/Admin association failures, preserve existing user-facing exception/result semantics and diagnostic ownership. Avoid adding raw remote error messages to new event data, recapturing a failure already captured by an existing logger, or changing unrelated Admin operations. A failure classification should be safe even with enabled consent and an adversarial backend error message. Expected cancellation and retry are not error alerts.

`CloudinaryUploadCancellationToken` listens to `request.done` to consume asynchronous errors, and `request.close()` awaits that same future in normal handling. Test the actual paths before editing: the passive listener must not double-report a failure already terminally observed, but must still prevent unhandled async exceptions and retain any genuinely otherwise-unobserved failure. Avoid speculative token/retry rewrites.

## Failure matrix and edge cases

1. Success at first POST: one new-upload success, no terminal error; progress remains monotonic.
2. 5xx or stream/body timeout followed by valid response: local retry diagnostics at debug, one final success classified as new upload only if the response lacks `existing: true`; otherwise reuse, with zero error-level retry events/captures.
3. Exhausted retry: one terminal failure classification, no false success; outcome of remote asset existence is not asserted.
4. 4xx, invalid 2xx asset metadata, preparation failure, oversized file/unsupported overwrite, missing local file: appropriate safe terminal classification; no duplicate or false HTTP attempt reporting. Preserve existing functional `Result` contract for supported failure classes.
5. Cancellation before preparation, during upload or response-body consumption, or during retry backoff: same cancellation semantics and no error alert; late cancelled callbacks cannot publish success.
6. Duplicate preparation: no POST, distinct reuse signal, existing asset result unchanged. A valid first or retried POST response with `existing: true` also reports reuse but **does not** assert absence of a POST.
7. Public: prior confirmed upload(s) followed by valid `submit-content` success/replay, explicit API rejection, or network/invalid-response ambiguity. Only valid acknowledgement confirms submission persistence; no invented orphan metric. Zero-asset submission stays valid.
8. Admin: confirmed upload receipt followed by confirmed association/replay, deterministic rejection, ambiguous response, and persisted local receipt recovery. No reordered Save phases, lost receipt, or premature success diagnostic.
9. Inject a sensitive canary into Cloudinary HTTP body and safe/untrusted exception messages, and test local Talker, typed Sentry breadcrumbs, console breadcrumbs, and serialized exception envelopes with consent enabled/disabled.

## Verification and delivery boundaries

Extend the existing Cloudinary client, logging event, public final-submission repository/ViewModel and Admin repository/editor tests; use the real Sentry/Talker test fixtures already present for privacy rather than building a parallel harness. Inspect test expectations before editing, especially existing assertions that currently expect `CloudinaryRequestFailed` on temporary retries. Assert number, severity, classification and ordering of events, not only that `Result` succeeds.

Implementation must execute focused tests, appropriate full Flutter regression, format and analysis checks, and `openspec validate reduce-cloudinary-logging-noise --strict`. Record actual commands/results/commit and compare any pre-existing failures. Review the diff against unchanged contracts, consent, idempotency and all out-of-scope backend/importer work. Keep logs, test output and transient validation artifacts out of Git.

This planning PR contains no implementation. OpenSpec canonical sync/archive and production deployment are later, separately authorized steps.
