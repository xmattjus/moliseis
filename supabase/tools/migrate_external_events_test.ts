import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  assertNoManifestImporterIdentity,
  configuredMigrationImporterId,
} from "./migrate_external_events.ts";
Deno.test("M8 CLI seed identity comes only from existing runtime env; manifest cannot control it", () => {
  const name = "EXTERNAL_EVENTS_IMPORTER_USER_ID";
  const previous = Deno.env.get(name);
  try {
    Deno.env.set(name, "00000000-0000-4000-8000-000000000001");
    assertEquals(
      configuredMigrationImporterId(),
      "00000000-0000-4000-8000-000000000001",
    );
    assertThrows(
      () =>
        assertNoManifestImporterIdentity({
          importer_user_id: "00000000-0000-4000-8000-000000000002",
        }),
      Error,
      "manifest_importer_identity_not_allowed",
    );
    assertNoManifestImporterIdentity({});
    Deno.env.delete(name);
    assertThrows(
      () => configuredMigrationImporterId(),
      Error,
      "missing_configured_importer_identity",
    );
    // Plan validation does not read importer env or resolve Auth.
    assertNoManifestImporterIdentity({});
  } finally {
    if (previous === undefined) Deno.env.delete(name);
    else Deno.env.set(name, previous);
  }
});

Deno.test("M8 actual --plan subprocess prints structured blocking diagnostics before any DB or importer-env access", async () => {
  const path = await Deno.makeTempFile({
    dir: "/tmp",
    prefix: "moliseis-m8-plan-",
    suffix: ".json",
  });
  try {
    const notes =
      "Imported from EventiMolise\nSource event ID: 42\nSource URL: https://eventimolise.it/event/fixture/";
    const pending = {
      id: 1,
      status: "pending",
      handled_at: null,
      promoted_event_id: null,
      promoted_place_id: null,
      target_event_id: null,
      internal_notes: notes,
    };
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
    for (const invalid of [true, false]) {
      const input = {
        submissions: [pending],
        observations: [
          invalid ? { ...observation, date: "2026-02-30" } : observation,
        ],
        captures: [],
        decisions: [],
        mismatch_evidence: [],
        proposal_explanations: [],
        never_attempted: [],
        dataset_kind: "fixture",
        population_evidence_ref: "fixture-population",
      };
      await Deno.writeTextFile(path, JSON.stringify(input));
      const result = await new Deno.Command(Deno.execPath(), {
        args: [
          "run",
          "--allow-read",
          new URL("./migrate_external_events.ts", import.meta.url).href,
          path,
          "--plan",
        ],
        stdout: "piped",
        stderr: "piped",
      }).output();
      assertEquals(result.code, 1);
      const report = JSON.parse(new TextDecoder().decode(result.stdout));
      assertEquals(report.exported_data_gates_pass, false);
      assertEquals(report.counts.ambiguous_pending, 1);
      assertEquals(report.counts.invalid_source_observations, invalid ? 1 : 0);
      assertEquals(report.production_contract_dry_run, "NOT_EXECUTED");
      assertEquals(report.production_audit_backfill_cutover, "NOT_EXECUTED");
    }
  } finally {
    await Deno.remove(path);
  }
});
