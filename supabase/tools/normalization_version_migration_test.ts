import { assertEquals } from "jsr:@std/assert@1";
import {
  planNormalizationVersionMigration,
  type VersionSnapshot,
} from "./normalization_version_migration.ts";
import {
  canonicalizeExternalEvent,
  hashNormalizedExternalEvent,
} from "../functions/_shared/external_event_normalization.ts";
async function snapshot(
  name: string,
  version: number,
): Promise<VersionSnapshot> {
  const normalized = canonicalizeExternalEvent({
    name,
    city: "City",
    category: "unknown",
    description: null,
    description_delta: null,
    latitude: null,
    longitude: null,
    all_day: false,
    start_date: "2026-10-02T12:00:00.123456Z",
    end_date: null,
  });
  return {
    normalized,
    normalization_version: version,
    moderation_hash: await hashNormalizedExternalEvent(normalized),
  };
}
Deno.test("M8 explicit version procedure converts current/proposed/all pending and recomputes hashes via shared canonicalizer", async () => {
  // Synthetic next version retains v1 shape for policy testing, not a runtime v2 contract.
  const current = await snapshot("Current", 1),
    proposed = await snapshot("Handled", 1),
    pending = await snapshot("Pending", 1);
  const convertedCurrent = await snapshot("Converted current", 2),
    convertedProposed = await snapshot("Converted handled", 2),
    convertedPending = await snapshot("Converted pending", 2);
  const result = planNormalizationVersionMigration({
    current,
    proposed,
    pending: [{ submission_id: 10, snapshot: pending }],
  }, {
    target_version: 2,
    evidence_ref: "explicit-converter-evidence",
    converted_current: convertedCurrent,
    converted_proposed: convertedProposed,
    converted_pending: [{ submission_id: 10, snapshot: convertedPending }],
  });
  assertEquals(result.outcome, "ready");
  if (result.outcome !== "ready") return;
  assertEquals(result.mode, "derived");
  assertEquals(result.current, convertedCurrent);
  assertEquals(result.proposed, convertedProposed);
  assertEquals(result.pending[0].snapshot, convertedPending);
  assertEquals(
    result.current.moderation_hash === current.moderation_hash,
    false,
  );
});
Deno.test("M8 refetch may establish baseline only for accounted old state; unconvertible proposed/pending blocks", async () => {
  const current = await snapshot("Current", 1),
    proposed = await snapshot("Handled", 1),
    refetched = await snapshot("Refetched", 2),
    convertedProposed = await snapshot("Converted handled", 2);
  const evidence = {
    target_version: 2,
    evidence_ref: "explicit-provider-refetch",
    converted_pending: [],
    refetched_current: refetched,
  };
  const baseline = planNormalizationVersionMigration({
    current,
    proposed: current,
    pending: [],
  }, evidence);
  assertEquals(baseline.outcome, "ready");
  if (baseline.outcome === "ready") {
    assertEquals(baseline.mode, "refetch_baseline");
    assertEquals(baseline.current, baseline.proposed);
  }
  assertEquals(
    planNormalizationVersionMigration(
      { current, proposed, pending: [] },
      evidence,
    ),
    {
      outcome: "migration_conflict",
      reason: "unconvertible_proposed_snapshot",
    },
  );
  const divergent = planNormalizationVersionMigration({
    current,
    proposed,
    pending: [],
  }, { ...evidence, converted_proposed: convertedProposed });
  assertEquals(divergent.outcome, "ready");
  if (divergent.outcome === "ready") {
    assertEquals(divergent.mode, "refetch_preserve_unhandled");
    assertEquals(divergent.proposed, convertedProposed);
  }
  assertEquals(
    planNormalizationVersionMigration({
      current,
      proposed: current,
      pending: [],
    }, {
      ...evidence,
      converted_current: refetched,
      converted_proposed: convertedProposed,
    }),
    {
      outcome: "migration_conflict",
      reason: "conversion_creates_unhandled_divergence",
    },
  );
  const unhandled = planNormalizationVersionMigration({
    current,
    proposed: null,
    pending: [],
  }, evidence);
  assertEquals(unhandled.outcome, "ready");
  if (unhandled.outcome === "ready") assertEquals(unhandled.proposed, null);
  assertEquals(
    planNormalizationVersionMigration({
      current,
      proposed: current,
      pending: [{ submission_id: 1, snapshot: current }],
    }, evidence),
    { outcome: "migration_conflict", reason: "unconvertible_pending_snapshot" },
  );
  assertEquals(
    planNormalizationVersionMigration({ current, proposed, pending: [] }, {
      ...evidence,
      converted_proposed: refetched,
    }),
    {
      outcome: "migration_conflict",
      reason: "conversion_erases_unhandled_divergence",
    },
  );
});
