// Opt-in local-only HTTP/process bridge. Never emit keys, JWTs or headers.
import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import postgres from "npm:postgres@3.4.5";
import {
  canonicalizeExternalEvent,
  hashNormalizedExternalEvent,
} from "../functions/_shared/external_event_normalization.ts";
import {
  createHandler,
  createProductionDependencies,
} from "../functions/admin-content-submissions/index.ts";

const apiUrl = Deno.env.get("API_URL")!;
const dbUrl = Deno.env.get("SUPABASE_DB_URL")!;
for (const value of [apiUrl, dbUrl]) {
  if (!["127.0.0.1", "localhost"].includes(new URL(value).hostname)) {
    throw new Error("Token E2E fixture must remain local");
  }
}
if (new URL(apiUrl).port !== "54321") {
  throw new Error("Token E2E requires the original local stack");
}
const privilegedKey = Deno.env.get("SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("ANON_KEY")!;
Deno.env.set("SUPABASE_URL", apiUrl);
Deno.env.set("SUPABASE_ANON_KEY", anonKey);
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", privilegedKey);
// Prefer these private local keys over inherited named-key configuration.
Deno.env.delete("SUPABASE_PUBLISHABLE_KEYS");
Deno.env.delete("SUPABASE_SECRET_KEYS");
const client = createClient(apiUrl, privilegedKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const sql = postgres(dbUrl, { max: 1, onnotice: () => {} });
const handler = createHandler(createProductionDependencies());
const fakeKey = "local-token-e2e-public-placeholder";
const importerId = crypto.randomUUID();
const externalId = crypto.randomUUID();
const cityName = `Token E2E ${crypto.randomUUID()}`;
let adminId: string | undefined;
let cityId: string | undefined;
let eventId: number | undefined;
let recordId: number | undefined;
let submissionId: number | undefined;
let sourceRevision = 0;
let stage = "initialization";
let loseResponse = false;
let lastApply: unknown = null;
let lastPreview: unknown = null;
let server: Deno.HttpServer | undefined;
const emit = (value: unknown) => console.log(JSON.stringify(value));

async function ingest(name: string) {
  const normalized = canonicalizeExternalEvent({
    name,
    category: "experience",
    description: null,
    description_delta: null,
    city: cityName,
    latitude: "41",
    longitude: "14",
    all_day: false,
    start_date: "2026-10-02T10:00:00.111222Z",
    end_date: null,
  });
  const [result] = await sql`
    select * from public.ingest_external_event('token_e2e',${externalId},null,null,
      ${sql.json(normalized)},1,${await hashNormalizedExternalEvent(
    normalized,
  )},
      '{}',1,${importerId})
  `;
  recordId = Number(result.record_id);
  submissionId = Number(result.pending_submission_id);
  return submissionId;
}

async function ownedState() {
  const [result] = await sql`
    select jsonb_build_object(
      'event',to_jsonb(e),'submission',to_jsonb(s),'record',to_jsonb(r),
      'pending', (select jsonb_agg(to_jsonb(p) order by p.id)
        from public.content_submissions p where p.external_event_record_id=r.id
        and p.status='pending')) as state
    from public.events e cross join public.content_submissions s
      cross join public.external_event_records r
    where e.id=${eventId!} and s.id=${submissionId!} and r.id=${recordId!}
  `;
  return result.state;
}

async function setup(input: { email: string; password: string }) {
  stage = "auth-create";
  const created = await client.auth.admin.createUser({
    email: input.email,
    password: input.password,
    email_confirm: true,
    app_metadata: { admin: true },
    user_metadata: { display_name: "Token E2E Admin" },
  });
  if (created.error || !created.data.user) {
    throw new Error(`Local Auth code ${created.error?.code ?? "missing-user"}`);
  }
  adminId = created.data.user.id;
  stage = "technical-user";
  await sql`insert into auth.users(id,email,raw_user_meta_data)
    values (${importerId},${`importer-${externalId}@example.test`},
      '{"display_name":"Token E2E importer"}')`;
  const [city] =
    await sql`insert into public.cities(name) values (${cityName}) returning id`;
  cityId = String(city.id);
  stage = "event";
  const [event] = await sql`
    insert into public.events(name,category,start_date,city_id,latitude,longitude,modified_at)
    values ('Source X','experience','2026-10-02T10:00:00.111222Z',${cityId},41,14,
      '2026-01-01T00:00:00.654321Z') returning id
  `;
  eventId = Number(event.id);
  stage = "ingest";
  await ingest("Source X");
  server = Deno.serve({
    hostname: "127.0.0.1",
    port: 0,
    onListen: () => {},
    onError: () => new Response("Local bridge failed", { status: 500 }),
  }, async (request) => {
    const url = new URL(request.url);
    if (url.pathname.startsWith("/auth/v1/")) {
      const headers = new Headers(request.headers);
      headers.set("apikey", anonKey);
      if (headers.get("authorization") === `Bearer ${fakeKey}`) {
        headers.set("authorization", `Bearer ${anonKey}`);
      }
      headers.delete("host");
      return await fetch(`${apiUrl}${url.pathname}${url.search}`, {
        method: request.method,
        headers,
        body: request.method === "GET"
          ? undefined
          : await request.arrayBuffer(),
      });
    }
    if (url.pathname !== "/functions/v1/admin-content-submissions") {
      return new Response("Not found", { status: 404 });
    }
    const body = await request.clone().json();
    let before: unknown;
    let equality: unknown;
    if (body.operation === "apply") {
      before = await ownedState();
      const [equal] = await sql`
        select s.modified_at::text as actual_submission, e.modified_at::text as actual_event,
          -- Bind text exactly as the RPC does, avoiding the JS timestamp serializer.
          s.modified_at=${body.submission_version_token}::text::timestamptz as submission,
          e.modified_at=${body.event_version_token}::text::timestamptz as event
        from public.content_submissions s cross join public.events e
        where s.id=${submissionId!} and e.id=${eventId!}
      `;
      equality = equal;
    }
    const response = await handler(request);
    if (body.operation === "mergePreview" && response.status === 200) {
      const { preview } = await response.clone().json();
      lastPreview = {
        submission_version_token: preview.submission_version_token,
        event_version_token: preview.event_version_token,
      };
    }
    if (body.operation === "apply") {
      lastApply = {
        body,
        equality,
        before,
        after: await ownedState(),
        status: response.status,
      };
      if (loseResponse && response.status === 200) {
        loseResponse = false;
        await response.arrayBuffer(); // SQL has committed; withhold its success.
        const broken = new ReadableStream<Uint8Array>({
          start(controller) {
            controller.enqueue(new TextEncoder().encode("{"));
            setTimeout(
              () => controller.error(new Error("Intentional lost response")),
              1,
            );
          },
        });
        return new Response(broken, {
          headers: {
            "Content-Type": "application/json",
            "Content-Length": "1024",
          },
        });
      }
    }
    return response;
  });
  return {
    url: `http://127.0.0.1:${(server.addr as Deno.NetAddr).port}`,
    fake_key: fakeKey,
    submission_id: submissionId,
    event_id: eventId,
    admin_id: adminId,
    importer_id: importerId,
  };
}

async function command(input: Record<string, unknown>) {
  switch (input.operation) {
    case "setup":
      return await setup(
        input as unknown as { email: string; password: string },
      );
    case "advance": {
      sourceRevision++;
      await ingest(sourceRevision === 1 ? "Source Y" : "Source Z");
      if (sourceRevision === 1) {
        // Fixture-only token assignment; no merge-content UPDATE/trigger bypass.
        await sql`update public.content_submissions
          set modified_at='2026-01-01T00:00:00.123456Z' where id=${submissionId!}`;
      }
      return { submission_id: submissionId };
    }
    case "tokens": {
      const [tokens] = await sql`
        select s.modified_at::text as submission,e.modified_at::text as event,
          (s.modified_at+interval '1 microsecond')::text as shifted_submission,
          (e.modified_at+interval '1 microsecond')::text as shifted_event
        from public.content_submissions s cross join public.events e
        where s.id=${submissionId!} and e.id=${eventId!}
      `;
      return { ...tokens, wire_preview: lastPreview };
    }
    case "mutateEvent":
      await sql`update public.events set description='Concurrent editorial description'
        where id=${eventId!}`;
      return {};
    case "loseResponse":
      loseResponse = true;
      return {};
    case "observe":
      return { apply: lastApply, state: await ownedState() };
    default:
      throw new Error("Unknown local fixture command");
  }
}

// stdin/stdout is a private process control channel, not a privileged HTTP API.
let pending = "";
let failed = false;
let stopping = false;
try {
  const decoder = new TextDecoder();
  for await (const chunk of Deno.stdin.readable) {
    pending += decoder.decode(chunk, { stream: true });
    while (pending.includes("\n")) {
      const end = pending.indexOf("\n");
      const line = pending.slice(0, end);
      pending = pending.slice(end + 1);
      const input = JSON.parse(line);
      if (input.operation === "shutdown") {
        emit({ stopping: true });
        stopping = true;
        break;
      }
      emit(await command(input));
    }
    if (stopping) break;
  }
} catch (error) {
  failed = true;
  const code =
    error instanceof Error && error.message.startsWith("Local Auth code ")
      ? error.message
      : (error as { code?: string }).code;
  emit({ error: "Local token fixture failed", stage, code });
} finally {
  try {
    await server?.shutdown();
    if (recordId) {
      await sql`delete from public.content_submissions where external_event_record_id=${recordId}`;
    }
    if (recordId) {
      await sql`delete from public.external_event_records where id=${recordId}`;
    }
    if (eventId) await sql`delete from public.events where id=${eventId}`;
    if (cityId) await sql`delete from public.cities where id=${cityId}`;
    await sql`delete from auth.users where id=${importerId}`;
    if (adminId) {
      const deleted = await client.auth.admin.deleteUser(adminId);
      if (deleted.error) failed = true;
    }
  } catch {
    failed = true;
  } finally {
    await sql.end();
  }
}
if (failed) Deno.exit(1);
