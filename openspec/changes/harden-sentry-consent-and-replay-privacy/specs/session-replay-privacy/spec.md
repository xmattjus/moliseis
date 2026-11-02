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

Selective redaction acceptance SHALL combine representative native dashboard recordings on Android/iOS, affected widget-boundary regressions and actual Sentry Replay inspection of public-form/editor masking. Owner inspection MAY supply the latter with accurate provenance. Widget assertions SHALL NOT prove native pixels or separate payload protection. All contributor masking and editorial/account visibility guarantees remain mandatory.

#### Scenario: Combined selective-redaction evidence
- **WHEN** native dashboard recordings on both platforms show synthetic contributor-name redaction with adjacent date/title/city/category/status visible, widget regressions preserve public-form/editor identity masks and editorial/image/create-account boundaries, and actual Sentry Replay inspection confirms public-form and editor contributor masking
- **THEN** the combined evidence satisfies selective Replay acceptance without claiming every screen was independently recorded on each platform
- **AND** product-owner inspection is distinguished from independently reproduced test output, with no invented recording identifier or platform attribution
- **AND** separate native recordings of every screen/create-mode variant are not mandatory absent evidence of a masking defect

#### Scenario: Separate payload exposure discovered
- **WHEN** verification discovers contributor values in a distinct error, breadcrumb, URL or metadata payload
- **THEN** UI masking alone is not claimed to protect that payload and the concrete disclosure is reported for a bounded scope decision
