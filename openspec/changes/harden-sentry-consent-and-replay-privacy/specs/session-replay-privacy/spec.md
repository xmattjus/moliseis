# Spec Delta

## Purpose

Protect contributor identity in diagnostic recordings while preserving useful public tourism and editorial context across submission and moderation screens.

## ADDED Requirements

### Requirement: Contributor identity is selectively obscured in Replay

Replay SHALL obscure contributor name and email in the public contribution form and administrative moderation displays. Approval or staff access SHALL NOT make contributor contact data public. Protection SHALL leave normal screen use and authorized staff access unchanged.

#### Scenario: Public contribution form
- **WHEN** a contributor enters or restores a name or email
- **THEN** the existing identity-field masks remain in effect without masking unrelated editorial input

#### Scenario: Dashboard row
- **WHEN** a moderation row shows contributor name with creation date
- **THEN** Replay obscures the name while retaining the adjacent date, title, city, category and status
- **AND** authorized staff can still read the identity in the application

#### Scenario: Editor proposed-by section
- **WHEN** edit mode renders contributor name or email in `Proposto da`, including finalized submissions
- **THEN** Replay obscures each present contributor identity field without obscuring the editorial content

### Requirement: Public content and administrator context retain Replay visibility

Replay SHALL retain globally unmasked text and images and useful public tourism content. The authenticated administrator context in `Creato come` SHALL NOT acquire a mask merely for containing a name or email. Intentionally public administrator identity information SHALL remain visible; it SHALL NOT be conflated with a submission contributor's private contact fields.

#### Scenario: Tourism and editorial content
- **WHEN** Replay records event/place titles, descriptions, cities, dates, categories, status, images or normal editorial controls
- **THEN** those fields remain visible under the current global privacy configuration

#### Scenario: Create-mode account context
- **WHEN** the editor renders `Creato come` from the current administrator account
- **THEN** that display retains its existing visibility and is not treated as the original submission contributor

### Requirement: Native recording proves selective redaction

Selective redaction acceptance SHALL include Android and iOS Replay inspection with synthetic contributor identities and visible non-sensitive controls. Widget-tree assertions SHALL establish placement only, not successful native pixel redaction or protection of separate telemetry payloads.

#### Scenario: Synthetic native moderation recording
- **WHEN** an isolated test recording includes the public form, dashboard and edit-mode identity section
- **THEN** synthetic contributor names/emails are unreadable while event/place titles, date, city, status and tourism images remain readable or visible
- **AND** the account-context branch remains distinguishable and preserves its approved visibility

#### Scenario: Separate payload exposure discovered
- **WHEN** verification discovers contributor values in a distinct error, breadcrumb, URL or metadata payload
- **THEN** UI masking alone is not claimed to protect that payload and the concrete disclosure is reported for a bounded scope decision
