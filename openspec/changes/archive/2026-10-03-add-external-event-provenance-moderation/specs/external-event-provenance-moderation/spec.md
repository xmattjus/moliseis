## Purpose

Provide provider-generic external Event identity and provenance, deterministic source-change proposal generation, safe moderation against moderator-owned canonical Events, and auditable migration from the existing EventiMolise importer.

## ADDED Requirements

### Requirement: External event identity is stable and provider-scoped

Each imported logical Event SHALL be represented by exactly one `public.external_event_records` row identified by `UNIQUE NULLS NOT DISTINCT (provider, external_id, occurrence_key)`. `provider` SHALL match `^[a-z0-9_]+$`; `external_id` and any non-null `occurrence_key` SHALL be non-empty after trim. Semantic title/city/date similarity SHALL NOT define external identity. An adapter's occurrence-key strategy SHALL be stable; changing it for an existing provider SHALL require an explicit data migration.

Normalized/proposed/metadata values SHALL satisfy jsonb-object checks, version fields SHALL be positive, and hashes SHALL satisfy SHA-256 hexadecimal format checks. The record SHALL retain provider identity, nullable source URL, current normalized/hash/version, nullable proposed normalized/hash/version, metadata/metadata version, nullable `ignored_at`, nullable canonical `event_id`, and creation/modification timestamps. `event_id` SHALL reference `events(id) ON DELETE RESTRICT`. RLS and ACLs SHALL deny anonymous and authenticated clients direct reads and mutations of this table; privileged operations SHALL use controlled service-role-only RPCs.

#### Scenario: Two providers describe the same event

- **WHEN** EventiMolise and another provider describe the same canonical event
- **THEN** each provider obtains its own external record
- **AND** moderation MAY link both records to the same canonical Event

#### Scenario: Concurrent first observation converges

- **WHEN** two ingest invocations observe the same previously unseen strong source identity concurrently
- **THEN** one external record SHALL exist after both transactions
- **AND** at most one imported pending submission SHALL exist for it

### Requirement: Canonical normalized state and hash are deterministic

The complete moderation-relevant normalized shape SHALL be canonicalized only by one pure shared TypeScript boundary under `_shared`, reused by ingest, migration/shadow tooling, and Admin merge logic. Version 1 SHALL contain every field: `name`, `category`, `description`, `description_delta`, `city`, `latitude`, `longitude`, `all_day`, `start_date`, and `end_date`. Missing provider values SHALL use explicit canonical values, including `unknown` category and nullable descriptions/coordinates. `start_date` SHALL be non-null and satisfy the existing Event temporal contract; `end_date` MAY be null. An adapter unable to produce a valid Event start SHALL reject/quarantine that source row rather than persist a place-like source record.

`moderation_hash` SHALL equal `SHA-256(canonicalEncode(normalized))` over the entire shape. Canonicalization SHALL define NFC Unicode normalization of scalar textual fields, field-specific trimming consistent with persisted Admin validation, explicit null semantics, stable enums, deterministic field ordering, UTC timestamp strings with explicit fractional precision preserving PostgreSQL microseconds without lossy JavaScript `Date` round trips, finite coordinates encoded as canonical JSON strings with deterministic negative-zero handling, and canonical Quill operations. Quill operation order SHALL be retained, a terminal newline SHALL be required, adjacent equivalent operations SHALL remain rejected, and attribute keys SHALL use fixed order.

Scalar textual fields are normalized to NFC. When `description_delta` is present, each Quill string insert is NFC-normalized independently and normalization SHALL NOT cross operation boundaries. Operation order and attributes SHALL remain unchanged, with attribute keys emitted in the fixed canonical order. The canonical `description` SHALL be derived exactly from the concatenated canonical inserts with the required terminal newline removed. Input `description` SHALL be canonically equivalent to the Delta plain-text projection, verified by comparing both plain-text projections after global NFC normalization; arbitrary mismatches SHALL fail closed. When no Delta is present, `description` is normalized as an ordinary scalar string.

SQL SHALL NOT implement canonicalization, Unicode/Quill/timestamp/coordinate normalization, hashing, or merge diff logic. Provider-specific data SHALL reside in versioned `metadata`. Provider cancelled/postponed states MAY reside there but SHALL NOT affect normalized state, hashes, merge, or proposal generation in Workstream A.

#### Scenario: NFC composition within one Quill insert

- **WHEN** a string insert contains a decomposed character entirely within that operation
- **THEN** its canonical insert SHALL contain the NFC-composed character

#### Scenario: NFC preserves Quill formatting boundaries

- **GIVEN** a bold insert contains `e` and the following unformatted insert contains a combining acute accent and terminal newline
- **WHEN** the Delta is canonicalized
- **THEN** both operation boundaries and attributes SHALL be preserved
- **AND** canonical description SHALL exactly concatenate the canonical inserts minus the terminal newline, retaining the cross-operation decomposed sequence
- **AND** the canonical Delta and derived description SHALL pass `parseAdminContentSubmissionsRequest` and an unchanged Admin Save

#### Scenario: Canonically equivalent inputs converge

- **GIVEN** two inputs are canonically equivalent and do not differ by a semantically relevant formatting boundary
- **WHEN** both are canonicalized and hashed
- **THEN** their canonical results and hashes SHALL be identical

#### Scenario: Canonicalization is idempotent

- **WHEN** an already canonical normalized state is canonicalized again
- **THEN** its complete canonical result SHALL remain identical

#### Scenario: Canonical Delta is compatible with Admin validation

- **WHEN** canonical Delta and its exactly derived description are submitted to `parseAdminContentSubmissionsRequest`
- **THEN** description validation SHALL succeed

#### Scenario: Semantic description mismatch fails closed

- **WHEN** input description and Delta plain-text projection differ after global NFC normalization
- **THEN** canonicalization SHALL reject the input rather than replace an arbitrary mismatch

#### Scenario: Database round-trip preserves hash

