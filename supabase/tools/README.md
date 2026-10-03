# External Event migration tools

These tools prepare and test audited migration data. No production audit,
backfill, freeze or cut-over has been executed by this implementation.

`audit_external_events.ts` consumes a JSON export with `submissions` (complete
database rows) and `observations` (parsed `EventiMoliseEvent` values from the
existing production provider adapter). `mismatch_evidence` optionally supplies
explicit operator classifications and evidence references. Capture raw provider
responses alongside this export so its interpretation can be reproduced.

Export only known historical technical importer rows, selected using the audited
legacy importer UUID, including accepted/rejected/pending history. Include
malformed notes in that population so failures are visible. Do not include human
submissions or select only successfully parsed notes. The UUID identifies
candidate history; source notes establish identity only, never immutable content
or image-attempt evidence. Keep exports private: submission rows contain
contributor identity.

```sh
deno run --allow-read supabase/tools/audit_external_events.ts audit-export.json
deno test --allow-read supabase/tools/external_event_migration_test.ts
```

The audit reports historical identity repetition separately from duplicate
current observations. Multiple historical revisions can be legitimate; multiple
canonical Event links remain a conflict. Handled ordering follows
`handled_at DESC NULLS
LAST, id DESC`, after UTC timestamp normalization,
retaining microseconds. Shadow comparison canonicalizes the moderated row only
for diagnostics. It never uses that row as an immutable source snapshot. Missing
observations, invalid rows, conflicting source observations and unexplained
differences remain unresolved.

The backfill drift baseline MUST be the SQL JSONB export from
`export_external_event_history.sql`, not a PostgREST export. The latter can
round coordinates differently from the direct SQL connection. Supply the audited
legacy UUID through psql's `legacy_importer_user_id` variable; save the JSON
privately and add the provider `observations` array and evidence manifest. SQL
JSONB preserves raw six-digit timestamps and double values. Backfill revalidates
all exported columns under locks, normalizing only named timestamp columns for
transport offset equivalence. Plaintext is never interpreted as a timestamp.

`planVerifiedBackfill` accepts closed classifications with evidence references,
per-submission source captures and separate mismatch explanations. A missing
observation only means unknown to the audit. A verified-absence classification
requires an explicit provider discovery/availability evidence reference. Pending
without its own capture, failed notes/adapter observations, contradictory
captures, accepted Place history or conflicting canonical Event links block the
gate.

`backfillVerifiedPlans` is privileged one-shot direct SQL tooling, not a public
RPC. It locks all submissions, then records, then Events; revalidates the
export; populates only verified provenance; preserves moderated
content/resolution; and calls the existing private enqueue primitive. Each batch
is atomic. Set `rollback: true` for local/dry-run verification. No production
invocation is included in this implementation. Replay validates existing record
snapshots and tuples instead of rewriting them. Legacy pending image budgets
consume the explicit migration timestamp unless a positive never-attempted
evidence reference is supplied; zero assets is not proof.

Migration manifest fields:

- `submissions`, `observations`: the complete SQL JSONB history and production
  adapter observations described above;
- `captures`: each verified source capture has submission ID, strong identity,
  `origin: verified_source_capture`, normalized v1 value and `evidence_ref`;
- `decisions`: one closed classification per audited identity, with the specific
  evidence/authorization references enforced by `planVerifiedBackfill`;
- `mismatch_evidence`: explicit mismatch classifications, never a percentage;
- `proposal_explanations`: exact strong identity, pending source hash and
  reference proving that source state remains unhandled;
- `never_attempted`: only positively verified pending submission IDs and
  evidence references; use an empty list for conservative image-budget
  consumption;
- `migration_timestamp`: explicit six-digit timestamp for budget consumption;
  The configured technical UUID comes only from the existing
  `EXTERNAL_EVENTS_IMPORTER_USER_ID` environment variable and is passed only to
  the real ingest RPC during dry-run. A manifest `importer_user_id` is rejected.
  Local `--plan` needs no importer environment; historical identity is never
  rewritten.

```sh
# Local JSON planning; no database access.
deno run --allow-read supabase/tools/migrate_external_events.ts manifest.json --plan
# Supply the privileged connection privately in MIGRATION_DB_URL. Never log it.
deno run --allow-read --allow-env --allow-net supabase/tools/migrate_external_events.ts manifest.json --dry-run
# ONLY after M9 release gates and operator authorization, not during implementation:
deno run --allow-read --allow-env --allow-net supabase/tools/migrate_external_events.ts manifest.json --apply
```

`--apply` additionally requires nonempty `release_gates` evidence references for
`additive_schema_notifications`, `compatible_admin_backend`,
`updated_admin_client`, `legacy_writer_frozen`, `queued_inflight_drained`,
`writer_quiescent`, `reviewed_audit_manifest`, and quiescent `t0` on the current
Europe/Rome date. These are auditable operator assertions, not an invented
runtime freeze API. The command runs the production-contract dry-run before
backfill and reports backfill separately from **NOT_EXECUTED** production
cut-over. It does not schedule, unschedule, deploy, fetch provider data,
activate ingest or retire the legacy writer. M9 owns those operational steps.
Keep the writer frozen throughout.

The new importer already uses only `ingestPreparedObservations` →
`ingest_external_event`; city/name/day similarity is advisory only. Preparing
that code does not authorize activation. Deploy/activate the provenance-aware
importer only at rollout step 8, after explicit cut-over and permanent legacy
retirement.

Apply checks the original quiescent T0 date before dry-run, again after dry-run,
and inside the committing backfill transaction immediately before completion.
Crossing Rome midnight rolls back; a fresh audit/T0 is required before cut-over.

`--plan` delivers the exported-data gate report: exact unresolved counts, closed
classifications and evidence references. Dataset kind and population evidence
must be explicit. The tool does not claim live production readiness from JSON
inputs. `--dry-run` adds `ROLLED_BACK_VERIFIED` only after the real production
RPC contract passes; an unexplained proposal fails the transaction. No mismatch
percentage is accepted. Populate `external_event_cutover_report.template.json`
with actual production evidence under M9: its counts are initially unknown and
production audit/backfill/cut-over remain **NOT_EXECUTED** in this
implementation.
