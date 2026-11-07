## ADDED Requirements

### Requirement: Private submission and diagnostic content is selectively protected

The application SHALL wrap private contributor identity/contact and reviewed private or unpublished submission, moderation and Debug diagnostic content in the appropriate official Replay masking components. Protection SHALL follow rendered content sensitivity, including user-authored text/assets where private, while preserving authorized UI access and useful public context. Error-triggered Replay SHALL obey the same contract.

#### Scenario: Private content is entered or restored

- **GIVEN** a reviewed classification of rendered public contribution, restored draft, confirmation/error, moderation list/editor and diagnostic-view surfaces
- **WHEN** contributor contact or classified private user-authored text, location, asset or moderation details are rendered
- **THEN** the application applies official masking boundaries to the private content while authorized users can still use/read it in the application
- **AND** adjacent deliberately public titles, dates, city, category, status and images retain useful visibility

#### Scenario: Error triggers a recording

- **GIVEN** sensitive submission, moderation or local diagnostic content is visible
- **WHEN** an error triggers Replay acquisition or flush
- **THEN** the same application masking boundaries apply; buffered recording behavior remains SDK-owned and is not newly verified here
- **AND** an event beforeSend filter is not claimed to sanitize recording pixels or payloads

### Requirement: Application masking boundaries use official SDK mechanisms

Replay SHALL retain official SDK selective masking with `maskAllText = false`, `maskAllImages = false`, existing sample rates and applicable `SentryMask` and typed masking rules. Application acceptance SHALL verify classified private widget boundaries and authorized UI behavior with focused regressions. It SHALL NOT reproduce SDK masking internals or require new native recordings, pixel comparisons or server-side Replay inspection for this change.

#### Scenario: Widget boundary is verified

- **WHEN** sensitive application content is rendered in a focused widget test
- **THEN** the appropriate official masking component is its ancestor and adjacent deliberately public or approved account context remains available
- **AND** this proves application wrapping rather than native pixels, all rendering paths or actual acquisition

#### Scenario: Device acquisition has not been observed

- **WHEN** native recordings or actual Replay inspection were not executed for this change
- **THEN** that limitation is accurately disclosed under the owner-accepted scope
- **AND** event filtering and widget assertions are not described as recording sanitization or native consent evidence

## MODIFIED Requirements

### Requirement: Public content and administrator context retain Replay visibility

Replay SHALL retain useful public tourism/editorial text and images under selective privacy protection. Classified private or unpublished material SHALL be protected even when displayed by editorial controls. The authenticated administrator context in `Creato come` SHALL NOT acquire a mask merely for containing a name or email. Intentionally public administrator identity information SHALL remain visible; it SHALL NOT be conflated with a submission contributor's private contact fields.

#### Scenario: Tourism and editorial content
- **WHEN** Replay records event/place titles, descriptions, cities, dates, categories, status, images or normal editorial controls
- **THEN** deliberately public fields remain visible; classified private/unpublished input in those controls follows selective protection

#### Scenario: Create-mode account context
- **WHEN** the editor renders `Creato come` from the current administrator account
- **THEN** that display retains its existing visibility and is not treated as the original submission contributor

### Requirement: Contributor identity is selectively obscured in Replay

Replay SHALL obscure contributor name and email in the public contribution form and administrative moderation displays. Approval or staff access SHALL NOT make contributor contact data public. Original dashboard title and city SHALL also be protected unless their publication is established independently; moderation status or a promotion link alone SHALL NOT prove the original values are public. Protection SHALL leave normal screen use and authorized staff access unchanged.

#### Scenario: Public contribution form
- **WHEN** a contributor enters or restores a name or email
- **THEN** the existing identity-field masks remain in effect
- **AND** other private or unpublished input follows its separate selective-protection contract while deliberately public context retains visibility

#### Scenario: Dashboard row
- **WHEN** a moderation row renders original contributor name, title and city without independent proof that the title and city are public
- **THEN** Replay obscures those original values while retaining adjacent date, category and status
- **AND** acceptance or promotion alone does not remove these masks
- **AND** separately proven public title/city context remains visible and authorized staff can still read and select the original row normally

#### Scenario: Pending contribution match warning

- **WHEN** the editor renders `matches.pendingWarnings` containing an unpublished pending contribution title
- **THEN** the private warning text is a descendant of `SentryMask`
- **AND** its visible text, layout, interaction and backend behavior remain unchanged

#### Scenario: Editor proposed-by section
- **WHEN** edit mode renders contributor name or email in `Proposto da`, including finalized submissions
- **THEN** Replay obscures each present contributor identity field
- **AND** deliberately public editorial context remains visible while classified private/unpublished content follows its selective-protection contract

## REMOVED Requirements

### Requirement: Native recording proves selective redaction

**Reason**: The owner explicitly withdraws the mandatory Android/iOS recording and server Replay inspection campaign for this PR while retaining application responsibility for private content classification and official selective masks.

**Migration**: Use focused application widget-boundary regressions and retain existing official SDK configuration. Preserve historical provenance and disclose unverified actual-device acquisition; do not infer native pixels, buffered frames or universal rendering safety from widget tests.
