## Context

See `proposal.md` for motivation and `specs/content-submission-edge-boundary-validation/spec.md` for normative behavior. The reviewed planning commit is `38afb27f791635708b25ef513f14ac93a8b1f602`; the authoritative production baseline remains `fe8a7e2d0f563031cc8e3231f9a3147ed0bd4868` (`feat(content-submission): harden server idempotency`). The intervening committed changes contain OpenSpec artifacts only, so the inspected Flutter, Edge, RPC, and database production path remains the Subplan 5 implementation.

Subplan 5 already owns and implements POST-only handling, strict Bearer authentication, authentication before privileged persistence, 128 KiB bounded/streaming JSON parsing, canonical UUID-v4 `client_submission_id`, principal-field lengths, date/category validation, Quill Delta validation and canonicalization, the existing asset metadata/shape/count rules, delayed store construction, one `SubmissionStore.submit()` call, one service-role `submit_content` RPC, atomic quota/idempotency/content/asset persistence, and the `created` / `replayed` / `rate_limited` outcomes. Its user-scoped first-commit-wins decision deliberately superseded the original high-level idea of an idempotency-conflict response: a later otherwise-valid body replays the first committed submission even when its content differs.

The re-audited production path is:

`Flutter wire payload -> submit-content authentication/body reader -> parseContentSubmission -> SubmissionStore.submit -> submit_content RPC -> content_submissions/submission_assets`.

Three concrete public-boundary gaps remain:

1. Coordinates are independently accepted as optional finite numbers, so partial numeric pairs and finite out-of-range values cross the store/RPC boundary unchanged.
2. Asset URL validation checks only HTTPS plus hostname `res.cloudinary.com`. Any authenticated internet caller can therefore submit another Cloudinary account, namespace, resource/delivery type, transformed path, or arbitrary public ID without using the official upload flow.
3. The maximum-five check does not reject repeated assets, so `[A, A]` can consume two public attachment slots.

The official public upload producer has two branches:

- New upload: Flutter hashes the file into `content_submissions/<lowercase 64-hex SHA-256>`, obtains signed fields from `prepare-cloudinary-upload`, POSTs them to `https://api.cloudinary.com/v1_1/<cloud-name>/image/upload`, and forwards Cloudinary's top-level `secure_url` unchanged.
- Existing/dedupe: `prepare-cloudinary-upload` looks up the exact public ID through Cloudinary's `resources/image/upload/<public-id>` Admin endpoint, verifies the returned `public_id`, and forwards its top-level `secure_url` through Flutter unchanged.

The repository signs the exact public ID, selects resource type `image` and delivery type `upload`, and never selects a transformed/derived delivery URL. Cloudinary's documented Upload API and single-asset Admin API responses give the top-level original asset URL as:

`https://res.cloudinary.com/<cloud-name>/image/upload/v<positive-decimal-version>/<public-id>.<format>`.

Their transformed URLs are separate eager/derived response entries, which neither public producer branch consumes. The repository does not synthesize a URL or expose the actual production cloud name in source; validation therefore uses the configured `CLOUDINARY_CLOUD_NAME`, and tests use a realistic non-production cloud name. Existing tests that pair `content_submissions/...` public IDs with URLs lacking that namespace are response-shape simplifications, not production-contract evidence.

## Goals / Non-Goals

**Goals:**

- Complete all Subplan 6 untrusted-input checks before the existing privileged store boundary.
- Keep coordinate validation local, preserve accepted numeric values exactly, and retain current omission/null compatibility.
- Enforce structural compatibility with the two official public Cloudinary producer branches without claiming remote provenance, existence, or ownership.
- Reject duplicate public assets by the already-validated content-addressed public ID while preserving the existing count-first behavior.
- Keep validation pure by passing external configuration from the composition root.
- Reuse only generic Cloudinary identity parsing that already belongs in the shared Cloudinary module; keep the public Content Submission URL grammar at `submit-content`.
- Use realistic, correlated producer/consumer fixtures and focused regressions instead of duplicating every parser case at handler level.

**Non-Goals:**

