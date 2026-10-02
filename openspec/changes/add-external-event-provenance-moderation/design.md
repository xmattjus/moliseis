## Context

Planning is grounded in repository HEAD `6445f42f86baa54b0e55006dee240693775dd623`, revalidated against the supplied baseline `0a57b74d807aad26142e39a9b2c9b4956ad664fd`. The working tree was clean and OpenSpec CLI was 1.12.0. The runtime contracts below remain unchanged between those HEADs. Review of the existing async cron/manual invocation path also requires an operational quiescence gate before T0: disabling scheduling alone does not establish a writer freeze.

The all-day change has now been archived into canonical specs. `event-all-day-semantics` explicitly retains legacy EventiMolise Rome-day deduplication, so this change includes a narrow MODIFIED delta for that requirement. Its temporal semantics are preserved. The other active change is `improve-admin-submission-editor-workflow` (unimplemented tasks); coordinate shared editor boundaries at implementation time without absorbing that change.

Authoritative repository evidence:

- `supabase/functions/import-external-events/{index.ts,import_logic.ts,eventimolise.ts}`;
- `supabase/functions/admin-content-submissions/{index.ts,admin_submission_store.ts,admin_submission_validation.ts}`;
- `supabase/functions/notify-submission-status/index.ts`;
- `supabase/migrations/20260822113151_remote_schema.sql`, `20260822120000_submission_asset_invariants.sql`, `20260825170713_promote_content_submission.sql`, `20260908065810_harden_content_submission_server_idempotency.sql`, and the latest promotion definition in `20261001175539_add_event_all_day_semantics.sql`;
- `lib/domain/models/admin_submission.dart`, `lib/data/repositories/admin_content_submission_repository_impl.dart`, and `lib/ui/admin/submissions/{view_models,widgets}/`;
- canonical `submission-promotion`, `event-all-day-semantics`, `event-temporal-input-validity`, `event-temporal-integrity`, and `content-submission-edge-boundary-validation` specs.

This is planning-only verification; no remote deployment state, remote server version, production audit, or runtime test result is claimed. Those remain implementation/release gates.

Relevant current behavior:

- `import-external-events` supports EventiMolise, directly inserts `content_submissions`, and currently blocks duplicates using normalized city + name + Rome calendar day.
-   The importer technical user comes from `EXTERNAL_EVENTS_IMPORTER_USER_ID`; the Edge Function validates the corresponding `auth.users` row and requires email plus `user_metadata.display_name`.
- `content_submissions.user_id`, `user_email`, and `user_name` are non-null. `client_submission_id` is intentionally nullable for Admin/import paths.
- `content_submissions.modified_at` has no maintaining trigger. Current Admin update/reject operations and promotion explicitly provide/update it.
- `events.modified_at` already has a database trigger.
- `add_submission_assets` and `delete_submission_asset` coordinate through the parent submission lock and require pending state.
-   Status notification currently observes `pending -> accepted/rejected`; the notification function additionally skips the configured importer UUID.
- `promote_content_submission` locks the submission first, retains same-target idempotent retries, creates the target/media transactionally, and then marks the source accepted.
-   Admin backend errors preserve HTTP status, backend code, and message as `AdminContentSubmissionApiException`.
-   Admin `changeStatus` accepts only `rejected` and explicitly rejects `accepted`; there is no current application reopen operation. Imported legacy-client rejection must be routed through the external transactional reject RPC.
-   EventiMolise discovery selects source start dates on or after the current Europe/Rome calendar date; the freeze/audit/cut-over window must finish within one such date.
-   PostgreSQL major version is configured as 17, so `UNIQUE NULLS NOT DISTINCT` is available; remote version remains a pre-deploy verification gate.

## Goals / Non-Goals

**Goals:** establish durable provider identity and provenance; permit multiple providers to reference one canonical Event; safely propose repeated source changes; preserve moderator-owned canonical edits; prevent duplicate publication; keep source/moderation concurrency deterministic; make EventiMolise migration auditable; reuse current Admin, promotion, Result, and transactional patterns.

**Non-Goals:** no event cancellation/postponement semantics, contributor badge/privacy/profile work, source-removal workflow, provider configuration database, generic revision history, canonical Event merge feature, media update merge, fuzzy-search extension, Place provenance redesign, account-deletion redesign, or generalized event-ingestion framework.

## Decisions

### 1. External source identity lives outside `content_submissions`

Create:

```
public.external_event_records
```

