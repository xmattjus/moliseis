## MODIFIED Requirements

### Requirement: Public submit wire envelope
The final `submit-content` request SHALL contain exactly the top-level keys `client_submission_id`, `category`, `city`, `name`, `description`, `description_delta`, `latitude`, `longitude`, `address`, `start_date`, `end_date`, `all_day`, `start_calendar_date`, `end_calendar_date`, `user_email`, `user_name`, and `assets`. It SHALL carry the supplied client identity unchanged; represent nullable content values as null; send false and null civil fields for timed/non-event content and serialize every non-null timed instant as a UTC ISO-8601 string; send true, null request timestamps, and exact Rome Gregorian civil-date strings for all-day content; preserve the existing immutable JSON-compatible description Delta structure; and preserve uploaded asset order. Each nested asset SHALL use the existing wire fields `url`, `width`, `height`, nullable `mime_type`, and nullable `duration_seconds`. Authenticated database ownership SHALL continue to be derived server-side from the request's bearer identity rather than from a client-supplied `user_id`.

#### Scenario: Complete request uses the public wire contract
- **WHEN** final submission is invoked with content, timed event instants, and uploaded assets
- **THEN** exactly one `submit-content` request carries every allowlisted top-level field, false mode, null civil-date fields, UTC temporal values, the unchanged description Delta, and asset metadata in supplied order

#### Scenario: Nullable values remain explicit
- **WHEN** an optional content, temporal, location, MIME, or duration value is absent
- **THEN** its corresponding allowlisted wire field is null rather than synthesized from unrelated local state

#### Scenario: Persistence and lifecycle fields are excluded
- **WHEN** the final request body is constructed
- **THEN** it contains no `user_id`, `created_at`, `modified_at`, `accepted_terms`, ObjectBox entity ID, checkpoint metadata, or other local lifecycle state

#### Scenario: Date-only attempt carries civil input from the captured draft
- **WHEN** final submission sends an all-day immutable attempt with uploaded assets
- **THEN** the same exact envelope contains true, null timestamps, the captured initial civil date and optional final civil date, and the unchanged identity and ordered assets

#### Scenario: Non-event attempt has no temporal values
- **WHEN** final submission sends non-event content
- **THEN** the envelope contains false and null in all four temporal input fields
