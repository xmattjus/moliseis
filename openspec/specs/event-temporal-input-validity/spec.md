## Purpose

Protect event editing and submission request boundaries from malformed calendar input without normalizing stored state or narrowing the intended valid ISO-like date syntax.

## Requirements

### Requirement: Date pickers present valid bounds for an inverted draft
When an event editor holds an end calendar date earlier than the start calendar date used as its lower bound, opening the end-date picker SHALL present lower-bound, initial-date, and upper-bound values that satisfy the active platform picker's invariants. At least one supported regression SHALL place the selected end in an earlier calendar year than the lower bound so both initial-before-lower and upper-before-lower failures are exercised. The presentation adjustment SHALL be limited to picker inputs and SHALL preserve behavior for ranges whose selected date is already within bounds.

#### Scenario: Material end picker opens for a cross-year inverted range
- **WHEN** a Material end-date picker is opened with a persisted selected end in December 2026 and its first selectable date in January 2027
- **THEN** the picker opens without an invariant failure, `initialDate >= firstDate`, `lastDate >= firstDate`, the effective initial date is clamped only for presentation, and the administrator can select a valid replacement date

#### Scenario: Compact iOS end picker opens for a cross-year inverted range
- **WHEN** a compact iOS end-date picker is opened with a persisted selected end in December 2026 and its minimum selectable date in January 2027
- **THEN** the Cupertino picker opens without an invariant failure, its initial date is not before its minimum date, its maximum date is not before its minimum date, the effective initial date is clamped only for presentation, and the administrator can select a valid replacement date

#### Scenario: Valid picker values remain unchanged
- **WHEN** a date picker is opened with a selected date already between its lower and upper bounds
- **THEN** the picker uses the existing selected date and selectable range without changing valid-range behavior

### Requirement: Picker presentation does not repair temporal state
Opening or dismissing a date picker SHALL NOT mutate, normalize, persist, or make persistence-ready an invalid underlying event draft. Existing client persistence validation SHALL continue to reject an inverted range until a supported editor action successfully changes it to a valid value.

#### Scenario: Opening an end picker is non-mutating
- **WHEN** an administrator opens an end-date picker for a cross-year inverted hydrated draft and dismisses it without confirming a replacement
- **THEN** the draft retains its original start and end values, remains invalid for persistence, and no update is written

#### Scenario: Confirmed valid replacement repairs the draft
- **WHEN** an administrator confirms an allowed end date that is not before the draft start
- **THEN** the editor applies that selected date through its normal edit boundary and the repaired draft can pass the existing persistence validation

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

### Requirement: Invalid-input hardening does not restore legacy local compatibility
This capability SHALL NOT infer event mode, synthesize temporal values, add compatibility parsing, or introduce migration behavior solely for pre-schema ObjectBox rows or other intentionally unsupported historical draft shapes.

#### Scenario: Pre-schema local row is outside this capability
- **WHEN** a local draft relies on a missing event-mode marker, an end-only legacy shape, or another pre-schema representation
- **THEN** this hardening provides no fallback projection or compatibility guarantee for that row

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
