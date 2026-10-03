import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  assertLegacyRestoreAllowed,
  assertReadyBeforeLegacyFreeze,
  assertReleaseDate,
  UPDATED_ADMIN_PROBES,
} from "./external_event_rollout_preflight.ts";
export const readiness = {
  release_gates: {
    additive_schema_notifications: "fixture/schema-notification-probes",
    compatible_admin_backend: "fixture/edge-before-rpc-409",
    updated_admin_client: "fixture/released-client-build",
  },
  updated_client_probe_refs: Object.fromEntries(
    UPDATED_ADMIN_PROBES.map((key) => [key, `fixture/${key}`]),
  ),
};
Deno.test("M9 missing updated client or update/ignore/stale path blocks before any freeze; legacy 409 alone cannot substitute", () => {
  let freezeCalls = 0;
  const freeze = (evidence: typeof readiness) => {
    assertReadyBeforeLegacyFreeze(evidence);
    freezeCalls++;
  };
  assertThrows(
    () =>
      freeze({
        ...readiness,
        release_gates: { ...readiness.release_gates, updated_admin_client: "" },
      }),
    Error,
    "missing_prefreeze_updated_admin_client",
  );
  for (const probe of UPDATED_ADMIN_PROBES) {
    assertThrows(() =>
      freeze({
        ...readiness,
        updated_client_probe_refs: {
          ...readiness.updated_client_probe_refs,
          [probe]: "",
        },
      })
    );
  }
  assertEquals(freezeCalls, 0);
  freeze(readiness);
  assertEquals(freezeCalls, 1);
});
Deno.test("M9 same-Rome-date success and pre-cutover abandonment require fresh T0; post-cutover legacy restore always rejected", () => {
  const t0 = "2026-10-02T21:00:00Z";
  assertReleaseDate(t0, "2026-10-02T21:59:59Z");
  assertThrows(
    () => assertReleaseDate(t0, "2026-10-02T22:00:00Z"),
    Error,
    "invalid_quiescent_t0_or_rome_date",
  );
  const expiredAudit = { discarded: false };
  let restores = 0;
  expiredAudit.discarded = true;
  assertLegacyRestoreAllowed(null);
  restores++;
  assertEquals(expiredAudit.discarded, true);
  assertEquals(restores, 1);
  assertReleaseDate("2026-10-03T08:00:00Z", "2026-10-03T09:00:00Z");
  assertThrows(
    () => {
      assertLegacyRestoreAllowed("fixture/signed-provenance-cutover");
      restores++;
    },
    Error,
    "legacy_writer_permanently_retired",
  );
  assertEquals(restores, 1);
});

Deno.test("post-cutover runbook names the operator-managed provenance activation and stop explicitly", async () => {
  const runbook = await Deno.readTextFile(
    new URL("./external_event_deployment_runbook.md", import.meta.url),
  );
  assert(
    /provenance cron is operator-managed and intentionally not created by schema\s+migrations/
      .test(runbook),
  );
  assert(!/same named schedule|new named schedule/i.test(runbook));
  const activation = runbook.split(
    "## 8. Activate only the provenance-aware importer",
  )[1]?.split("## Abandonment and rollback")[0];
  assert(activation, "The gated activation step must remain explicit.");
  const scheduler = activation.match(/```sql\n([\s\S]*?)```/)?.[1];
  assert(scheduler, "Activation must include executable scheduler SQL.");
  assert(scheduler.includes("cron.schedule_in_database("));
  assert(
    scheduler.includes("'import-external-events-eventimolise-provenance'"),
  );
  assert(scheduler.includes("'0 22,23 * * *'"));
  assert(scheduler.includes("import_external_events_function_url"));
  assert(scheduler.includes("import_external_events_cron_secret"));
  assert(scheduler.includes("x-import-secret"));
  assert(scheduler.includes("120000"));
  for (
    const [key, value] of [
      ["source", "'eventimolise'"],
      ["dry_run", "false"],
      ["limit", "20"],
      ["mode", "'scheduled'"],
    ]
  ) {
    assert(new RegExp(`'${key}'\\s*,\\s*${value}`).test(scheduler));
  }
  assert(
    !/cron\.schedule(?:_in_database)?\(\s*'import-external-events-eventimolise'/
      .test(runbook),
    "The runbook must never schedule the retired legacy job.",
  );
  const postCutover = runbook.split("**After cut-over:**")[1];
  assert(
    postCutover?.includes("import-external-events-eventimolise-provenance"),
  );
  assert(
    postCutover?.includes("cron.unschedule"),
    "Post-cutover stop must include explicit executable scheduler removal.",
  );
});
