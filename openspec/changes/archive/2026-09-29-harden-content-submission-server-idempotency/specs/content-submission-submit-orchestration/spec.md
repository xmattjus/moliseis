## REMOVED Requirements

### Requirement: Client identity is not idempotency
**Reason**: Subplan 5 makes the already-deployed client identity authoritative at the Edge/database boundary and therefore supersedes the temporary compatibility-only contract.

**Migration**: Replace this requirement with `Client identity is authoritative server idempotency`; keep the existing client wire field and local identity lifecycle unchanged.

## ADDED Requirements

### Requirement: Client identity is authoritative server idempotency
The deployed `submit-content` boundary SHALL require the existing canonical UUID-v4-compatible `client_submission_id`, persist it under the authenticated user's ownership, and use it to identify one logical backend submission. The first committed request SHALL own the remote payload and asset set. A later or concurrent otherwise-valid authenticated request from the same user with the same identity SHALL return the original positive `submission_id` without duplicate rows, asset associations, or quota consumption. Reuse by a different authenticated user SHALL be independent. Sending this field SHALL NOT bypass request validation, alter the existing local session identity lifecycle, or expose the backend identifier through the domain result.

#### Scenario: Submission boundary consumes client identity
- **WHEN** an otherwise valid authenticated request includes the existing canonical client identity
- **THEN** the backend validates and persists it as the ownership-scoped idempotency key

#### Scenario: Backend replay resolves duplicate submission risk
- **WHEN** the same user retries with an otherwise-valid request after the original request may have committed without delivering its response
- **THEN** the boundary returns the original positive identifier without another submission, asset set, or quota charge

#### Scenario: Existing client remains API-compatible
- **WHEN** the boundary acknowledges either first creation or replay
- **THEN** the existing repository receives a positive `submission_id` and continues returning `Result<void>` without a new domain model, Command, Provider, or ViewModel state

## MODIFIED Requirements

### Requirement: Subplan completion is not release readiness
Completion of the client orchestration capability alone SHALL continue to be identified as Content Submission Hardening Subplan 4. When the separate server-idempotency capability is implemented and verified, ambiguous final-request acknowledgement and duplicate database submission for the current authenticated client path SHALL no longer be reported as open. Completion of both capabilities SHALL still not imply Cloudinary rollback/deletion, persistent background submission, multi-draft support, guaranteed propagation of every best-effort local staged-cleanup failure, or whole-feature release proof.

#### Scenario: Subplan verification passes
- **WHEN** only the requirements of this client orchestration capability are verified
- **THEN** the result remains Subplan 4 rather than whole-feature release readiness

#### Scenario: Server idempotency closes the deferred acknowledgement gap
- **WHEN** the server-idempotency capability and its database/Edge regressions also pass
- **THEN** retry of the same authenticated client identity can recover the original committed acknowledgement without duplicate database content or quota consumption

#### Scenario: Remaining limitations stay explicit
- **WHEN** Subplan 5 is reported complete
- **THEN** unrelated Cloudinary, background-work, multi-draft, and best-effort local-cleanup limitations are not represented as solved