- **WHEN** canonical normalized JSON is written to PostgreSQL jsonb, read back through the production data boundary, and canonicalized again
- **THEN** its SHA-256 moderation hash SHALL remain identical

#### Scenario: Admin no-op round-trip creates no moderator changes

- **WHEN** an imported pending submission is loaded and saved without semantic edits
- **THEN** canonical submission state SHALL equal its immutable external snapshot
- **AND** merge preview SHALL report no moderator-changed groups

#### Scenario: Canonical Event start is unavailable

- **WHEN** adapter output cannot produce a valid non-null Event start under the existing temporal contract
- **THEN** the row SHALL be rejected/quarantined without creating a place-like external record


### Requirement: Proposal watermark advances only after moderation

`normalized`, `normalization_version`, and `moderation_hash` SHALL represent current observed source state. `proposed_normalized`, `proposed_normalization_version`, and `proposed_hash` SHALL represent the last source state accounted for by moderation, and SHALL be all null or all non-null. Equal current/proposed hash and version SHALL mean no unhandled state; a difference SHALL mean an unhandled state exists.

Creating a pending proposal SHALL NOT advance `proposed_*`. Successful reject, link, apply, or imported promotion SHALL advance the watermark to the handled submission's immutable external snapshot and evaluate enqueue before commit. Only explicit current-source acknowledgement MAY instead advance to the current record; it SHALL require an actually stale submission and equality of `expected_source_hash` with the locked current source hash. Normal handling SHALL NOT require `expected_source_hash`.

#### Scenario: Current source changes while proposal is pending

- **GIVEN** X is pending
- **WHEN** the source advances to Y
- **THEN** the external record current state SHALL become Y
- **AND** the watermark SHALL remain at its prior state
- **AND** X SHALL remain the sole pending submission

#### Scenario: Handling stale X immediately exposes Y

- **GIVEN** X is pending and the current source is Y
- **AND** explicit current-source acknowledgement is absent
- **WHEN** X is handled
- **THEN** the watermark SHALL advance to X
- **AND** a new pending Y SHALL be created in the same transaction when normal enqueue conditions allow it

### Requirement: Imported source snapshots are immutable

`content_submissions.external_event_record_id`, `external_normalized`, `external_normalization_version`, and `external_moderation_hash` SHALL be all-null for non-imported content or all-populated for imported content. A database OLD/NEW trigger SHALL keep all populated provenance immutable after insertion, including the record identity on which reject routing depends. `external_event_record_id` SHALL reference external records with `ON DELETE RESTRICT`.

`target_event_id` SHALL reference `events(id) ON DELETE RESTRICT`, be non-null only for accepted submissions, and be mutually exclusive with `promoted_event_id`. It SHALL mean acceptance against an existing Event; `promoted_event_id` SHALL continue to mean this submission created an Event. `source_asset_import_claimed_at` SHALL be non-null only for imported submissions.

#### Scenario: Admin edits imported content

- **WHEN** an administrator edits title, description, dates, category, city, or coordinates on an imported pending submission
- **THEN** its immutable external normalized snapshot, hash, version, and external-record identity SHALL remain unchanged

### Requirement: Source proposals use one database insertion path

Every automatic imported pending SHALL be created by one private database helper, conceptually `enqueue_external_event_proposal_if_needed`, while its external record row lock is held. A partial unique index SHALL enforce at most one pending per non-null `external_event_record_id` as structural fallback. The helper SHALL mechanically project already-canonical record state without recanonicalizing or uploading media; store current normalized/hash/version as immutable submission provenance; set `client_submission_id = NULL`; and provide all required non-null contributor identity fields.

For every supported normalized-v1 fixture, TypeScript canonicalizeSubmission of the persisted enqueue-created row SHALL reproduce normalized exactly before any Admin load/Save, including microseconds, temporal mode/range, coordinate string/double round-trip, nulls, category, description/delta, city and name. This SHALL be verified separately from the Admin no-op Save regression.

The helper SHALL return without insertion for ignored records, linked soft-deleted Events, or equal current/proposed hash and version; SHALL return an existing pending if present; and otherwise SHALL insert exactly one current-state pending and return its ID.

Ingest SHALL seed a new source workflow using configured `EXTERNAL_EVENTS_IMPORTER_USER_ID`; its service-role-only RPC SHALL resolve and validate authoritative `auth.users` email/display name through a private tightly permissioned helper. Admin request bodies SHALL NOT supply importer identity. Follow-up proposals after reject/link/apply/promotion SHALL copy `user_id`, `user_email`, and `user_name` from the imported submission just handled. Changing importer configuration SHALL NOT rewrite historical identities.

#### Scenario: Follow-up proposal after rejection

- **GIVEN** an imported pending is rejected while a newer source state already exists
- **WHEN** enqueue creates the newer pending
- **THEN** it SHALL have the same required database shape as a proposal created by ingest
- **AND** its contributor identity SHALL be inherited from the handled imported submission

#### Scenario: SQL enqueue projection reproduces normalized v1 before Admin edits

- **GIVEN** each supported normalized-v1 fixture covering timestamp microseconds, all_day, start/end, canonical coordinate strings → SQL double precision → canonical strings, nulls, category, description/description_delta, city and name
- **WHEN** the private enqueue boundary creates a persisted content_submissions row and the shared TypeScript canonicalizeSubmission reads that row before any Admin load/Save
- **THEN** canonicalizeSubmission(persisted row) SHALL equal the original normalized fixture in every field
- **AND** this regression SHALL remain separate from the Admin no-op Save regression

### Requirement: Semantic dedup is advisory only

The former city/name/day heuristic SHALL NOT suppress provenance ingestion, including duplicate listing appearances within a provider. The importer SHALL issue one transactional RPC per normalized external record, with no provider-batch transaction. New/concurrent strong identities SHALL converge through `INSERT ... ON CONFLICT DO NOTHING` followed by `SELECT ... FOR UPDATE`. Ingest SHALL update current state/hash/metadata only when persisted state materially differs and SHALL always reevaluate enqueue even when source hash did not change during that call. Its response SHALL expose record ID, Event/link state, pending submission ID when present, and whether the pending was newly created.

