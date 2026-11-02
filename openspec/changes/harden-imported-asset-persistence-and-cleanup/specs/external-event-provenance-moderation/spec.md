## MODIFIED Requirements

### Requirement: Source image import is at-most-once per submission

After ingest the Edge importer SHALL check an eligible current source image exists in the provider observation AND ingest returned an unlinked pending; only then SHALL it call the claim RPC. Without a source image it SHALL make no claim call. The service-role-only atomic RPC SHALL lock submission then external record and verify exclusively persisted state: imported provenance, pending status, record.event_id IS NULL, null prior source_asset_import_claimed_at, and zero submission assets. The RPC SHALL NOT receive or validate image_available, source image URL, or provider observation data. It SHALL atomically persist irreversible source_asset_import_claimed_at as the claim timestamp; only the claim winner SHALL use the Edge-owned URL to upload and associate the image. The claim SHALL remain after success or failure, and later observations SHALL NOT retry after upload failure or moderator removal.

For migrated legacy imported pending rows, backfill SHALL initialize a non-null claim unless audit positively verifies no prior automatic image attempt. Zero current assets SHALL NOT imply fresh eligibility. A conservative backfill claim SHALL represent migration-time consumption of the attempt budget without fabricating a historical upload time.

Existing `add_submission_assets` SHALL remain authoritative for association. A valid association response SHALL be an error-free array containing exactly one object row. A confirmed `created` response SHALL include a positive safe-integer asset ID and URL/width/height matching the upload receipt. A confirmed rejection SHALL include `id`, `url`, `width`, and `height`, all explicitly null; missing fields or populated asset fields SHALL make it indeterminate. When association returns a valid singleton, error-free `not_found`, `not_pending`, or `limit_reached` rejection, the importer SHALL attempt cleanup of the image freshly uploaded by this invocation, including when finalization wins before association. If association succeeds, or its outcome is indeterminate, the importer SHALL NOT delete the uploaded image. A failed or negative subsequent read SHALL NOT authorize deletion. Linked records SHALL never receive automatic image import, because source media updates are outside Workstream A. Current provider imagery SHALL be best-effort decoration rather than versioned moderation state.

#### Scenario: Two importer runs race for one image

- **WHEN** two runs attempt the same unclaimed imported pending concurrently
- **THEN** at most one SHALL receive the asset-import claim

#### Scenario: Linked record cannot receive an asset claim

- **GIVEN** the source record already links to an Event
- **WHEN** an atomic claim is attempted directly
- **THEN** persisted-state validation SHALL reject the claim without changing its timestamp

#### Scenario: Existing submission assets block an asset claim

- **GIVEN** an otherwise eligible imported pending already has assets
- **WHEN** an atomic claim is attempted
- **THEN** it SHALL be rejected without timestamp or asset mutation

#### Scenario: Edge observation without image does not claim

- **GIVEN** ingest returned an unlinked pending but the current observation has no eligible source image
- **WHEN** Edge orchestrates source assets
- **THEN** it SHALL call neither claim RPC nor upload

#### Scenario: Edge claims before uploading an eligible image

- **GIVEN** an eligible current source image and an unlinked pending returned by ingest
- **WHEN** Edge orchestrates the import
- **THEN** it SHALL call the persisted-state claim RPC before upload
- **AND** only its successful winner SHALL upload using the Edge-owned URL

#### Scenario: Moderator removes imported image

- **GIVEN** a source image was imported and the claim remains recorded
- **WHEN** a moderator removes the asset
- **THEN** later ingest observations SHALL NOT restore it automatically

#### Scenario: Upload fails after claim

- **WHEN** source-image upload fails after a successful claim
- **THEN** the claim SHALL remain recorded
- **AND** later observations SHALL not retry automatically

#### Scenario: Backfill preserves a legacy moderator image removal

- **GIVEN** a legacy pending had a source image imported and subsequently removed, or its prior automatic attempt history is unverifiable
- **WHEN** verified provenance is backfilled on that pending
- **THEN** its automatic image attempt budget SHALL be consumed with a non-null migration claim
- **AND** later ingest SHALL NOT restore the image even though current assets are empty

#### Scenario: Association commits but its response is lost

- **GIVEN** the claim was consumed and the newly uploaded image was associated through a committed database transaction
- **WHEN** the importer receives a network failure or cannot decode the association response
- **THEN** the importer SHALL NOT invoke Cloudinary destruction for that image
- **AND** the claim SHALL remain consumed

#### Scenario: Promotion races with lost association response

- **GIVEN** the association committed and the submission was promoted, copying the image URL to published media
- **WHEN** the importer receives an indeterminate association result
- **THEN** the uploaded image SHALL be retained without a destruction attempt

#### Scenario: Confirmed association rejection permits cleanup

- **GIVEN** this importer invocation freshly uploaded one image and issued one non-retried association request
- **WHEN** the association returns a valid singleton error-free `not_found`, `not_pending`, or `limit_reached` outcome
- **THEN** the importer SHALL attempt cleanup of this invocation's image
- **AND** the claim SHALL remain consumed

#### Scenario: Invalid or contradictory association response

