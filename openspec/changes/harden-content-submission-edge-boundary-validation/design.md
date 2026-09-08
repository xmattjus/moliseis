## Context

See `proposal.md` for motivation and `specs/content-submission-edge-boundary-validation/spec.md` for required behavior. The authoritative production baseline is `fe8a7e2d0f563031cc8e3231f9a3147ed0bd4868` (`feat(content-submission): harden server idempotency`). The inspected current HEAD, `efb2e6aa80b7b7a0c56eecdd2e3b139cf48924e2`, differs from that baseline only in two predecessor OpenSpec files; the production Flutter, Edge, RPC, and database path remains byte-equivalent for this audit.

Subplan 5 already made `submit-content` a POST-only authenticated boundary with strict Bearer parsing, a 128 KiB streaming JSON limit, canonical UUID-v4 client identity, principal-field lengths, shared date validation, category validation, Quill Delta validation/canonicalization, Cloudinary asset validation, a maximum of five assets, and delayed privileged store construction. After validation, one `SubmissionStore.submit()` call forwards an exact allowlist to the service-role-only `submit_content` RPC. That RPC atomically owns user-scoped idempotency, fixed-window quota, content insertion, asset insertion, and `created` / `replayed` / `rate_limited` outcomes. These mechanisms are implemented and are not redesign targets.

The remaining defect is at `submission_validation.ts`: `isOptionalFiniteNumber` validates latitude and longitude independently, and `parseContentSubmission` normalizes each with `?? null`. Direct inspection and parser execution show that latitude-only, number-plus-null, `90.000001`, and `180.000001` payloads currently validate successfully. `submission_store.ts` then forwards those values unchanged, and the RPC inserts them unchanged. The current Flutter wire mapper always emits both keys; the current ViewModel does not populate coordinates, so its public request sends both as null. The Edge remains responsible for untrusted direct callers even though the in-repository caller currently exercises only the no-coordinate case.

The broader differential audit found no additional concrete Edge mismatch. Existing string, date, category, Delta, asset, body-size, method, authentication, response, idempotency, quota, and persistence ordering contracts align across the current caller, parser, store, RPC, schema, and focused tests. Unknown top-level fields, Content-Type strictness, email syntax refinement, MIME/Cloudinary policy, new normalization, and different public error envelopes have no demonstrated failure mode in this path and remain out of scope.

## Goals / Non-Goals

**Goals:**

- Make the existing public parser the primary owner of nullable coordinate pairing, numeric finiteness, and inclusive geographic ranges.
- Preserve the exact accepted number and the existing public HTTP/error contract.
- Retain delayed store construction so malformed coordinates cannot reach service-role persistence, replay lookup, quota, content, or asset work.
- Add the smallest high-value parser matrix and handler isolation regression without duplicating store/RPC tests.

**Non-Goals:**

- Do not change Flutter models, the wire mapper, repository, ViewModel, UI validation, navigation, or submission orchestration.
- Do not add a migration, table constraint, RPC validation branch, generated database type change, or database test suite.
- Do not change authentication, body limits, identity, dates, categories, Delta, assets, idempotency, quota, persistence, response statuses/codes, Cloudinary, Admin, import, moderation, or promotion behavior.
- Do not add a schema library, generic validation framework, shared coordinate package, third-party dependency, or broad validator refactor.
- Do not synchronize, revise, archive, or otherwise modify any predecessor or main OpenSpec artifact.

## Decisions

### 1. Validate coordinates as one local parser concern

Replace only the current independent coordinate checks with one small private parser-local coordinate routine or equivalent localized logic. It accepts `undefined`/`null` as absence, rejects non-number and non-finite values, applies the field's inclusive min/max, and returns the original number. Parse latitude and longitude before constructing the validated result, then reject when exactly one parsed value is numeric.

Use the current field-specific messages—`latitude is not valid` and `longitude is not valid`—for type, finiteness, and range failures. Use `latitude and longitude must be provided together` for a valid-number/absence mismatch. The handler already maps every parser failure to HTTP 400 with code `VALIDATION_ERROR`; no handler response branch is needed.

`undefined` and `null` already converge to null at this public boundary. Preserve that compatibility: both omitted, both null, and one omitted plus the other null all mean no coordinate. Only a numeric/absent mismatch is a partial pair. This follows the existing normalization model and avoids inventing presence-sensitive semantics that neither persistence nor the Flutter caller observes.

Alternative considered: copy the Admin validator or extract shared coordinate validation. Rejected because Admin requires exact input keys and explicit nulls and uses different public messages, while this public parser accepts omissions. With only two consumers, a shared abstraction would couple distinct request contracts and violate KISS/Rule of Three.