Candidate discovery SHALL distinguish selectable canonical Event candidates from similar-pending warnings. It SHALL reuse exact active `cities.name` resolution where possible, Rome calendar-day proximity, and existing normalized text comparison without `pg_trgm`; permit manual Event lookup by name or ID; and refresh candidates at decision/preview. Advisory candidates SHALL NOT prohibit legitimate same-city/same-day Events.

#### Scenario: Second provider matches an existing source semantically

- **WHEN** a second provider supplies an event matching an existing EventiMolise submission by city, normalized name, and Rome day
- **THEN** its strong source identity SHALL still be persisted
- **AND** the semantic match SHALL be surfaced only as moderation candidate evidence

### Requirement: Existing Events may be linked without canonical mutation

After existing same-target already_resolved retry discovery, linking a pending submission, human or imported in either create/update mode, to an existing active Event SHALL require the locked persisted submission.start_date IS NOT NULL. A null start, including human Place-like or malformed/end-only legacy content, SHALL return not_event_submission with HTTP 422 NOT_EVENT_SUBMISSION and no acceptance, canonical link/content/media, watermark or enqueue mutation. The client start-or-end heuristic SHALL NOT determine backend eligibility. A valid new Event link SHALL accept the submission with `target_event_id` and authenticated `handled_by`, without changing Event fields or media. For imported records, an unlinked record SHALL acquire that Event link, the same existing link SHALL remain valid, and a different target SHALL fail as a relink conflict. Source relinking SHALL NOT occur implicitly. Imported link SHALL advance the watermark and enqueue newer current state atomically.

#### Scenario: First provider link establishes canonical target

- **GIVEN** an imported create-mode pending whose external record is unlinked
- **WHEN** the moderator links it to existing Event E
- **THEN** the submission SHALL be accepted with `target_event_id = E`
- **AND** the external record SHALL become linked to E
- **AND** E's content SHALL remain unchanged

#### Scenario: Same-target link is valid

- **GIVEN** an imported update-mode pending whose record already links to E
- **WHEN** the moderator selects link to E
- **THEN** the submission SHALL be accepted without mutating E
- **AND** the watermark SHALL advance

#### Scenario: Implicit relink is rejected

- **GIVEN** the source record links to E1
- **WHEN** a moderator requests link to E2
- **THEN** the operation SHALL fail
- **AND** the source record SHALL remain linked to E1

#### Scenario: Human Place-like submission cannot link to Event

- **GIVEN** a human pending with no Event start
- **WHEN** link to an existing Event is requested
- **THEN** resolution SHALL return `not_event_submission` with HTTP 422 `NOT_EVENT_SUBMISSION`
- **AND** the submission and Event SHALL remain unchanged

#### Scenario: End-only legacy submission cannot link to Event

- **GIVEN** a malformed legacy pending has an end but no start
- **WHEN** link to an existing Event is requested
- **THEN** backend resolution SHALL return `not_event_submission` regardless of the client Event heuristic
- **AND** no resolution, Event, watermark or enqueue mutation SHALL occur

#### Scenario: Valid human Event submission links successfully

- **GIVEN** a human pending has a valid non-null Event start and an active target Event
- **WHEN** the moderator links it
- **THEN** it SHALL become accepted with target_event_id and no promoted_event_id
- **AND** canonical Event fields and media SHALL remain unchanged

### Requirement: Imported Admin editing preserves Event identity

Admin update/Save SHALL inspect authoritative persisted provenance and reject an incoming persisted state with `start_date IS NULL` when `external_event_record_id IS NOT NULL`, returning domain `start_date_required` as HTTP 422 `START_DATE_REQUIRED` without content or resolution changes. Existing pending-only write guards and shared temporal validation SHALL remain in force. Human Place suggestions MAY still have both dates null. The UI SHALL prevent disabling Event mode for imported submissions, but backend validation SHALL remain authoritative for legacy/forged clients. No new content-type column or enum SHALL be introduced. Imported Place promotion SHALL continue to fail through existing `place_has_event_dates` readiness.

#### Scenario: Imported pending cannot lose Event mode through Save

- **GIVEN** an imported pending with a valid persisted start
- **WHEN** Admin update/Save attempts to remove Event mode and sends null start/end
- **THEN** the backend SHALL reject with `start_date_required` and HTTP 422 `START_DATE_REQUIRED`
- **AND** the prior submission state SHALL remain unchanged even if UI controls are bypassed

### Requirement: Apply uses a known source base and semantic groups

Apply SHALL be available only for pending imported updates whose record links to the requested active Event, with a non-null proposed source base, compatible proposed/submission normalization versions, and matching preview tokens. Human Event-like submissions and first-time provider links SHALL be link-only; incompatible versions SHALL return `normalization_mismatch`. For every new apply, the moderated persisted schedule SHALL satisfy the existing Event temporal contract, including non-null start, even when schedule is not in groups_to_apply. Null start SHALL return start_date_required (HTTP 422 START_DATE_REQUIRED); inverted chronology SHALL return invalid_date_range (HTTP 422 INVALID_DATE_RANGE). Edge SHALL validate temporal readiness before pending-only canonicalization/merge; SQL SHALL revalidate start/chronology under lock before any group mutation without duplicating canonicalization. Existing already_resolved retry discovery SHALL retain precedence. Invalid apply SHALL mutate no Event group/media, submission resolution, watermark, or enqueue state.

The closed semantic groups SHALL be `name: [name]`, `category: [category]`, `description: [description, description_delta]`, `schedule: [start_date, end_date, all_day]`, and `location: [city, latitude, longitude]`. For each group G, `base = record.proposed_normalized.G`, `source = submission.external_normalized.G`, `moderated = canonicalize(persisted submission).G`, and `event = canonicalize(current Event).G`. The authoritative TypeScript calculation SHALL use:

```text
providerChanged(G) = source != base
moderatorChanged(G) = moderated != source
apply(G) = providerChanged(G) OR moderatorChanged(G)
overwrite(G) = apply(G) AND event != base AND event != moderated
```

The Edge Function SHALL compute `groups_to_apply` from authoritative reads using the shared canonicalizer; Flutter SHALL NOT authoritatively choose groups. SQL SHALL reject unknown or duplicate groups, recheck preconditions/tokens, and copy every requested complete group from persisted moderated submission state without recalculating merge semantics. Unchanged placeholder source groups SHALL be presented as not applied rather than requiring completion. Exact active city resolution SHALL follow promotion semantics and return `city_not_found` atomically on failure; description/schedule/location SHALL never be partially written. Existing Event temporal and synchronization invariants SHALL remain in force, and apply SHALL NOT modify media.

#### Scenario: First provider observation cannot apply

- **GIVEN** an imported submission whose source record has no proposed normalized base
- **WHEN** the moderator evaluates it against an existing Event
- **THEN** link MAY be offered
- **AND** apply SHALL NOT be offered or accepted

#### Scenario: Schedule changes atomically

- **WHEN** schedule is one group selected for apply
- **THEN** start date, end date, and all-day mode SHALL be copied together
- **AND** no mixed old/new schedule tuple SHALL be produced

#### Scenario: Location city cannot diverge from coordinates

- **WHEN** location is selected for apply
- **THEN** city and coordinate pair SHALL be processed as one group
- **AND** unresolved active city mapping SHALL fail the entire location apply

#### Scenario: Imported update with invalid schedule cannot apply

- **GIVEN** an imported update whose moderated persisted schedule has null start or inverted chronology
- **WHEN** a new apply is requested, including when schedule is absent from the requested groups
- **THEN** it SHALL fail with `start_date_required` or `invalid_date_range` respectively
- **AND** no Event group, resolution, watermark, media or enqueue mutation SHALL occur

### Requirement: Preview warns before overwriting canonical editorial state

Merge preview SHALL mark every `overwrite(G)` under the normative merge equations, including moderator-only edits. The UI SHALL support explicit “Mantieni valore attuale” by copying the complete current Event group into the editable submission and saving through the normal Admin update path; the next preview SHALL recompute from persisted state. No separate per-field patch model or merge-choice table SHALL be introduced.

#### Scenario: Moderator edit would replace canonical description

- **GIVEN** canonical Event description already differs from the source base
- **AND** the pending submission has a moderator change in description
- **WHEN** preview is calculated
- **THEN** description SHALL be marked as overwrite even when the provider itself did not change that group

### Requirement: Apply uses preview concurrency tokens

Preview SHALL return raw database strings `submission_version_token` and `event_version_token`. Flutter SHALL retain and send exactly those strings without DateTime parsing, ISO rewriting, timezone conversion, or precision truncation. The apply RPC SHALL compare the locked row timestamps with these preview tokens using exact equality only; tokens SHALL NOT be interpreted as ordered business versions. The Edge MAY reread state to recompute groups but SHALL NOT substitute newer tokens. Token failures SHALL return `submission_changed` or `event_changed` without writes. `handled_by` SHALL originate only from the authenticated Admin JWT verified by the Edge and SHALL NOT be accepted from request bodies.

#### Scenario: Event changes after preview

- **WHEN** another writer modifies the Event after preview but before apply
- **THEN** apply SHALL fail with `event_changed`
- **AND** no requested group SHALL be written

#### Scenario: Submission changes after preview

- **WHEN** the pending submission changes after preview but before apply
- **THEN** apply SHALL fail with `submission_changed`
- **AND** no Event content SHALL be written

### Requirement: Every merge-content write invalidates the submission token

A database trigger SHALL cover real semantic changes to `name`, `category`, `description`, `description_delta`, `start_date`, `end_date`, `all_day`, `city`, `latitude`, and `longitude`, regardless of writer. It SHALL set the new `modified_at` to a value equivalent to `greatest(clock_timestamp(), OLD.modified_at + interval '1 microsecond')`, using wall-clock time and guaranteeing a token distinct from OLD even for repeated updates in one transaction. Admin field saves SHALL NOT be the sole token owner. Existing status/finalization writes MAY retain explicit timestamp behavior. Exact equality SHALL remain the only concurrency interpretation.

#### Scenario: Direct SQL writer changes a merge group

- **WHEN** a merge-content column is updated without using the Admin Edge Function
- **THEN** `content_submissions.modified_at` SHALL change
- **AND** an earlier preview token SHALL no longer match

#### Scenario: Repeated semantic writes produce distinct equality tokens

- **WHEN** merge content is changed twice in one database transaction, including calls observing the same clock precision
- **THEN** each trigger-generated submission token SHALL differ from its prior value by at least one microsecond
- **AND** earlier preview tokens SHALL fail exact equality validation


### Requirement: Reject discards one complete source revision

Rejecting an imported update SHALL mark that entire external revision as reviewed and rejected.

#### Scenario: Rejected Y remains the next comparison base

- **GIVEN** X was previously accepted
- **AND** Y is rejected
- **WHEN** source state Z later arrives
- **THEN** provider changes SHALL be evaluated from Y to Z
- **AND** unchanged changes introduced in Y SHALL not be independently re-proposed

### Requirement: Ignore suppresses proposals until explicitly reversed

Imported Reject UI and handler SHALL expose the optional ignore_source flag and explain that rejecting a revision marks that complete source revision examined/discarded: its still-present changes SHALL not be independently re-proposed until the provider changes the corresponding group again. Selecting ignore SHALL additionally explain that future revisions of the record are suppressed until explicitly un-ignored. Request bodies SHALL NOT control handled_by. Imported rejection MAY atomically ignore the record; it SHALL reject the submission, set `ignored_at`, advance the watermark, and evaluate enqueue in that order. Un-ignore SHALL lock the record, clear ignore, resolve inherited technical identity from prior submissions ordered by `handled_at DESC NULLS LAST, id DESC`, and immediately reevaluate enqueue. Without a usable imported identity, un-ignore SHALL fail rather than manufacture one, with no partial state change.

