import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import postgres from "npm:postgres@3.4.5";
import { prepareEvent } from "../functions/import-external-events/import_logic.ts";
import { hashNormalizedExternalEvent } from "../functions/_shared/external_event_normalization.ts";
import { assertLegacyRestoreAllowed } from "../tools/external_event_rollout_preflight.ts";

const databaseUrl = Deno.env.get("SUPABASE_DB_URL") ?? "";
assert(["localhost", "127.0.0.1"].includes(new URL(databaseUrl).hostname));

Deno.test("local route withdrawal drains queued/manual legacy writes before T0; post-cutover rollback retains provenance", async () => {
  const sql = postgres(databaseUrl, { max: 3, onnotice: () => {} });
  const userId = crypto.randomUUID();
  const externalId = crypto.randomUUID();
  let routeAvailable = true;
  let provenanceHandler: (() => Promise<Response>) | null = null;
  let activeLegacy = 0;
  let releaseLegacy!: () => void;
  const sourceBarrier = new Promise<void>((resolve) => releaseLegacy = resolve);
  let entered!: () => void;
  const twoEntered = new Promise<void>((resolve) => entered = resolve);
  const server = Deno.serve({
    hostname: "127.0.0.1",
    port: 0,
    onListen: () => {},
  }, async () => {
    // Test-only equivalent of withdrawing the deployed route. Scheduling alone
    // does not fence manual or already-dispatched invocations.
    if (!routeAvailable) {
      return new Response("route withdrawn", { status: 404 });
    }
    if (provenanceHandler) return await provenanceHandler();
    activeLegacy++;
    if (activeLegacy === 2) entered();
    try {
      await sourceBarrier;
      await sql`insert into public.content_submissions(user_id,user_email,user_name,name,city,start_date) values(${userId},'rollout@example.test','Rollout','Legacy fixture','City','2026-10-02T12:00:00Z')`;
      return new Response("legacy request finished");
    } finally {
      activeLegacy--;
    }
  });
  const localUrl = `http://127.0.0.1:${server.addr.port}`;
  try {
    await sql`insert into auth.users(id,email,raw_user_meta_data) values(${userId},'rollout@example.test','{"display_name":"Rollout"}')`;
    const queued = fetch(localUrl);
    // A manual request still enters after the schedule has hypothetically been
    // disabled; it must also be drained before recording quiescent T0.
    const manual = fetch(localUrl);
    await twoEntered;
    assertEquals(activeLegacy, 2);
    const recordT0 = async () => {
      if (activeLegacy !== 0) throw new Error("legacy_not_quiescent");
      const [row] = await sql`select clock_timestamp()::text as t0`;
      return String(row.t0);
    };
    await assertRejectsQuiescence(recordT0);
    routeAvailable = false;
    const lateQueued = await fetch(localUrl);
    assertEquals(lateQueued.status, 404);
    await lateQueued.text();
    assertEquals(activeLegacy, 2);
    releaseLegacy();
    await Promise.all([queued, manual].map(async (request) => {
      const response = await request;
      assertEquals(response.status, 200);
      await response.text();
    }));
    assertEquals(activeLegacy, 0);
    const t0 = await recordT0();
    const [before] =
      await sql`select count(*)::int as count, bool_and(created_at <= ${t0}::text::timestamptz) as before_t0 from public.content_submissions where user_id=${userId}`;
    assertEquals(before.count, 2);
    assertEquals(before.before_t0, true);
    const withdrawn = await fetch(localUrl);
    assertEquals(withdrawn.status, 404);
    await withdrawn.text();
    const normalized = prepareEvent({
      id: 1,
      title: "Provenance retained",
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
    }).normalized;
    const hash = await hashNormalizedExternalEvent(normalized);
    provenanceHandler = async () => {
      await sql`select public.ingest_external_event('rollout_fixture',${externalId},null,'https://eventimolise.it/event/fixture/',${
        sql.json(normalized)
      },1,${hash},${sql.json({})},1,${userId}::uuid)`;
      return new Response("provenance ingest finished");
    };
    routeAvailable = true;
    const activated = await fetch(localUrl);
    assertEquals(activated.status, 200);
    await activated.text();
    const snapshot = async () => {
      const records =
        await sql`select to_jsonb(r) as row from public.external_event_records r where provider='rollout_fixture' and external_id=${externalId}`;
      const submissions =
        await sql`select to_jsonb(s) as row from public.content_submissions s where user_id=${userId} order by id`;
      return {
        records: records.map((r) => r.row),
        submissions: submissions.map((s) => s.row),
      };
    };
    const atCutover = await snapshot();
    assertEquals(atCutover.records.length, 1);
    assertEquals(atCutover.submissions.length, 3);
    // Rollback withdraws new ingestion; the permanent cut-over evidence forbids
    // resurrecting the old writer. Neither schema nor persisted data is undone.
    assertThrows(
      () => assertLegacyRestoreAllowed("fixture/cutover"),
      Error,
      "legacy_writer_permanently_retired",
    );
    routeAvailable = false;
    const postRollback = await fetch(localUrl);
    assertEquals(postRollback.status, 404);
    await postRollback.text();
    assertEquals(await snapshot(), atCutover);
  } finally {
    routeAvailable = false;
    releaseLegacy();
    await server.shutdown();
    await sql`delete from public.content_submissions where user_id=${userId}`;
    await sql`delete from public.external_event_records where provider='rollout_fixture' and external_id=${externalId}`;
    await sql`delete from auth.users where id=${userId}`;
    await sql.end();
  }
});

async function assertRejectsQuiescence(operation: () => Promise<string>) {
  try {
    await operation();
    throw new Error("expected quiescence rejection");
  } catch (error) {
    assertEquals((error as Error).message, "legacy_not_quiescent");
  }
}
