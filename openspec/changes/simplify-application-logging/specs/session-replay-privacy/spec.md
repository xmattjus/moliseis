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

#### Scenario: Editor proposed-by section
- **WHEN** edit mode renders contributor name or email in `Proposto da`, including finalized submissions
- **THEN** Replay obscures each present contributor identity field
- **AND** deliberately public editorial context remains visible while classified private/unpublished content follows its selective-protection contract

### Requirement: Native recording proves selective redaction

Selective redaction acceptance SHALL combine representative native dashboard recordings on Android/iOS, affected widget-boundary regressions and actual Sentry Replay inspection of public-form/editor masking. Owner inspection MAY supply the latter with accurate provenance. Widget assertions SHALL NOT prove native pixels or separate payload protection. Contributor and original unpublished dashboard title/city protection and deliberately public editorial/account visibility guarantees remain mandatory.

#### Scenario: Combined selective-redaction evidence
- **WHEN** native dashboard recordings on both platforms show synthetic contributor-name and original unpublished title/city redaction with adjacent date/category/status and separately proven public tourism title/city context visible, widget regressions preserve public-form/editor private-content masks and public editorial/image/create-account boundaries, and actual Sentry Replay inspection confirms public-form/editor protection
- **THEN** the combined evidence satisfies selective Replay acceptance without claiming every screen was independently recorded on each platform
- **AND** product-owner inspection is distinguished from independently reproduced test output, with no invented recording identifier or platform attribution
- **AND** separate native recordings of every screen/create-mode variant are not mandatory absent evidence of a masking defect

#### Scenario: Separate payload exposure discovered
- **WHEN** verification discovers protected contributor or unpublished values in a distinct error, breadcrumb, URL or metadata payload
- **THEN** UI masking alone is not claimed to protect that payload and the concrete disclosure is reported for a bounded scope decision
