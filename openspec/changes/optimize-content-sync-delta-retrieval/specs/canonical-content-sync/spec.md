## Purpose

Synchronize canonical Supabase cities, places, events and media into the existing local cache with paginated bootstrap and incremental retrieval, preserving semantic freshness, offline behavior, atomic content publication and durable cursor authority.

## ADDED Requirements

### Requirement: Canonical modification markers represent semantic resource changes

For the four canonical tables, `modified_at` SHALL represent the last semantically relevant resource change, with relevance defined per table, rather than every SQL UPDATE. Semantic columns SHALL be cities: name, description_delta, deleted_at; events: name, description, description_delta, start_date, end_date, all_day, latitude, longitude, city_id, category, deleted_at; places: name, description, description_delta, latitude, longitude, city_id, category, deleted_at; media: url, description, author, license, license_url, width, height, event_id, place_id, deleted_at. Null transitions SHALL be compared safely. id, created_at and modified_at SHALL NOT decide semantic mutation.

On a semantic UPDATE the DB-owned marker SHALL be `greatest(clock_timestamp(), OLD.modified_at + interval '1 microsecond')`, strictly greater than its previous value. On an UPDATE with no semantic difference the marker SHALL remain OLD.modified_at, regardless of an attempted caller-supplied marker. Canonical INSERT marker defaults SHALL use clock_timestamp(), with created_at defaults unchanged. The migration SHALL persist the table-specific semantic marker principle and deleted_at lifecycle relevance as column documentation on exactly the four canonical modified_at columns; inline SQL comments alone SHALL NOT substitute for persistent DB metadata. created_at SHALL be immutable metadata for all supported canonical runtime writers and SHALL NOT participate in the semantic predicate. Manual/privileged created_at corrections outside supported runtime paths SHALL be outside the replication contract; no new created_at guard infrastructure SHALL be introduced. The distinct modification/token/workflow contracts of content_submissions and external_event_records SHALL remain unchanged.

Canonical sync SHALL remain restore-capable as clarified by external-event-provenance-moderation: generic marker behavior, local state mapping and low-level DB/mapper/sync regressions SHALL cover deleted_at non-null → null, without introducing a supported Event restore RPC, Admin command/UI, moderation workflow, runtime producer or provenance enqueue change. A future supported Event restore operation SHALL retain the linked-source enqueue obligation defined by that capability.

#### Scenario: Persistent semantic documentation
- **WHEN** the migrated canonical column metadata is inspected
- **THEN** all four modified_at columns document table-specific semantic change and deleted_at lifecycle relevance, without imposing that contract on submission or source-record columns

#### Scenario: Supported writers preserve creation metadata
- **WHEN** a supported canonical runtime writer updates a row
- **THEN** created_at remains unchanged, is absent from the semantic-change predicate and gains no new guard infrastructure

#### Scenario: Generic lifecycle coverage adds no restore operation
- **WHEN** low-level tests exercise a canonical Event deleted_at non-null → null transition
- **THEN** the marker and local active state follow generic sync semantics without adding a supported Event restore operation or changing provenance enqueue behavior

#### Scenario: Semantic Event edit
- **WHEN** any Event semantic field changes, including all_day alone or a nullable field transition
- **THEN** its new marker is strictly greater than the old marker

#### Scenario: Deletion and restoration are semantic
- **WHEN** a canonical row changes deleted_at from null to a deletion timestamp, from deleted to active, or to another deletion timestamp
- **THEN** each real change strictly advances modified_at

#### Scenario: Repeated immediate mutation
- **WHEN** two semantic updates happen immediately to the same row, including when its prior marker exceeds current wall time
- **THEN** each successive marker is strictly greater than the previous one

#### Scenario: Non-semantic or no-op write
- **WHEN** an UPDATE changes no semantic column, including an attempt to set only modified_at or created_at
- **THEN** modified_at equals its previous value

#### Scenario: Insert and unrelated workflow contracts
- **WHEN** canonical content is inserted without an explicit marker and unrelated submission/source workflows execute
- **THEN** the canonical marker uses the server's current wall time while created_at and unrelated workflow marker behavior remain unchanged

### Requirement: Legacy deleted rows are normalized before freshness-only merging

The backend upgrade SHALL first remove the interfering legacy canonical marker triggers, then normalize every row with deleted_at IS NOT NULL to `greatest(deleted_at, old modified_at + interval '1 microsecond')` before replacement UPDATE behavior becomes active. Every affected marker SHALL be strictly newer than its pre-migration value. Active rows and created_at SHALL remain unchanged by this repair. The migration SHALL NOT replace tombstone chronology with current wall time or infer unobservable historical restores.

#### Scenario: Legacy deletion is newer than local marker
- **WHEN** a previously cached active row has a server tombstone with deleted_at greater than its historical modified_at
- **THEN** migration produces the specified strictly newer marker and bootstrap merges the deletion

