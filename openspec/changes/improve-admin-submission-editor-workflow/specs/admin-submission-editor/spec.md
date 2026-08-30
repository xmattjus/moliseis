## Purpose

Define the lifecycle of the admin submission editor so a new in-memory draft can become a persisted pending submission without leaving the editor, while safely staging images until persisted identity has been adopted.

## ADDED Requirements

### Requirement: Successful Save keeps the admin editor session open

A successful admin create or update Save SHALL keep the current editor session open. The editor SHALL become clean only when all unsaved field changes and staged images have been persisted, and moderation actions SHALL be reevaluated immediately under the existing persisted-status and publication-readiness rules.

#### Scenario: Existing pending submission is saved
- **GIVEN** an administrator is editing a persisted pending submission
- **AND** the editor is dirty
- **WHEN** Save completes successfully
- **THEN** the editor SHALL remain open
- **AND** the editor SHALL become clean
- **AND** Publish and Reject SHALL be evaluated immediately using the existing moderation and publication-readiness rules

#### Scenario: New submission is created without staged images
- **GIVEN** an administrator is editing a valid new submission
- **AND** no images are staged
- **WHEN** Save receives a successful create response and the live editor adopts its result
- **THEN** the editor SHALL remain open
- **AND** the same editor session SHALL thereafter represent the newly persisted pending submission
- **AND** the editor SHALL be clean
- **AND** a later Save with field changes SHALL update that persisted submission rather than create another submission

#### Scenario: Moderation readiness is reevaluated after Save
- **GIVEN** a persisted pending editor has unsaved field changes
- **WHEN** Save persists those changes successfully
- **THEN** Reject SHALL become available when no other existing guard blocks it
- **AND** Publish SHALL become available only when every existing publication-readiness rule is satisfied
- **AND** an `unknown` category SHALL continue to block Publish without blocking Reject

#### Scenario: Save reflects authoritative editable values in the mounted form
- **GIVEN** a live new or persisted pending editor submits editable values
- **AND** persistence normalizes one or more of those values, such as trimming the city or name
- **WHEN** Save receives a successful create or update response
- **THEN** the editor's mounted controls SHALL reflect the authoritative editable values returned by persistence
- **AND** applying an update response that omits loaded asset associations SHALL preserve every confirmed asset already held by the editor
- **AND** the synchronization SHALL NOT replace the editor route or require a detail reload solely to display the authoritative values

#### Scenario: Save completes while a moderation confirmation is open
- **GIVEN** a Save was already in flight
- **AND** a moderation confirmation is open when that Save completes
- **WHEN** the successful Save is observed
- **THEN** the Save SHALL NOT close the editor
- **AND** completing or dismissing the confirmation SHALL NOT cause a deferred editor exit because of that Save
- **AND** any moderation attempt SHALL still satisfy the normal moderation rules after the confirmation resolves

### Requirement: Initial create transitions the same editor session to persisted state

After a successful initial create response is received and its result is adopted by a live editor, that editor session SHALL acquire the persisted identity and authoritative state required for normal pending editing and moderation without requiring the administrator to leave and reopen the editor. A remote insert commit alone SHALL NOT be treated as local identity adoption. Once adopted, the persisted identity SHALL NOT be discarded for the remainder of that live editor session, and subsequent Saves in that session SHALL NOT invoke create again.

Exactly-once remote creation before identity adoption is outside this capability's guarantee. Under the existing backend contract, a create can commit while its successful response is lost or otherwise not observed; the editor then has no reliable way to distinguish that outcome from a request that did not commit, and a later create retry can produce another submission.

#### Scenario: Create result becomes authoritative editor state
- **GIVEN** a valid new editor session
- **WHEN** a successful initial create response is received while the editor is live
- **AND** the editor adopts that result
- **THEN** the editor SHALL acquire the newly persisted submission identity
- **AND** it SHALL reflect the authoritative pending state returned by persistence
- **AND** persisted-only editor operations SHALL become eligible under their existing rules
- **AND** the editor SHALL present itself as an existing submission without route replacement

#### Scenario: Successful create adoption prevents later create
- **GIVEN** a new editor has received a successful create response
- **AND** the live editor has adopted the returned persisted identity
- **WHEN** Save is invoked again in that editor session
- **THEN** Save SHALL reuse the existing persisted submission and update fields only when needed
- **AND** create SHALL NOT be invoked again by that editor session

#### Scenario: Create error is observed before identity adoption
- **GIVEN** a new editor session with a field draft and zero or more staged images
- **AND** no persisted identity has been adopted
- **WHEN** the client observes a create error instead of a successful response
- **THEN** the editor SHALL remain a new draft with no adopted persisted identity
- **AND** the field draft SHALL remain available for correction or retry
- **AND** every staged image SHALL remain staged
- **AND** no staged image upload or backend association SHALL start
- **AND** a later Save SHALL remain eligible to invoke create because no persisted identity is available
- **AND** this capability SHALL NOT guarantee that only one remote submission exists if the earlier request committed before its response was lost

