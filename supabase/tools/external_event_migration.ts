import {
  canonicalizeEventTimestamp,
  canonicalizeExternalEvent,
  canonicalizeSubmission,
  EXTERNAL_EVENT_NORMALIZATION_VERSION,
  hashNormalizedExternalEvent,
  type NormalizedExternalEvent,
} from "../functions/_shared/external_event_normalization.ts";
import type { Database } from "../functions/_shared/database.types.ts";
import {
  type PreparedExternalEvent,
  prepareEvent,
} from "../functions/import-external-events/import_logic.ts";
import type { EventiMoliseEvent } from "../functions/import-external-events/eventimolise.ts";

export type LegacySubmission =
  Database["public"]["Tables"]["content_submissions"]["Row"];
export type SourceIdentity = {
  provider: "eventimolise";
  external_id: string;
  occurrence_key: null;
};
export function identityKey(identity: SourceIdentity): string {
  return JSON.stringify([
    identity.provider,
    identity.external_id,
    identity.occurrence_key,
  ]);
}

/** Notes identify a source; they are never evidence of its original contents. */
export function parseLegacySourceNotes(notes: string | null): SourceIdentity {
  if (!notes?.startsWith("Imported from EventiMolise\n")) {
    throw new Error("missing_importer_header");
  }
  const ids = [...notes.matchAll(/^Source event ID: ([1-9]\d*)$/gm)];
  const urls = [...notes.matchAll(/^Source URL: (\S+)$/gm)];
  if (
    ids.length !== 1 || urls.length !== 1 ||
    !Number.isSafeInteger(Number(ids[0][1]))
  ) throw new Error("invalid_source_notes");
  const url = new URL(urls[0][1]);
  if (
    url.protocol !== "https:" || url.hostname !== "eventimolise.it" ||
    !url.pathname.startsWith("/event/") || url.username || url.password
  ) throw new Error("invalid_source_url");
  return {
    provider: "eventimolise",
    external_id: ids[0][1],
    occurrence_key: null,
  };
}

/** Local exported data only: no fetching, credentials, writes or implicit dedup. */
export async function auditLegacySources(
  rows: LegacySubmission[],
  observations: EventiMoliseEvent[],
) {
  const source = new Map<string, PreparedExternalEvent[]>();
  const observationFailures: Array<{ index: number; error: string }> = [];
  observations.forEach((observation, index) => {
    try {
      const prepared = prepareEvent(observation);
      const key = identityKey({
        provider: prepared.provider,
        external_id: prepared.externalId,
        occurrence_key: prepared.occurrenceKey as null,
      });
      source.set(key, [...(source.get(key) ?? []), prepared]);
    } catch (error) {
      observationFailures.push({ index, error: String(error) });
    }
  });
  const parseFailures: Array<{ submission_id: number; error: string }> = [];
  const groups = new Map<string, LegacySubmission[]>();
  for (const row of rows) {
    try {
      const key = identityKey(parseLegacySourceNotes(row.internal_notes));
      groups.set(key, [...(groups.get(key) ?? []), row]);
    } catch (error) {
      parseFailures.push({ submission_id: row.id, error: String(error) });
    }
  }
  const identities = await Promise.all(
    [...groups].map(async ([key, history]) => {
      const observed = source.get(key) ?? [];
      const hashes = await Promise.all(
        observed.map((event) => hashNormalizedExternalEvent(event.normalized)),
      );
      const links = [
        ...new Set(
          history.map((row) => row.promoted_event_id ?? row.target_event_id)
            .filter((id) => id !== null),
        ),
      ];
      return {
        identity: JSON.parse(key) as [string, string, null],
        submission_ids: history.map((row) => row.id),
        historical_identity_count: history.length,
        duplicate_historical_identity: history.length > 1,
        statuses: history.map((row) => ({ id: row.id, status: row.status })),
        handled_order: [...history].sort((a, b) =>
          (b.handled_at == null ? "" : canonicalizeEventTimestamp(b.handled_at))
            .localeCompare(
              a.handled_at == null
                ? ""
                : canonicalizeEventTimestamp(a.handled_at),
            ) || b.id - a.id
        ).map((row) => ({ id: row.id, handled_at: row.handled_at })),
        event_links: links,
        multiple_canonical_events: links.length > 1,
        current_source_available: observed.length > 0,
        duplicate_current_occurrences: observed.length,
        conflicting_current_snapshots: new Set(hashes).size > 1,
        shadow: observed[0]?.normalized ?? null,
      };
    }),
  );
  return {
    execution: "EXPORTED_DATA_ONLY",
    parse_failures: parseFailures,
    observation_failures: observationFailures,
    identities,
  };
}

