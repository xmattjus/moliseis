# Tasks

## 1. Reconfirm implementation baseline

- [x] 1.1 Inspect current checkout HEAD, applicable instructions, latest authoritative asset SQL definitions, importer callers, and applicable spec before modifying code; reconcile any drift from the reviewed planning baseline.
- [x] 1.2 Verify existing Deno test expectations and document the pre-fix destructive case; do not treat a passing test of unsafe behavior as acceptance.

## 2. Safe association and cleanup decisions

- [x] 2.1 Classify single-image association outcomes as `created`, the three confirmed rejections, or indeterminate. Allow Cloudinary cleanup only for explicitly confirmed rejection; never for exceptions or malformed/contradictory RPC responses. Require explicit null rejection payload fields and receipt-matching success data with a positive safe-integer ID.
- [x] 2.2 Preserve original failure information and identify cleanup uncertainty, including unexpected Cloudinary destroy response bodies, without issuing retry/reconciliation-driven destructive cleanup.
- [x] 2.3 Keep admission, claim timestamp, at-most-once behavior, moderation deletion, and current RPC/SQL contracts untouched.

## 3. Accurate importer reporting and moderation notes

- [x] 3.1 Distinguish upload failure, confirmed rejection, indeterminate association and cleanup uncertainty in the importer's diagnostics; retain claim failures as pre-upload diagnostics. Add `assets_unknown` outside `assets_uploaded`/`assets_failed`; keep cleanup status secondary to the rejection and do not assert absence of an image on an unknown outcome.
- [x] 3.2 Prevent existing persisted `internal_notes` from being overwritten by failure-warning updates. Read persisted notes once and condition at most one update on their exact previous value, including null; request returned identity to detect zero matched rows. On read/update error, exception, conflict or unconfirmed response, do not retry or replace the original failure; record diagnostic uncertainty and continue the batch.
- [x] 3.3 Preserve `without_asset` as a skipped-observation counter; do not present it as a persisted-asset inventory or rename it in this change.

## 4. Regression and local integration tests

- [x] 4.1 Replace the unit test that currently expects destruction after a generic RPC error. Cover explicit `not_found`/`not_pending`/`limit_reached`, valid `created`, transport failure, thrown exception, empty/duplicate/malformed replies, unexpected outcome, and contradictory responses. Replace outcome-only fixtures with full SQL response shapes; cover rejection payloads that are missing/non-null and success payloads with invalid IDs or mismatched URL/dimensions. Assert one association request per admitted upload.
- [x] 4.2 Verify Cloudinary destroy success/uncertain cases and reporter behavior with focused unit/transport tests, including no secret leakage, counter partitioning, cleanup status, no false manual-add note, null/non-null existing notes, zero-row conditional updates, read/write exceptions, and unconfirmed note writes preserving the primary failure and later batch processing.
- [x] 4.3 Use local PostgreSQL/PostgREST and real `add_submission_assets` after a real claim; intercept/discard the successful RPC response only after a separate connection verifies commit. Assert the row persists and no destroy call occurs. Include a second interleaving with real Event promotion committed before delivering the simulated failure; assert promotion success and both submission/media references. Use valid promotion prerequisites, not Link as a media-copy substitute.
- [x] 4.4 Verify real finalization *before* association still yields explicit `not_pending` and safe cleanup. Regress claim concurrency, failure-consumed claim, one-shot later observation, moderator removal permanence and unclaimed existing-pending image eligibility. Keep and run the existing capacity, parent-lock serialization and owned-deletion tests in `submission_asset_invariants_db_test.ts`; cover lost rejection response as unknown without cleanup.
- [x] 4.5 Run relevant Deno format/type checks, focused unit tests, and both existing real-database asset/invariant runners; record exactly which checks ran and their observed outcomes. Do not claim database acceptance if Docker/local stack is unavailable.

## 5. Review and handoff

- [x] 5.1 Review focused diff for unrelated changes, RPC/schema/grant drift, accidental extra writes, report compatibility and unnecessary abstractions; run strict OpenSpec validation and `git diff --check`; inspect untracked artifact whitespace and paths explicitly, since no dedicated documentation/hygiene gate is defined in this checkout.
- [x] 5.2 Publish the change via the repository's PR workflow only after required verification and authorization. Do not commit temporary probe scripts, test dumps, or generated operational evidence.