#### Scenario: Tombstone marker already reaches deletion time
- **WHEN** a deleted row has modified_at equal to or greater than deleted_at
- **THEN** repair still advances the historical marker by at least one microsecond

### Requirement: Server cursor is stateless and least privileged

The backend SHALL expose parameterless `public.get_content_sync_cursor()` returning a timestamptz based on clock_timestamp(), without persistent backend state. It SHALL run as SQL SECURITY INVOKER with empty search_path, available to anon and authenticated client roles, without PUBLIC or unnecessary service_role EXECUTE grants or elevated data access. The returned timestamp SHALL be a high-water observation, not a transactional dataset snapshot.

#### Scenario: Client retrieves a cursor
- **WHEN** a client using either required role calls the RPC
- **THEN** it receives the current server timestamp without changing stored content or replication state

#### Scenario: Excessive execution privileges are absent
- **WHEN** function ownership, volatility, search_path and execution ACLs are inspected
- **THEN** the cursor has invoker privileges, live wall-clock behavior, empty search_path and only the required client execution grants besides its owner

### Requirement: Full bootstrap and deltas are paginated by identity

Remote sync retrieval SHALL include active rows and tombstones, fetch complete rows ordered by ascending id with requested limit 500, and apply id > lastId after each nonempty page. The first page SHALL omit the id lower bound. Retrieval SHALL terminate only on an empty page, including when the server's actual row cap is less than 500. A page or decoding failure SHALL fail the entire prepare without partial success or local writes.

An absent local content cursor SHALL select full-table bootstrap with no modified_at filter. A present cursor C SHALL select inclusive `modified_at >= C - 24 hours` on every page. There SHALL be no modified_at upper bound and no timestamp/id compound cursor. Each canonical table SHALL have an ordinary B-tree modified_at index covering deleted rows as well as active rows.

#### Scenario: Bootstrap crosses multiple pages
- **WHEN** full retrieval receives a nonempty page, then a short nonempty page, then more rows and finally an empty page
- **THEN** all rows are prepared with ascending-id continuation and only the empty page ends retrieval

#### Scenario: Delta includes lower-bound equality and tombstones
- **WHEN** a delta page contains rows whose marker equals C minus 24 hours, deleted rows and rows newer than the server cursor
- **THEN** all qualifying rows are retrieved, with the same inclusive lower bound on later id pages

#### Scenario: Empty first page
- **WHEN** the first query returns no rows
- **THEN** prepare succeeds with an empty collection and makes no continuation request

#### Scenario: Later page fails
- **WHEN** a page after an earlier successful page fails or cannot decode
- **THEN** prepare returns failure and no accumulated content is committed locally

### Requirement: Overlap and replay provide bounded operational robustness

The protocol SHALL use a 24-hour safety overlap and at-least-once delivery with idempotent local merge. Its explicit operating assumption SHALL be that a canonical mutation transaction does not remain uncommitted for 24 hours after assigning modified_at. Overlap SHALL NOT be represented as mathematical commit ordering or a multi-request snapshot. Canonical removals requiring propagation SHALL use soft-delete; hard-delete propagation SHALL remain outside this protocol.

#### Scenario: Row changes after its id was scanned
- **WHEN** an already-passed row changes after pre-fetch server cursor U
- **THEN** its newer marker qualifies for subsequent delta retrieval even if it was missed in this scan

#### Scenario: Older timestamp becomes visible late
- **WHEN** a transaction with a pre-U marker becomes visible after a query within the stated 24-hour assumption
- **THEN** the next inclusive overlap query can retrieve the row without requiring an upper bound or commit-order token

#### Scenario: Cursor equals previous cursor
- **WHEN** the server returns U equal to C
- **THEN** the client still fetches the inclusive overlap range

### Requirement: Local merge applies complete newer remote state idempotently

For a locally absent row the client SHALL create an active DTO and ignore a tombstone DTO. For a present row, remote modified_at equal to or older than local modified_at SHALL be a no-op for both active and deleted state; a newer marker SHALL merge the complete remote state, including modified_at and deletion state. Mapping SHALL derive isDeleted from deleted_at for every canonical type, including City. Local non-remote values, especially Event/Place saved state and stable identities, SHALL be preserved. Repeated delivery SHALL be harmless.

#### Scenario: Active content is updated or deleted
- **WHEN** a newer active or tombstone DTO targets a present active row
- **THEN** all remote values and the marker are merged, deletion reflects the DTO and local saved state remains

#### Scenario: Deleted content is restored or revised
- **WHEN** a present deleted row receives a newer active DTO or newer changed tombstone
- **THEN** complete state is merged, including restoration or the revised deleted state

#### Scenario: Equal or older replay
- **WHEN** any present row receives an equal or older marker, including an older tombstone
- **THEN** it remains unchanged

#### Scenario: Absent content
- **WHEN** no local row exists for an active DTO or a tombstone DTO
- **THEN** the active row is created and the tombstone is ignored