// Re-export the existing boundary for shadow comparison; no migration-specific
// temporal/Unicode/coordinate implementation is permitted here.
export { canonicalizeSubmission };

export type SnapshotEvidence = {
  submission_id: number;
  identity: SourceIdentity;
  origin: "verified_source_capture";
  evidence_ref: string;
  normalized: NormalizedExternalEvent;
};

/** Each populated tuple owns its evidence, independently of record baseline. */
export async function verifiedSubmissionSnapshots(
  rows: LegacySubmission[],
  evidence: SnapshotEvidence[],
) {
  const seen = new Set<number>();
  return await Promise.all(evidence.map(async (capture) => {
    if (seen.has(capture.submission_id)) {
      throw new Error("duplicate_snapshot_evidence");
    }
    seen.add(capture.submission_id);
    const row = rows.find((candidate) =>
      candidate.id === capture.submission_id
    );
    if (
      !row || capture.origin !== "verified_source_capture" ||
      !capture.evidence_ref?.trim()
    ) throw new Error("unverified_source_snapshot");
    if (
      identityKey(parseLegacySourceNotes(row.internal_notes)) !==
        identityKey(capture.identity)
    ) throw new Error("snapshot_identity_mismatch");
    const normalized = canonicalizeExternalEvent(capture.normalized);
    return {
      submission_id: row.id,
      identity: capture.identity,
      evidence_ref: capture.evidence_ref,
      external_normalized: normalized,
      external_normalization_version: EXTERNAL_EVENT_NORMALIZATION_VERSION,
      external_moderation_hash: await hashNormalizedExternalEvent(normalized),
    };
  }));
}

export type MismatchKind =
  | "source_evolution"
  | "editorial_moderation_enrichment"
  | "known_importer_transformation"
  | "unresolved";
export type MismatchEvidence = {
  submission_id: number;
  kind: MismatchKind;
  evidence_ref: string;
};

/** Comparison is diagnostic; a moderated row never becomes a source snapshot. */
export async function shadowCompare(
  rows: LegacySubmission[],
  observations: EventiMoliseEvent[],
  explanations: MismatchEvidence[] = [],
) {
  const audit = await auditLegacySources(rows, observations);
  return rows.map((row) => {
    try {
      const identity = parseLegacySourceNotes(row.internal_notes);
      const source = audit.identities.find((entry) =>
        JSON.stringify(entry.identity) === identityKey(identity)
      );
      if (!source?.shadow || source.conflicting_current_snapshots) {
        return {
          submission_id: row.id,
          state: "unresolved",
          reason: source?.conflicting_current_snapshots
            ? "conflicting_observations"
            : "source_unavailable",
        };
      }
      const historical = canonicalizeSubmission(row);
      const fields = Object.keys(source.shadow).filter((field) =>
        JSON.stringify(source.shadow![field as keyof typeof source.shadow]) !==
          JSON.stringify(historical[field as keyof typeof historical])
      );
      if (!fields.length) {
        return { submission_id: row.id, state: "equal", fields };
      }
      const evidence = explanations.filter((entry) =>
        entry.submission_id === row.id
      );
      if (
        evidence.length !== 1 || !evidence[0].evidence_ref.trim() ||
        ![
          "source_evolution",
          "editorial_moderation_enrichment",
          "known_importer_transformation",
          "unresolved",
        ].includes(evidence[0].kind)
      ) return { submission_id: row.id, state: "unresolved", fields };
      return {
        submission_id: row.id,
        state: evidence[0].kind,
        evidence_ref: evidence[0].evidence_ref,
        fields,
      };
    } catch (error) {
      return {
        submission_id: row.id,
        state: "unresolved",
        reason: String(error),
      };
    }
  });
}

