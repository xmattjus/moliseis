# content-submission-submit-orchestration Specification

## Purpose

Define one durable, immutable, and retry-safe public Content Submission attempt from local checkpoint through asset upload, Edge acknowledgement, and successful local session retirement.

## Requirements

### Requirement: Explicit final submission contract
The public Content Submission contract SHALL name the final whole-submission operation `submit` and SHALL accept the stable client submission identity, immutable submission content, and ordered uploaded asset metadata as distinct inputs. Binary asset upload SHALL remain separately exposed as `uploadImageTask`. Final submission SHALL report success or failure without exposing the backend row identifier as a new domain result. The former final whole-submission name `upload` SHALL not be retained unless an external compatibility obligation is verified.

#### Scenario: Caller submits one logical attempt
- **WHEN** a caller invokes final submission with a client identity, immutable content, and ordered uploaded assets
- **THEN** the final Content Submission boundary uses those three inputs and reports success or failure without returning a backend row identifier

#### Scenario: Binary upload remains independently addressable
- **WHEN** a caller needs to upload one local asset to Cloudinary
- **THEN** it continues to use `uploadImageTask` without invoking or depending on final whole-submission

#### Scenario: Old final-operation name is not retained speculatively
- **WHEN** every verified production consumer is migrated to `submit`
- **THEN** the public repository exposes no final whole-submission `upload` alias

### Requirement: Public submit wire envelope
The final `submit-content` request SHALL contain exactly the top-level keys `client_submission_id`, `category`, `city`, `name`, `description`, `description_delta`, `latitude`, `longitude`, `address`, `start_date`, `end_date`, `user_email`, `user_name`, and `assets`. It SHALL carry the supplied client identity unchanged; represent nullable content values as null; serialize every non-null event instant as a UTC ISO-8601 string; preserve the existing immutable JSON-compatible description Delta structure; and preserve uploaded asset order. Each nested asset SHALL use the existing wire fields `url`, `width`, `height`, nullable `mime_type`, and nullable `duration_seconds`. Authenticated database ownership SHALL continue to be derived server-side from the request's bearer identity rather than from a client-supplied `user_id`.

#### Scenario: Complete request uses the public wire contract
- **WHEN** final submission is invoked with content, event instants, and uploaded assets
- **THEN** exactly one `submit-content` request carries every allowlisted top-level field, UTC temporal values, the unchanged description Delta, and asset metadata in supplied order

#### Scenario: Nullable values remain explicit
- **WHEN** an optional content, temporal, location, MIME, or duration value is absent
- **THEN** its corresponding allowlisted wire field is null rather than synthesized from unrelated local state

#### Scenario: Persistence and lifecycle fields are excluded
- **WHEN** the final request body is constructed
- **THEN** it contains no `user_id`, `created_at`, `modified_at`, `accepted_terms`, ObjectBox entity ID, checkpoint metadata, or other local lifecycle state

### Requirement: Submit acknowledgement and errors
Each final-submission call SHALL make exactly one `submit-content` request and SHALL report success only when the response is an object containing a positive integer `submission_id`; additional response keys SHALL be accepted. A missing, non-integer, zero, negative, or otherwise invalid identifier SHALL be reported as a response-format failure. A backend Function failure SHALL be surfaced as a public Content Submission-specific error that always preserves the HTTP status. When failure details are a map, a non-empty `code` SHALL be preserved and a non-empty `message` SHALL be used. When failure details are instead a non-empty string, that string SHALL be used as the message. Otherwise, a non-empty reason phrase SHALL be used, followed by a stable public Content Submission fallback message. Other client or transport failures SHALL be reported as errors. No failure or malformed response SHALL trigger an automatic second request.

#### Scenario: Positive acknowledgement succeeds
- **WHEN** the Edge Function responds with a positive integer `submission_id`, with or without additional metadata
- **THEN** final submission returns success without exposing the identifier through the domain result

#### Scenario: Malformed success envelope fails closed
- **WHEN** the response is not an object or its `submission_id` is missing, non-integer, zero, or negative
- **THEN** final submission reports a response-format failure and performs no hidden retry

#### Scenario: Map Function details preserve fields
- **WHEN** the Edge Function responds with an HTTP failure carrying non-empty `code` and `message` details
- **THEN** the returned public API exception preserves the HTTP status, code, and message and the failure is logged once

#### Scenario: String Function details provide the message
- **WHEN** the Edge Function responds with an HTTP failure whose details are a non-empty string rather than a map
- **THEN** the returned public API exception preserves the HTTP status and uses that string as its message