The existing Admin dashboard SHALL expose a minimal “Fonti ignorate” filter/list independently of pending submissions. Authenticated Admin Edge operation listIgnoredSources SHALL return ignored record ID, provider/external identity, normalized source name, ignored_at and optional Event ID. Each row SHALL offer “Riattiva fonte”, routed by the Flutter repository and dashboard ViewModel Command to explicit Admin Edge operation unIgnoreSource with external_event_record_id. The Edge SHALL verify Admin identity, reject caller-supplied handled_by, call authoritative set_source_ignored(false), and expose its outcome plus resulting/existing pending ID when present. UI SHALL show success/failure, refresh ignored and pending lists, and offer the returned pending when present. No general source-management subsystem SHALL be introduced.

#### Scenario: Reject and ignore does not recreate pending

- **WHEN** an imported pending is rejected with source-ignore enabled
- **THEN** `ignored_at` SHALL be written before enqueue evaluation
- **AND** no replacement pending SHALL be created

#### Scenario: Un-ignore immediately resumes outstanding proposal

- **GIVEN** an ignored source has current state different from its watermark
- **WHEN** ignore is cleared
- **THEN** enqueue SHALL run immediately
- **AND** no additional provider observation SHALL be required

#### Scenario: Ignored source is reachable without a pending

- **GIVEN** an ignored record has no pending submission
- **WHEN** Admin selects “Fonti ignorate” and chooses “Riattiva fonte” on that row
- **THEN** the explicit unIgnoreSource Edge path SHALL invoke the authoritative RPC without direct client table access
- **AND** success SHALL refresh the ignored/pending lists and expose any returned proposal; failure SHALL show the RPC error without changing ignore or watermark state

#### Scenario: Reject explains revision-level and source-ignore effects

- **WHEN** Admin rejects an imported pending
- **THEN** the UI SHALL explain revision-level discard and offer ignore_source
- **AND** selecting it SHALL explain suppression until un-ignore and transmit the option through the repository/handler without a caller-controlled handled_by

### Requirement: Imported submissions do not emit contributor status email

The database status trigger SHALL suppress webhook enqueue whenever `external_event_record_id IS NOT NULL`. `notify-submission-status` SHALL also skip structurally external submissions, including manual retries, and retain the configured importer-UUID check as defense in depth for legacy/pre-backfill rows. This structural filter SHALL deploy in the schema/notification-compatibility stage before backfill/cut-over.

#### Scenario: Imported proposal is accepted or rejected

- **WHEN** an imported pending transitions to accepted or rejected
- **THEN** the status webhook SHALL not be enqueued for that transition

### Requirement: Human Event link retains accepted notification behavior

A human Event-like pending accepted through link with target_event_id and no promoted_event_id SHALL retain ordinary status notification and a valid accepted-email payload using user_name, user_email, name, city and status. The notification workflow SHALL NOT require promoted IDs for this path. The existing template SHALL remain unchanged unless implementation-time evidence demonstrates a real regression. Structurally imported submissions SHALL remain suppressed, with the legacy importer-UUID check as defense in depth.

#### Scenario: Human Event link produces ordinary accepted email

- **GIVEN** a human pending Event submission with valid contributor and content data
- **WHEN** link to an existing Event sets accepted status and the ordinary notification workflow processes it
- **THEN** it SHALL produce the normal valid accepted-email payload for that user's email/name and submission name/city despite null promoted_event_id
- **AND** canonical Event fields/media SHALL remain unchanged

### Requirement: Source image import is at-most-once per submission

After ingest the Edge importer SHALL check an eligible current source image exists in the provider observation AND ingest returned an unlinked pending; only then SHALL it call the claim RPC. Without a source image it SHALL make no claim call. The service-role-only atomic RPC SHALL lock submission then external record and verify exclusively persisted state: imported provenance, pending status, record.event_id IS NULL, null prior source_asset_import_claimed_at, and zero submission assets. The RPC SHALL NOT receive or validate image_available, source image URL, or provider observation data. It SHALL atomically persist irreversible source_asset_import_claimed_at as the claim timestamp; only the claim winner SHALL use the Edge-owned URL to upload and associate the image. The claim SHALL remain after success or failure, and later observations SHALL NOT retry after upload failure or moderator removal.

For migrated legacy imported pending rows, backfill SHALL initialize a non-null claim unless audit positively verifies no prior automatic image attempt. Zero current assets SHALL NOT imply fresh eligibility. A conservative backfill claim SHALL represent migration-time consumption of the attempt budget without fabricating a historical upload time.

Existing `add_submission_assets` SHALL remain authoritative for association. If finalization wins before association, the uploaded asset SHALL be cleaned up through existing Cloudinary cleanup behavior. Linked records SHALL never receive automatic image import, because source media updates are outside Workstream A. Current provider imagery SHALL be best-effort decoration rather than versioned moderation state.

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

### Requirement: EventiMolise cut-over is evidence-gated

Existing EventiMolise history SHALL migrate only after identity audit of known importer notes for source IDs/URLs, parse-failure and strong-identity duplicate reports, write-free shadow normalization through the production adapter/canonicalizer, explicit historical snapshot/mismatch classification, and remediation. Ambiguous pending histories and duplicate identities mapping to different Events SHALL be resolved before cut-over. Verified backfill SHALL create/link records, populate verified immutable provenance and install final staged constraints/indexes. Provenance cut-over SHALL then retire the legacy writer/semantic dedup, followed by new ingest activation in the normative rollout order. Cut-over SHALL require zero ambiguous legacy pending rows, zero unresolved strong-identity conflicts, and zero unexplained shadow mismatches; a mismatch-rate threshold SHALL NOT substitute for these gates.

#### Scenario: Ambiguous pending blocks cut-over