- No production Flutter model, mapper, repository, ViewModel, upload, retry, staging, state-management, routing, navigation, UI validation, error taxonomy, `canRetry`, or error-UX change.
- No database schema, migration, generated type, RPC, quota, idempotency, transaction, RLS, URL-host check, coordinate check, or duplicate-asset constraint.
- No Cloudinary Admin API or remote existence check during submission; no remote byte/hash verification, signed-upload provenance proof, per-user asset ownership, orphan cleanup, deletion, or upload retry redesign.
- No global Cloudinary-only rule for `submission_assets`; no TicketOne, EventiMolise, future-importer, rehosting-policy, Admin, promotion, moderation, or conversion redesign.
- No client-declared trust field such as `asset_source`, `trusted_asset`, or `allow_external_asset`.
- No new MIME policy, unknown-top-level-field rejection, stricter Content-Type rule, email-regex refinement, new normalization, generic Edge refactor, schema library, validation framework, package, or third-party dependency.
- No rewrite, synchronization, archival, or completion-state change for any previous or main OpenSpec artifact.

## Decisions

### 1. Preserve one validation-before-privilege pipeline

The handler remains thin:

`authenticate -> bounded JSON parse -> complete untrusted-input validation -> construct store -> one submit_content RPC -> stable HTTP mapping`.

`parseContentSubmission` receives a small explicit validation configuration containing the Cloudinary cloud name. `createProductionDependencies` obtains that value through the existing `requiredEnv` composition-root pattern and the handler passes it to the parser. Tests inject a deterministic non-production cloud name. `submission_validation.ts` does not read `Deno.env`, construct a privileged client, or perform network I/O.

All coordinates and assets are validated before the validated submission is constructed. Only a successful parse permits `createStore()`. Consequently, every new failure has zero store constructions, zero `SubmissionStore.submit()` calls, and no RPC, replay lookup, quota, content, or asset work.

Alternative considered: construct the store earlier and let the RPC reject malformed data. Rejected because it weakens the existing trust boundary, duplicates public-wire behavior below the parser, and performs privileged work for inputs that can be rejected deterministically.

### 2. Validate coordinates as one parser-local nullable pair

Map `undefined` and `null` to absence. Both absent, both null, and mixed omitted/null representations all become `(null, null)`. Parse a present value only when it is a finite number within its field's inclusive range, returning the same number. After field validation, reject exactly-one-numeric pairs with `latitude and longitude must be provided together`.

Type, finiteness, and range failures retain `latitude is not valid` or `longitude is not valid`. No clamping, rounding, wrapping, swapping, geocoding, or precision truncation is introduced.

Alternative considered: share the Admin coordinate helper. Rejected because Admin requires a different request shape and explicit-key semantics, including punctuation in its public messages. Two small validators with different ingress contracts do not justify coupling them.

Alternative considered: add `content_submissions` CHECK constraints. Rejected in Decision 5 because the defect is public-wire validation and legacy/trusted writer behavior is broader.

### 3. Enforce one canonical public-upload structural URL contract

After the existing asset metadata parser succeeds, public `submit-content` validates the asset URL against this exact canonical form:

`https://res.cloudinary.com/<configured-cloud-name>/image/upload/v<positive-decimal-version>/content_submissions/<lowercase-64-hex-sha256>.<lowercase-alphanumeric-format>`.

This is a structural compatibility check, not a provenance proof. The validator requires:

- literal HTTPS and exact delivery hostname `res.cloudinary.com`;
- no user information and no explicit port;
- an exact configured cloud-name path segment;
- exact resource type `image` and delivery type `upload`;
- one positive decimal `v...` version segment;
- exact `content_submissions` namespace;
- one lowercase 64-hex digest as the public-ID leaf;
- one non-empty lowercase alphanumeric Cloudinary format extension;
- no transformation, alternate delivery, extra/repeated path, percent-encoded/path-normalized substitute, query, or fragment components.

The parser preserves an accepted URL string exactly; it does not rewrite or canonicalize it. The public ID `content_submissions/<digest>` is extracted only as validation metadata and duplicate identity, not added to the persistence payload.

The shared Cloudinary module may expose or minimally adapt its existing generic delivery parser so HTTPS, exact hostname, and configured cloud-name checks are not copied. Generic parsing must not encode `image/upload/content_submissions` policy. The public `submit-content` validator owns those remaining path and canonical-form rules. Existing dedupe lookup behavior continues using only the generic helper plus its independent exact returned-`public_id` comparison.