with the logical shape:

```
id bigint identity primary key

provider text not null
external_id text not null
occurrence_key text null
source_url text null

normalized jsonb not null
normalization_version integer not null
moderation_hash text not null

proposed_normalized jsonb null
proposed_normalization_version integer null
proposed_hash text null

metadata jsonb not null default '{}'
metadata_version integer not null

ignored_at timestamptz null

event_id bigint null references events(id) on delete restrict

created_at timestamptz not null default now()
modified_at timestamptz not null default now()
```

Identity SHALL be:

```
UNIQUE NULLS NOT DISTINCT (provider, external_id, occurrence_key)
```

`provider` SHALL match `^[a-z0-9_]+$`.

`external_id` SHALL be non-empty after trim. Non-null `occurrence_key` SHALL also be non-empty after trim.

`occurrence_key` strategy is part of the adapter identity contract. Changing from null to a discriminator, or otherwise changing occurrence strategy for an existing provider, requires an explicit data migration rather than a normal import.

`event_id` is the record's current canonical Event link and uses `ON DELETE RESTRICT`. Soft delete remains separate from source ignore.

Normalized/proposed/metadata values SHALL satisfy jsonb-object checks, versions SHALL be positive, hashes SHALL satisfy SHA-256 hexadecimal format checks, and the proposed triple SHALL be all-null or all-valued.

The table SHALL be client-closed through RLS. No anonymous or authenticated client shall read or mutate it directly.

### 2. `normalized` is the entire moderation-relevant canonical source shape

Version 1 normalized external Event state is a complete canonical object containing:

```
name
category
description
description_delta
city
latitude
longitude
all_day
start_date
end_date
```

`start_date` SHALL be non-null and valid under the current Event temporal contract. `end_date` remains nullable. Every external record represents an Event, never a Place. An adapter unable to produce a valid start SHALL reject/quarantine that row before provenance persistence rather than create place-like imported content. Existing all-day Rome-boundary, chronology, and microsecond semantics remain authoritative.

A provider that does not supply an optional value still produces the complete shape, for example:

```
category = unknown
description = null
description_delta = null
latitude = null
longitude = null
```

`moderation_hash` SHALL be:

```
SHA-256(canonicalEncode(normalized))
```

over the entire normalized shape. There is no separate moderation subset.

Provider-specific/non-canonical information belongs in `metadata`. Until Workstream B, provider lifecycle status such as cancelled/postponed may be retained as metadata but SHALL NOT enter `normalized`, the hash, merge calculations, or proposal generation.

### 3. One TypeScript canonicalizer owns normalized representation and hashing

Create one pure shared TypeScript boundary under `_shared` and use it from importer, migration/shadow tooling, and Admin merge logic.

SQL SHALL NOT implement Unicode normalization, source canonicalization, hashing, Quill normalization, timestamp normalization, coordinate normalization, or merge diff logic.

Canonicalization SHALL define at minimum:

-   NFC Unicode normalization;
-   field-specific trim semantics matching persisted Admin validation;
-   explicit null semantics;
-   stable enum representation;
-   deterministic key/field ordering through a fixed canonical array or equivalent stable representation;
-   UTC timestamp strings with explicit canonical fractional precision, preserving PostgreSQL-supported microseconds without a lossy JavaScript `Date` round-trip;
-   finite coordinates represented inside normalized JSON as canonical strings rather than JSON numbers, including deterministic handling of negative zero;
-   canonical Quill operations using existing validation guarantees, operation order unchanged, terminal newline required, adjacent equivalent operations rejected as today, and attribute keys emitted in one fixed order.

`description` and `description_delta` remain one semantic merge group.

A persisted `normalized` value read through PostgreSQL `jsonb`/PostgREST and canonicalized again SHALL produce the same hash.

### 4. Current source state and moderation watermark are separate

`normalized` / `normalization_version` / `moderation_hash` describe the currently observed source state.

`proposed_normalized` / `proposed_normalization_version` / `proposed_hash` describe the last source state actually accounted for by moderation.

The proposed triple SHALL be entirely null or entirely non-null.

Creating a pending proposal SHALL NOT advance the watermark.

Handling the pending proposal SHALL advance the watermark to the handled submission's immutable external snapshot unless the explicitly guarded "current source already evaluated" operation advances it to the current record instead.

Therefore:

```
current == proposed
→ nothing unhandled exists

current != proposed
→ an unhandled source state exists
```

### 5. Imported submissions retain immutable provenance and RPC-owned resolution

