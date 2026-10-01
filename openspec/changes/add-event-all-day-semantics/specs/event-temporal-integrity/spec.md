## MODIFIED Requirements

### Requirement: Content submission dates form a valid optional interval
The database SHALL allow both submission dates to be absent when `all_day=false`, or an optional end paired with a present start in either mode. When `all_day=true`, the database SHALL require a non-null start even with a null end. It SHALL reject an end without a start and an end earlier than the start on insert or update. Equal start and end instants SHALL be valid.

#### Scenario: Both dates are absent
- **WHEN** a content submission is inserted or updated with `all_day=false`, null start, and null end
- **THEN** the date constraints accept the row

#### Scenario: Start has no end
- **WHEN** a content submission is inserted or updated with a start and null end
- **THEN** the date constraints accept the row

#### Scenario: End is present without a start
- **WHEN** a content submission is inserted or updated with null start and a non-null end
- **THEN** the database rejects the row

#### Scenario: End equals or follows start
- **WHEN** a content submission is inserted or updated with a start and an end equal to or later than it
- **THEN** the date constraints accept the row, including differences at timestamp microsecond precision

#### Scenario: End precedes start
- **WHEN** a content submission is inserted or updated with an end earlier than its start, including a sub-millisecond inversion
- **THEN** the database rejects the row

#### Scenario: All-day mode requires a start even without an end
- **WHEN** a content submission is inserted or updated with `all_day=true`, null start, and null end
- **THEN** the database rejects the row
