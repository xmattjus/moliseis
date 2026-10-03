import postgres from "npm:postgres@3.4.5";
import {
  prepareEvent,
} from "../functions/import-external-events/import_logic.ts";
import { buildMigrationGateReport } from "./external_event_gate_report.ts";
import { planVerifiedBackfill } from "./external_event_migration.ts";
import {
  assertReleaseDate,
  backfillVerifiedPlans,
} from "./backfill_external_events.ts";

export function assertNoManifestImporterIdentity(
  input: Record<string, unknown>,
) {
  if ("importer_user_id" in input) {
    throw new Error("manifest_importer_identity_not_allowed");
  }
}
export function configuredMigrationImporterId(): string {
  const value = Deno.env.get("EXTERNAL_EVENTS_IMPORTER_USER_ID")?.trim();
  if (!value) throw new Error("missing_configured_importer_identity");
  return value;
}

/** Explicit one-shot entry point. Production execution needs M9 release proofs. */
if (import.meta.main) {
  try {
    const [path, mode = "--plan"] = Deno.args;
    if (
      !path || Deno.args.length > 2 ||
      !["--plan", "--dry-run", "--apply"].includes(mode)
    ) throw new Error("invalid_migration_arguments");
    const input = JSON.parse(await Deno.readTextFile(path));
    assertNoManifestImporterIdentity(input);
    for (
      const key of [
        "submissions",
        "observations",
        "captures",
        "decisions",
        "mismatch_evidence",
        "proposal_explanations",
        "never_attempted",
      ]
    ) {
      if (!Array.isArray(input[key])) {
        throw new Error("incomplete_migration_manifest");
      }
    }
    const gateReport = await buildMigrationGateReport(input);
    if (mode === "--plan") {
      console.log(JSON.stringify(gateReport));
      if (!gateReport.exported_data_gates_pass) Deno.exit(1);
    } else {
      if (!gateReport.exported_data_gates_pass) {
        throw new Error("exported_data_cutover_gates_failed");
      }
      const plans = await planVerifiedBackfill(
        input.submissions,
        input.observations,
        input.captures,
        input.decisions,
        input.mismatch_evidence,
      );
      if (mode === "--apply") {
        for (
          const key of [
            "additive_schema_notifications",
            "compatible_admin_backend",
            "updated_admin_client",
            "legacy_writer_frozen",
            "queued_inflight_drained",
            "writer_quiescent",
            "reviewed_audit_manifest",
          ]
        ) {
          if (
            typeof input.release_gates?.[key] !== "string" ||
            !input.release_gates[key].trim()
          ) throw new Error("missing_release_gate_evidence");
        }
        const t0 = input.release_gates.t0;
        if (typeof t0 !== "string") {
          throw new Error("invalid_quiescent_t0_or_rome_date");
        }
        assertReleaseDate(t0, new Date().toISOString());
      }
      const dbUrl = Deno.env.get("MIGRATION_DB_URL");
      if (!dbUrl) throw new Error("missing_migration_db_url");
      const importerUserId = configuredMigrationImporterId();
      const sql = postgres(dbUrl, { max: 1, onnotice: () => {} });
      try {
        const dry = await backfillVerifiedPlans(sql, plans, {
          migration_timestamp: input.migration_timestamp,
          never_attempted: input.never_attempted,
          rollback: true,
          verify_ingest: {
            observations: input.observations.map(prepareEvent),
            importer_user_id: importerUserId,
            explanations: input.proposal_explanations,
          },
        });
        if (mode === "--apply") {
          assertReleaseDate(input.release_gates.t0, new Date().toISOString());
          await backfillVerifiedPlans(sql, plans, {
            migration_timestamp: input.migration_timestamp,
            never_attempted: input.never_attempted,
            rollback: false,
            release_guard: { t0: input.release_gates.t0 },
          });
        }
        console.log(JSON.stringify({
          execution: mode === "--apply"
            ? "VERIFIED_BACKFILL_APPLIED"
            : "TRANSACTIONAL_DRY_RUN_ROLLED_BACK",
          production_cutover: "NOT_EXECUTED",
          gate_report: {
            ...gateReport,
            production_contract_dry_run: "ROLLED_BACK_VERIFIED",
          },
          classified_records: plans.length,
          explained_pending_proposals: dry.filter((entry) =>
            entry.pending_submission_id !== null
          ).length,
        }));
      } finally {
        await sql.end();
      }
    }
  } catch (error) {
    const message = error instanceof Error && /^[a-z_]+$/.test(error.message)
      ? error.message
      : "database_or_input_failure";
    console.error(message);
    Deno.exit(1);
  }
}
