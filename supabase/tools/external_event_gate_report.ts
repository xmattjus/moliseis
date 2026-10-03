import {
  auditLegacySources,
  identityAndSnapshotGate,
  type LegacySubmission,
  type MismatchEvidence,
  planVerifiedBackfill,
  type RecordDecision,
  shadowCompare,
  type SnapshotEvidence,
} from "./external_event_migration.ts";
import type { EventiMoliseEvent } from "../functions/import-external-events/eventimolise.ts";
export type MigrationManifest = {
  submissions: LegacySubmission[];
  observations: EventiMoliseEvent[];
  captures: SnapshotEvidence[];
  decisions: RecordDecision[];
  mismatch_evidence: MismatchEvidence[];
  dataset_kind: "fixture" | "production_export";
  population_evidence_ref: string;
};
/** Export diagnostics never certify live production freeze/backfill/cut-over. */
export async function buildMigrationGateReport(input: MigrationManifest) {
  const audit = await auditLegacySources(input.submissions, input.observations);
  const comparisons = await shadowCompare(
    input.submissions,
    input.observations,
    input.mismatch_evidence,
  );
  let classificationError: string | null = null;
  let plans: Awaited<ReturnType<typeof planVerifiedBackfill>> | null = null;
  let identityGate: Awaited<ReturnType<typeof identityAndSnapshotGate>> | null =
    null;
  try {
    identityGate = await identityAndSnapshotGate(
      input.submissions,
      input.observations,
      input.captures,
    );
    plans = await planVerifiedBackfill(
      input.submissions,
      input.observations,
      input.captures,
      input.decisions,
      input.mismatch_evidence,
    );
  } catch (error) {
    classificationError = error instanceof Error
      ? error.message
      : "invalid_migration_manifest";
  }
  const unexplained = comparisons.filter((entry) => {
    if (entry.state !== "unresolved") return false;
    if (entry.reason !== "source_unavailable" || plans === null) return true;
    return !input.decisions.some((decision) =>
      ["verified_no_longer_observable", "retain_legacy"].includes(
        decision.classification,
      ) && !!decision.availability_evidence_ref?.trim() &&
      audit.identities.some((identity) =>
        JSON.stringify(identity.identity) ===
          JSON.stringify([
            decision.identity.provider,
            decision.identity.external_id,
            decision.identity.occurrence_key,
          ]) && identity.submission_ids.includes(entry.submission_id)
      )
    );
  });
  const populationVerified = !!input.population_evidence_ref?.trim() &&
    ["fixture", "production_export"].includes(input.dataset_kind);
  return {
    execution: "EXPORTED_DATA_ONLY",
    dataset_kind: input.dataset_kind,
    population_evidence_ref: input.population_evidence_ref,
    production_audit_backfill_cutover: "NOT_EXECUTED",
    production_contract_dry_run: "NOT_EXECUTED",
    exported_data_gates_pass: populationVerified &&
      identityGate?.pass === true && plans !== null && unexplained.length === 0,
    counts: {
      source_note_parse_failures: audit.parse_failures.length,
      invalid_source_observations: audit.observation_failures.length,
      ambiguous_pending: identityGate?.ambiguous_pending.length ?? null,
      unresolved_identity_link_conflicts:
        identityGate?.unresolved_identity_link_conflicts.length ?? null,
      unexplained_shadow_mismatches: unexplained.length,
      classified_records: plans?.length ?? null,
      null_watermarks: plans?.filter((plan) => plan.proposed === null).length ??
        null,
    },
    classification_error: classificationError,
    unresolved_submission_ids: unexplained.map((entry) => entry.submission_id),
    classifications: plans?.map((plan) => ({
      identity: plan.identity,
      classification: plan.classification,
      evidence_ref: plan.evidence_ref,
    })) ?? [],
  };
}