Add to `content_submissions`:

```
external_event_record_id bigint null
external_normalized jsonb null
external_normalization_version integer null
external_moderation_hash text null

target_event_id bigint null

source_asset_import_claimed_at timestamptz null
```

`external_event_record_id` references `external_event_records(id) ON DELETE RESTRICT`.

`target_event_id` references `events(id) ON DELETE RESTRICT`.

The four `external_*` provenance fields SHALL be either all null or all non-null.

For imported submissions they are immutable after insert. Enforce this with a database trigger comparing `OLD` and `NEW`; ordinary Admin updates cannot mutate source provenance.

`target_event_id` records acceptance against a pre-existing Event. `promoted_event_id` continues to mean "this submission created this Event".

They are mutually exclusive:

```
promoted_event_id IS NULL OR target_event_id IS NULL
```

and `target_event_id` may be non-null only for an accepted submission.

`source_asset_import_claimed_at` may be non-null only for an imported submission.

For a runtime UPDATE where `OLD.external_event_record_id IS NOT NULL`, changing any of `status`, `target_event_id`, `promoted_event_id`, or `promoted_place_id` SHALL require a transaction-local authorized resolution context. The guard tests each column using `IS DISTINCT FROM`, covering pending-to-final, final-to-pending, and direct durable-link mutations. Generic writers cannot reopen accepted/rejected imported rows or collide with the one-pending index.

Authorized external reject, link, apply, and promotion RPCs SHALL establish `set_config('app.external_resolution', 'on', true)` before controlled mutation. Runtime paths outside those RPCs SHALL fail. This GUC is a consistency mechanism against unsupported writers, not an authorization boundary against arbitrary privileged SQL: a service-role/database administrator capable of such SQL can also set it. Authorization remains in RPC grants, verified Admin JWTs, and RLS/ACLs. Ingest, asset-claim, and resolution RPCs SHALL be service-role-only; private helpers SHALL have no client execution grants.

Existing reject-only `changeStatus` requests for imported rows SHALL be server-routed to the external reject RPC; human rejection remains on its current path. No compatibility path for `changeStatus: accepted` is required. A future generic finalization/reopen API must expose a stable domain conflict such as `external_requires_resolution` rather than leak a trigger exception as HTTP 500.

Reject routing may read provenance before the moderation lock because populated `external_event_record_id` is immutable. The selected transactional reject RPC still locks and revalidates the row authoritatively. Explicit migration of verified legacy rows is separate from ordinary runtime mutation and SHALL not relax the deployed provenance invariant.

### 6. At most one pending proposal exists per external record

Add:

```
UNIQUE (external_event_record_id)
WHERE external_event_record_id IS NOT NULL
  AND status = 'pending'
```

Every automatic insertion of an imported pending submission SHALL occur while the corresponding `external_event_records` row lock is held.

The unique index remains a structural fallback rather than the normal concurrency mechanism.

### 7. Automatic pending creation exists in one private database primitive

Create one private helper conceptually equivalent to:

```
enqueue_external_event_proposal_if_needed(...)
```

It is the only production path that INSERTs an automatically generated imported `content_submission`.

It performs only deterministic projection from already canonical `record.normalized` into submission columns. This mechanical projection is not a second canonicalizer.

It SHALL:

1.  run while the external record lock is held;

2.  return without inserting when `ignored_at IS NOT NULL`;

3.  return without inserting when a linked Event is soft-deleted;

4.  return the existing pending when one already exists;

5.  return without inserting when current and proposed hash/version are equal;

6.  otherwise insert exactly one pending submission from the current `normalized`;

7.  store the current normalized/hash/version as immutable submission provenance;

8.  use `client_submission_id = NULL`;

9.  return the resulting/existing pending submission identifier when relevant.

The helper SHALL NOT upload media.

### 8. Technical identity is seeded only by ingest and inherited thereafter

For a new external record with no existing imported submission, `import-external-events` obtains `EXTERNAL_EVENTS_IMPORTER_USER_ID` exactly as today.

The ingest RPC is service-role-only. It receives the configured importer user ID and resolves/validates its authoritative email/display name from `auth.users` through a private, tightly permissioned database helper.

No Admin request body may supply importer identity.

When reject/link/apply/promotion handling immediately enqueues the next revision, the new submission copies `user_id`, `user_email`, and `user_name` from the imported submission just handled.