### Requirement: Images can be staged before initial persistence

While an admin editor has no adopted persisted submission identity, the administrator SHALL be able to select images and stage them in the current editor session. Staging SHALL NOT upload the image or mutate backend asset state.

#### Scenario: Administrator selects an image in new mode
- **GIVEN** a new admin editor with remaining image capacity
- **WHEN** the administrator selects an image
- **THEN** the selected image SHALL appear as staged in the editor
- **AND** no remote image upload SHALL start
- **AND** no backend asset association SHALL be created
- **AND** the editor SHALL communicate that the image remains pending persistence

#### Scenario: Administrator removes a staged image
- **GIVEN** a new admin editor contains a staged image
- **WHEN** the administrator removes that image before persistence
- **THEN** the image SHALL be removed from staged state
- **AND** no backend asset deletion SHALL occur
- **AND** the removed image SHALL NOT be uploaded by a later Save

#### Scenario: Removing the final staged image restores clean state
- **GIVEN** staged images are the editor's only unpersisted work
- **WHEN** the administrator removes the final staged image
- **THEN** the editor SHALL become clean
- **AND** the removed capacity SHALL become available for another selection

#### Scenario: Combined image capacity reaches five
- **GIVEN** an admin editor contains persisted and/or staged images
- **WHEN** the combined image count reaches five
- **THEN** the editor SHALL prevent selecting another image
- **AND** the existing backend asset-limit enforcement SHALL remain authoritative for persisted assets

### Requirement: First Save persists staged images only after create result adoption

When a new editor has staged images, Save SHALL first receive a successful create response and adopt its persisted identity while the editor is live. Only after that adoption SHALL the editor persist staged images through the existing remote image-upload and backend asset-association behavior. Images SHALL be processed sequentially in their selection order, and a staged image SHALL leave staged state only after its backend asset association is confirmed.

#### Scenario: First Save with one staged image succeeds
- **GIVEN** a valid new editor with one staged image
- **WHEN** Save receives and adopts a successful create result and completes staged persistence
- **THEN** create-result adoption SHALL complete before image upload starts
- **AND** an adopted persisted submission identity SHALL exist before backend asset association starts
- **AND** the image SHALL be uploaded through the existing image-upload behavior
- **AND** the uploaded image SHALL be associated with the newly persisted submission through the existing asset behavior
- **AND** the resulting persisted asset SHALL appear in the editor
- **AND** the staged image SHALL be removed from staged state
- **AND** the editor SHALL be clean and remain open

#### Scenario: First Save with multiple staged images succeeds
- **GIVEN** a valid new editor with multiple staged images
- **WHEN** Save receives and adopts a successful create result
- **THEN** that Save SHALL enter staged persistence using the adopted identity
- **AND** staged images SHALL be persisted sequentially in selection order
- **AND** each successfully associated image SHALL move from staged state to persisted asset state
- **AND** Save SHALL complete only after all staged images are persisted

### Requirement: Partial staged-image failure preserves retryable progress

If a live editor adopts a successful initial create result but later staged-image persistence fails, the editor SHALL preserve the adopted persisted identity and all confirmed asset progress. Failed and not-yet-processed images SHALL remain staged for retry, any successful upload awaiting association SHALL retain the information needed to retry association without uploading the same bytes again in the current session, and moderation SHALL remain unavailable until persistence is complete.

#### Scenario: Image upload fails after successful create
- **GIVEN** a successful initial create result has been adopted
- **AND** at least one staged image remains unpersisted
- **WHEN** an image upload fails
- **THEN** the editor SHALL remain open as the persisted pending submission
- **AND** the failed image and all not-yet-persisted staged images SHALL remain staged
- **AND** already-confirmed persisted assets SHALL remain persisted in editor state
- **AND** the editor SHALL remain persistence-incomplete so moderation cannot start

#### Scenario: Backend asset association fails after upload
- **GIVEN** a successful initial create result has been adopted
- **AND** a staged image has uploaded successfully
- **WHEN** associating that image with the submission fails
- **THEN** the editor SHALL retain the persisted submission identity
- **AND** the corresponding image SHALL remain staged for retry
- **AND** the successful upload result SHALL be retained for a later association retry in the same editor session
- **AND** that retry SHALL NOT upload the same image bytes again
- **AND** a later Save SHALL NOT create another submission because the editor retains its adopted identity

#### Scenario: Asset association response is ambiguous
- **GIVEN** a staged image has a retained successful upload result
- **AND** its backend association request may have committed but no successful response was observed
- **WHEN** the administrator retries Save
- **THEN** the editor SHALL reuse the retained upload result without uploading the same image bytes again
- **AND** the editor SHALL retry the unconfirmed backend association
- **AND** this capability SHALL NOT guarantee exactly-once association because the existing backend contract has no association idempotency guarantee

