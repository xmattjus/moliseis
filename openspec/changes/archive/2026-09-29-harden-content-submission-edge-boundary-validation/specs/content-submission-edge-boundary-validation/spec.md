## Purpose

Defines complete validation and privilege-isolation behavior for untrusted public `submit-content` requests, including nullable geographic coordinates, official Cloudinary upload structure, and per-request asset uniqueness.

## ADDED Requirements

### Requirement: Public submission coordinates form one nullable pair
The public Content Submission boundary SHALL treat `latitude` and `longitude` as one nullable pair. Each field MAY be omitted or explicitly `null` to represent no coordinate. After omission/null normalization, either both values SHALL be null or both SHALL be numbers. If exactly one value is numeric while the other is omitted or null, the request SHALL be rejected with HTTP 400, code `VALIDATION_ERROR`, and message `latitude and longitude must be provided together`.

#### Scenario: Both coordinate fields are omitted
- **WHEN** an otherwise valid public submission omits both `latitude` and `longitude`
- **THEN** validation succeeds with both validated coordinates equal to null

#### Scenario: Both coordinate fields are explicitly null
- **WHEN** an otherwise valid public submission supplies null for both coordinates
- **THEN** validation succeeds with both validated coordinates equal to null

#### Scenario: Omitted and null absence representations are mixed
- **WHEN** an otherwise valid public submission omits either coordinate field and supplies null for the other
- **THEN** validation succeeds with both validated coordinates equal to null

#### Scenario: Latitude is numeric without numeric longitude
- **WHEN** an otherwise valid public submission supplies numeric `latitude` while `longitude` is omitted or null
- **THEN** the boundary returns the stable pair-mismatch validation failure

#### Scenario: Longitude is numeric without numeric latitude
- **WHEN** an otherwise valid public submission supplies numeric `longitude` while `latitude` is omitted or null
- **THEN** the boundary returns the stable pair-mismatch validation failure

### Requirement: Present coordinates are finite numbers within geographic ranges
When a public submission supplies a numeric coordinate pair, `latitude` SHALL be a finite number in inclusive range `[-90, 90]` and `longitude` SHALL be a finite number in inclusive range `[-180, 180]`. Strings, booleans, objects, arrays, `NaN`, positive infinity, and negative infinity SHALL NOT be accepted. Invalid latitude SHALL retain message `latitude is not valid`; invalid longitude SHALL retain message `longitude is not valid`; handler responses SHALL retain HTTP 400 and code `VALIDATION_ERROR`.

#### Scenario: Zero pair is accepted
- **WHEN** an otherwise valid public submission supplies coordinates `(0, 0)`
- **THEN** both coordinates pass validation

#### Scenario: Inclusive latitude limits are accepted
- **WHEN** otherwise valid requests supply latitude `-90` or `90` with a valid numeric longitude
- **THEN** each request passes coordinate validation

#### Scenario: Inclusive longitude limits are accepted
- **WHEN** otherwise valid requests supply longitude `-180` or `180` with a valid numeric latitude
- **THEN** each request passes coordinate validation

#### Scenario: Latitude immediately outside its range is rejected
- **WHEN** an otherwise valid paired request supplies latitude immediately below `-90` or immediately above `90`
- **THEN** the boundary returns the stable invalid-latitude validation failure

#### Scenario: Longitude immediately outside its range is rejected
- **WHEN** an otherwise valid paired request supplies longitude immediately below `-180` or immediately above `180`
- **THEN** the boundary returns the stable invalid-longitude validation failure

#### Scenario: Non-number coordinate representations are rejected
- **WHEN** either coordinate is represented by a string, boolean, object, or array
- **THEN** the boundary rejects the request using that field's existing invalid-coordinate message

#### Scenario: Non-finite direct parser inputs are rejected
- **WHEN** direct parser input supplies `NaN`, positive infinity, or negative infinity for either coordinate
- **THEN** the parser rejects the input using that field's existing invalid-coordinate message

### Requirement: Accepted coordinate values are preserved exactly
The public boundary SHALL forward each accepted coordinate number unchanged. It SHALL NOT clamp, round, wrap, swap, geocode, normalize, or truncate coordinate precision.

#### Scenario: Ordinary Molise coordinates survive parsing unchanged
- **WHEN** an otherwise valid public submission supplies ordinary in-range latitude and longitude values
- **THEN** the validated submission contains exactly the supplied numeric values in their original fields

#### Scenario: Boundary coordinates are not adjusted
- **WHEN** an otherwise valid request supplies an inclusive latitude or longitude limit with a valid paired coordinate
- **THEN** the validated submission retains the exact supplied limit without adjustment

