# Design

## Context

The existing importer performs two separate database transactions around a Cloudinary upload. The association response controls compensation, but losing that response does not establish transaction rollback. Runtime acceptance requires the local database reproductions described below; planning validation is not runtime evidence.

`importSourceAssetIfEligible` commits an irreversible claim before Cloudinary upload. `uploadAndPersistImportedAsset` uploads first, then calls `add_submission_assets` and currently destroys the returned Cloudinary public ID in a broad catch. The SQL function locks the parent submission and explicitly returns `not_found`, `not_pending`, `limit_reached` before insertion, or inserted `created` rows. The request and response are not atomic with Cloudinary. Promotion may copy URLs to published media while the API response is in flight. The claim trigger forbids resetting a consumed timestamp. Existing tests currently expect deletion after a generic RPC error; those assertions encode the defect.

Relevant source paths: `supabase/functions/import-external-events/index.ts` (claim, association, compensation, outer reporting), `supabase/functions/_shared/cloudinary.ts` (upload/destroy), `supabase/migrations/20260822120000_submission_asset_invariants.sql` (association RPC), `supabase/migrations/20261002201857_claim_external_event_source_asset.sql` (claim), `supabase/functions/import-external-events/index_test.ts`, and `supabase/tests/external_event_assets_db_test.ts`. Recheck later migrations and current HEAD before implementation.

The importer pins `@supabase/supabase-js@2.112.3`. Its matching `@supabase/postgrest-js@2.112.3` source uses POST for these RPC calls, restricts automatic retries to GET/HEAD/OPTIONS, and normalizes fetch failures into an error response with status zero when throw-on-error is disabled. Therefore a returned RPC `error` is not proof of database rollback; the tests must exercise this client transport behavior as well as thrown failures.

## Goals / Non-Goals

**Goals:** retain valid images on uncertain association; preserve safe cleanup when rejection is authoritative; produce accurate administrative/report status; retain previous moderation and claim invariants; exercise the real commit/lost-response case.

**Non-goals:** cross-service transactions, durable retry ledgers, resetting a claim, re-uploading after moderator removal, new schema or general-purpose reconciliation, or broad Cloudinary API refactors.

## Decisions

### 1. Only the explicit SQL rejection allowlist authorizes destruction

Treat as confirmed rejection only a successful RPC call with `error === null`, an actual response array containing exactly one non-null object row, and outcome exactly `not_found`, `not_pending`, or `limit_reached`. The row must include `id`, `url`, `width`, and `height`, all exactly null, as returned by the authoritative SQL rejection branches. Missing fields or a rejection carrying asset data are indeterminate, not permission to delete. For this importer, the association request is a singleton, non-retried write of one freshly uploaded object. The known rejection branches return before insertion, so the object from this invocation may be cleaned up.

Confirmed association requires the same error-free singleton envelope, outcome `created`, a positive safe-integer asset ID, and URL/width/height equal to the upload receipt. Invalid or mismatched success data is indeterminate. Neither confirmed nor malformed success authorizes destruction. Any transport error, thrown exception, empty/duplicate/malformed reply, unexpected outcome (including malformed success), or conflicting `data` and `error` is indeterminate: retain the object and do not initiate cleanup. Do not retry this non-idempotent association. Avoid broad `catch`-driven destructive compensation; associate cleanup directly with the confirmed-rejection branch.

Why not inspect the database first? A matching reference supports retention, but a negative read does not rule out an in-flight commit; it cannot authorize deletion. Do not add a reconciliation read in this change. The existing Admin replay RPC is not a substitute: its receipt matching is not a durable import-attempt record, and replay after row deletion could associate again while pending.

### 2. Explicit outcome propagation without a generic workflow framework

Keep the caller capable of distinguishing: upload failure (possibly no Cloudinary receipt), association rejection, association unknown, and confirmed association. Use a narrow local discriminated result or typed errors as appropriate for the existing code; do not impose a project-wide error hierarchy. The current `uploaded` / `skipped` success return can remain if only the failure path requires classification.

Unknown association SHALL NOT generate the existing unconditional note asserting that import failed and manual re-addition is needed. It SHALL be visible as unknown in importer reporting with the submission ID and, when available, the uploaded public ID. Keep claim failures identifiable as pre-upload failures rather than inventing an upload or association result. Diagnostics must not expose credentials, signed upload fields, or raw upstream response bodies.