/** A manifest cannot omit an ambiguous pending or waive conflicting Event links. */
export async function identityAndSnapshotGate(
  rows: LegacySubmission[],
  observations: EventiMoliseEvent[],
  evidence: SnapshotEvidence[],
) {
  if (new Set(rows.map((row) => row.id)).size !== rows.length) {
    throw new Error("duplicate_export_submission_id");
  }
  const tuples = await verifiedSubmissionSnapshots(rows, evidence);
  const audit = await auditLegacySources(rows, observations);
  const ambiguousPending = new Set(
    rows.filter((row) =>
      row.status === "pending" &&
      !tuples.some((tuple) => tuple.submission_id === row.id)
    ).map((row) => row.id),
  );
  for (const identity of audit.identities) {
    const pending = rows.filter((row) =>
      identity.submission_ids.includes(row.id) && row.status === "pending"
    );
    if (pending.length > 1) {
      for (const row of pending) ambiguousPending.add(row.id);
    }
  }
  const conflicts = audit.identities.filter((entry) =>
    entry.multiple_canonical_events || entry.conflicting_current_snapshots
  ).map((entry) => entry.identity);
  return {
    pass: ambiguousPending.size === 0 && conflicts.length === 0 &&
      audit.parse_failures.length === 0 &&
      audit.observation_failures.length === 0,
    ambiguous_pending: [...ambiguousPending],
    unresolved_identity_link_conflicts: conflicts,
  };
}

export const MIGRATION_CLASSIFICATIONS = [
  "verified_handled",
  "editorial_baseline",
  "remediated_real_drift",
  "rejected_baseline",
  "ignored_baseline",
  "verified_unhandled",
  "verified_no_longer_observable",
] as const;
export type MigrationClassification = typeof MIGRATION_CLASSIFICATIONS[number];
export type RecordDecision = {
  identity: SourceIdentity;
  classification: MigrationClassification | "retain_legacy";
  evidence_ref: string;
  last_handled_submission_id?: number;
  handled_snapshot?: {
    normalized: NormalizedExternalEvent;
    evidence_ref: string;
  };
  availability_evidence_ref?: string;
  baseline_authorization_ref?: string;
  remediation_ref?: string;
  ignore_authorization_ref?: string;
  never_handled_evidence_ref?: string;
};
export type MigrationPlan = {
  identity: SourceIdentity;
  classification: MigrationClassification;
  evidence_ref: string;
  current: NormalizedExternalEvent;
  proposed: NormalizedExternalEvent | null;
  current_hash: string;
  proposed_hash: string | null;
  event_id: number | null;
  ignored: boolean;
  history: LegacySubmission[];
  tuples: Awaited<ReturnType<typeof verifiedSubmissionSnapshots>>;
};

