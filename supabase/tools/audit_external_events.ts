import {
  auditLegacySources,
  shadowCompare,
} from "./external_event_migration.ts";

if (import.meta.main) {
  if (Deno.args.length !== 1) {
    throw new Error(
      "Usage: deno run --allow-read supabase/tools/audit_external_events.ts <export.json>",
    );
  }
  const input = JSON.parse(await Deno.readTextFile(Deno.args[0]));
  if (!Array.isArray(input.submissions) || !Array.isArray(input.observations)) {
    throw new Error("Expected submissions and observations arrays");
  }
  console.log(
    JSON.stringify(
      {
        audit: await auditLegacySources(input.submissions, input.observations),
        shadow: await shadowCompare(
          input.submissions,
          input.observations,
          input.mismatch_evidence ?? [],
        ),
      },
      null,
      2,
    ),
  );
}
