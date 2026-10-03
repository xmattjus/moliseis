import { assertEquals } from "jsr:@std/assert@1";
import {
  buildMigrationGateReport,
  type MigrationManifest,
} from "./external_event_gate_report.ts";
import { prepareEvent } from "../functions/import-external-events/import_logic.ts";
import type { LegacySubmission } from "./external_event_migration.ts";
const observation = {
  id: 42,
  title: "Source",
  date: "2026-10-02",
  time: "12:00",
  endDate: null,
  endTime: null,
  location: "City",
  locations: ["City"],
  categories: [],
  organizers: [],
  url: "https://eventimolise.it/event/fixture/",
  image: null,
};
const row = {
  ...prepareEvent(observation).normalized,
  id: 1,
  name: "Editorial enrichment",
  latitude: null,
  longitude: null,
  status: "accepted",
  handled_at: "2026-10-01T12:00:00Z",
  promoted_event_id: 10,
  promoted_place_id: null,
  target_event_id: null,
  internal_notes:
    "Imported from EventiMolise\nSource event ID: 42\nSource URL: https://eventimolise.it/event/fixture/",
} as LegacySubmission;
const manifest: MigrationManifest = {
  submissions: [row],
  observations: [observation],
  captures: [],
  decisions: [{
    identity: {
      provider: "eventimolise",
      external_id: "42",
      occurrence_key: null,
    },
    classification: "editorial_baseline",
    evidence_ref: "fixture/classification",
    baseline_authorization_ref: "fixture/operator",
  }],
  mismatch_evidence: [{
    submission_id: 1,
    kind: "editorial_moderation_enrichment",
    evidence_ref: "fixture/editorial-comparison",
  }],
  dataset_kind: "fixture",
  population_evidence_ref: "fixture/complete-population",
};
Deno.test("M8 gate report proves exported fixture counts while production and real dryrun remain NOT_EXECUTED", async () => {
  const report = await buildMigrationGateReport(manifest);
  assertEquals(report.exported_data_gates_pass, true);
  assertEquals(report.counts, {
    source_note_parse_failures: 0,
    invalid_source_observations: 0,
    ambiguous_pending: 0,
    unresolved_identity_link_conflicts: 0,
    unexplained_shadow_mismatches: 0,
    classified_records: 1,
    null_watermarks: 0,
  });
  assertEquals(report.production_audit_backfill_cutover, "NOT_EXECUTED");
  assertEquals(report.production_contract_dry_run, "NOT_EXECUTED");
  assertEquals(report.dataset_kind, "fixture");
  const failed = await buildMigrationGateReport(
    {
      ...manifest,
      mismatch_evidence: [],
      mismatch_rate_threshold: 1,
    } as MigrationManifest,
  );
  assertEquals(failed.exported_data_gates_pass, false);
  assertEquals(failed.counts.unexplained_shadow_mismatches, 1);
  assertEquals(
    (await buildMigrationGateReport({
      ...manifest,
      population_evidence_ref: "",
    })).exported_data_gates_pass,
    false,
  );
});
Deno.test("M8 report does not reinterpret invalid provider observations as verified absence", async () => {
  const report = await buildMigrationGateReport({
    ...manifest,
    observations: [{ ...observation, date: "2026-02-30" }],
    decisions: [{
      ...manifest.decisions[0],
      classification: "retain_legacy",
      availability_evidence_ref: "invalid-is-not-absence",
    }],
  });
  assertEquals(report.exported_data_gates_pass, false);
  assertEquals(report.counts.invalid_source_observations, 1);
  assertEquals(report.counts.classified_records, null);
});