/** Closed operator decisions; missing historical evidence cannot become null base. */
export async function planVerifiedBackfill(
  rows: LegacySubmission[],
  observations: EventiMoliseEvent[],
  captures: SnapshotEvidence[],
  decisions: RecordDecision[],
  mismatchEvidence: MismatchEvidence[] = [],
) {
  const gate = await identityAndSnapshotGate(rows, observations, captures);
  if (!gate.pass) throw new Error("identity_or_pending_snapshot_gate_failed");
  const audit = await auditLegacySources(rows, observations);
  const tuples = await verifiedSubmissionSnapshots(rows, captures);
  const comparisons = await shadowCompare(rows, observations, mismatchEvidence);
  const seen = new Set<string>();
  const plans: MigrationPlan[] = [];
  for (const decision of decisions) {
    const key = identityKey(decision.identity);
    if (seen.has(key)) throw new Error("duplicate_record_classification");
    seen.add(key);
    const audited = audit.identities.find((entry) =>
      JSON.stringify(entry.identity) === key
    );
    if (!audited || !decision.evidence_ref?.trim()) {
      throw new Error("unverified_record_classification");
    }
    const history = rows.filter((row) =>
      audited.submission_ids.includes(row.id)
    );
    const handled = history.filter((row) => row.status !== "pending").sort((
      a,
      b,
    ) =>
      (b.handled_at == null ? "" : canonicalizeEventTimestamp(b.handled_at))
        .localeCompare(
          a.handled_at == null ? "" : canonicalizeEventTimestamp(a.handled_at),
        ) || b.id - a.id
    );
    const latest = handled[0];
    const current = audited.shadow;
    const snapshot = decision.handled_snapshot;
    const verifiedHandled = !!snapshot?.evidence_ref?.trim() &&
      latest?.id === decision.last_handled_submission_id;
    const latestTuple = tuples.find((tuple) =>
      tuple.submission_id === latest?.id
    );
    if (latest?.promoted_place_id != null) {
      throw new Error("accepted_place_history_requires_remediation");
    }
    if (
      latestTuple && snapshot &&
      latestTuple.external_moderation_hash !==
        await hashNormalizedExternalEvent(
          canonicalizeExternalEvent(snapshot.normalized),
        )
    ) throw new Error("conflicting_handled_snapshot_evidence");
    if (
      latestTuple &&
      [
        "editorial_baseline",
        "remediated_real_drift",
        "rejected_baseline",
        "ignored_baseline",
      ].includes(decision.classification)
    ) throw new Error("unverifiable_baseline_has_verified_latest_snapshot");
    if (decision.classification === "retain_legacy") {
      if (
        current || tuples.some((tuple) =>
          audited.submission_ids.includes(tuple.submission_id)
        ) || history.some((row) =>
          row.status === "pending"
        ) || !decision.availability_evidence_ref?.trim()
      ) {
        throw new Error(
          "retain_legacy_requires_verified_absence_without_snapshot",
        );
      }
      continue;
    }
    if (
      !(MIGRATION_CLASSIFICATIONS as readonly string[]).includes(
        decision.classification,
      )
    ) throw new Error("unknown_migration_classification");
    let proposed: NormalizedExternalEvent | null;
    let normalized: NormalizedExternalEvent;
    switch (decision.classification) {
      case "verified_handled":
        if (!current || !verifiedHandled) {
          throw new Error("verified_handled_evidence_required");
        }
        normalized = current;
        proposed = canonicalizeExternalEvent(snapshot!.normalized);
        break;
      case "verified_no_longer_observable":
        if (
          current || !verifiedHandled ||
          !decision.availability_evidence_ref?.trim()
        ) throw new Error("verified_absence_and_handled_snapshot_required");
        normalized = canonicalizeExternalEvent(snapshot!.normalized);
        proposed = normalized;
        break;
      case "verified_unhandled":
        if (
          !current || handled.length ||
          !decision.never_handled_evidence_ref?.trim() || !history.some((row) =>
            row.status === "pending"
          )
        ) throw new Error("verified_never_handled_evidence_required");
        normalized = current;
        proposed = null;
        break;
      case "editorial_baseline": {
        const explanation = comparisons.find((entry) =>
          entry.submission_id === latest?.id
        );
        if (
          !current || latest?.status !== "accepted" ||
          audited.event_links.length !== 1 ||
          !decision.baseline_authorization_ref?.trim() ||
          ![
            "equal",
            "editorial_moderation_enrichment",
            "known_importer_transformation",
          ].includes(explanation?.state ?? "")
        ) throw new Error("editorial_baseline_evidence_required");
        normalized = current;
        proposed = current;
        break;
      }
      case "remediated_real_drift":
        if (
          !current || latest?.status !== "accepted" ||
          audited.event_links.length !== 1 ||
          !decision.remediation_ref?.trim() ||
          !decision.baseline_authorization_ref?.trim()
        ) throw new Error("real_drift_remediation_required");
        normalized = current;
        proposed = current;
        break;
      case "rejected_baseline":
      case "ignored_baseline":
        if (
          !current || latest?.status !== "rejected" ||
          !decision.baseline_authorization_ref?.trim() ||
          (decision.classification === "ignored_baseline" &&
            !decision.ignore_authorization_ref?.trim())
        ) throw new Error("rejected_baseline_authorization_required");
        normalized = current;
        proposed = current;
        break;
    }
    plans.push({
      identity: decision.identity,
      classification: decision.classification,
      evidence_ref: decision.evidence_ref,
      current: normalized!,
      proposed: proposed!,
      current_hash: await hashNormalizedExternalEvent(normalized!),
      proposed_hash: proposed! === null
        ? null
        : await hashNormalizedExternalEvent(proposed!),
      event_id: audited.event_links[0] ?? null,
      ignored: decision.classification === "ignored_baseline",
      history,
      tuples: tuples.filter((tuple) =>
        audited.submission_ids.includes(tuple.submission_id)
      ),
    });
  }
  if (
    audit.parse_failures.length ||
    audit.identities.some((entry) => !seen.has(JSON.stringify(entry.identity)))
  ) throw new Error("incomplete_history_classification");
  return plans;
}