- **WHEN** a legacy EventiMolise pending cannot be assigned a verified immutable source snapshot
- **THEN** production cut-over SHALL remain blocked until it is handled or remediated

### Requirement: Normalization versions are migrated explicitly

A new normalization version SHALL never become active through ordinary ingest alone. When derivable from old state, an explicit migration SHALL convert current normalized state, proposed normalized state, and pending immutable snapshots and recompute hashes while retaining pending/watermark semantics. When refetch is required, an explicit baseline migration MAY set both new current and proposed only if old current equaled old proposed. Existing divergence SHALL NOT be erased; an unconvertible proposed base SHALL become a migration conflict requiring remediation. Workstream B SHALL follow this procedure before lifecycle status enters normalized state.

#### Scenario: New version requires a newly fetched field

- **WHEN** normalization v2 needs source data not retained by v1
- **THEN** rollout SHALL perform explicit provider refetch/baseline migration
- **AND** unresolved current-versus-proposed divergence SHALL not be silently erased

### Requirement: Imported resolution columns are owned by authorized RPCs

For every runtime UPDATE with `OLD.external_event_record_id IS NOT NULL`, any change to `status`, `target_event_id`, `promoted_event_id`, or `promoted_place_id` SHALL require transaction-local resolution context. Authorized external reject, link, apply, and promotion RPCs SHALL establish `set_config('app.external_resolution', 'on', true)` before controlled mutation. All other runtime paths SHALL fail such mutations, including all status changes in either direction. The GUC SHALL be documented/tested as a consistency guard against accidental unsupported writers, not authorization against malicious arbitrary SQL by service role or database administrators; authorization SHALL remain in service-role grants, Admin JWT validation, RLS/ACLs, and controlled boundaries.

Current `changeStatus` SHALL remain rejection-only. Released imported rejection requests SHALL route server-side to the external reject RPC using immutable provenance identity; human rejection SHALL retain its existing path. The unlocked routing read SHALL be followed by authoritative RPC locking/revalidation. No generic accepted-status compatibility path or reopen operation SHALL be introduced. Any future generic status API attempting imported finalization/reopening SHALL return a stable domain conflict such as `external_requires_resolution`, not a leaked trigger exception as HTTP 500.

#### Scenario: Imported rows cannot be reopened generically

- **GIVEN** an imported accepted or rejected submission
- **WHEN** a normal writer attempts to change its status back to pending
- **THEN** the resolution guard SHALL reject the update
- **AND** no partial-UNIQUE collision or new pending state SHALL occur

#### Scenario: Imported resolution links cannot be edited directly

- **WHEN** a writer changes `target_event_id`, `promoted_event_id`, or `promoted_place_id` on an imported row outside an authorized resolution RPC
- **THEN** the database SHALL reject the update

#### Scenario: Imported finalization requires resolution context

- **WHEN** a normal writer changes an imported pending status to accepted or rejected without authorized resolution context
- **THEN** the database SHALL reject the update
- **AND** released Admin rejection SHALL instead use the transactional external reject path

### Requirement: Resolution retries precede pending-only merge calculation

For link/apply against Event E, the Edge SHALL first read sufficient authoritative resolution state to recognize `status = accepted AND target_event_id = E`. Such a retry SHALL invoke idempotent RPC mode or return its authoritative `already_resolved` representation before pending-only merge calculation; SQL SHALL remain final authority. Apply retries SHALL NOT canonicalize/merge again, validate old preview tokens, write Event fields, advance watermarks, or enqueue twice. A different target SHALL remain a conflict.

#### Scenario: Lost apply response reaches authoritative already resolved

- **GIVEN** apply to E committed but its HTTP response was lost
- **WHEN** the same request is retried with its original preview tokens
- **THEN** the Edge SHALL reach `already_resolved` before pending-only merge
- **AND** the RPC SHALL make no additional Event, watermark, or enqueue writes

#### Scenario: Lost link response reaches authoritative already resolved

- **GIVEN** link to E committed but its HTTP response was lost
- **WHEN** the same link is retried
- **THEN** the Edge SHALL reach authoritative `already_resolved` before pending-only merge
- **AND** it SHALL NOT enqueue twice or advance the watermark again

### Requirement: Moderation operations preserve global lock order

Operations owning submission, external record, and Event SHALL lock `content_submissions → external_event_records → events`. Ingest and un-ignore SHALL lock the external record without acquiring ownership of an existing submission. Every automatic pending INSERT SHALL hold the record lock; asset claims SHALL preserve submission-before-record relative order. Representative ingest/resolve/promotion/asset overlaps SHALL avoid duplicate pending and resolve/promotion deadlocks.

#### Scenario: Concurrent ingest and handling preserve one pending

- **WHEN** ingest overlaps rejection, link, apply, or promotion of an imported pending
- **THEN** row locking and the partial unique index SHALL preserve at most one pending for its external record
- **AND** the established lock order SHALL avoid representative promotion/resolve deadlocks

### Requirement: Special current-source acknowledgement is explicitly guarded

Imported detail/preview SHALL expose the pending external_moderation_hash, current moderation_hash and current source snapshot shown to the moderator. The editor SHALL mark the pending stale exactly when these hashes differ and SHALL offer “Considera valutata anche la versione corrente della fonte” only in that state. An explicit selection SHALL travel through Flutter repository and editor ViewModel to the authenticated Edge resolution handler as acknowledge_current_source=true and expected_source_hash exactly matching the displayed current source state; Edge SHALL pass that hash unchanged and derive handled_by from Admin JWT only. The selection SHALL advance proposed to current only when the handled submission is actually stale and the supplied `expected_source_hash` equals the locked current source hash. Without this selection, handling SHALL use the immutable handled snapshot and SHALL require no source-hash token. Non-stale acknowledgement and missing/mismatching expected_source_hash SHALL return source_changed (HTTP 409 SOURCE_CHANGED) without resolution, watermark or enqueue mutation. The UI SHALL reload/review current source state after source_changed and require explicit renewed selection; on success it SHALL show the outcome and reload resolved/follow-up pending state. Existing already_resolved retry precedence SHALL remain unchanged.