### Requirement: Public assets match the official upload structural contract
Every asset accepted by untrusted public `submit-content` SHALL have a delivery URL structurally compatible with the official Molise Is public upload flow. Its canonical form SHALL be `https://res.cloudinary.com/<configured-cloud-name>/image/upload/v<positive-decimal-version>/content_submissions/<lowercase-64-hex-sha256>.<lowercase-alphanumeric-format>`. The URL SHALL use the exact configured cloud name, resource type `image`, delivery type `upload`, and content-addressed public-ID namespace. It SHALL have no user information, explicit port, transformation segment, unexpected/repeated path segment, percent-encoded or path-normalized substitute, query, or fragment. Accepted URL strings SHALL be preserved exactly.

#### Scenario: Normal new-upload URL is accepted
- **WHEN** an otherwise valid asset contains the canonical top-level `secure_url` returned after the official signed new-upload flow
- **THEN** the public boundary accepts the asset and preserves its URL unchanged

#### Scenario: Existing-asset dedupe URL is accepted
- **WHEN** an otherwise valid asset contains the canonical top-level `secure_url` returned by the official existing-asset lookup flow
- **THEN** the public boundary accepts the asset and preserves its URL unchanged

#### Scenario: HTTP or foreign delivery host is rejected
- **WHEN** an asset URL uses HTTP, a hostname other than exact `res.cloudinary.com`, user information, or an explicit port
- **THEN** the boundary returns HTTP 400, code `VALIDATION_ERROR`, and message `asset url is not valid`

#### Scenario: Different Cloudinary account is rejected
- **WHEN** an asset URL's cloud-name path segment differs from configured `CLOUDINARY_CLOUD_NAME`
- **THEN** the boundary returns the stable asset-URL validation failure

#### Scenario: Wrong resource or delivery type is rejected
- **WHEN** an asset URL uses a form such as `video/upload` or `image/fetch`
- **THEN** the boundary returns the stable asset-URL validation failure

#### Scenario: Foreign namespace or malformed public ID is rejected
- **WHEN** an asset URL uses a namespace other than `content_submissions` or its public-ID leaf is not exactly 64 lowercase hexadecimal characters
- **THEN** the boundary returns the stable asset-URL validation failure

#### Scenario: Non-canonical Cloudinary path is rejected
- **WHEN** an asset URL is unversioned, extensionless, transformed, contains extra/repeated segments, or substitutes percent encoding or path normalization for canonical path text
- **THEN** the boundary returns the stable asset-URL validation failure

#### Scenario: Query and fragment variants are rejected
- **WHEN** an otherwise canonical asset URL contains a query string or fragment
- **THEN** the boundary returns the stable asset-URL validation failure

### Requirement: Structural validation makes no remote provenance claim
Public structural validation SHALL NOT claim to prove remote asset existence, Cloudinary Admin ownership, the signed request that created the asset, per-user ownership, or correspondence between remote bytes and the SHA-256 embedded in the public ID. Subplan 6 SHALL NOT perform remote Cloudinary verification at submission time.

#### Scenario: Structurally valid input needs no remote lookup
- **WHEN** a public asset URL satisfies the complete local structural contract
- **THEN** request validation proceeds without a Cloudinary Admin or asset-existence request

#### Scenario: Structural acceptance is described accurately
- **WHEN** Subplan 6 behavior is documented or reported
- **THEN** it is described as structural compatibility with the official upload flow rather than cryptographic or remote provenance proof

### Requirement: Public requests contain no duplicate assets
After retaining the existing maximum-five array-length check, the public boundary SHALL validate each asset and derive its `content_submissions/<sha256>` public ID. No two assets in one request SHALL have the same validated public ID. A repeated public ID SHALL return HTTP 400, code `VALIDATION_ERROR`, and message `assets must not contain duplicates`. Distinct accepted assets SHALL retain their input order and values.

#### Scenario: One asset is valid
- **WHEN** an otherwise valid public request contains `[A]`
- **THEN** asset validation succeeds

#### Scenario: Two distinct assets are valid
- **WHEN** an otherwise valid public request contains `[A, B]` with distinct validated public IDs
- **THEN** both assets pass in their original order

#### Scenario: Repeated asset is rejected
- **WHEN** an otherwise valid public request contains `[A, A]`
- **THEN** the boundary returns the stable duplicate-asset validation failure

#### Scenario: Five distinct assets remain valid
- **WHEN** an otherwise valid public request contains five structurally valid assets with distinct public IDs
- **THEN** all five assets pass validation

#### Scenario: Six-entry request preserves count precedence
- **WHEN** a public request contains six assets
- **THEN** the boundary retains the existing `assets length is not valid` validation failure before duplicate or per-asset validation