Alternative considered: encode the pair as a new public type or generic schema. Rejected because `ValidatedContentSubmission` has one production construction path and localized runtime validation is sufficient; changing the type hierarchy would not improve the untrusted-input boundary.

### 2. Preserve numbers rather than sanitize them

Range checks are comparisons only. Return accepted numeric inputs directly into `ValidatedContentSubmission`; do not call rounding, fixed-precision, absolute-value, modulo, geocoding, or clamp operations. Inclusive comparisons accept exactly `-90`, `90`, `-180`, and `180`.

Alternative considered: clamp or wrap out-of-range values. Rejected because that silently changes authored location data, hides client defects, and can persist a materially different place.

### 3. Keep database coordinate ownership unchanged

Coordinate pairing/ranges remain public Edge validation, not a new `content_submissions` table invariant in this subplan. The Subplan 5 RPC is service-role-only and explicitly documents that the Edge authenticates and validates the public payload while the RPC owns database quota, idempotency, content, and asset invariants. It receives parsed coordinates and performs no independent public-wire interpretation.

This choice is supported by all known writers and consumers:

- the public Flutter caller emits both coordinate keys and currently sends both as null;
- the Admin create/update validator already enforces finite numbers, the same inclusive ranges, and pair presence before its store writes;
- the external-event importer writes both coordinates as null;
- promotion does not write submission coordinates and already rejects incomplete, out-of-range, NaN, and infinite legacy submission coordinates before creating range-constrained `events` or `places`;
- existing promotion database tests intentionally insert incomplete and non-finite/out-of-range submission coordinates to verify that compatibility behavior.

A new table check would therefore expand ownership beyond the defective public boundary, could fail against existing legacy rows, and would invalidate deliberate promotion fixtures. No current writer needs a constraint to remain correct, so defense-in-depth does not justify a migration here.

Alternative considered: add pairing and range CHECK constraints matching `events`/`places`. Rejected because published entities require valid non-null coordinates, while `content_submissions` is a nullable intake/moderation record that intentionally supports incomplete legacy state. The tables have different lifecycle contracts.

Alternative considered: duplicate checks inside `submit_content`. Rejected because only the authenticated Edge can execute this public RPC in production, the RPC already consumes a validated representation, and duplicated message/ordering rules would create two authorities without protecting a demonstrated additional writer.

### 4. Split exhaustive parser coverage from focused handler isolation

Add table-driven parser tests for both omitted, both null, mixed omitted/null absence, all four numeric/absence pair failures, each exact inclusive boundary with a valid counterpart, immediately outside each boundary, invalid primitive/container types, direct non-finite inputs, and ordinary-value preservation. JSON cannot encode non-finite numbers, so those cases belong at the direct parser boundary rather than in handler JSON tests.

At the handler boundary, use representative incomplete-pair and out-of-range requests and assert the exact 400 `VALIDATION_ERROR` envelope, zero store constructions, and zero store calls. Existing handler architecture already proves that zero construction implies no `SubmissionStore.submit()` or RPC attempt. Do not replicate the full parser matrix in handler tests.

If the existing store-test fixture is edited, make its currently incomplete `latitude: null` / `longitude: 14.66` pair valid so test-only `ValidatedContentSubmission` data respects the parser contract. Do not add store or database validation; store forwarding remains unchanged.

Alternative considered: test every invalid coordinate at both parser and handler layers. Rejected because it couples the handler suite to parser internals without adding persistence-isolation evidence.

## Risks / Trade-offs

- **A non-repository caller may rely on malformed coordinates being accepted** → This is the intended hardening behavior; valid no-coordinate and paired-coordinate payloads remain compatible, while failures retain the stable 400 validation envelope.
- **Public and Admin coordinate helpers may diverge** → Keep the small public logic local and assert the complete public matrix; do not merge distinct contracts until a third compatible consumer or a demonstrated maintenance defect justifies it.
- **Direct tests can construct a semantically invalid `ValidatedContentSubmission`** → Correct misleading fixtures when touched and rely on the single production parser construction path; avoid a type-system redesign for test-only construction.
- **A future privileged writer could bypass public validation** → Evaluate that writer under its own contract when introduced. Current admin/import paths are already safe, and promotion protects publication from legacy malformed rows.

## Migration Plan

1. Add focused failing parser and handler regressions against the current implementation, including zero store construction/calls.
2. Implement the localized public coordinate parser and pair check without changing the handler/store/RPC/database/Flutter contracts.
3. Run focused formatting, type checks, submit-content tests, strict OpenSpec validation, diff checks, and adversarial scope review.
4. Deploy only the updated `submit-content` Edge Function after verification; no database ordering, data backfill, generated type update, or Flutter release is required.

Rollback, if necessary, is limited to restoring the prior Edge validator in a separately reviewed deployment. No database rollback is involved because this change introduces no migration or stored-data transformation.