`set_source_ignored(false)` obtains identity from an existing submission of that external record, preferring the most recent by `handled_at DESC NULLS LAST, id DESC`. If no usable imported identity exists, un-ignore fails instead of manufacturing one.

Changing `EXTERNAL_EVENTS_IMPORTER_USER_ID` therefore affects new source workflows without rewriting historical source identity.

### 9. Ingest is record-scoped and never uses semantic dedup as a blocker

The importer SHALL issue one transactional ingest RPC per normalized external record.

It SHALL NOT wrap a provider batch in one database transaction.

The RPC SHALL use insert-on-conflict followed by row locking for new/concurrent strong identities:

```
INSERT ... ON CONFLICT DO NOTHING
SELECT ... FOR UPDATE
```

It then updates current normalized/hash/metadata state only when persisted state materially differs and always evaluates proposal enqueue, even when the current hash did not change during that invocation.

The existing city + normalized name + Rome day heuristic SHALL NOT filter source records before provenance persistence.

Within-provider duplicate listing appearances also SHALL converge through strong source identity, not semantic city/name/day suppression.

The ingest response SHALL expose at least:

```
record_id
event_id / linked state
pending_submission_id when present
whether the pending was newly created
```

so the Edge importer can make the asset decision.

### 10. Candidate discovery is advisory

The Admin Edge Function SHALL provide candidate discovery for pending event submissions.

It SHALL return separately:

```
canonical Event candidates
similar pending submission warnings
```

Pending submissions are warnings, not selectable canonical targets.

Baseline matching reuses existing deterministic project semantics:

-   exact active `cities.name` resolution where possible;
-   Rome calendar-day proximity;
-   existing normalized text comparison.

No `pg_trgm` dependency is introduced.

Candidate discovery is advisory and cannot prohibit legitimate same-city/same-day Events.

Admin SHALL also permit manual Event lookup by name or ID when automatic city-based candidates are insufficient.

Candidates SHALL be refreshed at the decision/preview boundary rather than treated as durable state.

### 11. Admin exposes external `create` and `update` mode

For imported submissions:

```
record.event_id IS NULL  → create
record.event_id IS NOT NULL → update
```

The Admin list/detail contract SHALL expose this mode.

A current client uses:

-   create: normal Event promotion or link to an existing Event;
-   update: link to the already-linked Event or apply an update.

A legacy Admin client that attempts Event promotion for an update receives stable `source_already_linked` backend failure. Existing repository error normalization SHALL surface it as an API exception rather than parsing it as a successful promotion payload.

### 12. Linking never rewrites canonical content

`link` accepts a pending submission against an existing active Event without changing Event fields or media.

Human submissions may use link.

For imported submissions:

-   if `record.event_id IS NULL`, link to E establishes `record.event_id = E`;
-   if `record.event_id = E`, linking again to E is valid;
-   if `record.event_id = E1`, linking to E2 is rejected as a relink conflict.

Relinking a source record is a separate future administrative feature.

Successful link:

```
status = accepted
target_event_id = selected Event
handled_by = authenticated Admin
watermark advances when imported
enqueue newer current source state if needed
```

### 13. Apply exists only for source updates with a known base

`apply` is permitted only when:

-   submission is imported and pending;
- `record.event_id` equals the requested target Event;
-   target Event is active;
- `record.proposed_normalized` is non-null;
-   proposed/submission normalization versions are compatible;
-   submission and Event concurrency tokens still equal those from the preview.

Human submissions and first-time provider links have no trustworthy source base and are link-only.

Both link and apply SHALL support authoritative same-target idempotency: an already accepted submission with `target_event_id = requested Event` returns `already_resolved`. A different target remains a conflict.

The Edge handler SHALL read enough authoritative resolution state and branch to the RPC retry path before pending-only merge preview/recalculation. SQL remains final authority and checks accepted/same-target resolution before pending-only preconditions or token validation. An apply retry SHALL not canonicalize/merge again, validate old preview tokens, write Event fields again, advance the watermark again, or enqueue twice. Handler and RPC tests SHALL cover commit → lost HTTP response → retry for both link and apply.

### 14. Merge units are semantic groups

The merge units are:

```
name:
  name

category:
  category

description:
  description
  description_delta

schedule:
  start_date
  end_date
  all_day

location:
  city
  latitude
  longitude
```

`city` is part of `location` so a city change cannot be applied independently of its coordinate pair.

For group `G`:

