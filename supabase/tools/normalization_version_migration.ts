import type { Json } from "../functions/_shared/database.types.ts";
export type VersionSnapshot = {
  normalization_version: number;
  moderation_hash: string;
  normalized: Json;
};
export type VersionMigrationState = {
  current: VersionSnapshot;
  proposed: VersionSnapshot | null;
  pending: Array<{ submission_id: number; snapshot: VersionSnapshot }>;
};
export type VersionMigrationEvidence = {
  target_version: number;
  evidence_ref: string;
  converted_current?: VersionSnapshot;
  converted_proposed?: VersionSnapshot;
  converted_pending: Array<
    { submission_id: number; snapshot: VersionSnapshot }
  >;
  refetched_current?: VersionSnapshot;
};
function validTarget(
  snapshot: VersionSnapshot | undefined,
  version: number,
): snapshot is VersionSnapshot {
  return !!snapshot && snapshot.normalization_version === version &&
    /^[a-f0-9]{64}$/.test(snapshot.moderation_hash) &&
    snapshot.normalized !== null && typeof snapshot.normalized === "object" &&
    !Array.isArray(snapshot.normalized);
}
/** Offline transition policy only. A specific future version supplies canonical
 * converted values/hashes from the one shared TS canonicalizer; no runtime v2
 * profile, conversion semantics, hashing implementation or bypass is added here. */
export function planNormalizationVersionMigration(
  old: VersionMigrationState,
  evidence: VersionMigrationEvidence,
) {
  const conflict = (reason: string) => ({
    outcome: "migration_conflict" as const,
    reason,
  });
  const target = evidence.target_version;
  if (
    !Number.isInteger(target) || target <= old.current.normalization_version ||
    !evidence.evidence_ref?.trim()
  ) return conflict("invalid_version_migration_evidence");
  const ids = new Set(old.pending.map((entry) => entry.submission_id));
  if (
    ids.size !== old.pending.length ||
    evidence.converted_pending.length !== ids.size ||
    new Set(evidence.converted_pending.map((entry) => entry.submission_id))
        .size !== ids.size ||
    evidence.converted_pending.some((entry) =>
      !ids.has(entry.submission_id) || !validTarget(entry.snapshot, target)
    )
  ) return conflict("unconvertible_pending_snapshot");
  const accounted = old.proposed !== null &&
    old.current.moderation_hash === old.proposed.moderation_hash &&
    old.current.normalization_version === old.proposed.normalization_version;
  let current: VersionSnapshot;
  let proposed: VersionSnapshot | null;
  let mode: "derived" | "refetch_baseline" | "refetch_preserve_unhandled";
  if (
    validTarget(evidence.converted_current, target) &&
    (old.proposed === null || validTarget(evidence.converted_proposed, target))
  ) {
    current = evidence.converted_current;
    proposed = old.proposed === null ? null : evidence.converted_proposed!;
    mode = "derived";
  } else if (validTarget(evidence.refetched_current, target)) {
    current = evidence.refetched_current;
    if (accounted) {
      proposed = current;
      mode = "refetch_baseline";
    } else if (old.proposed === null) {
      proposed = null;
      mode = "refetch_preserve_unhandled";
    } else if (validTarget(evidence.converted_proposed, target)) {
      proposed = evidence.converted_proposed;
      mode = "refetch_preserve_unhandled";
    } else return conflict("unconvertible_proposed_snapshot");
  } else {return conflict(
      old.proposed !== null && !validTarget(evidence.converted_proposed, target)
        ? "unconvertible_proposed_snapshot"
        : "unconvertible_current_snapshot",
    );}
  if (accounted && current.moderation_hash !== proposed?.moderation_hash) {
    return conflict("conversion_creates_unhandled_divergence");
  }
  // A conversion must not claim that distinct unhandled states became accounted.
  if (
    !accounted && old.proposed !== null &&
    current.moderation_hash === proposed?.moderation_hash
  ) return conflict("conversion_erases_unhandled_divergence");
  return {
    outcome: "ready" as const,
    mode,
    target_version: target,
    current,
    proposed,
    pending: evidence.converted_pending,
    evidence_ref: evidence.evidence_ref,
  };
}
