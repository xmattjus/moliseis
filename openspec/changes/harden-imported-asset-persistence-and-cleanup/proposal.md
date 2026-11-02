# Proposal

## Why

The external-event importer currently treats an indeterminate `add_submission_assets` RPC outcome as permission to delete an image just uploaded to Cloudinary. The database may have committed the association before its response was lost, so cleanup can destroy an image still referenced by a submission or already-promoted Event. The importer must compensate only for confirmed SQL rejection while retaining the existing irreversible, at-most-once image-claim policy.

## What Changes

- Classify association responses into confirmed success, explicit rejection, and indeterminate outcome. Only an error-free, valid singleton response containing the authoritative rejection `not_found`, `not_pending`, or `limit_reached` permits cleanup of this attempt's newly uploaded image.
- Retain uploaded images whenever the association outcome is uncertain, including transport failures, exceptions and missing, malformed, unexpected, or contradictory responses. Do not interpret a negative or failed subsequent read as proof of safe deletion.
- Distinguish confirmed failure, uncertain association, and unconfirmed cleanup in importer reporting. Do not falsely instruct moderators to re-add an image that may already be associated, or overwrite persisted internal notes when recording failure details.
- Preserve claim irreversibility, moderation removal, eligibility of previously unclaimed existing pending submissions, and parent-row locking; test real commit/response-loss and finalization interleavings.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `external-event-provenance-moderation`: Make external source-image compensation safe under indeterminate association outcomes, preserving at-most-once policy and truthful operational reporting.

## Impact

- `supabase/functions/import-external-events/index.ts` and focused TypeScript tests; bounded Cloudinary destroy response handling only as necessary for truthful cleanup reporting.
- Existing Supabase local-DB integration tests in `supabase/tests/external_event_assets_db_test.ts`, with transport response-loss injection.
- No schema migration, RPC changes, generated database types, new dependencies, Flutter changes, RLS/grant changes, automatic retries, or new reconciliation service.

## Non-goals

No reclaim/reset of `source_asset_import_claimed_at`, no automatic recovery after a genuinely failed attempt, no new asset identity or uniqueness constraint, no change to Admin replay semantics, no general orphan scavenger, and no importer-wide metrics redesign. Renaming `without_asset` is deferred unless necessary to avoid a materially false statement in the affected reporting path.
