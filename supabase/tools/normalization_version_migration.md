# Explicit normalization-version migration procedure

No production v2 profile is defined or activated here. Workstream B must define
its concrete version contract and extend the existing single shared TypeScript
canonicalizer before generating new snapshots/hashes. The offline transition
policy in `normalization_version_migration.ts` fixture-tests accounting rules;
it neither converts arbitrary future source data nor exposes a runtime migration
API.

1. Stop provenance-aware scheduling/manual invocations, drain queued/in-flight
   ingest, and freeze affected Admin resolutions. Verify quiescence before
   exporting all current/proposed source snapshots, versions/hashes and every
   immutable pending snapshot through SQL JSONB, retaining raw tokens and
   canonical Event links.
2. Implement the approved, version-specific conversion in the single shared TS
   canonicalizer. Derive every current/proposed/pending snapshot when possible
   and recompute each complete-shape hash there. Record converter/source
   evidence. Never copy moderator-edited submission fields into a source
   snapshot.
3. If current cannot be derived, refetch explicitly. Only old current
   hash/version equal to old proposed hash/version permits refetched current to
   establish both new current/proposed baseline. For divergence, convert
   proposed faithfully and preserve the distinct handled base. Keep null
   proposed null for a proven unhandled workflow. An unconvertible proposed or
   pending snapshot blocks the record for remediation; no default link-only
   acknowledgement is permitted.
4. Review the complete converted manifest with
   `planNormalizationVersionMigration`. Every pending ID must have exactly one
   conversion. Fixture versions here use the existing ten-field shape solely to
   exercise transition semantics; they are not a new normalization contract or a
   runtime version switch.
5. Prepare a reviewed, privileged one-shot forward data migration. In one
   explicit transaction acquire
   `LOCK TABLE public.content_submissions IN SHARE
   ROW EXCLUSIVE MODE` as the
   **first submission lock**, before any record or Event lock. Then
   lock/revalidate affected submission rows, external records next, Events last;
   revalidate all exported snapshots/versions/hashes/status/ link/raw tokens.
   PostgreSQL 17 documents this lock mode for trigger disable/enable
   ([ALTER TABLE](https://www.postgresql.org/docs/17/sql-altertable.html)).
   Acquire the table lock up front, rather than upgrading after holding Event
   locks: human Link/Save or asset writers could otherwise wait for an Event
   while holding a conflicting submission table lock. No public RPC or GUC
   provenance bypass is introduced.
6. For this controlled migration only, disable the specific populated-provenance
   immutability trigger `guard_submission_external_provenance` inside that
   transaction immediately around the reviewed pending tuple updates. Convert
   all four immutable provenance fields together, then re-enable that trigger
   before transaction completion. Table DDL locking prevents concurrent
   unguarded writes; transaction rollback restores trigger state on any failure.
   Do not disable RLS, the resolution guard, asset-budget irreversibility or
   timestamp ownership.
7. Update current/proposed triples atomically with their new hashes and
   versions; preserve resolution/media/linkage/ignored state and moderator
   content. Recheck pending/watermark accounting and trigger enabled state
   before commit. Convert pending snapshots even if a record is currently
   ignored or linked to a deleted Event. Run a production-contract dry-run with
   the concrete approved version and explain every resulting proposal before
   reactivating ingest/resolutions.

An SQL converter, SQL hash/canonicalizer, public migration endpoint, generic
provider framework or silent runtime upgrade is not part of this procedure.