This contract accepts the top-level `secure_url` from both official branches. It rejects another Cloudinary cloud/account, another namespace, `video/upload`, `image/fetch`, transformed delivery paths, unversioned URLs, extensionless URLs, malformed/uppercase/short hashes, URLs with query/fragment data, encoded namespace/hash forms, non-default host/port variants, and all other shapes not emitted by the producer.

Alternative considered: preserve the current HTTPS-plus-host check. Rejected because an authenticated caller can bypass upload preparation and reference an arbitrary Cloudinary account or asset.

Alternative considered: accept every URL shape Cloudinary can theoretically deliver. Rejected because fetch/authenticated/private/derived/transformed/custom-delivery forms are not emitted by this producer and would make the public contract broader and harder to reason about.

Alternative considered: call Cloudinary to prove remote existence, account ownership, signed-request ancestry, user ownership, or byte/hash correspondence. Rejected because those are different security guarantees requiring remote state and new failure modes; the available URL cannot establish all of them.

### 4. Reject duplicates by validated public ID after count validation

`parseAssets` retains the existing array-shape and `length > 5` check before parsing individual assets. Each of at most five entries then passes metadata and structural URL validation. Track the extracted `content_submissions/<digest>` value in a small local set; a repeated public ID returns `assets must not contain duplicates`.

The public ID is preferable to raw URL because it is already available from structural validation and identifies the same content-addressed asset even if a caller presents two otherwise accepted version/format variants. No generic URL canonicalization subsystem is needed. The persisted asset array and order remain unchanged for distinct assets.

Thus one asset, two distinct assets, and five distinct assets remain valid; `[A, A]` fails; and any six-entry array retains the existing `assets length is not valid` result before duplicate or per-asset checks.

Alternative considered: `UNIQUE(content_submission_id, url)` or a change to `add_submission_assets`. Rejected because duplicate rejection is a public-ingress policy, not an established invariant for every trusted writer, and a database rule would not preserve the desired count/error ordering.

### 5. Keep database and trusted-ingestion ownership unchanged

Coordinate pairing/ranges, official-upload structural compatibility, and duplicate rejection are primary responsibilities of the untrusted public `submit-content` boundary:

- Admin already enforces its own finite coordinate pair and range rules.
- The current external-event importer is a privileged server-side path and currently writes null coordinates/rehosts media through its own contract.
- Promotion rejects incomplete, out-of-range, NaN, and infinite legacy submission coordinates before creating range-constrained published entities.
- Existing promotion tests deliberately persist malformed legacy submission coordinates.
- `submit_content` is service-role-only and owns database quota, idempotency, content, and asset transaction invariants after Edge validation.
- `add_submission_assets` and `submission_assets` have no global Cloudinary-account or per-submission-URL uniqueness invariant.

Accordingly, Subplan 6 adds no migration. The Cloudinary structural-origin validation is exclusive to untrusted public `submit-content`. It is not a global invariant of `submission_assets` or generic backend persistence. Trusted server-side ingestion paths may persist provider-controlled HTTPS asset URLs when their ingestion contract requires the asset to remain hosted by the provider. Trust comes from the controlled server-side ingress, never from a caller-supplied flag.

Alternative considered: defense-in-depth constraints for coordinates, Cloudinary host/account, or duplicate URLs. Rejected because they would change legacy and trusted-writer compatibility without a demonstrated global invariant and would expand this Edge subplan into a data migration.

### 6. Preserve the established public response and idempotency contracts

Parser failures continue to map to HTTP 400 and `VALIDATION_ERROR`. Structural URL failures reuse `asset url is not valid`; duplicate public IDs use `assets must not contain duplicates`. Unauthorized, created, replayed, rate-limited, malformed-RPC, and persistence-failure behavior remains exactly as Subplan 5 established.

A request reusing a committed `client_submission_id` still passes the complete current public parser before privileged replay lookup. Invalid new coordinates, asset structure, or duplicate assets therefore fail rather than replay. An otherwise-valid changed body retains first-commit-wins replay behavior; this subplan does not resurrect an idempotency-conflict response.

