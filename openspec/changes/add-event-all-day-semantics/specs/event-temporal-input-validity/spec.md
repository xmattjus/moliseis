## MODIFIED Requirements

### Requirement: Submission dates have strict Gregorian calendar validity
For the timed/legacy input branch, the shared authoritative request validation used by public and admin submission adapters SHALL continue to accept only the project's intended ISO-like lexical contract: `YYYY-MM-DD`, or an existing supported `YYYY-MM-DD` date-time form with no offset, UTC `Z`, or an explicit numeric offset and with optional fractional seconds at the precision currently supported by the backend. Every accepted form SHALL state a real Gregorian year, month, and day; a string SHALL NOT become valid merely because the JavaScript date parser accepts or normalizes an alternate syntax. Gregorian validity SHALL be evaluated before and independently from end/start temporal ordering. In the explicit all-day branch, civil-date fields SHALL instead use exact `YYYY-MM-DD` Gregorian dates and normalize under the temporal-mode requirements below; the timed/legacy accepted syntax SHALL NOT be narrowed by adding this branch.

#### Scenario: Impossible Gregorian date is rejected by shared validation
- **WHEN** a start or end value states an impossible date such as `2024-02-30`, `2023-02-29`, or `2024-04-31`, either alone or in a supported offset-less or `Z` date-time form
- **THEN** shared validation returns the corresponding invalid-start or invalid-end result before range ordering can accept the value

#### Scenario: Impossible offset date-time remains invalid
- **WHEN** an impossible month-boundary or leap-year combination includes fractional seconds and an explicit numeric offset
- **THEN** shared validation rejects it as an invalid calendar date rather than accepting the JavaScript-normalized instant

#### Scenario: Intended ISO-like forms remain accepted unchanged
- **WHEN** a real Gregorian date is supplied as `YYYY-MM-DD` or as an existing supported `YYYY-MM-DD` date-time with no offset, UTC `Z`, an explicit positive or negative numeric offset, or a currently supported fractional-second precision
- **THEN** shared validation accepts the value under the existing nullable/pairing rules and preserves the original string

#### Scenario: Alternate parser-defined syntax is outside the contract
- **WHEN** a string is not one of the intended ISO-like lexical forms even though the runtime JavaScript date parser happens to accept it
- **THEN** shared validation rejects the string with the corresponding invalid-start or invalid-end result

#### Scenario: Gregorian century and month-length rules are enforced
- **WHEN** validation evaluates `2000-02-29`, `1900-02-29`, `2024-02-29`, `2023-02-29`, `2024-04-30`, and `2024-04-31`
- **THEN** it accepts `2000-02-29`, `2024-02-29`, and `2024-04-30`, and rejects `1900-02-29`, `2023-02-29`, and `2024-04-31`

#### Scenario: Gregorian rules apply to every date-time variant
- **WHEN** the same impossible leap-year or month-boundary date is used in a supported offset-less, `Z`, numeric-offset, or fractional-second date-time
- **THEN** shared validation rejects it with the same field-specific invalid-date result as its date-only equivalent

#### Scenario: Public and admin adapters enforce shared calendar validity
- **WHEN** an impossible Gregorian date reaches either the public submission request parser or the admin create/update request parser
- **THEN** the adapter rejects the request using its existing field-specific invalid-date response and does not pass the value to persistence

#### Scenario: Microsecond range ordering is preserved
- **WHEN** two valid date-time strings differ only below JavaScript millisecond precision or denote equal instants through different offsets
- **THEN** the existing microsecond-aware ordering behavior continues to distinguish inverted ranges from equal or chronological ranges

## ADDED Requirements

### Requirement: Temporal input formats are mutually exclusive
Public submission validation SHALL accept omitted `all_day` as false for legacy payloads and SHALL reject a present non-boolean flag, including null. With false, civil-date fields SHALL be absent or null and the existing timestamp/date lexical contract and nullable pairing rules SHALL remain valid. With true, request timestamps SHALL be absent or null, `start_calendar_date` SHALL be a required exact Gregorian `YYYY-MM-DD` string, and `end_calendar_date` SHALL be absent/null or an exact Gregorian date on or after the start. Supplying non-null values from both formats SHALL be rejected before privileged persistence. Admin full-input validation SHALL enforce the same mode rules with an explicit complete field set containing `all_day`, `start_date`, `end_date`, `start_calendar_date`, and `end_calendar_date`, using null for unused temporal fields. Non-event input SHALL use false with all temporal fields null; the Admin contract SHALL NOT become a generic PATCH. Complete validation SHALL apply to both first attempts and replays.

#### Scenario: Legacy payload remains timed
- **WHEN** an otherwise-valid legacy request omits the mode and civil-date fields
- **THEN** it uses false and the existing nullable and ISO-like date/timestamp grammar without changing its accepted values

#### Scenario: Single-day civil input is accepted
- **WHEN** true is supplied with `start_calendar_date=2026-10-12`, absent/null final date, and absent/null request timestamps
- **THEN** validation accepts the all-day branch and normalizes a start with null end

#### Scenario: Ordered civil range is accepted
- **WHEN** true is supplied with valid Gregorian civil dates whose final date equals or follows the start
- **THEN** validation accepts the range and normalizes its final civil-day bound

#### Scenario: Gregorian and lexical errors fail before normalization
- **WHEN** a civil field contains `2026-02-30`, `1900-02-29`, a non-string, a non-padded date, or a date-time string
- **THEN** validation rejects the field before normalization or persistence, while a real leap day such as `2000-02-29` passes Gregorian validation

#### Scenario: Mode cannot be inferred from malformed input
- **WHEN** the mode is non-boolean, true lacks a civil start, false has a non-null civil date, or either mode mixes non-null request timestamps with civil dates
- **THEN** validation rejects the request without guessing a temporal mode or issuing a write

#### Scenario: Final civil date precedes the start
- **WHEN** an all-day request supplies a final civil date before its initial date
- **THEN** validation rejects the range before persistence

### Requirement: Shared normalization returns only persistible temporal values
Public, Admin, and importer temporal write boundaries SHALL use the same normalization semantics and produce only `all_day`, `start_date`, and `end_date` for persistence. All-day civil input SHALL be normalized to the canonical persisted representation defined by `event-all-day-semantics`; legacy/timed values SHALL retain their established meaning and supported fractional precision. Civil input fields SHALL NOT become new database date columns.

#### Scenario: Public and Admin normalize the same civil input identically
- **WHEN** the same valid all-day civil range reaches public and Admin validation
- **THEN** their stores receive identical mode and normalized temporal bounds and no civil input columns

#### Scenario: Import normalization agrees with submission normalization
- **WHEN** a source adapter supplies the same date-only range
- **THEN** the importer receives the same canonical Rome bounds and true mode as the submission boundaries

#### Scenario: Final microsecond survives a millisecond runtime
- **WHEN** an all-day final bound is normalized through the backend runtime
- **THEN** the persisted string retains the last microsecond of the Rome day rather than truncating it to milliseconds or moving it to next-day midnight
