// Local-only bridge for the opt-in Flutter E2E. Stdout contains remote rows only.
import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import postgres from "npm:postgres@3.4.5";
import type { Database } from "../functions/_shared/database.types.ts";
import { parseContentSubmission } from "../functions/submit-content/submission_validation.ts";
import { createSubmissionStore } from "../functions/submit-content/submission_store.ts";

import { parseAdminContentSubmissionsRequest } from "../functions/admin-content-submissions/admin_submission_validation.ts";
import { createAdminSubmissionStore } from "../functions/admin-content-submissions/admin_submission_store.ts";

const apiUrl = Deno.env.get("API_URL")!;
const dbUrl = Deno.env.get("SUPABASE_DB_URL")!;
for (const url of [apiUrl, dbUrl]) {
  if (!["127.0.0.1", "localhost"].includes(new URL(url).hostname)) {
    throw new Error("E2E fixture must remain local");
  }
}
const client = createClient<Database>(
  apiUrl,
  Deno.env.get("SERVICE_ROLE_KEY")!,
  {
    auth: { persistSession: false, autoRefreshToken: false },
  },
);
const sql = postgres(dbUrl, { max: 1 });
const requests = JSON.parse(await new Response(Deno.stdin.readable).text());
if (!Array.isArray(requests) || requests.length !== 3) {
  throw new Error("Expected three captured requests");
}
let userId: string | undefined;
let cityId: string | undefined;
try {
  const { data, error } = await client.auth.admin.createUser({
    email: requests[0].user_email,
    password: `Local-E2E-${crypto.randomUUID()}`,
    email_confirm: true,
  });
  if (error || !data.user) throw new Error("Could not create local E2E user");
  userId = data.user.id;
  const [city] = await sql<{ id: string }[]>`
    insert into public.cities (name) values (${requests[0].city}) returning id
  `;
  cityId = city.id;
  const rows = [];
  for (const request of requests) {
    const parsed = parseContentSubmission(request, "fixture");
    if (!parsed.ok) throw new Error(parsed.message);
    const outcome = await createSubmissionStore(client).submit({
      userId,
      submission: parsed.value,
    });
    if (outcome.outcome !== "created") {
      throw new Error("Atomic submission failed");
    }
    // Public editing does not own coordinates. The normal Admin full-input
    // boundary adds publication readiness without changing captured dates/mode.
    const editorial = parseAdminContentSubmissionsRequest({
      operation: "update",
      submission_id: outcome.submissionId,
      input: {
        category: request.category,
        city: request.city,
        name: request.name,
        description: request.description,
        description_delta: request.description_delta,
        all_day: request.all_day,
        start_date: request.start_date,
        end_date: request.end_date,
        start_calendar_date: request.start_calendar_date,
        end_calendar_date: request.end_calendar_date,
        latitude: 41.5629,
        longitude: 14.6697,
      },
    });
    if (!editorial.ok || editorial.value.operation !== "update") {
      throw new Error("Admin full-input normalization failed");
    }
    const updated = await createAdminSubmissionStore(client).update(
      outcome.submissionId,
      editorial.value.input,
      new Date().toISOString(),
    );
    if (updated.outcome !== "updated") {
      throw new Error("Admin enrichment failed");
    }
    if (updated.submission.all_day !== parsed.value.all_day) {
      throw new Error("Admin enrichment changed mode");
    }
    const promoted = await client.rpc("promote_content_submission", {
      p_submission_id: outcome.submissionId,
      p_target: "event",
      p_handled_by: userId,
    });
    if (promoted.error || promoted.data?.[0]?.outcome !== "created") {
      throw new Error("Locked promotion failed");
    }
    const eventId = Number(promoted.data[0].entity_id);
    const fetched = await client.from("events").select("*").eq("id", eventId)
      .single();
    if (fetched.error || !fetched.data) throw new Error("Remote fetch failed");
    // Assert publication copied the same locked temporal snapshot, retaining
    // exact microseconds in SQL before JS/Flutter decoding.
    const [same] = await sql<{ identical: boolean }[]>`
      select e.all_day = s.all_day and
        e.start_date is not distinct from s.start_date and
        e.end_date is not distinct from s.end_date as identical
      from public.events e join public.content_submissions s
        on s.promoted_event_id = e.id where e.id = ${eventId}
    `;
    if (!same.identical) {
      throw new Error("Publication temporal snapshot differs");
    }
    rows.push(fetched.data);
  }
  console.log(JSON.stringify(rows));
} finally {
  try {
    if (userId) {
      await sql`delete from public.content_submissions where user_id = ${userId}::uuid`;
    }
    if (cityId) {
      await sql`delete from public.events where city_id = ${cityId}`;
      await sql`delete from public.cities where id = ${cityId}`;
    }
  } finally {
    try {
      if (userId) {
        await sql`delete from public.submission_rate_limits where user_id = ${userId}::uuid`;
        const deleted = await client.auth.admin.deleteUser(userId);
        if (deleted.error) throw new Error("Local fixture user cleanup failed");
      }
    } finally {
      await sql.end();
    }
  }
}
