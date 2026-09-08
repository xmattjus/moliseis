## Why

The deployed `submit-content` parser validates latitude and longitude independently as optional finite numbers, so it currently accepts incomplete coordinate pairs and finite values outside geographic ranges, then forwards them across the privileged persistence boundary. Subplan 5 already established the authenticated, bounded, fully parsed single-RPC boundary; Subplan 6 should close only this remaining public-wire validation gap without duplicating its idempotency, quota, asset, or transaction mechanisms.

## What Changes

- Treat public submission coordinates as one nullable pair: both may be omitted, both may be `null`, or both must be present as finite numbers.
- Reject a numeric latitude without a numeric longitude and vice versa, including number-plus-`null` and number-plus-omission combinations.
- Enforce inclusive latitude `[-90, 90]` and longitude `[-180, 180]` ranges while preserving accepted numeric values exactly, with no clamping, rounding, wrapping, geocoding, normalization, or precision truncation.
- Preserve HTTP 400, `VALIDATION_ERROR`, and the current field-specific invalid-coordinate messages; add one stable pair-mismatch message.
- Complete coordinate parsing before constructing the submission store, invoking `SubmissionStore.submit()`, or reaching the service-role `submit_content` RPC.
- Add focused parser coverage for absence, nullability, pairing, inclusive limits, immediately out-of-range values, invalid types/non-finite values, and exact value preservation, plus handler coverage proving invalid coordinates make zero store calls.
- Keep coordinate enforcement at the public Edge boundary. Do not add a database constraint or migration: the service-role RPC intentionally consumes already-validated public input, while existing admin/import paths already enforce or emit valid pairs and established promotion tests intentionally retain malformed legacy-row behavior.

## Capabilities

### New Capabilities

- `content-submission-edge-boundary-validation`: Public `submit-content` coordinate-pair validation, exact accepted-value preservation, stable observable failure behavior, and isolation from privileged persistence.

### Modified Capabilities

None. The implemented Subplans 1–5 and synchronized main specifications remain unchanged and are reused as architectural context.

## Impact

- Production scope: `supabase/functions/submit-content/submission_validation.ts` only.
- Test scope: focused additions to `submission_validation_test.ts` and `index_test.ts`; the submission-store fixture may be corrected to use a valid coordinate pair if touched by type or semantic consistency checks.
- Public API: valid requests and successful acknowledgements are unchanged; newly rejected coordinate payloads retain HTTP 400 and code `VALIDATION_ERROR`.
- Database: no schema, migration, RPC, quota, idempotency, content, asset, RLS, admin, import, moderation, or promotion change.
- Flutter: no model, mapper, repository, ViewModel, routing, navigation, UI, or test change is required because the current wire mapper already emits both coordinate fields together and the current public form submits both as `null`.
- Dependencies and packages: none.
