import { assertEquals, assertRejects, assertThrows } from "jsr:@std/assert@1";
import {
  auditLegacySources,
  identityAndSnapshotGate,
  type LegacySubmission,
  MIGRATION_CLASSIFICATIONS,
  parseLegacySourceNotes,
  planVerifiedBackfill,
  shadowCompare,
  verifiedSubmissionSnapshots,
} from "./external_event_migration.ts";
import type { EventiMoliseEvent } from "../functions/import-external-events/eventimolise.ts";
import { prepareEvent } from "../functions/import-external-events/import_logic.ts";
const notes = (id: number) =>
  `Imported from EventiMolise\nSource event ID: ${id}\nSource URL: https://eventimolise.it/event/fixture/`;
const row = (
  id: number,
  event: number | null = null,
) => ({
  id,
  internal_notes: notes(42),
  status: "accepted",
  handled_at: `2026-10-02T10:00:0${id}Z`,
  promoted_event_id: event,
  target_event_id: null,
} as LegacySubmission);
const observation: EventiMoliseEvent = {
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
Deno.test("M8 identity audit reports parse, duplicate occurrence, history ordering and canonical-link conflicts", async () => {
  const report = await auditLegacySources([row(2, 10), row(1, 11), {
    ...row(3),
    internal_notes: "bad",
  }], [observation, observation, { ...observation, date: "2026-02-30" }]);
  assertEquals(report.parse_failures.length, 1);
  assertEquals(report.observation_failures.length, 1);
  const identity = report.identities[0];
  assertEquals(identity.identity, ["eventimolise", "42", null]);
  assertEquals(identity.multiple_canonical_events, true);
  assertEquals(identity.duplicate_current_occurrences, 2);
  assertEquals(identity.current_source_available, true);
  assertEquals(identity.handled_order.map((entry) => entry.id), [2, 1]);
  assertEquals(identity.historical_identity_count, 2);
  assertEquals(identity.duplicate_historical_identity, true);
  assertEquals(identity.shadow?.name, "Source");
  const absent = await auditLegacySources([row(1)], []);
  assertEquals(absent.identities[0].current_source_available, false);
});

Deno.test("M8 shadow interpretation reuses production adapter and requires explicit mismatch evidence", async () => {
  const historical = {
    ...row(1),
    name: "Edited",
    city: "City",
    category: "unknown",
    description: null,
    description_delta: null,
    latitude: null,
    longitude: null,
    all_day: false,
    start_date: "2026-10-02T10:00:00.000000Z",
    end_date: null,
  } as LegacySubmission;
  const before = JSON.stringify(historical);
  assertEquals(
    (await shadowCompare([historical], [observation]))[0].state,
    "unresolved",
  );
  for (
    const kind of [
      "source_evolution",
      "editorial_moderation_enrichment",
      "known_importer_transformation",
    ] as const
  ) {
    const [comparison] = await shadowCompare([historical], [observation], [{
      submission_id: 1,
      kind,
      evidence_ref: "audit/fixture-1",
    }]);
    assertEquals(comparison.state, kind);
    assertEquals(comparison.fields, ["name"]);
  }
  assertEquals(
    (await shadowCompare([{ ...historical, name: "Source" }], [observation]))[0]
      .state,
    "equal",
  );
  assertEquals((await shadowCompare([historical], []))[0].state, "unresolved");
  assertEquals(JSON.stringify(historical), before);
});
Deno.test("M8 notes never silently guess invalid or ambiguous identity", () => {
  assertEquals(parseLegacySourceNotes(notes(42)), {
    provider: "eventimolise",
    external_id: "42",
    occurrence_key: null,
  });
  for (
    const value of [
      null,
      notes(0),
      notes(42) + "\nSource event ID: 43",
      notes(42).replace("https:", "http:"),
      notes(42).replace("eventimolise.it", "example.test"),
    ]
  ) assertThrows(() => parseLegacySourceNotes(value));
});

Deno.test("M8 immutable tuple derives only from its own verified capture, never edited legacy columns", async () => {
  const historical = { ...row(1), name: "Moderator enrichment" };
  const capture = {
    submission_id: 1,
    identity: parseLegacySourceNotes(notes(42)),
    origin: "verified_source_capture" as const,
    evidence_ref: "captures/42/revision1",
    normalized: prepareEvent(observation).normalized,
  };
  const [tuple] = await verifiedSubmissionSnapshots([historical], [capture]);
  assertEquals(tuple.external_normalized.name, "Source");
  assertEquals(historical.name, "Moderator enrichment");
  assertEquals(await verifiedSubmissionSnapshots([historical], []), []);
  await assertRejects(
    () =>
      verifiedSubmissionSnapshots([historical], [{
        ...capture,
        evidence_ref: "",
      }]),
    Error,
    "unverified_source_snapshot",
  );
  await assertRejects(
    () =>
      verifiedSubmissionSnapshots([historical], [{
        ...capture,
        identity: { ...capture.identity, external_id: "43" },
      }]),
    Error,
    "snapshot_identity_mismatch",
  );
  await assertRejects(
    () => verifiedSubmissionSnapshots([historical], [capture, capture]),
    Error,
    "duplicate_snapshot_evidence",
  );
});

Deno.test("M8 identity/snapshot gate covers omitted and malformed pending; link conflicts cannot be waived", async () => {
  const pending = { ...row(1), status: "pending" as const };
  assertEquals(
    (await identityAndSnapshotGate([pending], [observation], []))
      .ambiguous_pending,
    [1],
  );
  assertEquals(
    (await identityAndSnapshotGate([{ ...pending, internal_notes: "bad" }], [
      observation,
    ], [])).pass,
    false,
  );
  const capture = {
    submission_id: 1,
    identity: parseLegacySourceNotes(notes(42)),
    origin: "verified_source_capture" as const,
    evidence_ref: "capture",
    normalized: prepareEvent(observation).normalized,
  };
  assertEquals(
    (await identityAndSnapshotGate([pending], [observation], [capture])).pass,
    true,
  );
  const conflict = await identityAndSnapshotGate(
    [pending, row(2, 10), row(3, 11)],
    [observation],
    [capture],
  );
  assertEquals(conflict.pass, false);
  assertEquals(conflict.unresolved_identity_link_conflicts.length, 1);
});

Deno.test("M8 closed classification explains all seven watermark states and keeps newer pending immutable", async () => {
  const normalized = prepareEvent(observation).normalized;
  const old = { ...normalized, name: "Old source" };
  const accepted = {
    ...row(1, 10),
    ...normalized,
    latitude: null,
    longitude: null,
    name: "Editorial name",
  };
  const rejected = {
    ...accepted,
    status: "rejected" as const,
    promoted_event_id: null,
  };
  const pending = {
    ...row(2),
    ...normalized,
    status: "pending" as const,
    latitude: null,
    longitude: null,
    handled_at: null,
  };
  const identity = parseLegacySourceNotes(notes(42));
  const capture = {
    submission_id: 2,
    identity,
    origin: "verified_source_capture" as const,
    evidence_ref: "pending-capture",
    normalized,
  };
  const base = {
    identity,
    evidence_ref: "classification",
    baseline_authorization_ref: "operator/baseline",
  };
  for (const classification of MIGRATION_CLASSIFICATIONS) {
    const unhandled = classification === "verified_unhandled";
    const rejectedMode = classification === "rejected_baseline" ||
      classification === "ignored_baseline";
    const history = unhandled
      ? [pending]
      : rejectedMode
      ? [rejected]
      : [accepted, pending];
    const absent = classification === "verified_no_longer_observable";
    const decision = {
      ...base,
      classification,
      last_handled_submission_id: 1,
      handled_snapshot: { normalized: old, evidence_ref: "handled-capture" },
      availability_evidence_ref: "provider/discovery-absence",
      never_handled_evidence_ref: "complete-history-never-handled",
      remediation_ref: "manual-reconciliation",
      ignore_authorization_ref: "operator/ignore",
    };
    const [plan] = await planVerifiedBackfill(
      history,
      absent ? [] : [observation],
      history.includes(pending) ? [capture] : [],
      [decision],
      [{
        submission_id: 1,
        kind: "editorial_moderation_enrichment",
        evidence_ref: "editorial-review",
      }],
    );
    assertEquals(plan.classification, classification);
    assertEquals(plan.proposed === null, unhandled);
    assertEquals(plan.ignored, classification === "ignored_baseline");
    if (classification === "verified_handled") {
      assertEquals(plan.current.name, "Source");
      assertEquals(plan.proposed?.name, "Old source");
      assertEquals(plan.tuples[0].external_normalized.name, "Source");
    }
    if (!["verified_handled", "verified_unhandled"].includes(classification)) {
      assertEquals(plan.current, plan.proposed);
    }
    assertEquals(plan.tuples.some((tuple) => tuple.submission_id === 1), false);
  }
  await assertRejects(
    () =>
      planVerifiedBackfill([accepted], [observation], [], [{
        ...base,
        classification: "verified_unhandled",
        never_handled_evidence_ref: "missing-is-not-proof",
      }]),
    Error,
    "verified_never_handled_evidence_required",
  );
  await assertRejects(
    () => planVerifiedBackfill([accepted], [observation], [], []),
    Error,
    "incomplete_history_classification",
  );
});

Deno.test("M8 contradictory handled capture, unverifiable-baseline capture and accepted Place history are rejected", async () => {
  const normalized = prepareEvent(observation).normalized;
  const historical = {
    ...row(1, 10),
    ...normalized,
    latitude: null,
    longitude: null,
  };
  const identity = parseLegacySourceNotes(notes(42));
  const capture = {
    submission_id: 1,
    identity,
    origin: "verified_source_capture" as const,
    evidence_ref: "capture",
    normalized,
  };
  const decision = {
    identity,
    classification: "verified_handled" as const,
    evidence_ref: "decision",
    last_handled_submission_id: 1,
    handled_snapshot: {
      normalized: { ...normalized, name: "Different snapshot" },
      evidence_ref: "contradiction",
    },
  };
  await assertRejects(
    () =>
      planVerifiedBackfill([historical], [observation], [capture], [decision]),
    Error,
    "conflicting_handled_snapshot_evidence",
  );
  await assertRejects(
    () =>
      planVerifiedBackfill([historical], [observation], [capture], [{
        ...decision,
        handled_snapshot: undefined,
        classification: "editorial_baseline",
        baseline_authorization_ref: "operator",
      }]),
    Error,
    "unverifiable_baseline_has_verified_latest_snapshot",
  );
  await assertRejects(
    () =>
      planVerifiedBackfill(
        [{ ...historical, promoted_event_id: null, promoted_place_id: 99 }],
        [observation],
        [],
        [decision],
      ),
    Error,
    "accepted_place_history_requires_remediation",
  );
  await assertRejects(
    () =>
      verifiedSubmissionSnapshots([historical], [
        { ...capture, origin: "moderated_row" } as unknown as typeof capture,
      ]),
    Error,
    "unverified_source_snapshot",
  );
  await assertRejects(
    () => identityAndSnapshotGate([historical, historical], [observation], []),
    Error,
    "duplicate_export_submission_id",
  );
});

Deno.test("M8 invalid-only or valid-plus-invalid observations cannot pass absence/current classification", async () => {
  const normalized = prepareEvent(observation).normalized;
  const history = {
    ...row(1),
    ...normalized,
    latitude: null,
    longitude: null,
    status: "rejected" as const,
  };
  const identity = parseLegacySourceNotes(notes(42));
  const capture = { normalized, evidence_ref: "handled-capture" };
  const decision = {
    identity,
    classification: "verified_no_longer_observable" as const,
    evidence_ref: "decision",
    availability_evidence_ref: "absence-claim",
    last_handled_submission_id: 1,
    handled_snapshot: capture,
  };
  for (
    const observations of [[{ ...observation, date: "2026-02-30" }], [
      observation,
      { ...observation, date: "2026-02-30" },
    ]]
  ) {
    assertEquals(
      (await identityAndSnapshotGate([history], observations, [])).pass,
      false,
    );
    await assertRejects(
      () => planVerifiedBackfill([history], observations, [], [decision]),
      Error,
      "identity_or_pending_snapshot_gate_failed",
    );
  }
});

Deno.test("M8 genuine drift in unverifiable accepted history blocks until explicit reconciliation and baseline authorization", async () => {
  const normalized = prepareEvent(observation).normalized;
  const history = {
    ...row(1, 10),
    ...normalized,
    name: "Canonical editorial value",
    latitude: null,
    longitude: null,
  };
  const base = {
    identity: parseLegacySourceNotes(notes(42)),
    classification: "remediated_real_drift" as const,
    evidence_ref: "audited-real-drift",
  };
  await assertRejects(
    () => planVerifiedBackfill([history], [observation], [], [base]),
    Error,
    "real_drift_remediation_required",
  );
  await assertRejects(
    () =>
      planVerifiedBackfill([history], [observation], [], [{
        ...base,
        remediation_ref: "reconciled-event",
      }]),
    Error,
    "real_drift_remediation_required",
  );
  await assertRejects(
    () =>
      planVerifiedBackfill([history], [observation], [], [{
        ...base,
        classification: "verified_handled",
      }]),
    Error,
    "verified_handled_evidence_required",
  );
  const [plan] = await planVerifiedBackfill([history], [observation], [], [{
    ...base,
    remediation_ref: "reconciled-event",
    baseline_authorization_ref: "operator-authorized-current-baseline",
  }]);
  assertEquals(plan.current, plan.proposed);
  assertEquals(plan.event_id, 10);
  assertEquals(plan.tuples, []);
});

Deno.test("M8 rejected/ignored baselines require authorization; verified absence without source evidence creates no record", async () => {
  const normalized = prepareEvent(observation).normalized;
  const history = {
    ...row(1),
    ...normalized,
    latitude: null,
    longitude: null,
    status: "rejected" as const,
  };
  const base = {
    identity: parseLegacySourceNotes(notes(42)),
    classification: "rejected_baseline" as const,
    evidence_ref: "reviewed-rejection",
  };
  await assertRejects(
    () => planVerifiedBackfill([history], [observation], [], [base]),
    Error,
    "rejected_baseline_authorization_required",
  );
  await assertRejects(
    () =>
      planVerifiedBackfill([history], [observation], [], [{
        ...base,
        classification: "ignored_baseline",
        baseline_authorization_ref: "baseline",
      }]),
    Error,
    "rejected_baseline_authorization_required",
  );
  await assertRejects(
    () =>
      planVerifiedBackfill([history], [], [], [{
        ...base,
        classification: "verified_no_longer_observable",
        availability_evidence_ref: "verified-discovery-absence",
        last_handled_submission_id: 1,
      }]),
    Error,
    "verified_absence_and_handled_snapshot_required",
  );
  await assertRejects(
    () =>
      planVerifiedBackfill([history], [], [], [{
        ...base,
        classification: "retain_legacy",
      }]),
    Error,
    "retain_legacy_requires_verified_absence_without_snapshot",
  );
  assertEquals(
    await planVerifiedBackfill([history], [], [], [{
      ...base,
      classification: "retain_legacy",
      availability_evidence_ref: "verified-discovery-absence",
    }]),
    [],
  );
  const [plan] = await planVerifiedBackfill([history], [], [], [{
    ...base,
    classification: "verified_no_longer_observable",
    availability_evidence_ref: "verified-discovery-absence",
    last_handled_submission_id: 1,
    handled_snapshot: {
      normalized,
      evidence_ref: "verified-last-handled-capture",
    },
  }]);
  assertEquals(plan.current, plan.proposed);
  assertEquals(plan.proposed_hash === null, false);
  assertEquals(plan.tuples, []);
});

Deno.test("M8 multiple verified legacy pending revisions for one strong identity require remediation before partial UNIQUE backfill", async () => {
  const normalized = prepareEvent(observation).normalized;
  const history = [
    { ...row(1), status: "pending" as const, handled_at: null },
    { ...row(2), status: "pending" as const, handled_at: null },
  ];
  const identity = parseLegacySourceNotes(notes(42));
  const captures = history.map((row) => ({
    submission_id: row.id,
    identity,
    origin: "verified_source_capture" as const,
    evidence_ref: `verified/${row.id}`,
    normalized,
  }));
  const gate = await identityAndSnapshotGate(history, [observation], captures);
  assertEquals(gate.pass, false);
  assertEquals(gate.ambiguous_pending, [1, 2]);
  await assertRejects(
    () =>
      planVerifiedBackfill(history, [observation], captures, [{
        identity,
        classification: "verified_unhandled",
        evidence_ref: "reviewed",
        never_handled_evidence_ref: "no-handled-revision",
      }]),
    Error,
    "identity_or_pending_snapshot_gate_failed",
  );
});