#### Scenario: A later image fails after earlier images were confirmed
- **GIVEN** a successful initial create result was adopted with multiple staged images
- **AND** one or more earlier images were successfully associated
- **WHEN** a later image fails to upload or associate
- **THEN** every confirmed earlier image SHALL remain persisted and absent from staged state
- **AND** retry SHALL NOT reprocess those confirmed earlier images
- **AND** the failed image and every unstarted later image SHALL remain staged

#### Scenario: Retry after partial failure
- **GIVEN** a previous Save adopted the persisted submission identity but left staged images unpersisted
- **WHEN** the administrator invokes Save again
- **THEN** Save SHALL operate on the already-created submission
- **AND** it SHALL retry remaining staged-image persistence
- **AND** it SHALL NOT create another submission
- **AND** it SHALL NOT repeat confirmed asset associations
- **AND** successful retry SHALL clear every staged image that becomes persisted and leave the editor clean

### Requirement: Already-persisted editors retain immediate image-add behavior

Selecting a new image while editing an already-persisted pending submission SHALL continue to use the existing immediate image upload and backend association behavior. Pre-create staging SHALL NOT change normal persisted-edit image semantics.

#### Scenario: Persisted pending editor adds an image
- **GIVEN** a persisted pending submission with remaining image capacity
- **WHEN** the administrator selects a new image after the submission is already persisted
- **THEN** the image SHALL be uploaded and associated immediately according to existing behavior
- **AND** the operation SHALL continue to respect the existing pending-only, capacity, and operation-exclusion rules

#### Scenario: Final-status editor cannot mutate assets or fields
- **GIVEN** a persisted submission is accepted or rejected
- **WHEN** the administrator views it in the editor
- **THEN** its existing read-only field and asset guards SHALL remain in effect

### Requirement: Staged persistence remains route-scoped and disposal-safe

Staged images and their retry metadata SHALL exist only for the current editor route. After disposal, no create, update, upload, or association result SHALL mutate editor state, and no later staged image or association SHALL start. An already-started remote operation can still complete under its existing contract, but this capability SHALL NOT attempt compensating deletion or rollback and SHALL NOT introduce background continuation of unstarted staged work.

#### Scenario: Editor is disposed before create identity adoption
- **GIVEN** create is in flight for a new editor with zero or more staged images
- **WHEN** the editor route is disposed before a successful result is adopted
- **THEN** any later create result SHALL NOT mutate the disposed editor or be adopted into its route-scoped state
- **AND** no staged image upload or backend association SHALL start afterward
- **AND** the capability SHALL NOT require cancellation or rollback of a remote insert that already completed
- **AND** the route-scoped state SHALL NOT be required to retain an identity that was never adopted while live

#### Scenario: Editor exits during a staged image upload
- **GIVEN** Save is persisting staged work for a persisted pending submission
- **AND** a staged image upload is in progress
- **WHEN** the editor route is disposed
- **THEN** the active upload SHALL be cancelled on a best-effort basis
- **AND** no unstarted staged image SHALL begin processing after disposal
- **AND** completion callbacks SHALL NOT mutate disposed editor state or start a later asset association

#### Scenario: Editor exits while asset association is already in flight
- **GIVEN** an uploaded staged image is being associated with the backend
- **WHEN** the editor route is disposed before the association returns
- **THEN** the editor SHALL NOT attempt client-side rollback
- **AND** the eventual response SHALL NOT mutate disposed editor state

### Requirement: Dashboard refresh does not depend on Save closing the editor

The admin submissions dashboard SHALL refresh after an editor route opened from that dashboard returns, so the list reflects persistence and moderation changes performed during the session. A successful Save SHALL NOT need to close the editor solely to trigger dashboard freshness.

#### Scenario: Administrator saves and later exits the editor
- **GIVEN** the administrator opens an admin editor from the submissions dashboard
- **AND** performs a successful create or update Save while remaining in the editor
- **WHEN** the editor route later returns to the dashboard through back navigation or a moderation-success exit
- **THEN** the dashboard SHALL reload its submissions list
- **AND** the reload SHALL NOT depend on Save having closed the editor

#### Scenario: Administrator exits without mutation
- **GIVEN** the administrator opens an admin editor and makes no persisted change
- **WHEN** the editor exits
- **THEN** refreshing the dashboard SHALL remain valid behavior
- **AND** the system SHALL NOT require mutation-tracking complexity solely to suppress that refresh

#### Scenario: An older list request is in flight when the editor returns
- **GIVEN** a dashboard list request that started before the editor route returned is still in flight
- **WHEN** the editor route returns to the dashboard
- **THEN** that older request alone SHALL NOT satisfy the post-return refresh obligation
- **AND** the dashboard SHALL ensure that another list request starts after the editor has returned
- **AND** the post-return request MAY wait for the older request to settle rather than running concurrently