```
base      = record.proposed_normalized.G
source    = submission.external_normalized.G
moderated = canonicalize(current submission).G
event     = canonicalize(current Event).G

providerChanged(G) =
  source != base

moderatorChanged(G) =
  moderated != source

apply(G) =
  providerChanged(G) OR moderatorChanged(G)

overwrite(G) =
  apply(G)
  AND event != base
  AND event != moderated
```

If a group is applied, SQL copies the complete group from the persisted moderated submission.

Placeholder source values in a group with neither provider nor moderator change SHALL be presented as "not applied", not as fields requiring completion.

### 15. Merge calculation is TypeScript-only

The Admin Edge Function owns merge calculation for both preview and apply orchestration using the same shared canonicalizer as the importer.

SQL SHALL NOT recalculate `providerChanged`, `moderatorChanged`, `overwrite`, or canonical group values.

The Edge Function computes the closed `groups_to_apply` set from authoritative server reads.

Flutter SHALL NOT authoritatively choose groups.

The SQL apply RPC receives the server-computed groups and SHALL:

-   reject unknown/duplicate group names;
-   recheck apply preconditions;
-   validate preview concurrency tokens;
-   lock and update only the requested closed groups.

### 16. Preview tokens originate at preview and remain opaque

Merge preview SHALL return raw database-version token strings:

```
submission_version_token
event_version_token
```

Flutter SHALL retain them as opaque strings.

They SHALL NOT pass through `DateTime.parse`, `toIso8601String`, timezone conversion, or precision truncation before apply.

At apply:

1.  Flutter sends exactly the preview token strings.

2.  The Admin Edge Function MAY reread submission/Event to recompute groups, but SHALL NOT replace the supplied preview tokens with newer values.

3.  The RPC locks submission → record → Event.

4.  The RPC compares the locked row timestamps for exact equality with the preview tokens.

5.  Any mismatch returns `submission_changed` or `event_changed`.

Tokens are equality markers only. No ordering or monotonicity interpretation is permitted.

`handled_by` comes only from the authenticated Admin JWT verified by the Edge Function and is never accepted from the request body.

### 17. `content_submissions.modified_at` becomes DB-owned for merge content

Add a database trigger covering every submission column participating in merge groups:

```
name
category
description
description_delta
start_date
end_date
all_day
city
latitude
longitude
```

Any UPDATE statement making a real semantic change to these fields SHALL set `modified_at` authoritatively to a value equivalent to:

```sql
greatest(clock_timestamp(), OLD.modified_at + interval '1 microsecond')
```

Transaction-start `now()` alone is insufficient. Multiple updates in the same transaction SHALL produce distinct tokens even when clock precision repeats. A no-op merge-content write does not require advancement by this trigger. Exact equality remains the only concurrency interpretation; the timestamp is not an ordered business version.

Admin field-save code SHALL no longer be the sole owner of this token.

Focused DB tests SHALL update each merge group through direct SQL, including repeated writes within the same transaction, and verify earlier equality tokens no longer match.

Existing status/finalization writes may retain their existing explicit modification timestamp behavior; the merge-token requirement is specifically that no writer can change merge content without invalidating an earlier preview.

### 18. Apply writes groups atomically and preserves existing Event invariants

For `location`, the RPC resolves `submission.city` against an active exact `cities.name`, using the same canonical city rule as promotion. Failure returns `city_not_found`; no partial location write occurs.

For `description`, both description fields move together.

For `schedule`, all temporal fields move together.

The Event row is locked before mutation. Its existing `modified_at` trigger advances the Event synchronization marker.

Apply does not modify Event media.

### 19. Overwrite warnings are explicit

Preview SHALL identify every `overwrite(G)`.

The UI SHALL allow an explicit "Mantieni valore attuale" action for an overwrite group by copying the current canonical Event group into the editable submission and saving through the normal Admin update path.

A subsequent preview then recomputes from the persisted submission.

No separate per-field patch model or merge-choice table is introduced.

### 20. Reject is revision-level

Rejecting an imported source revision means the entire source revision is considered reviewed and discarded.

The watermark advances to that rejected submission's external snapshot.

Therefore, if X was accepted, Y rejected, and Z later arrives, provider change comparison is Y → Z. Changes introduced in Y and unchanged in Z are not re-proposed.

Partial acceptance uses normal submission editing followed by apply; Reject is not field-level moderation.

The source-ignore option SHALL explain this revision-level behavior.

### 21. Ignore is reversible

Reject MAY request `ignore_source`.

When selected, in the same transaction:

1.  submission is rejected;

2.  `ignored_at` is written;

3.  watermark is advanced;

4.  enqueue is evaluated.

Because `ignored_at` is already set, no replacement pending is created.

`set_source_ignored(false)`:

1.  locks the record;

2.  clears `ignored_at`;

3.  resolves inherited importer identity from prior submissions;

4.  immediately evaluates enqueue.

No future source observation is required to resume proposals.

### 22. Stale source state is enqueued immediately after handling

A pending submission may become stale while open because ingest updates `record.normalized`.

When reject/link/apply/promotion handles the current pending:

1.  watermark advances to the handled source snapshot;

2.  if the moderator explicitly selected "considera valutata anche la versione corrente", the current record may instead become the watermark only after stale-state validation and `expected_source_hash` equality;

3.  enqueue is evaluated before transaction commit.

Thus X may be accepted/rejected while source Y is already current, producing a fresh pending Y in the same transaction.

Normal handling does not require `expected_source_hash`; the special current-source acknowledgement does.

The special option SHALL fail with `source_changed` unless the submission is actually stale and expected_source_hash equals the locked current hash. Failure SHALL persist no resolution, watermark, or enqueue changes.

### 23. Global lock order is explicit

Operations involving all three entities use:

```
content_submissions
→ external_event_records
→ events
```

Ingest has no owned submission and locks only `external_event_records`.

Every automatic pending INSERT occurs while the external-record lock is held.

Asset-claim operations may lock submission and then its external record, preserving the same relative ordering.

Concurrency tests SHALL prove no duplicate pending and no promotion/resolve deadlock for representative overlaps.

### 24. Promotion cannot create a second canonical Event

Extend the existing promotion RPC without redesigning it.

Existing durable promotion-link retry discovery retains precedence.

For a pending imported Event submission with no existing promotion link:

-   lock submission;
-   lock external record;
-   reread `record.event_id` under lock;
-   if non-null, return `source_already_linked` without creating Event/media or changing moderation state;
-   if null, continue existing readiness/publication behavior.

Imported records represent Events; their required non-null start preserves the existing `place_has_event_dates` rejection of Place promotion. Do not let normal Admin editing clear the Event discriminator to evade imported Event-only resolution.

Successful imported Event promotion additionally, in the same transaction:

```
record.event_id = new Event id
watermark = submission external snapshot
enqueue_if_needed(record)
```

If source state changed while the promoted submission was pending, promotion ends with the Event created from the reviewed snapshot and a new pending for the newer source state.

### 25. External submissions never send user status email

Imported status notification suppression SHALL use the structural fact:

```
external_event_record_id IS NOT NULL
```

rather than relying solely on technical-user UUID/email.

The DB notification trigger SHALL not enqueue the status webhook for structurally imported submissions.

`notify-submission-status` SHALL retain the existing importer-UUID check as defense in depth for pre-backfill/legacy rows and SHALL also skip structurally external submissions, including manual retry.

The structural filter SHALL deploy before or together with EventiMolise backfill/cut-over.

### 26. Source asset import is at-most-once per imported submission

`source_asset_import_claimed_at` represents an irreversible automatic import attempt budget consumed for that submission. For runtime-created submissions it records the atomic claim before the attempt; for legacy backfill it may record migration-time suppression of an already-used or unverifiable historical attempt budget, not an invented historical upload timestamp.

Create a service-role-only atomic asset-claim boundary.

Before uploading, it SHALL lock the submission, and where required the linked external record, then require:

-   imported pending submission;
-   external record not yet linked to an Event;
- `source_asset_import_claimed_at IS NULL`;
-   zero current submission assets;
-   a source image is available in the current observation.

It then sets `source_asset_import_claimed_at` and returns claimed success.

Only the winner uploads.

The claim remains set after both success and failure.

Therefore:

-   overlapping importer runs cannot automatically upload twice;
-   a permanently broken source image is not retried indefinitely;
-   if a moderator later removes the imported image, it is not re-added automatically.

After upload, existing `add_submission_assets` remains authoritative. If the submission ceased to be pending before association, the upload is cleaned up using existing Cloudinary cleanup behavior.

No automatic source-image import is attempted for a record already linked to an Event because Workstream A does not merge media updates.

The current provider image at claim time is treated as best-effort source decoration, not a versioned moderation field.

### 27. Admin mode and backend failures remain backward-compatible

New Admin responses may add external mode/provenance data; current parsing must remain tolerant of additional response keys.

