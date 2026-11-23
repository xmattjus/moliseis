# Application observability delta

## ADDED Requirements

### Requirement: Handled upload and association connectivity failures preserve diagnostics without initiating exception capture

For terminal Cloudinary upload, public submission and Admin staged asset association failures, the application SHALL initiate zero Sentry exception captures for a handled cause recognized as connectivity. The existing owner SHALL preserve the business result, original available local cause and stack in Debug, and the consent- and level-eligible sanitized breadcrumb. Eligibility for other failures SHALL remain governed by their existing ownership and field policies.

#### Scenario: Terminal socket failure or exhausted upload timeout

- **GIVEN** reporting consent and an eligible logging level
- **WHEN** a Cloudinary upload ends with a socket failure or exhausts its permitted timeout attempts
- **THEN** the original terminal result and one classified terminal diagnostic remain, with zero application exception captures across attempts and request completion observers
- **AND** the approved breadcrumb carries the existing stage, category and bounded status when applicable, without asserting whether the remote asset exists.

#### Scenario: Public submission loses its acknowledgement

- **GIVEN** a public submission with its existing idempotency key
- **WHEN** the final request fails with a recognized socket, timeout or HTTP client transport exception, including one recovered from typed fetch-wrapper details
- **THEN** the repository returns the same recovered exception, the outcome remains unconfirmed and the owner initiates zero application exception captures
- **AND** consent permits the existing bounded outcome breadcrumb without initiating another request.

#### Scenario: Admin staged association loses its acknowledgement

- **GIVEN** a staged upload receipt and active reporting consent
- **WHEN** its association request encounters a handled typed connectivity failure
- **THEN** the error result retains the cause, the existing receipt recovery and exact-replay rules apply, and the owner initiates zero application exception captures
- **AND** the approved breadcrumb identifies the operation and unconfirmed outcome.

#### Scenario: A failure lacks trustworthy evidence of connectivity

- **GIVEN** active consent and an otherwise reportable terminal failure
- **WHEN** the owner receives an opaque fetch wrapper, an ordinary HTTP exception, a server rejection, a malformed acknowledgement or an unexpected exception
- **THEN** exactly one sanitized application report retains the approved technical context and causal breadcrumb
- **AND** rejected and unconfirmed outcomes continue to follow the available backend evidence. Private error text, request bodies, credentials, URLs and raw stacks stay out of the application report envelope.

#### Scenario: Consent disables application forwarding

- **GIVEN** application reporting consent is disabled
- **WHEN** an eligible local failure is logged in any of the three paths
- **THEN** Debug diagnostics retain the attached cause and available stack, and the application adds zero Sentry breadcrumbs and initiates zero exception captures for that failure.

#### Scenario: An automatic network exception reaches the SDK

- **GIVEN** an SDK-owned automatic error
- **WHEN** its cause resembles an expected connectivity failure from a handled operation
- **THEN** existing automatic Dart projection and native SDK ownership continue to apply independently, without an extra application capture or a global connectivity suppression.
