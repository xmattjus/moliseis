## ADDED Requirements

### Requirement: Private submission and diagnostic content is selectively protected

Replay SHALL protect private contributor identity/contact and reviewed private or unpublished submission, moderation and diagnostic content. Protection SHALL follow rendered content sensitivity, including user-authored text/assets where private, while preserving authorized UI access and useful public context. Error-triggered Replay SHALL obey the same contract.

#### Scenario: Private content is entered or restored

- **GIVEN** a reviewed classification of rendered public contribution, restored draft, confirmation/error, moderation list/editor and diagnostic-view surfaces
- **WHEN** contributor contact or classified private user-authored text, location, asset or moderation details are rendered
- **THEN** Replay obscures the private content while authorized users can still use/read it in the application
- **AND** adjacent deliberately public titles, dates, city, category, status and images retain useful visibility

#### Scenario: Error triggers a recording

- **GIVEN** sensitive submission, moderation or local diagnostic content is visible
- **WHEN** an error triggers Replay acquisition or flush
- **THEN** the recording applies the same selective privacy protections, including protected buffered frames
- **AND** an event beforeSend filter is not claimed to sanitize recording pixels or payloads

### Requirement: Recording acceptance covers classified private surfaces

Replay acceptance SHALL characterize actual Flutter/native rendering and verify affected private categories with bounded native recordings and attributed actual Replay inspection. Consent and opt-out SHALL govern recording acquisition. Missing runtime evidence SHALL remain explicit rather than being inferred from widget masks.

#### Scenario: Selective protection is evaluated

- **WHEN** classified private fields/assets and adjacent public controls are exercised in Android/iOS recordings and affected widget regressions
- **THEN** actual redaction, useful public visibility, authorized UI usability and error-triggered behavior are demonstrated
- **AND** keyboard/native overlays, images and platform-view limitations are identified and necessary safeguards verified
- **AND** existing combined dashboard/public-form/editor acceptance remains required, with owner-provided inspection distinguished from independently reproduced evidence

#### Scenario: Opt-out or rendering evidence is uncertain

- **WHEN** recording behavior after effective shutdown or a private rendering boundary cannot be verified
- **THEN** the missing criterion and environment/rendering limitation are recorded with explicit owner disposition before a readiness claim
- **AND** no new recording acquisition after verified shutdown is permitted; pre-revocation buffers are distinguished from new acquisition
- **AND** selective masking is retained only where it satisfies the reviewed privacy contract; an inadequate boundary requires a reviewed safeguard before acceptance

## MODIFIED Requirements

### Requirement: Public content and administrator context retain Replay visibility

Replay SHALL retain useful public tourism/editorial text and images under selective privacy protection. Classified private or unpublished material SHALL be protected even when displayed by editorial controls. The authenticated administrator context in `Creato come` SHALL NOT acquire a mask merely for containing a name or email. Intentionally public administrator identity information SHALL remain visible; it SHALL NOT be conflated with a submission contributor's private contact fields.

#### Scenario: Tourism and editorial content
- **WHEN** Replay records event/place titles, descriptions, cities, dates, categories, status, images or normal editorial controls
- **THEN** deliberately public fields remain visible; classified private/unpublished input in those controls follows selective protection

#### Scenario: Create-mode account context
- **WHEN** the editor renders `Creato come` from the current administrator account
- **THEN** that display retains its existing visibility and is not treated as the original submission contributor