#### Scenario: Missing details use stable fallbacks
- **WHEN** Function failure details do not provide a usable message
- **THEN** final submission uses a non-empty reason phrase when available and otherwise uses the stable public Content Submission fallback message while preserving HTTP status

#### Scenario: Generic transport failure is not retried
- **WHEN** a non-Function client or transport exception occurs
- **THEN** that exception is logged and returned as an error after one invocation attempt

### Requirement: Durable submission attempt
Before any remote side effect begins, the system SHALL establish one submission attempt from an immutable capture of the current draft, its stable client identity, and ordered staged-asset membership. The exact captured draft SHALL be durably checkpointed before the first asset upload or final backend request. Remote work SHALL be authorized only after submission eligibility and durable ownership are established and that checkpoint succeeds. A snapshot already known to be durable SHALL not require a redundant save. This guarantee SHALL apply to direct submission as well as the existing UI transition, whose separate pre-submit checkpoint remains in force. Existing submission eligibility and feedback rules SHALL be preserved without adding accepted-terms, form, category, geolocation, description-length, or email-policy validation.

#### Scenario: Dirty direct submission checkpoints before the first asset
- **WHEN** a dirty valid draft with staged assets is submitted directly
- **THEN** the exact captured draft is durably saved before the first asset upload begins

#### Scenario: No-asset submission checkpoints before final request
- **WHEN** a dirty valid draft with no staged assets is submitted directly
- **THEN** the exact captured draft is durably saved before final submission is invoked

#### Scenario: Known durable snapshot avoids a redundant save
- **WHEN** the captured draft structurally equals the known durable checkpoint baseline
- **THEN** preparation succeeds without another draft save and may proceed to remote work

#### Scenario: Failed checkpoint prevents all remote work
- **WHEN** persistence of the captured submission snapshot fails
- **THEN** submission reports that error without starting an asset upload or final backend request, and the current identity and dirty-state relationship remain unchanged

#### Scenario: Unknown persisted ownership prevents submission
- **WHEN** durable draft ownership cannot be established during preparation
- **THEN** submission returns the retained persistence error without checkpointing a fresh identity or beginning remote work

### Requirement: Remote work uses captured state
Every remote operation for a submission attempt SHALL use only its captured draft, stable client identity, and ordered asset membership, even if current local state changes afterward. Asset uploads SHALL occur one at a time in captured order, successful asset metadata SHALL retain that order, and the first asset-upload failure SHALL stop the attempt before the final backend request. Later local asset changes SHALL not add or remove entries from the in-flight attempt. Remote failure handling SHALL not delete or roll back assets already uploaded to Cloudinary.

#### Scenario: Draft changes while checkpoint is pending
- **WHEN** draft A is captured and its save remains pending, live draft B replaces it, persistence of A succeeds, and the later remote attempt fails
- **THEN** remote work uses A and A's client identity while B remains current and dirty relative to durable baseline A and the failed attempt relinquishes ownership of that logical session

#### Scenario: Draft changes during Cloudinary upload
- **WHEN** an asset upload for a prepared attempt remains pending and the live form is edited
- **THEN** the final submission content is still built from the draft captured before remote work

#### Scenario: Asset membership changes during remote work
- **WHEN** the live staged-asset list changes after preparation
- **THEN** the in-flight attempt neither adds nor removes payload entries based on that later membership and processes only its captured assets in captured order, reporting the ordinary first-upload error if a captured source independently becomes unavailable

#### Scenario: First asset failure stops final submission
- **WHEN** any sequential Cloudinary upload returns an error
- **THEN** submission returns that error, sends no final request, preserves local staged sources, and retains the same client identity for retry

#### Scenario: Final request failure preserves retryable session
- **WHEN** every asset upload succeeds but final submission returns an error
- **THEN** local finalization does not begin, staged sources and live session remain available, and a later attempt uses the same client identity

### Requirement: Submission attempt owns its session
Once an exact captured session has been durably checkpointed and authorized for remote work, that submission attempt SHALL exclusively own the logical session until either an unconfirmed remote outcome releases ownership or valid acknowledgement is followed by successful local retirement. While ownership exists, an external explicit clear or discard SHALL fail before clearing persisted draft state, deleting staged-session state, rotating identity, or creating a replacement session; the same rule SHALL apply when the clear request was already waiting behind successful attempt preparation. Every returned failure, malformed acknowledgement, transport failure, or unexpected exception before valid acknowledgement SHALL release ownership while preserving the same logical session for edit, retry, or later explicit discard. Valid acknowledgement SHALL retain ownership through local finalization. Later mutations carrying the owned identity SHALL remain part of that same logical session: they SHALL survive and remain dirty if remote work fails, but SHALL be intentionally retired without cloning or transfer when the captured attempt succeeds.