- **WHEN** the association call throws, reports an error, returns no rows, multiple rows, malformed data, an unknown outcome, a rejection with missing or populated asset fields, mismatched success fields, or both data and an error
- **THEN** the importer SHALL treat association as indeterminate
- **AND** it SHALL NOT destroy the uploaded image
- **AND** it SHALL NOT retry the non-idempotent association write

#### Scenario: Reconciliation read cannot establish non-association

- **WHEN** any optional follow-up database read fails or returns no matching association
- **THEN** the importer SHALL NOT use that result as permission to delete an uploaded image whose association outcome is indeterminate

#### Scenario: Existing pending receives its first eligible image

- **GIVEN** an unlinked pending submission has no assets and no consumed claim because earlier observations had no eligible source image
- **WHEN** a later observation contains an eligible image and ingest returns the same pending with `pending_created=false`
- **THEN** the importer SHALL permit its first claim and, if it wins, one upload and one association attempt

### Requirement: Asset association races retain irreversible claims

Final asset association SHALL use existing pending-only asset RPCs and parent-row locking, and automatic import failure cleanup SHALL NOT clear or reset the source claim. Cleanup SHALL require a confirmed association rejection; indeterminate association SHALL retain the upload, and cleanup failure SHALL remain distinguishable from successful deletion.

#### Scenario: Finalization wins before asset association

- **GIVEN** a claim winner has uploaded an image and the submission ceases to be pending before association
- **WHEN** `add_submission_assets` returns a valid singleton error-free `not_pending` response with all asset payload fields explicitly null
- **THEN** the importer SHALL attempt cleanup of the uploaded image and report any unconfirmed cleanup
- **AND** its claim SHALL remain set and later observations SHALL not retry

#### Scenario: Finalization rejection response is lost

- **GIVEN** finalization wins before association and the association inserts no asset
- **WHEN** the rejection response is lost or malformed
- **THEN** the importer SHALL retain the uploaded image because rejection is not confirmed
- **AND** its claim SHALL remain set and later observations SHALL not retry

#### Scenario: Linked source never imports an update image

- **GIVEN** an external source record already links to an Event
- **WHEN** ingest observes a current provider image
- **THEN** no automatic image claim/upload SHALL occur

## ADDED Requirements

### Requirement: Imported image association diagnostics reflect outcome certainty

The importer SHALL distinguish pre-upload claim failure, upload failure, confirmed association rejection, indeterminate association, and uncertain cleanup without falsely asserting that an image is absent. Automatic moderation notes SHALL preserve previously persisted notes. Diagnostic failures SHALL NOT replace the primary import outcome or abort processing of later observations.

#### Scenario: Unknown association is not declared an image import failure

- **WHEN** the association outcome is indeterminate
- **THEN** the import report SHALL increment `assets_unknown`, without incrementing `assets_uploaded` or `assets_failed`, and identify the submission and unknown association phase
- **AND** any reviewer guidance SHALL instruct inspection of current submission assets before manual addition
- **AND** it SHALL NOT unconditionally write an image-failed note or disclose credentials, signed request fields, or raw upstream response bodies

#### Scenario: Cleanup completion is unknown

- **GIVEN** a valid confirmed association rejection allowed a cleanup attempt
- **WHEN** Cloudinary cleanup fails or its response cannot confirm destruction
- **THEN** reporting SHALL distinguish unconfirmed cleanup from confirmed deletion
- **AND** the original association rejection SHALL remain identifiable and count once in `assets_failed`, not in `assets_unknown`

#### Scenario: Existing moderation notes survive failure reporting

- **GIVEN** a pending submission already has stored internal notes
- **WHEN** the importer records a confirmed image import failure
- **THEN** those stored notes SHALL remain intact
- **AND** a concurrent note change SHALL NOT be silently overwritten
- **AND** null stored notes SHALL be handled without inventing or copying observation-derived notes

#### Scenario: Upload failure does not restart automatic import

- **GIVEN** an eligible source image was claimed for a pending submission
- **WHEN** the Cloudinary upload fails before a usable receipt is returned
- **THEN** the importer SHALL report the upload failure without attempting association or invented cleanup
- **AND** later observations SHALL NOT reclaim the image budget

#### Scenario: Failure-note persistence cannot be confirmed

- **GIVEN** a confirmed import failure and a note read or conditional update that fails, throws, matches no row, or loses its response
- **WHEN** the importer records diagnostics
- **THEN** the primary import failure SHALL remain in the report with note-write uncertainty
- **AND** the importer SHALL NOT retry the note write, assert that the note is absent, or abort later observations

#### Scenario: Counters describe attempt outcomes rather than asset inventory

- **WHEN** the importer reports asset processing
- **THEN** `assets_uploaded` SHALL count confirmed associations, `assets_failed` SHALL count failed claim/upload attempts and explicit association rejections, and `assets_unknown` SHALL count indeterminate associations
- **AND** cleanup uncertainty SHALL remain secondary to the primary rejection rather than count another failed asset
- **AND** `without_asset` SHALL retain its skipped-observation meaning without being presented as the number of submissions lacking persisted images
