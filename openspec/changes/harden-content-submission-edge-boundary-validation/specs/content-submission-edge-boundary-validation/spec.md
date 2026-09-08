## Purpose

Defines the public `submit-content` coordinate contract and guarantees that malformed geographic data is rejected before privileged submission persistence can be reached.

## ADDED Requirements

### Requirement: Public submission coordinates form one nullable pair
The public Content Submission boundary SHALL treat `latitude` and `longitude` as one nullable pair. Each field MAY be omitted or explicitly `null` to represent no coordinate; after this absence normalization, either both values SHALL be null or both SHALL be numbers. If exactly one value is numeric while the other is omitted or null, the request SHALL be rejected. An omitted field paired with an explicitly null field SHALL continue to represent no coordinate rather than a partial numeric pair.

#### Scenario: Both coordinate fields are omitted
- **WHEN** an otherwise valid public submission omits both `latitude` and `longitude`
- **THEN** validation succeeds with both validated coordinates equal to null

#### Scenario: Both coordinate fields are explicitly null
- **WHEN** an otherwise valid public submission supplies null for both coordinates
- **THEN** validation succeeds with both validated coordinates equal to null

#### Scenario: Omitted and null absence representations are mixed
- **WHEN** an otherwise valid public submission omits one coordinate field and supplies null for the other
- **THEN** validation succeeds with both validated coordinates equal to null

#### Scenario: Latitude is present without numeric longitude
- **WHEN** an otherwise valid public submission supplies numeric `latitude` while `longitude` is omitted or null
- **THEN** the boundary rejects the request with HTTP 400, code `VALIDATION_ERROR`, and message `latitude and longitude must be provided together`

#### Scenario: Longitude is present without numeric latitude
- **WHEN** an otherwise valid public submission supplies numeric `longitude` while `latitude` is omitted or null
- **THEN** the boundary rejects the request with HTTP 400, code `VALIDATION_ERROR`, and message `latitude and longitude must be provided together`

### Requirement: Present coordinates are finite numbers within geographic ranges
When a public submission supplies a numeric coordinate pair, `latitude` SHALL be a finite number in the inclusive range `[-90, 90]` and `longitude` SHALL be a finite number in the inclusive range `[-180, 180]`. Strings, booleans, objects, arrays, `NaN`, positive infinity, and negative infinity SHALL NOT be accepted as coordinates. Invalid latitude SHALL retain the message `latitude is not valid`; invalid longitude SHALL retain the message `longitude is not valid`; handler responses SHALL retain HTTP 400 and code `VALIDATION_ERROR`.

#### Scenario: Inclusive latitude limits are accepted
- **WHEN** otherwise valid public submissions supply paired coordinates with latitude equal to `-90` or `90`
- **THEN** both requests pass coordinate validation

#### Scenario: Inclusive longitude limits are accepted
- **WHEN** otherwise valid public submissions supply paired coordinates with longitude equal to `-180` or `180`
- **THEN** both requests pass coordinate validation

#### Scenario: Latitude immediately outside its range is rejected
- **WHEN** an otherwise valid paired request supplies latitude immediately below `-90` or immediately above `90`
- **THEN** the boundary rejects the request as invalid latitude

#### Scenario: Longitude immediately outside its range is rejected
- **WHEN** an otherwise valid paired request supplies longitude immediately below `-180` or immediately above `180`
- **THEN** the boundary rejects the request as invalid longitude

#### Scenario: Non-number coordinate representations are rejected
- **WHEN** either coordinate is represented by a string, boolean, object, or array
- **THEN** the boundary rejects the request using that field's existing invalid-coordinate message

#### Scenario: Non-finite parser inputs are rejected
- **WHEN** direct parser input supplies `NaN`, positive infinity, or negative infinity for either coordinate
- **THEN** the parser rejects the input using that field's existing invalid-coordinate message

### Requirement: Accepted coordinate values are preserved exactly
The public submission boundary SHALL forward each accepted coordinate number unchanged. It SHALL NOT clamp, round, wrap, geocode, normalize, or truncate coordinate precision.

#### Scenario: Ordinary valid coordinates survive parsing unchanged
- **WHEN** an otherwise valid public submission supplies ordinary in-range latitude and longitude values
- **THEN** the validated submission contains exactly the supplied numeric values

#### Scenario: Boundary coordinates are not adjusted
- **WHEN** an otherwise valid public submission supplies any inclusive latitude or longitude limit with a valid paired coordinate
- **THEN** the validated submission retains that exact limit value without adjustment

### Requirement: Coordinate validation completes before privileged persistence
Authentication and complete request parsing SHALL retain the Subplan 5 ordering in which validation finishes before the privileged submission store is constructed or invoked. A coordinate validation failure SHALL NOT invoke submission persistence, the `submit_content` RPC, quota handling, submission creation, or asset creation. It SHALL NOT bypass validation merely because `client_submission_id` already identifies a committed submission.

#### Scenario: Invalid pair never reaches the submission store
- **WHEN** an authenticated request contains an incomplete numeric coordinate pair
- **THEN** the handler returns the stable coordinate validation failure with zero submission-store constructions and zero submission-store calls

#### Scenario: Invalid range never reaches the submission store
- **WHEN** an authenticated request contains an out-of-range coordinate
- **THEN** the handler returns the stable field-specific validation failure with zero submission-store constructions and zero submission-store calls

#### Scenario: Replay identity does not bypass coordinate validation
- **WHEN** an authenticated request reuses an existing client submission identity but supplies invalid coordinates
- **THEN** validation fails before any replay lookup, quota operation, content write, or asset write

### Requirement: Subplan completion remains bounded
Completion of this capability SHALL be reported only as Content Submission Hardening Subplan 6: `submit-content` Edge boundary and validation hardening. It SHALL preserve the established Subplans 1–5 contracts and SHALL NOT be represented as making the entire Content Submission feature release-ready or release-proof.

#### Scenario: Subplan verification passes
- **WHEN** every requirement and regression in this capability passes
- **THEN** the result is reported as Subplan 6 complete while whole-program release readiness remains deferred to the complete hardening sequence