#### Scenario: Current-source acknowledgement consumes the observed newer revision

- **GIVEN** X is pending, Y is current, and the moderator explicitly acknowledges Y with matching `expected_source_hash`
- **WHEN** X is handled under the source record lock
- **THEN** proposed SHALL advance to Y
- **AND** enqueue SHALL observe no unhandled Y

#### Scenario: Invalid current-source acknowledgement fails

- **WHEN** the special acknowledgement is requested for a non-stale submission or a source hash that no longer matches
- **THEN** resolution SHALL return `source_changed` without advancing the watermark or persisting resolution

#### Scenario: Stale acknowledgement reaches resolution with the shown hash

- **GIVEN** detail/preview shows stale pending X and current source Y
- **WHEN** Admin reviews Y, selects the acknowledgement, and handles X through reject/link/apply/promotion
- **THEN** repository/ViewModel/Edge SHALL preserve Y's shown hash as expected_source_hash
- **AND** matching locked state SHALL advance proposed to Y and display the successful resolution outcome

#### Scenario: Source changes after the moderator observes it

- **GIVEN** Admin selected acknowledgement for displayed current hash Y
- **WHEN** source advances before the resolution RPC locks the record
- **THEN** it SHALL return source_changed as HTTP 409 SOURCE_CHANGED without resolution/watermark/enqueue changes
- **AND** the UI SHALL reload current state before renewed explicit acknowledgement

#### Scenario: Non-stale pending has no acknowledgement action

- **GIVEN** pending external_moderation_hash equals current moderation_hash
- **WHEN** Admin renders the editor or a client submits acknowledgement anyway
- **THEN** UI SHALL offer no acknowledgement action and backend SHALL reject the forged option with source_changed without mutation

### Requirement: External Admin mode follows current record linkage

Imported Admin list/detail SHALL expose `create` when the record is unlinked and `update` when linked. Create SHALL support normal Event promotion or link; update SHALL support same-target link or apply. Additional response keys SHALL remain compatible with existing tolerant parsing. Legacy update promotion SHALL map SQL `source_already_linked` to HTTP 409 code `PROMOTION_SOURCE_ALREADY_LINKED` through the existing `FunctionException → AdminContentSubmissionApiException` boundary with preserved backend status/code/message; the current UI SHALL provide actionable copy. Existing Result, Command, Provider/ChangeNotifier, and repository boundaries SHALL remain in use.

#### Scenario: Linked-source mode prevents duplicate publication

- **GIVEN** a pending source record already links to E
- **WHEN** Admin loads list/detail or a legacy client attempts promotion
- **THEN** current clients SHALL see update mode
- **AND** legacy promotion SHALL return HTTP 409 `PROMOTION_SOURCE_ALREADY_LINKED` for SQL `source_already_linked`, not a success payload

### Requirement: Soft-deleted linked Events suppress source proposals

When a record links to an Event with non-null `deleted_at`, ingest MAY update current source state and metadata but enqueue SHALL create no pending and SHALL NOT advance proposed. No Event restore workflow, RPC, trigger, UI, or current restore test SHALL be introduced. Any future supported operation restoring a soft-deleted Event SHALL reevaluate enqueue for every linked source record whose current differs from its watermark.

#### Scenario: Source changes while canonical target is soft deleted

- **GIVEN** an external record links to a soft-deleted Event
- **WHEN** ingest observes a new source revision
- **THEN** current state MAY advance
- **AND** no new pending SHALL be created and proposed SHALL remain unchanged

### Requirement: Migration classification completely explains watermark state

Every created migration record SHALL have an explicit classification explaining its initial watermark; difficulty reconstructing history SHALL NOT justify null proposed. The migration SHALL use these classes:

- `verified_handled`: current SHALL use observable shadow state, and proposed SHALL use the verified last handled immutable source snapshot; normal divergence semantics SHALL apply.
- `editorial_baseline`: for unverifiable accepted history with trustworthy identity/current shadow and explicitly classified editorial-only mismatch, the historical submission SHALL remain structurally legacy/unlinked; record Event linkage SHALL use its unambiguous historical `promoted_event_id`; current and proposed SHALL both use shadow current as the one-time editorial baseline.
- `remediated_real_drift`: unverifiable accepted history with genuine provider change SHALL be a blocking migration conflict until explicit reconciliation establishes a trustworthy current baseline and authorizes `proposed := current`. It SHALL NOT default to null proposed or link-only acknowledgement.
- `rejected_baseline` or `ignored_baseline`: unverifiable rejected observable history SHALL use shadow current for both current and proposed. Only explicit operator classification as permanent suppression SHALL additionally set `ignored_at` for `ignored_baseline`; future source changes MAY generate proposals otherwise.
- `verified_no_longer_observable`: if a verified handled snapshot exists, current and proposed SHALL both use it; without any verified source snapshot, no record SHALL be created and historical submission SHALL remain legacy.
- `verified_unhandled`: null proposed SHALL be permitted only with explicit evidence that no source revision has ever been handled, such as a verified legacy pending representing current unhandled state. Every migrated null-proposed record SHALL carry this classification; accepted/rejected unverifiable history SHALL NOT qualify by missing evidence.

A newer pending SHALL retain its own verified immutable snapshot without advancing proposed. Historical accepted promotions SHALL establish record Event linkage only when unambiguous.

#### Scenario: Real source drift with unverifiable accepted history blocks migration

- **GIVEN** an accepted historical source revision has no trustworthy immutable source snapshot
- **AND** shadow comparison demonstrates a genuine provider change relative to the canonical Event
- **WHEN** migration classification runs
- **THEN** that record SHALL be a migration conflict
- **AND** cut-over SHALL remain blocked until explicit remediation establishes a trustworthy baseline

#### Scenario: Rejected unverifiable history is not re-proposed at cut-over

