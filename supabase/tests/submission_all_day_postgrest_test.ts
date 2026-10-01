import { assert, assertEquals } from "jsr:@std/assert@1";
import postgres from "npm:postgres@3.4.5";

function localValue(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`${name} is required by the local PostgREST smoke`);
  }
  return value;
}

Deno.test("actual PostgREST dispatch supports omitted and explicit mode; public roles remain denied", async () => {
  const apiUrl = localValue("API_URL");
  const databaseUrl = localValue("SUPABASE_DB_URL");
  for (const url of [apiUrl, databaseUrl]) {
    assert(
      ["127.0.0.1", "localhost"].includes(new URL(url).hostname),
      "Smoke must remain local",
    );
  }
  const serviceKey = localValue("SERVICE_ROLE_KEY");
  const anonKey = localValue("ANON_KEY");
  const sql = postgres(databaseUrl, { max: 1 });
  const password = `Local-smoke-${crypto.randomUUID()}`;
  const email = `all-day-postgrest-${crypto.randomUUID()}@example.test`;
  let userId: string | undefined;
  try {
    const createdUser = await fetch(`${apiUrl}/auth/v1/admin/users`, {
      method: "POST",
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ email, password, email_confirm: true }),
    });
    assertEquals(createdUser.status, 200);
    const user = await createdUser.json();
    userId = user.id;
    assert(typeof userId === "string");
    const login = await fetch(`${apiUrl}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { apikey: anonKey, "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });
    assertEquals(login.status, 200);
    const session = await login.json();
    assert(typeof session.access_token === "string");
    const args = {
      p_user_id: userId,
      p_client_submission_id: crypto.randomUUID(),
      p_city: "Campobasso",
      p_name: "Local PostgREST smoke",
      p_description: null,
      p_description_delta: null,
      p_latitude: null,
      p_longitude: null,
      p_address: null,
      p_start_date: null,
      p_end_date: null,
      p_category: null,
      p_user_email: email,
      p_user_name: "Local smoke",
      p_assets: [],
    };
    const rpc = (
      body: Record<string, unknown>,
      token = serviceKey,
      key = serviceKey,
    ) =>
      fetch(`${apiUrl}/rest/v1/rpc/submit_content`, {
        method: "POST",
        headers: {
          apikey: key,
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });
    for (
      const body of [args, {
        ...args,
        p_client_submission_id: crypto.randomUUID(),
        p_all_day: true,
        p_start_date: "2026-10-24T22:00:00Z",
        p_end_date: "2026-10-25T22:59:59.999999Z",
      }]
    ) {
      const response = await rpc(body);
      assertEquals(response.status, 200);
      const [outcome] = await response.json();
      assertEquals(outcome.outcome, "created");
      const [stored] = await sql<
        { all_day: boolean; start_matches: boolean; end_matches: boolean }[]
      >`select all_day,
          start_date is not distinct from ${body.p_start_date}::text::timestamptz as start_matches,
          end_date is not distinct from ${body.p_end_date}::text::timestamptz as end_matches
        from public.content_submissions where id = ${outcome.submission_id}`;
      assertEquals(stored, {
        all_day: Object.hasOwn(body, "p_all_day"),
        start_matches: true,
        end_matches: true,
      });
    }
    for (
      const [token, key] of [[anonKey, anonKey], [
        session.access_token,
        anonKey,
      ]]
    ) {
      const response = await rpc(
        { ...args, p_client_submission_id: crypto.randomUUID() },
        token,
        key,
      );
      assert(
        [401, 403].includes(response.status),
        "Public RPC must reject execution",
      );
      await response.body?.cancel();
    }
  } finally {
    if (userId) {
      await sql`delete from public.content_submissions where user_id = ${userId}`;
      await sql`delete from public.submission_rate_limits where user_id = ${userId}`;
      const deleted = await fetch(`${apiUrl}/auth/v1/admin/users/${userId}`, {
        method: "DELETE",
        headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
      });
      await deleted.body?.cancel();
      assertEquals(deleted.status, 200);
    }
    await sql.end();
  }
});