Retain confirmed-failure warnings using one read of the persisted `internal_notes` and at most one conditional update. Append to the exact stored value, matching submission ID and that value in the update predicate; use a null predicate when the stored value is null. Do not use `event.internalNotes` or a content-version token as the concurrency guard. Request returned row identity to distinguish an applied write from zero matched rows. On a read error, missing row, conflict, thrown exception, or unconfirmed update response, do not retry; preserve the original import outcome, continue the batch, and record note-write uncertainty in diagnostics. A lost update response does not prove the note was absent. No new RPC or note-specific infrastructure is needed.

Keep `assets_uploaded` for confirmed association and `assets_failed` for failed claim/upload attempts or explicit association rejection. Add `assets_unknown` for indeterminate association, excluded from both existing counters. Cleanup is a secondary result of an explicit rejection, not another failed image or an unknown association: report its confirmed/unconfirmed status alongside the primary error. Retain existing report keys and the `import_asset` stage; expose the failure phase and certainty in its diagnostics. `without_asset` remains the existing skipped-observation counter, not a claim that persisted images are absent; renaming it is outside this change.

### 3. Cleanup outcome is itself fallible

Attempt Cloudinary deletion only for explicit rejection. A thrown destroy error is cleanup uncertainty and must not replace the primary rejection classification. A 2xx HTTP status with an unexpected/malformed destroy body does not establish deletion; the shared helper currently checks status only. Where changed in this plan, recognize Cloudinary's documented positive response `result: ok`, classify other responses as unconfirmed, and keep this behavior restricted to the affected helper. Do not infer deletion from CDN cache behavior or issue repeated blind destroys.

### 4. Preserve the existing one-shot claim policy

Do not modify `claim_external_event_source_asset`, the irreversible trigger, `add_submission_assets`, Admin association replay RPC, grants, RLS, generated types, or promotion. After genuine upload/association failure the claim remains consumed; a subsequent observation does not retry. If a previously existing pending was never claimed and later gains an eligible source image, its first claim remains permitted. Moderator deletion stays permanent across later observations.

## Risks / Trade-offs

- **Retained orphans after a rolled-back but unacknowledged association:** an acceptable conservative trade-off; no destructive guesses or automatic retry.
- **Warnings may be absent or unconfirmed after note-write conflicts or errors:** preserve existing notes and the primary import outcome; the importer report retains diagnostic evidence. The inspected application writers are initial enqueue and importer warning replacement; no Admin note-edit feature is assumed.
- **Existing tests assert the unsafe behavior:** replace that assertion; do not simply add a separate test that leaves the wrong expectation intact.
- **Promotion race:** ensure the integration test verifies that published media still references a retained image after response loss.
- **Cloudinary destroy result semantics:** test `result: ok`, unexpected JSON, invalid bodies and transport exceptions. The [official Upload API](https://cloudinary.com/documentation/image_upload_api_reference#destroy_method) documents `result: ok` for successful destroy; CDN delivery caches are not evidence of retained/deleted origin assets.

## Verification and release

1. Unit/transport tests: full SQL response shapes, explicit rejection, all uncertain responses, one request per import attempt, destroy response classes, counter partitioning and report phases. Cover null/non-null stored notes, conditional-update conflicts, zero matched rows, thrown errors, lost update responses, and preservation of the original failure and later batch processing.
2. Real local Postgres/PostgREST integration: consume the real claim, let the actual association RPC finish, verify its committed row through a separate database connection, then withhold/replace its response in the client transport. Assert zero destroy calls and the unchanged association. In a second interleaving, perform real Event promotion before delivering the simulated transport failure and verify both submission and media references; Link alone does not copy media. Set up valid category/location/content and source-resolution prerequisites so promotion is asserted successful. Also test explicit `not_pending` while finalization wins *before* association. Cloudinary upload/deletion may use injected receipts and spies; database commit and promotion must be real.
3. Regression tests: claim irreversibility, one-winner overlapping importer, zero retry on later observation and after moderator removal, eligibility of a previously unclaimed pending with a newly available image.
4. Re-run relevant Deno checks and DB test runners on an available local stack; record the exact commands and observed results. An unavailable local stack blocks database acceptance and is not a test pass.
5. Deploy the Edge Function independently after review and required local DB verification. No database deployment is part of this change. Rollback would restore the unsafe broad cleanup; therefore assess rollback against the original P1 and prefer forward-fixing if the new classification misbehaves.