Alternative considered: add new error codes/statuses or client `canRetry` classifications. Rejected because stable validation mapping is sufficient here and client error taxonomy is a separate mini-subplan.

### 7. Use realistic contract fixtures with layered tests

Parser tests own the complete coordinate, structural-URL, duplicate, count-precedence, and preservation matrices. Use realistic non-production values whose public ID and URL path agree:

- cloud name such as `moliseis-test`;
- public IDs `content_submissions/<64 lowercase hex>`;
- top-level URLs such as `https://res.cloudinary.com/moliseis-test/image/upload/v1700000000/content_submissions/<digest>.jpg`.

Use at least one distinct canonical format/version fixture for the normal upload branch and another for the dedupe branch. Do not treat the existing `demo`, `test`, namespace-free, extensionless, or unrelated-host fixtures as allowed production shapes.

Handler tests stay small: representative partial/out-of-range coordinate, foreign Cloudinary structure, duplicate asset, and malformed-replay requests prove HTTP 400/`VALIDATION_ERROR`, zero store constructions, and zero store calls. Parser tests cover the rest.

Producer regressions correct or supplement correlated fixtures in shared Cloudinary lookup, `prepare-cloudinary-upload`, Flutter preparation, and Flutter upload tests. The public-ID generator test proves the digest contract; the preparation/dedupe and new-upload tests prove each branch forwards a realistic canonical URL; the public parser tests prove those forms are accepted. Production Flutter remains unchanged.

Alternative considered: duplicate the full parser matrix at handler level or add a cross-language fixture framework. Rejected because representative isolation tests plus small realistic constants in the existing suites provide the contract evidence without new infrastructure.

## Risks / Trade-offs

- **Cloudinary changes its top-level canonical `secure_url` response** -> Producer tests fail or legitimate submissions fail closed; update this public contract only after verifying the official producer's new shape, rather than pre-authorizing speculative variants.
- **Existing simplified fixtures appear to justify broader URLs** -> Correlate public IDs and URL paths and separate response-shape test intent from production-contract evidence.
- **Shared generic Cloudinary parsing changes dedupe lookup behavior** -> Keep the helper limited to generic delivery identity and run all existing shared/prepare tests; retain exact returned-`public_id` verification.
- **The target `submit-content` runtime lacks or mismatches Cloudinary configuration** -> Before deployment, verify without printing the value that `CLOUDINARY_CLOUD_NAME` is present and names the same Cloudinary product environment used by `prepare-cloudinary-upload`; otherwise the composition root can fail closed before serving even assetless submissions.
- **A caller supplies a structurally valid URL for bytes that do not match its digest** -> Accepted residual limitation; this subplan proves structure only and explicitly does not make remote byte/hash or per-user provenance claims.
- **A future trusted importer needs provider-hosted media** -> Keep the rule out of database/store/RPC invariants and attach it only to public `submit-content`.
- **Strict validation changes behavior for malformed non-repository clients** -> Intentional hardening; valid official producer output and stable public error envelopes remain compatible.

## Migration Plan

1. Reconfirm the Subplan 5 production baseline and characterize correlated normal-upload and dedupe fixtures before editing production code.
2. Add focused failing parser and handler regressions, then implement the pure coordinate, structural-origin, duplicate, and configuration-injection changes without changing persistence.
3. Correct/supplement producer fixtures and run focused Deno and Flutter producer-to-consumer regressions, formatting, and type checks.
4. Complete the adversarial review and strict OpenSpec validation before `/opsx-apply` can be considered ready.
5. Before deployment, verify through the target environment's approved configuration mechanism, without printing the value, that `CLOUDINARY_CLOUD_NAME` is available to `submit-content` and identifies the same Cloudinary product environment used by `prepare-cloudinary-upload`.
6. Deploy only the verified Subplan 6 Edge/shared-function code. Subplan 6 introduces no additional database migration, but the Subplan 5 `submit_content` RPC and supporting schema migration must already be deployed in the same target environment before the hardened `submit-content` Edge Function.

Rollback is Edge/shared-function first while leaving the additive Subplan 5 database/RPC state in place. No Subplan 6 database rollback or data backfill exists. Completion remains limited to Content Submission Hardening Subplan 6; client error taxonomy/`canRetry` and final Subplan 7 end-to-end validation remain separate release-readiness work.
