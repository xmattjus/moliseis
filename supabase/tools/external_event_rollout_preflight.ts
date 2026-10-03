import { assertReleaseDate } from "./backfill_external_events.ts";
export const UPDATED_ADMIN_PROBES = [
  "update_link",
  "update_apply",
  "reject_ignore",
  "ignored_records_unignore",
  "stale_indicator",
  "current_source_acknowledgement",
  "source_changed",
  "opaque_preview_tokens",
] as const;
/** Read-only release-evidence checks, not a deployment controller or live probe. */
export function assertReadyBeforeLegacyFreeze(
  input: {
    release_gates?: Record<string, unknown>;
    updated_client_probe_refs?: Record<string, unknown>;
  },
) {
  for (
    const key of [
      "additive_schema_notifications",
      "compatible_admin_backend",
      "updated_admin_client",
    ]
  ) {
    const ref = input.release_gates?.[key];
    if (typeof ref !== "string" || !ref.trim()) {
      throw new Error(`missing_prefreeze_${key}`);
    }
  }
  for (const key of UPDATED_ADMIN_PROBES) {
    const ref = input.updated_client_probe_refs?.[key];
    if (typeof ref !== "string" || !ref.trim()) {
      throw new Error(`missing_updated_admin_probe_${key}`);
    }
  }
}
export function assertLegacyRestoreAllowed(cutoverEvidenceRef: string | null) {
  if (cutoverEvidenceRef !== null) {
    throw new Error("legacy_writer_permanently_retired");
  }
}
export { assertReleaseDate };
if (import.meta.main) {
  try {
    if (Deno.args.length !== 1) {
      throw new Error("expected_release_evidence_json");
    }
    const input = JSON.parse(await Deno.readTextFile(Deno.args[0]));
    assertReadyBeforeLegacyFreeze(input);
    console.log(
      JSON.stringify({
        execution: "EVIDENCE_PREFLIGHT_ONLY",
        production_freeze: "NOT_EXECUTED",
        result: "PREFREEZE_EVIDENCE_COMPLETE",
      }),
    );
  } catch (error) {
    console.error(
      error instanceof Error ? error.message : "invalid_release_evidence",
    );
    Deno.exit(1);
  }
}