A legacy client attempting promotion on an imported update receives a normal backend error (SQL `source_already_linked`, HTTP 409 code `PROMOTION_SOURCE_ALREADY_LINKED`) through the existing `FunctionException` → `AdminContentSubmissionApiException` path.

The new client SHALL map this error to actionable copy rather than a generic crash/failure state.

### 28. EventiMolise migration is audited before cut-over

Migration SHALL NOT infer provenance blindly from all historical submission rows.

The rollout has five phases:

1.  identity audit: parse EventiMolise source ID/URL from known historical importer notes; report parse failures and duplicate strong identities;

2.  shadow normalization: run the production TypeScript adapter/canonicalizer against current provider data without writes;

3.  classification: determine historical source snapshots/watermarks, distinguish editorial differences from actual source changes, and identify ambiguous pending rows;

4.  remediation: manually resolve duplicate source IDs mapping to different canonical Events and every pending row whose immutable historical source snapshot cannot be established;

5.  cut-over: create/link external records, populate immutable submission provenance, apply final constraints/indexes where staged, disable old semantic dedup, and activate new ingest.

Release gate:

```
zero ambiguous legacy pending imported submissions
zero unresolved strong-identity conflicts
all unexplained shadow mismatches resolved
```

Every external record created during migration SHALL have one explicit classification explaining its initial watermark. Migration shall not infer a source snapshot from moderator-edited columns or treat missing evidence as unhandled history.

| Classification | Required evidence and initial state |
| --- | --- |
| `verified_handled` | A verified immutable last-handled source snapshot exists. Current is shadow/current source if observable; proposed is the verified last-handled snapshot. A verified newer pending retains its own snapshot and does not advance proposed. |
| `editorial_baseline` | Accepted historical source snapshot is unverifiable, strong identity/current shadow are trustworthy, canonical linkage is unambiguous, and mismatch is explicitly classified as editorial transformation. The historical submission remains structurally legacy/unlinked; record.event_id is its historical promoted Event; current = proposed = shadow current. |
| `remediated_real_drift` | Accepted unverifiable history with genuine source drift is initially a blocking migration conflict. Explicit remediation establishes a trustworthy baseline, for example manual reconciliation of the canonical Event with observed source followed by explicit authorization of proposed := current. No default link-only acknowledgement or null-base update is allowed. |
| `rejected_baseline` | Unverifiable rejected history is observable and explicitly classified. Historical row stays legacy; current = proposed = shadow current, never null proposed. Future changes may propose again. |
| `ignored_baseline` | Same explicit observable rejected baseline, plus operator-authorized permanent suppression through ignored_at != null. |
| `verified_unhandled` | Verified evidence proves no revision has ever been handled, for example a legacy pending representing current unhandled source. Only this classification permits a null proposed triple. |
| `verified_no_longer_observable` | Source is no longer observable but a verified handled snapshot exists; current = proposed = that snapshot. Without any verified source snapshot no record is created and historical submission remains legacy. |

For legacy pending rows populated with imported provenance, backfill SHALL consume the automatic source-image attempt budget by initializing source_asset_import_claimed_at non-null unless the audit positively verifies no prior automatic source-image attempt. Zero current assets does not establish fresh eligibility: the legacy importer uploaded immediately after insertion, and a moderator may since have removed that image. Use a documented migration timestamp for conservative suppression, not an invented past attempt time. Test both previously imported-then-removed images and failed/unverifiable attempts so later ingest cannot re-add them.

Every submission actually populated with imported provenance requires its own verified immutable source snapshot. An editorial/rejected baseline on a record does not manufacture provenance for unverifiable historical submissions. Every migrated null watermark SHALL have explicit `verified_unhandled` evidence. Accepted/rejected unverifiable history never qualifies merely because its snapshot is absent.

No arbitrary mismatch-rate threshold alone permits cut-over; unexplained mismatches, real-drift conflicts awaiting remediation, identity/link conflicts, and ambiguous pending snapshots block it. The final production-contract dry-run SHALL explain every proposed revision as genuinely unhandled source state.