### Requirement: Complete public validation precedes privileged persistence
Authentication and bounded request parsing SHALL retain the Subplan 5 ordering in which every public field, Delta, date, coordinate, asset metadata, asset structural-origin, and duplicate check completes before the privileged submission store is constructed or invoked. A validation failure SHALL NOT invoke `SubmissionStore.submit()`, the `submit_content` RPC, replay lookup, quota handling, submission creation, or asset creation. A committed `client_submission_id` SHALL NOT bypass the current validation contract.

#### Scenario: Invalid coordinate pair never reaches privileged persistence
- **WHEN** an authenticated request contains an incomplete or out-of-range coordinate pair
- **THEN** the handler returns HTTP 400 and `VALIDATION_ERROR` with zero store constructions and zero store calls

#### Scenario: Invalid structural origin never reaches privileged persistence
- **WHEN** an authenticated request contains a structurally foreign or non-canonical asset URL
- **THEN** the handler returns HTTP 400 and `VALIDATION_ERROR` with zero store constructions and zero store calls

#### Scenario: Duplicate asset never reaches privileged persistence
- **WHEN** an authenticated request repeats a validated asset public ID
- **THEN** the handler returns HTTP 400 and `VALIDATION_ERROR` with zero store constructions and zero store calls

#### Scenario: Replay identity does not bypass current validation
- **WHEN** an authenticated request reuses an already committed client submission identity but contains coordinates or assets invalid under this capability
- **THEN** validation fails before store construction, privileged replay lookup, quota work, or any database write

#### Scenario: Otherwise-valid changed replay remains first-commit-wins
- **WHEN** a later request reuses a committed client identity and passes the complete current public validation boundary
- **THEN** Subplan 5 replay semantics apply without a new idempotency-conflict outcome

### Requirement: Public-ingress asset policy is not a global storage invariant
The official-upload structural rule and duplicate rejection SHALL apply only to the untrusted public `submit-content` ingress. They SHALL NOT become Cloudinary-host, URL, or uniqueness constraints on generic submission storage, lower-level RPCs, Admin paths, or trusted server-side importers. Trusted server-side ingestion MAY persist provider-controlled HTTPS assets when its own controlled ingestion contract requires provider hosting. An untrusted caller SHALL NOT be able to opt out through a caller-controlled trust/source field.

#### Scenario: Trusted importer contract remains host-agnostic
- **WHEN** a trusted server-side ingestion path is authorized by its own contract to retain provider-hosted HTTPS media
- **THEN** the Subplan 6 public Cloudinary rule does not prohibit generic persistence of that media

#### Scenario: Public caller cannot self-declare trust
- **WHEN** an untrusted public caller supplies a field claiming an asset or source is trusted or externally allowed
- **THEN** the public boundary does not use that field to bypass structural or duplicate validation

#### Scenario: No global database constraint is introduced
- **WHEN** Subplan 6 is implemented
- **THEN** no coordinate, Cloudinary-host/account, asset-URL, or duplicate-asset database constraint or migration is added

### Requirement: Established response and persistence contracts remain unchanged
Subplan 6 SHALL preserve the existing public mappings for unauthorized requests, successful creation, idempotent replay, rate limiting, and server failures. It SHALL preserve the maximum-five rule, principal fields, dates, categories, Delta canonicalization, asset metadata validation, single store invocation, single service-role RPC, atomic quota handling, first-commit-wins idempotency, and atomic submission/asset persistence. It SHALL NOT introduce a new validation error taxonomy or client retry classification.

#### Scenario: Existing valid request reaches one atomic persistence call
- **WHEN** an authenticated request passes every current validation rule
- **THEN** the handler constructs one store and invokes it once using the established Subplan 5 RPC contract

#### Scenario: Existing outcomes retain their mappings
- **WHEN** persistence returns `created`, `replayed`, or `rate_limited`, or returns an established failure
- **THEN** the handler uses the existing Subplan 5 HTTP status and response envelope for that outcome

#### Scenario: Client error taxonomy remains separate
- **WHEN** Subplan 6 validation fails
- **THEN** the response uses the established validation mapping without adding `canRetry` or new client-facing error categories

### Requirement: Subplan completion remains bounded
Completion of this capability SHALL be reported only as Content Submission Hardening Subplan 6: `submit-content` Edge boundary and validation hardening. It SHALL NOT be represented as making the entire Content Submission feature release-ready or release-proof.

#### Scenario: Subplan verification passes
- **WHEN** every requirement, producer-consumer regression, and adversarial review item in this capability passes
- **THEN** Subplan 6 may be reported complete while client error-taxonomy work and final Subplan 7 end-to-end release-readiness validation remain outstanding
