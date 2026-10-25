# Historical implementation evidence and rollout boundary

## Scope and provenance

This is a condensed record of the implementation checkpoint, not verification
newly executed during documentation finalization. The original apply started at
clean local/remote main `58efee0f36c1f1051f49e7c58b0f4d8ef1f79de9` and was committed
as `9e2f49ed2956ff641423610d56b68b6217535dce`. The documentation-only clarification
followed in `05b0f9e3432462a2fbf86c84dc4b6f80e0ed4ab9`; it changed no runtime behavior
and reran no runtime tests. All 21 implementation tasks were recorded complete.
The retained results below were reported by the original execution record; they
have not been independently rerun by this finalization.

The original local environment used Flutter 3.47.5, Dart 3.13.4, ObjectBox 5.3.2,
Supabase CLI 2.119.0, PostgreSQL 17.6, Deno 2.9.7 and Docker 29.7.2. Original apply
used disposable local databases and performed no production deployment or release.

## Backend and generated-contract conclusions

The original backend runners under `supabase/tests/` all exited 0: canonical
content sync (10 passed), genuine migration upgrade (1), Event temporal (6),
submission promotion (37), submission idempotency (11), external Event resolution
(26), ingest (23), moderation (20), provenance (9), assets (12), migration (16)
and rollout (4); the external Event token end-to-end fixture also exited 0.
Tasks.md retains the executable gate paths, without duplicating their transcripts.

The upgrade test replayed unchanged historical migrations, seeded all four tables
under legacy triggers, then applied the new migration once. It checked exact
repair for tombstones with deleted_at greater than, equal to and less than the old
marker, unchanged active rows/created_at, and replacement triggers. Cleanup was
verified. The writer audit found request-scoped canonical RPCs, no supported
created_at updates and soft-delete propagation. The 24-hour transaction assumption
was operational, not a database-enforced commit-order guarantee.

Deno formatting/type checks and runner shell syntax checks passed. Local database
lint/advisors exited 0, with existing findings only: unused `proposal` in
promote_content_submission and mutable search_path in add_submission_assets and
delete_submission_asset; none targeted the new functions.

Generated types were reproduced from both historical and migrated schemas. The
original CLI required explicit `--schema public,graphql_public` to retain the
existing graphql_public schema. A temporary TypeScript 5.9.3 AST formatter changed
only StringLiteral property names matching `^[$A-Za-z_][$A-Za-z_0-9]*$` on
PropertySignature/PropertyAssignment nodes to identifiers, in descending source
offset order, before Deno formatting. Historical generation then matched baseline
byte-for-byte; two migrated generations matched each other. The retained schema
diff added only the parameterless cursor RPC returning string. No dependency or
temporary formatter was retained and no generated type was hand-edited.

## Local-store and orchestration conclusions

A temporary producer using unchanged baseline bindings captured a real closed
previous-model store with non-default settings, related content and Event/Place
saved state. Its immutable fixture README retains producer HEAD, model hash and
values under `test/fixtures/objectbox/pre_content_sync_cursor/`; the producer was
removed. Reopen/persist/reopen tests and the independent pre_all_day regression
passed. Model review preserved all old UIDs and appended only cursor property
`11:6213775870090488596` to AppSettings `6:8898619296747710534`.

A review found that nullable scalar copyWith arguments retained old values on
remote null; the established sentinel pattern corrected this and independent
review confirmed the fix. Controlled Completers established concurrent preparation
and commit ordering. A late Media failure rolled back writes in all four real
boxes. A settings-save failure after content commit preserved old persisted and
in-memory cursor authority; replay then saved exactly the observed server cursor.

The combined focused Flutter gate passed 358 tests. Baseline full suite: 2148
passed, 6 skipped. The first final run found three restoration fixtures with a
recent lastSyncedAt but no cursor; their already-synced setup was corrected to
include a cursor without changing navigation or assertions. The final rerun
passed 2213 tests with 6 existing skips, exit 0. Analyzer exited 1 with 291
pre-existing informational diagnostics; normalization by severity, message, file
and rule (excluding shifted line numbers) found zero new/worsened diagnostics.
Final generator comparisons and Deno checks passed again.

## Unique compatibility smoke and operational boundary

Local HTTP smoke confirmed anon/authenticated cursor access and service_role
denial; its temporary authenticated user was removed. A temporary legacy-client
integration test passed against actual migrated local-stack HTTP responses before
and after soft-delete of four seeded rows. It used exact baseline `58efee0`
BaseSyncRepository, Synchronizable, four repository implementations/contracts and
City mapper, changing only relocated imports; other DTO codecs/mappers matched
that baseline. Eight prepares/commits created then deleted four rows in real
ObjectBox, preserving identity, relations and saved state and explicitly checking
the old deletion branch's retained marker. All temporary producers, copies and
SQL fixtures were removed. This smoke cannot be reconstructed from the retained
delta-client tests alone and is why this evidence record is retained.

That smoke establishes pre-upgrade full-sync client compatibility with the
migrated backend, not reverse ObjectBox compatibility. The old-store to new-model
migration was verified; the exact old binary opening an upgraded store was not.
The forward-compatible rollback constraints remain in design.md and the canonical
content sync specification; no rollback release was implemented or tested.

At the original apply checkpoint, production rollout remained a separate
operation and main specs had not been synchronized or the change archived.
Subsequently, before this finalization, the user reported successful production
migration deployment and successful initial synchronization on a debug device.
These are user-reported operational outcomes, not independently verified here;
they do not establish all deployed ACL/regression/legacy-client gates or a
published app release. Backend-first release prerequisites remain applicable.

The original apply and later contract-remediation records each reported strict
OpenSpec change validation and git diff checks passing. Those historical results
are distinct from the current finalization validation. This documentation-only
finalization performs no deployment, runtime testing or app release.
