## Why

Content Submission currently shows an immediate `Riprova` action for every ordinary progress error even though the released client must first coexist with a legacy, non-idempotent `submit-content` server. A failure may be technically transient without making replay safe: the client can receive a 500 or transport error after the legacy server has already committed all or part of the submission.

## What Changes

- Define the retry semantic narrowly as whether the user can safely execute the current immediate manual retry action now, rather than whether the technical cause may eventually recover.
- Make the client-first rollout constraint normative: until the hardened idempotent server is guaranteed to be the serving contract, every ambiguous final `submit-content` failure—including `INTERNAL_ERROR`/500 and transport timeouts—fails closed for immediate remote retry because the client has no server-generation or commit-status signal.
- Preserve the verified final-submit fields and taxonomy without parsing `message`, `reasonPhrase`, `toString()`, or localized text. Validation, authentication, method, rate-limit, legacy/current 500, malformed acknowledgement, and unknown/mismatched failures do not expose immediate retry.
- Treat every current `prepare-cloudinary-upload` failure as non-retryable for the immediate action. In particular, `CLOUDINARY_PREPARATION_ERROR`/502 covers both operational and deterministic invalid-field failures and therefore proves neither transience nor safe replay.
- Leave direct Cloudinary terminal failures fail-closed at the Content Submission boundary. Preserve the shared client's existing internal HTTP-5xx/timeout retries, progress, cancellation, and content-addressed reuse without leaking feature semantics into shared infrastructure or wrapping `ImageUploadTask` solely for this UI decision.
- Expose a read-only ViewModel retry getter derived from the current submission `Command` result and `submissionFinalizationPending`; add no mutable retry flag and no data-layer dependency. Under the current compatibility matrix, only a stopped failed local finalization is immediately retryable.
- Remove blind ordinary-error `Riprova`. A non-retryable failure keeps Home and provides the existing safe return-to-form path without clearing the draft, rotating `client_submission_id`, or deleting staged assets.
- Preserve finalization-only retry after confirmed remote success, including zero repeated checkpoint, upload, or final-submit work and exactly one identity rotation after successful local retirement.
- Add focused repository, ViewModel, progress-widget, routing, restoration, and unchanged Edge-taxonomy verification for the corrected fail-closed matrix and lifecycle invariants.
- Keep future relaxation of final-submit 500/transport handling outside this change. It may be reconsidered only after the hardened idempotent server is guaranteed for all supported clients or another reliable capability signal is separately specified and deployed.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `content-submission-submit-orchestration`: Define safe immediate retry independently from technical transience, enforce legacy-compatible final-submit replay safety, and preserve finalization and session invariants.
- `content-submission-navigation-lifecycle`: Replace blind ordinary-error retry with safe return-to-form behavior while preserving running, success, finalization, Back, Home, and restoration contracts.

## Impact

- UI orchestration: `ContentSubmissionViewModel` gains one derived immediate-retry getter; no data-layer import, domain failure hierarchy, transport wrapper, retry manager, or parallel state is introduced.
- Progress/navigation: only failed-state action selection changes; layout, styles, unrelated copy, route ownership, and form-exit policy remain unchanged.
- Data and upload boundaries: existing exception normalization, `ImageUploadTask`, Cloudinary preparation/direct-upload clients, and internal retry behavior remain unchanged; tests document why their terminal failures fail closed at the progress action.
- Backend and rollout: no Edge Function, SQL, RPC, migration, RLS, idempotency, deployment negotiation, or release operation is added. The client behavior is deliberately safe against both the legacy and hardened server generations during the planned client-first rollout.