The legacy cron writer `import-external-events-eventimolise` SHALL be disabled before audit. Because cron uses asynchronous `net.http_post` and the handler also accepts manual runs that await source fetching before writes, disabling scheduling alone does not freeze legacy persistence. Prevent new manual legacy invocations and drain all queued/in-flight legacy requests before recording a quiescent `T0`; verify no legacy writer can persist further rows through audit and cut-over. If quiescence cannot be established, do not start the audit. This is an operational gate, not a new import-run ledger or ingestion framework. Freeze, audit, shadow, classification, backfill, gate checks, provenance cut-over, and activation SHALL complete within one Europe/Rome calendar date, before the next Rome midnight. Current source discovery filters `date >= current Rome date`, so an audit cannot cross midnight and remain complete.

Before provenance cut-over, if the Rome date changes or gates cannot finish before midnight, abandon the attempt, discard the audit snapshot, optionally re-enable the unchanged legacy writer, and retry later from a fresh `T0`. Do not carry a stale audit into another date.

Provenance cut-over is the explicit point of no return for the legacy writer. After this point the legacy city/name/day writer SHALL NEVER be scheduled again. Post-cut-over rollback stops provenance-aware ingest and retains additive schema and migrated provenance; it cannot restore the legacy importer.

### 29. Normalization-version changes are explicit migrations

A runtime importer SHALL NOT silently change `normalization_version`.

If the next version is derivable entirely from v1:

-   convert `normalized`;
-   convert `proposed_normalized`;
-   convert any pending submission `external_normalized`;
-   recompute hashes;
-   retain pending/watermark semantics.

If the new version requires previously unavailable source data, perform provider refetch in an explicit baseline-migration mode.

When old current == old proposed, the refetched v2 state may establish both new current and proposed baseline.

When old current != old proposed, pending/unhandled state must not be erased. If proposed cannot be faithfully converted, classify the record as a migration conflict for manual remediation.

Runtime apply rejects incompatible versions as `normalization_mismatch`.

Workstream B depends on this procedure before promoting source lifecycle status into normalized state.

### 30. Soft-deleted linked Events block source proposals

When `record.event_id` references an Event with `deleted_at IS NOT NULL`, ingest may update current source state/metadata but enqueue SHALL not create a new proposal and SHALL not advance proposed.

Any future supported operation that restores a soft-deleted canonical Event SHALL reevaluate enqueue for every linked external source record whose current state differs from its moderation watermark. No restore RPC, trigger, UI, or current restore test is part of Workstream A.

## Risks / Trade-offs

- Historical moderation may have erased source evidence → keep unverifiable rows legacy, use only explicitly classified baselines, and block ambiguous pending or genuine unremediated drift.
- Unscheduling cron leaves queued/in-flight or manual writes possible → establish and verify writer quiescence before T0 and maintain it through cut-over.
- Freeze can outlast provider discovery coverage → require one Rome calendar date and restart pre-cut-over attempts with a fresh T0.
- Lost resolution response can incorrectly enter pending-only merge → branch to same-target authoritative retry before calculation and preserve DB idempotency.
- Timestamp precision can hide edits → use wall clock plus a minimum microsecond advance for submission merge content and preserve raw preview equality tokens.
- Privileged unsupported writers can bypass a GUC → rely on service-role grants, verified Admin boundaries and RLS/ACLs for authorization; use the resolution guard for consistency.
- Legacy image attempt history may be missing after moderator removal → consume the backfilled pending attempt budget unless audit verifies no prior attempt; zero assets alone never re-enables automatic import.
- Source image import may fail permanently for one submission → accept best-effort decoration and an irreversible claim so moderator removals are preserved.

## Migration Plan

1. Deploy additive schema foundation and backward-compatible notification/Admin backend, including structural email filtering and source_already_linked mapping before any RPC can emit that outcome. Preserve legacy runtime behavior until cut-over.
2. Disable the legacy cron writer, prevent new manual legacy invocations, drain queued/in-flight requests and verify quiescence, then record T0 and its Rome date, and execute the complete decision-28 audit/shadow/classification/remediation workflow. Apply verified backfill and final constraints/indexes only when all gates pass; use a fresh attempt if the pre-cut-over date window is exceeded.
3. Mark provenance cut-over explicitly, permanently retire legacy writes, and activate provenance-aware per-record ingest before the next Rome midnight; then release the updated Admin client.
4. If rollback is needed after cut-over, stop new ingest while retaining additive schema and provenance. Never schedule the legacy writer again. Before cut-over an abandoned attempt may restore the unchanged legacy writer and discard its audit snapshot.

## Readiness

No architectural decisions remain open. Remote PostgreSQL version, complete production history classification, conflict remediation, runtime/concurrency tests, and the single-date cut-over are required implementation/release checks, not claimed completed by this planning change.