#### Scenario: Clear is rejected during asset upload
- **WHEN** an external clear or discard is requested while an owned submission attempt is waiting for an asset-upload outcome
- **THEN** the request reports failure before draft clear, staged-session cleanup, identity rotation, or replacement-session creation and the owned identity remains current

#### Scenario: Clear is rejected during final request
- **WHEN** an external clear or discard is requested while an owned submission attempt is waiting for final backend acknowledgement
- **THEN** the request reports failure before draft clear, staged-session cleanup, identity rotation, or replacement-session creation and the owned identity remains current

#### Scenario: Queued clear cannot overtake claimed ownership
- **WHEN** a clear request waits behind preparation and that preparation successfully checkpoints and claims the session before releasing local arbitration
- **THEN** the clear request fails without retiring or rotating the session and remote work proceeds for the captured attempt

#### Scenario: Unconfirmed failure releases ownership
- **WHEN** an owned attempt receives an asset-upload error, final-submission error, transport failure, malformed acknowledgement, or other failure before valid acknowledgement
- **THEN** ownership is released, the same logical session and identity remain available, and a later explicit clear or discard is allowed through the normal persistence-first policy

#### Scenario: Unexpected pre-acknowledgement failure cannot strand ownership
- **WHEN** an unexpected exception interrupts an owned attempt before valid acknowledgement
- **THEN** submission reports an error and relinquishes ownership so the unchanged logical session is not permanently blocked from retry or explicit discard

#### Scenario: Late same-session mutation survives failure
- **WHEN** captured draft A owns the attempt, live draft B is created with the same client identity, and the attempt fails before valid acknowledgement
- **THEN** B remains current and dirty relative to checkpoint A, ownership is released, and no replacement identity is synthesized

#### Scenario: Late same-session mutation retires after success
- **WHEN** captured draft A owns the attempt, live draft B is created with the same client identity, and A receives valid acknowledgement followed by successful local retirement
- **THEN** A is the submitted payload, B is intentionally retired with that completed logical session, and one fresh empty session with a different identity is created without cloning B or transferring it to another session

### Requirement: Finalization-only retry after success
After valid final acknowledgement, the system SHALL record confirmed remote success and retain ownership of the acknowledged client identity before attempting persistence-first local retirement. Successful finalization SHALL verify that both the submission owner and the current logical session still match that acknowledged identity before any destructive work; an identity mismatch SHALL fail closed without draft clear, staged cleanup, replacement-session mutation, or additional identity rotation. A failed local retirement SHALL keep the completed session's identity owned and current and its finalization recoverable, and external clear or discard SHALL remain forbidden. Every later retry for that confirmed submission SHALL target only the same acknowledged session and perform only local finalization: it SHALL perform no new attempt preparation, draft checkpoint, asset upload, or final backend request. One successful finalization SHALL retire that matching session exactly once, create exactly one different valid fresh client identity, clear pending finalization, and release ownership.

#### Scenario: Local finalization failure does not resend
- **WHEN** final submission succeeds and one or more local clear attempts fail
- **THEN** exactly one final backend request has been sent, finalization remains recoverable, the acknowledged identity remains owned and current, and external clear or discard remains blocked

#### Scenario: Finalization-only retry rotates once
- **WHEN** a later finalization-only retry succeeds
- **THEN** no remote work is repeated, only the matching acknowledged persisted/staged session is retired through the existing policy, exactly one fresh identity becomes current, and submission ownership is released

#### Scenario: Final request failure does not enter finalization
- **WHEN** final submission returns an error or malformed acknowledgement
- **THEN** successful local session retirement does not start, submission ownership is released, and the same logical session remains retryable or explicitly discardable

#### Scenario: Identity mismatch fails closed
- **GIVEN** valid acknowledgement belongs to client identity A
- **WHEN** successful finalization observes that either the submission owner or current logical session no longer represents A
- **THEN** finalization reports failure before draft clear or staged cleanup, leaves the different current session untouched, performs no identity rotation, and does not mark acknowledged-session finalization complete

#### Scenario: Concurrent clear cannot cause a second rotation
- **WHEN** external clear is rejected while attempt A owns the session and A later completes remote acknowledgement and local finalization successfully
- **THEN** the acknowledged A session is retired once and exactly one fresh identity is created without an intermediate or second rotation

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
