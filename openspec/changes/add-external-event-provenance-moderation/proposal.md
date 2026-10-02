## Why

The existing external-event importer treats an imported event as a one-shot pending `content_submission` and deduplicates later imports through the heuristic combination of normalized city, name, and Rome calendar day. That model cannot safely support multiple providers, repeated source revisions, canonical events already known to Molise Is, or moderator-owned edits without either losing provenance or creating duplicate published events.

Introduce a provider-generic external-event provenance and moderation boundary that keeps external source identity separate from `content_submissions`, preserves moderator ownership of canonical `events`, and lets source revisions enter the existing moderation workflow without provider-specific schema changes.

The change deliberately does not implement public contributor attribution or event lifecycle states such as postponed/cancelled. Those remain separate Workstreams C and B.

## What Changes

-   Add `external_event_records` as the durable identity and current-state record for one logical provider event.
-   Replace importer deduplication by city/name/day with strong provider identity `(provider, external_id, occurrence_key)`; retain the former heuristic only for moderation candidate discovery.
-   Store one canonical normalized source snapshot and SHA-256 hash per external record, plus a separate `proposed_*` watermark representing the last source state actually handled by moderation.
-   Link imported `content_submissions` structurally to their source record and retain an immutable canonical source snapshot on each submission.
-   Enforce at most one pending submission per external record.
-   Centralize automatic proposal creation in one private database primitive so ingest and moderation follow-up paths create the same database-valid submission shape.
-   Allow a pending suggestion to be linked to an existing Event. Allow source updates to be applied to an already-linked Event only when a known source baseline exists.
-   Compute update merge semantics only in shared TypeScript code. SQL owns row locking, concurrency-token validation, closed write-group validation, and atomic persistence; it does not reimplement canonicalization or merge logic.
-   Protect canonical moderator edits through grouped three-way merge preview and explicit overwrite warnings.
-   Extend promotion so a source record already linked to an Event cannot create a duplicate Event.
-   Suppress status-email notifications structurally for imported submissions.
-   Make imported resolution columns RPC-owned, including all status transitions and durable resolution-link mutations. Preserve same-target link/apply retries before pending-only merge calculation.
-   Require a valid non-null Event start in normalized v1; gate EventiMolise migration on total watermark classification, a single Rome-date freeze window, and permanent retirement of the legacy writer after cut-over.
-   Make source-image import best-effort and at-most-once per imported submission through an atomic asset-import claim.
-   Backfill the existing EventiMolise history through an audited shadow-mode cut-over rather than heuristic blind migration.

## Capabilities

### New Capabilities

- `external-event-provenance-moderation`: Owns external provider identity, normalized source state, moderation watermarks, imported submission snapshots, proposal enqueue semantics, candidate discovery, link/apply workflows, merge preview, concurrency, ignore behavior, external notification isolation, importer asset claim, and EventiMolise migration/cut-over.

### Modified Capabilities

- `event-all-day-semantics`: Replace the existing EventiMolise Rome-day deduplication requirement with strong provider identity; preserve the adapter-owned temporal interpretation and existing date handling. This delta is necessary because the canonical capability currently requires the legacy deduplication behavior.
- `submission-promotion`: Promotion of an imported event submission must respect existing external-record linkage, atomically establish the initial canonical Event link when it creates one, advance the source watermark, and enqueue a newer already-observed source state when necessary.

## Impact

-   Forward Supabase migrations for `external_event_records`, new `content_submissions` provenance/linkage/asset-claim fields, constraints, indexes, triggers, private helpers, and service-role-only RPCs.
- `import-external-events` adapter/orchestration, shared TypeScript normalization/hash utilities, EventiMolise backfill/shadow tooling, and importer tests.
- `admin-content-submissions` request/response contracts, candidate search, merge preview, reject/link/apply/un-ignore operations, notification filtering, and generated database types.
-   Flutter Admin models/repository/ViewModel/UI for external `create`/`update` mode, candidate warnings, link/apply actions, overwrite preview, and opaque concurrency tokens.
-   Existing public `submit-content`, public Content Submission form/draft/upload orchestration, rate limiting, ObjectBox event synchronization, Places, and media update semantics remain unchanged.
-   No provider registry, profiles, public attribution badge, import-run ledger, revision table, `superseded` status, `target_place_id`, removal lifecycle, `event_status`, source-media update merge, `pg_trgm`, generalized ingestion framework, or new package.
