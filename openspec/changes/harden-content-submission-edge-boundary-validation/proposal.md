## Why

The authenticated public `submit-content` boundary still accepts incomplete or out-of-range coordinates, Cloudinary URLs that are unrelated to the configured Molise Is public-upload flow, and duplicate assets within one request. These values can cross into the service-role persistence operation even though they do not belong to the valid public Content Submission domain, so Subplan 6 must complete untrusted-input validation while preserving the atomic, idempotent boundary established by Subplan 5.

## What Changes

- Treat `latitude` and `longitude` as one nullable pair, accept the existing omitted/null no-coordinate representations, require finite numeric pairs within inclusive geographic ranges, and preserve accepted numbers exactly.
- Require every asset accepted through public `submit-content` to match the canonical structural contract emitted by the official Molise Is Cloudinary upload flow: the configured cloud name, `image/upload`, a versioned `content_submissions/<lowercase SHA-256>` public ID, and its Cloudinary format extension.
- Reject structurally foreign Cloudinary accounts, namespaces, resource/delivery types, transformed or otherwise non-canonical paths, query/fragment variants, malformed content-addressed IDs, and other delivery forms that the official public producer does not emit.
- Reject duplicate assets in one public request by validated Cloudinary public ID while preserving the existing maximum-five check and its validation precedence.
- Inject `CLOUDINARY_CLOUD_NAME` from the production composition root into pure request validation and minimally reuse the existing shared generic Cloudinary delivery-identity logic; keep Content Submission-specific policy local to public `submit-content`.
- Preserve validation-before-privilege ordering for all new rules. Invalid coordinates, asset origin, or duplicates fail before store construction, `SubmissionStore.submit()`, replay lookup, quota work, the `submit_content` RPC, or any content/asset write.
- Preserve Subplan 5 first-commit-wins semantics for requests that pass current validation. A committed `client_submission_id` does not let a malformed replay bypass validation, and no public idempotency-conflict outcome is introduced.
- Replace or supplement unrealistic Cloudinary test fixtures with correlated public IDs and delivery URLs, and add focused parser, handler-isolation, and producer-to-consumer regressions.
- Keep coordinate, structural-origin, and duplicate rules at the untrusted public Edge ingress. Do not add a database migration or globalize them across Admin or trusted server-side ingestion paths.

## Capabilities

### New Capabilities

- `content-submission-edge-boundary-validation`: Complete public `submit-content` coordinate, Cloudinary structural-origin, asset-uniqueness, validation-ordering, and stable failure behavior.

### Modified Capabilities

None. Subplans 1–5 and main specifications remain read-only architectural context; this self-contained capability preserves rather than rewrites their established contracts.

## Impact

- Production Edge scope: `supabase/functions/submit-content/submission_validation.ts`, the `submit-content` composition root in `index.ts`, and only the minimal generic Cloudinary helper exposure/adaptation in `supabase/functions/_shared/cloudinary.ts` needed to avoid duplicating cloud identity checks.
- Test scope: focused `submit-content` parser/handler/store fixtures, shared Cloudinary and `prepare-cloudinary-upload` producer fixtures, and the existing Flutter Cloudinary public-ID/preparation/upload tests needed to prove both official producer branches remain consumer-compatible.
- Public API: newly rejected payloads retain HTTP 400 and code `VALIDATION_ERROR`; existing unauthorized, created, replayed, rate-limited, and server-failure mappings remain unchanged. Duplicate assets use the stable message `assets must not contain duplicates`; structural-origin failures retain `asset url is not valid`.
- Runtime configuration: `submit-content` explicitly consumes the existing `CLOUDINARY_CLOUD_NAME`; deployment must verify that it is configured for the same Cloudinary product environment used by `prepare-cloudinary-upload`, without logging its value.
- Persistence: no schema, migration, RPC, RLS, quota, idempotency, transaction, Admin, importer, moderation, promotion, or generic storage change. Trusted server-side ingestion remains able to persist provider-controlled HTTPS media under its own ingress contract.
- Flutter production: no model, mapper, repository, ViewModel, upload orchestration, routing, navigation, UI, or state-management change. Test-fixture corrections do not change production client behavior.
- Dependencies and packages: none.