#### Scenario: City lifecycle
- **WHEN** City creation or merge maps deletion and a later restoration
- **THEN** City deletion state follows deleted_at consistently with other canonical types

### Requirement: Local cursor is distinct from scheduling state and preserves old caches

Local singleton settings SHALL persist nullable dateNano contentSyncCursorAt, default null, distinct from lastSyncedAt. Existing lastSyncedAt SHALL remain the device completion timestamp for scheduling, and SHALL NOT be reinterpreted as a server cursor. A genuine pre-change ObjectBox cache SHALL reopen with existing UIDs, settings, content and saved state preserved and the new cursor null.

A successful sync-state persistence SHALL save cursor and completion timestamp together once; a failed save SHALL leave both the persisted and repository in-memory previous settings authoritative.

#### Scenario: Existing installation upgrades
- **WHEN** a database created by the previous bindings with non-default populated settings is opened by the new bindings
- **THEN** all previous settings and content survive, and contentSyncCursorAt is null

#### Scenario: Sync state saves together
- **WHEN** sync state persistence succeeds
- **THEN** both supplied timestamps are written in one settings save and remain correct after reopening

#### Scenario: Settings save fails
- **WHEN** writing the two sync timestamps fails
- **THEN** neither the in-memory settings nor the authoritative persisted cursor advances

### Requirement: Content commit precedes durable cursor advancement

Each sync SHALL read local C, obtain server U before content fetches, prepare all four repositories concurrently, atomically commit their content across repositories, and only then persist cursor U and completion time. Success SHALL require successful settings persistence. Cursor fetch failure SHALL cause no prepare or commit; any prepare failure SHALL cause no content commit; commit failure SHALL roll back all repositories. Settings failure after content commit SHALL return sync error while allowing committed content to remain and preserving the old cursor for retry. Success SHALL persist exactly U in UTC, even if fetched rows have markers greater than U. Cursor SHALL never advance before content commit.

#### Scenario: Cursor acquisition fails
- **WHEN** server cursor RPC fails, including because the backend lacks it
- **THEN** sync returns error without repository fetch or commit and without silent fallback

#### Scenario: Concurrent prepare failure
- **WHEN** all four preparations were started concurrently and one fails
- **THEN** no repository commits and the cursor stays unchanged

#### Scenario: Local commit failure
- **WHEN** one commit fails after earlier repository writes in the transaction
- **THEN** all writes roll back and settings are not advanced

#### Scenario: Cursor persistence failure after content success
- **WHEN** content commits but settings save fails
- **THEN** sync returns error, retains the old cursor and completion timestamp, and retry safely replays rows

#### Scenario: Successful sync includes newer data
- **WHEN** retrieval sees markers greater than U and all phases succeed
- **THEN** saved cursor is exactly UTC U and lastSyncedAt is the post-commit completion clock value

### Requirement: Bootstrap precedence preserves scheduling and offline failure classification

A null content cursor SHALL require immediate bootstrap even if lastSyncedAt is recent. With a non-null cursor, existing scheduling SHALL remain due at lastSyncedAt plus three days, or immediately when lastSyncedAt is absent. Forced sync SHALL bypass scheduling while still selecting full/delta from the cursor. Fatal-first-sync error classification SHALL continue to depend on absence of lastSyncedAt, preserving offline access for installations with a previous successful sync.

#### Scenario: Recently synced installation needs first cursor
- **WHEN** lastSyncedAt is recent but contentSyncCursorAt is null
- **THEN** automatic sync performs bootstrap immediately

#### Scenario: Ordinary scheduled or forced delta
- **WHEN** the cursor exists and scheduling is evaluated or a sync is forced
- **THEN** normal sync uses the unchanged three-day boundary and forced sync bypasses it, with both using delta retrieval

#### Scenario: Upgraded cache bootstrap fails
- **WHEN** bootstrap fails with an existing lastSyncedAt and a valid old cache
- **THEN** the error is nonfatal and existing offline/cache navigation remains available

#### Scenario: New installation bootstrap fails
- **WHEN** bootstrap fails with no previously successful sync
- **THEN** the existing fatal-first-sync retry behavior remains

### Requirement: Backend-first rollout preserves installed clients

The backend migration and invariant, ACL and existing Event/concurrency/promotion/external provenance/moderation regression gates SHALL pass before releasing a delta-aware client. Installed clients SHALL continue full retrieval and parsing against the unchanged canonical row shape, observing the corrected markers for deletion/restoration. A new client against an old backend SHALL explicitly fail cursor acquisition rather than silently approximate a successful sync.

#### Scenario: Old client uses migrated backend
- **WHEN** an installed full-sync client retrieves canonical content after backend migration
- **THEN** its DTO parsing and existing full-sync/deletion behavior continue against the same row shape

#### Scenario: Release ordering
- **WHEN** preparing the new Flutter release
- **THEN** backend migration deployment and regression evidence are prerequisites to release approval