- **GIVEN** a historical rejected external Event has no trustworthy original source snapshot and remains observable
- **WHEN** it is migrated
- **THEN** current and proposed SHALL both use the explicitly classified shadow baseline
- **AND** proposed SHALL NOT be null
- **AND** ignore MAY be established only through explicit migration classification

#### Scenario: Editorial mismatch receives a one-time baseline

- **GIVEN** accepted history is unverifiable but strong identity and shadow current are trustworthy
- **AND** its difference is explicitly classified as moderator/editorial transformation
- **WHEN** migration establishes the unambiguous historical Event link
- **THEN** current and proposed SHALL both use shadow current
- **AND** the unverifiable historical submission SHALL remain structurally legacy and unlinked

#### Scenario: Missing source without verified snapshot stays legacy

- **GIVEN** a historical source is no longer observable and has no verified source snapshot
- **WHEN** backfill classification runs
- **THEN** no external record SHALL be created
- **AND** its historical submission SHALL remain legacy

#### Scenario: Null watermark requires verified never-handled classification

- **WHEN** a migrated record has null proposed
- **THEN** cut-over SHALL require explicit verified-unhandled evidence
- **AND** unverifiable accepted/rejected history SHALL NOT pass that gate

### Requirement: Rollout provides complete Admin moderation before provenance cut-over

Deployment SHALL proceed in this order: (1) additive schema, DB guards and notification compatibility; (2) compatible Admin Edge/backend; (3) updated Admin Flutter client; (4) legacy EventiMolise freeze, quiescence and T0; (5) identity audit/shadow/classification/remediation; (6) verified backfill and final gates; (7) provenance cut-over and permanent legacy-writer retirement; (8) provenance-aware EventiMolise importer activation. The updated client with normal update-mode Link/Apply and ignore/stale paths SHALL be available before any external update-mode pending can appear in production, including via backfill. Legacy Promote conflict handling protects integrity but SHALL NOT substitute for rollout readiness. Existing same-Rome-date and irreversible legacy retirement constraints SHALL remain authoritative.

#### Scenario: Updated Admin client is unavailable before backfill

- **WHEN** rollout readiness is checked and the updated client is not yet available for ordinary external update moderation
- **THEN** legacy freeze/backfill/cut-over and new ingest activation SHALL not proceed
- **AND** serving PROMOTION_SOURCE_ALREADY_LINKED to legacy clients SHALL not satisfy the readiness gate

### Requirement: EventiMolise freeze and legacy retirement have explicit boundaries

The runbook SHALL disable `import-external-events-eventimolise`, prevent new manual legacy invocations, drain queued/in-flight legacy requests, verify writer quiescence before recording T0, complete audit/shadow/backfill/gates, and activate provenance-aware ingest within one Europe/Rome calendar date. Because discovery includes only starts on/after the current Rome date, an audit SHALL NOT cross Rome midnight and remain considered complete. If completion is unsafe before midnight and provenance cut-over has not occurred, the attempt SHALL be abandoned, its snapshot discarded, and a fresh T0 SHALL be required; the unchanged legacy writer MAY be restored only before cut-over.

Provenance cut-over SHALL be the explicit point of no return: the legacy city/name/day writer SHALL never again be scheduled. Post-cut-over rollback SHALL stop new ingest while retaining additive schema and migrated provenance; it SHALL NOT restore legacy ingestion.

#### Scenario: Freeze cannot safely finish within the Rome date

- **GIVEN** provenance cut-over has not happened and completion before the next Rome midnight is unsafe
- **WHEN** the operator aborts the attempt
- **THEN** the audit snapshot SHALL be discarded and a future attempt SHALL use fresh T0
- **AND** unchanged legacy ingestion MAY be restored only before provenance cut-over

#### Scenario: Post-cut-over rollback cannot resume legacy ingestion

- **GIVEN** provenance cut-over has occurred
- **WHEN** rollback is required
- **THEN** provenance-aware ingest SHALL stop while schema and migrated provenance remain
- **AND** the legacy writer SHALL never be scheduled again

#### Scenario: Queued or manual legacy requests prevent a false freeze

- **GIVEN** scheduling is disabled but a legacy request is queued/in flight or manual invocation remains possible
- **WHEN** freeze readiness is checked
- **THEN** T0 SHALL not be recorded and audit SHALL not start until legacy requests are drained and new manual legacy writes are prevented
- **AND** quiescence SHALL be preserved through cut-over so late unprovenanced rows cannot escape the audit

### Requirement: Asset association races retain irreversible claims

Final asset association SHALL use existing pending-only asset RPCs and parent-row locking, and automatic import failure cleanup SHALL NOT clear or reset the source claim.

#### Scenario: Finalization wins before asset association

- **GIVEN** a claim winner has uploaded an image
- **WHEN** the submission ceases to be pending before `add_submission_assets` associates it
- **THEN** association SHALL fail and existing Cloudinary cleanup SHALL remove the uploaded image
- **AND** its claim SHALL remain set and later observations SHALL not retry

#### Scenario: Linked source never imports an update image

- **GIVEN** an external source record already links to an Event
- **WHEN** ingest observes a current provider image
- **THEN** no automatic image claim/upload SHALL occur

### Requirement: Technical identity and client closure remain enforced

Ingest, asset-claim, and resolution RPCs SHALL be service-role-only; private enqueue and authoritative auth-user lookup helpers SHALL be tightly permissioned and inaccessible to direct client execution. Admin identity SHALL come from verified JWTs, never request-provided actor IDs. Un-ignore SHALL preserve historical imported identity selection rather than use newly configured identity.

#### Scenario: Un-ignore has no usable historical identity

- **GIVEN** an ignored record has no usable prior imported submission identity
- **WHEN** un-ignore requests immediate enqueue
- **THEN** the operation SHALL fail without manufacturing contributor identity

#### Scenario: Anonymous or authenticated client accesses external records

- **WHEN** an anonymous or authenticated client attempts direct table access or service-role-only RPC execution
- **THEN** RLS/ACLs and RPC grants SHALL deny the operation
