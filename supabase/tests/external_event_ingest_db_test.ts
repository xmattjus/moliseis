import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import postgres, { type Sql } from "npm:postgres@3.4.5";
import {
  canonicalizeExternalEvent,
  canonicalizeSubmission,
  type EventNormalizationInput,
  hashNormalizedExternalEvent,
  type NormalizedExternalEvent,
} from "../functions/_shared/external_event_normalization.ts";

function localValue(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is required by local ingest tests`);
  return value;
}
const databaseUrl = localValue("SUPABASE_DB_URL");
const apiUrl = localValue("API_URL");
for (const url of [databaseUrl, apiUrl]) {
  assert(
    ["localhost", "127.0.0.1"].includes(new URL(url).hostname),
    "Tests must stay local",
  );
}
const serviceKey = localValue("SERVICE_ROLE_KEY");
const normalized: NormalizedExternalEvent = {
  name: "Concerto",
  category: "unknown",
  description: null,
  description_delta: null,
  city: "Campobasso",
  latitude: null,
  longitude: null,
  all_day: false,
  start_date: "2026-10-02T10:00:00.123456Z",
  end_date: null,
};

function rest(path: string, init: RequestInit = {}) {
  return fetch(`${apiUrl}/rest/v1/${path}`, {
    ...init,
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
      ...init.headers,
    },
  });
}

Deno.test("M2 normalized JSONB actual PostgREST round-trip rehashes identically", async () => {
  const sql = postgres(databaseUrl, { max: 1 });
  let recordId: string | undefined;
  try {
    const fixture = canonicalizeExternalEvent({
      ...normalized,
      name: "Café",
      description: " Café ",
      latitude: "41.123456789012344",
      longitude: "14.1",
    });
    const hash = await hashNormalizedExternalEvent(fixture);
    const [inserted] = await sql`insert into public.external_event_records
      (provider, external_id, normalized, normalization_version, moderation_hash, metadata_version)
      values ('roundtrip', ${crypto.randomUUID()}, ${
      sql.json(fixture)
    }, 1, ${hash}, 1) returning id`;
    recordId = String(inserted.id);
    await sql`notify pgrst, 'reload schema'`;
    const [stored] =
      await sql`select normalized from public.external_event_records where id = ${recordId}`;
    assertEquals(
      await hashNormalizedExternalEvent(
        canonicalizeExternalEvent(stored.normalized),
      ),
      hash,
    );
    let response = await rest(
      `external_event_records?id=eq.${recordId}&select=normalized`,
    );
    // Local PostgREST reload is asynchronous; bound retry is only for cache readiness.
    for (let attempt = 0; response.status === 404 && attempt < 4; attempt++) {
      await response.text();
      await new Promise((resolve) => setTimeout(resolve, 100));
      response = await rest(
        `external_event_records?id=eq.${recordId}&select=normalized`,
      );
    }
    assertEquals(response.status, 200);
    const [observed] = await response.json();
    assertEquals(canonicalizeExternalEvent(observed.normalized), fixture);
    assertEquals(
      await hashNormalizedExternalEvent(
        canonicalizeExternalEvent(observed.normalized),
      ),
      hash,
    );
  } finally {
    if (recordId) {
      await sql`delete from public.external_event_records where id = ${recordId}`;
    }
    await sql.end();
  }
});

async function ingestFixture(run: (sql: Sql, userId: string) => Promise<void>) {
  const sql = postgres(databaseUrl, { max: 1 });
  const userId = crypto.randomUUID();
  try {
    await sql`begin`;
    await sql`insert into auth.users(id, email, raw_user_meta_data) values (${userId}, 'importer@example.test', '{"display_name":"Importer fixture"}')`;
    await run(sql, userId);
  } finally {
    await sql`rollback`;
    await sql.end();
  }
}

async function ingest(
  sql: Sql,
  userId: string,
  externalId: string,
  state = normalized,
  metadata: Parameters<Sql["json"]>[0] = {},
  version = 1,
) {
  const hash = await hashNormalizedExternalEvent(state);
  const [result] = await sql`select * from public.ingest_external_event(
    'fixture', ${externalId}, null, 'https://example.test/source', ${
    sql.json(state)
  }, ${version}, ${hash}, ${sql.json(metadata)}, 1, ${userId})`;
  return result;
}

Deno.test("M2 ingest locks strong identity, writes only material current changes and enqueues", () =>
  ingestFixture(async (sql, userId) => {
    await sql`set local role service_role`;
    const externalId = crypto.randomUUID();
    const first = await ingest(sql, userId, externalId);
    assertEquals(first.outcome, "ingested");
    assertEquals(first.pending_created, true);
    assert(first.record_id !== null && first.pending_submission_id !== null);
    const [before] =
      await sql`select modified_at::text as token, proposed_hash from public.external_event_records where id = ${first.record_id}`;
    assertEquals(before.proposed_hash, null);
    const second = await ingest(sql, userId, externalId);
    assertEquals(second.record_id, first.record_id);
    assertEquals(second.pending_submission_id, first.pending_submission_id);
    assertEquals(second.pending_created, false);
    const [unchanged] =
      await sql`select modified_at::text as token from public.external_event_records where id = ${first.record_id}`;
    assertEquals(unchanged.token, before.token);
    const changedState = { ...normalized, name: "New source" };
    const changed = await ingest(sql, userId, externalId, changedState);
    assertEquals(changed.pending_submission_id, first.pending_submission_id);
    const [current] =
      await sql`select normalized, modified_at::text as token, proposed_hash from public.external_event_records where id = ${first.record_id}`;
    assertEquals(current.normalized, changedState);
    assert(current.token !== before.token);
    assertEquals(current.proposed_hash, null);
    const [pending] =
      await sql`select external_normalized, client_submission_id from public.content_submissions where id = ${first.pending_submission_id}`;
    assertEquals(pending.external_normalized, normalized);
    assertEquals(pending.client_submission_id, null);
    const mismatch = await ingest(sql, userId, externalId, normalized, {}, 2);
    assertEquals(mismatch.outcome, "normalization_mismatch");
    const [afterMismatch] =
      await sql`select normalized, modified_at::text as token from public.external_event_records where id = ${first.record_id}`;
    assertEquals(afterMismatch, {
      normalized: changedState,
      token: current.token,
    });
  }));

async function persistedProjection(sql: Sql, id: string | number) {
  const [row] = await sql<
    EventNormalizationInput[]
  >`select name, category, description, description_delta, city, latitude, longitude,
    all_day, start_date::text, end_date::text from public.content_submissions where id = ${id}`;
  return row;
}

Deno.test("M2 single enqueue mechanically projects canonical source and immutable snapshot", () =>
  ingestFixture(async (sql, userId) => {
    const state = canonicalizeExternalEvent({
      ...normalized,
      name: "Café",
      city: "Isernia",
      category: "history",
      description: "e\u0301",
      description_delta: [{ insert: "e", attributes: { bold: true } }, {
        insert: "\u0301\n",
      }],
      latitude: "41.123456789012344",
      longitude: "-0",
      end_date: "2026-10-02T10:00:00.654321Z",
    });
    const result = await ingest(sql, userId, crypto.randomUUID(), state);
    assertEquals(
      canonicalizeSubmission(
        await persistedProjection(sql, result.pending_submission_id),
      ),
      state,
    );
    const [snapshot] =
      await sql`select external_event_record_id, external_normalized, external_normalization_version,
    external_moderation_hash, user_id, user_email, user_name, client_submission_id from public.content_submissions where id = ${result.pending_submission_id}`;
    assertEquals(snapshot.external_event_record_id, result.record_id);
    assertEquals(snapshot.external_normalized, state);
    assertEquals(snapshot.external_normalization_version, 1);
    assertEquals(
      snapshot.external_moderation_hash,
      await hashNormalizedExternalEvent(state),
    );
    assertEquals(snapshot.user_id, userId);
    assertEquals(snapshot.user_email, "importer@example.test");
    assertEquals(snapshot.user_name, "Importer fixture");
    assertEquals(snapshot.client_submission_id, null);
  }));

Deno.test("M2 actual PostgREST submission coordinate projection preserves canonical strings", async () => {
  const sql = postgres(databaseUrl, { max: 1 });
  const userId = crypto.randomUUID();
  let recordId: string | undefined;
  try {
    await sql`insert into auth.users(id, email, raw_user_meta_data) values (${userId}, 'coordinate@example.test', '{"display_name":"Coordinate fixture"}')`;
    const state = canonicalizeExternalEvent({
      ...normalized,
      latitude: "41.123456789012344",
      longitude: "14.123456789012345",
    });
    const rpcResponse = await rest("rpc/ingest_external_event", {
      method: "POST",
      body: JSON.stringify({
        p_provider: "fixture",
        p_external_id: crypto.randomUUID(),
        p_occurrence_key: null,
        p_source_url: "https://example.test/source",
        p_normalized: state,
        p_normalization_version: 1,
        p_moderation_hash: await hashNormalizedExternalEvent(state),
        p_metadata: {},
        p_metadata_version: 1,
        p_importer_user_id: userId,
      }),
    });
    assertEquals(rpcResponse.status, 200);
    const [result] = await rpcResponse.json();
    assertEquals(result.outcome, "ingested");
    assertEquals(result.event_id, null);
    assertEquals(result.pending_created, true);
    assert(
      typeof result.record_id === "number" &&
        typeof result.pending_submission_id === "number",
    );

    recordId = String(result.record_id);
    const response = await rest(
      `content_submissions?id=eq.${result.pending_submission_id}&select=name,category,description,description_delta,city,latitude,longitude,all_day,start_date,end_date`,
    );
    assertEquals(response.status, 200);
    const [row] = await response.json();
    assertEquals(canonicalizeSubmission(row), state);
  } finally {
    if (recordId) {
      await sql`delete from public.content_submissions where external_event_record_id = ${recordId}`;
      await sql`delete from public.external_event_records where id = ${recordId}`;
    }
    await sql`delete from auth.users where id = ${userId}`;
    await sql.end();
  }
});

Deno.test("M2 ingest seeds authoritative Auth identity and invalid identity rolls back source creation", () =>
  ingestFixture(async (sql) => {
    const validUser = crypto.randomUUID();
    await sql`insert into auth.users(id, email, raw_user_meta_data) values (${validUser}, ' authoritative@example.test ', '{"display_name":"  Authoritative name  "}')`;
    const valid = await ingest(sql, validUser, crypto.randomUUID());
    const [row] =
      await sql`select user_id, user_email, user_name from public.content_submissions where id = ${valid.pending_submission_id}`;
    assertEquals(row, {
      user_id: validUser,
      user_email: "authoritative@example.test",
      user_name: "Authoritative name",
    });
    for (
      const options of [
        { exists: false, email: null, metadata: {} },
        { exists: true, email: null, metadata: { display_name: "Name" } },
        { exists: true, email: "invalid@example.test", metadata: {} },
        {
          exists: true,
          email: "blank@example.test",
          metadata: { display_name: " " },
        },
        {
          exists: true,
          email: "number@example.test",
          metadata: { display_name: 123 },
        },
      ]
    ) {
      const invalidUser = crypto.randomUUID();
      if (options.exists) {
        await sql`insert into auth.users(id, email, raw_user_meta_data) values (${invalidUser}, ${options.email}, ${
          sql.json(options.metadata)
        })`;
      }
      const externalId = crypto.randomUUID();
      await sql`savepoint invalid_identity`;
      const error = await assertRejects(() =>
        ingest(sql, invalidUser, externalId)
      );
      assertEquals(
        (error as Error).message,
        "external_importer_identity_invalid",
      );
      await sql`rollback to savepoint invalid_identity`;
      const [count] =
        await sql`select count(*)::integer as count from public.external_event_records where provider = 'fixture' and external_id = ${externalId}`;
      assertEquals(count.count, 0);
    }
  }));

Deno.test("M2 changed configured identity seeds new workflow but existing workflow inherits history", () =>
  ingestFixture(async (sql, userId) => {
    const secondUser = crypto.randomUUID();
    await sql`insert into auth.users(id, email, raw_user_meta_data) values (${secondUser}, 'new-importer@example.test', '{"display_name":"New importer"}')`;
    const externalId = crypto.randomUUID();
    const first = await ingest(sql, userId, externalId);
    await sql`select set_config('app.external_resolution', 'on', true)`;
    await sql`update public.content_submissions set status = 'rejected' where id = ${first.pending_submission_id}`;
    await sql`update public.external_event_records set proposed_normalized = normalized, proposed_normalization_version = normalization_version, proposed_hash = moderation_hash where id = ${first.record_id}`;
    const followup = await ingest(sql, secondUser, externalId, {
      ...normalized,
      name: "Future source state",
    });
    const [historical] =
      await sql`select user_id, user_email, user_name from public.content_submissions where id = ${followup.pending_submission_id}`;
    assertEquals(historical, {
      user_id: userId,
      user_email: "importer@example.test",
      user_name: "Importer fixture",
    });
    const seeded = await ingest(sql, secondUser, crypto.randomUUID());
    const [newWorkflow] =
      await sql`select user_id, user_email, user_name from public.content_submissions where id = ${seeded.pending_submission_id}`;
    assertEquals(newWorkflow, {
      user_id: secondUser,
      user_email: "new-importer@example.test",
      user_name: "New importer",
    });
  }));

Deno.test("M2 ingest RPC is service-role-only and private Auth/enqueue helpers have no API grants", () =>
  ingestFixture(async (sql, userId) => {
    const rpcSignature =
      "public.ingest_external_event(text,text,text,text,jsonb,integer,text,jsonb,integer,uuid)";
    for (const role of ["anon", "authenticated"]) {
      const [grant] =
        await sql`select has_function_privilege(${role}, ${rpcSignature}, 'EXECUTE') as allowed`;
      assertEquals(grant.allowed, false);
      await sql.unsafe(`set local role ${role}`);
      await sql`savepoint denied_ingest`;
      const error = await assertRejects(() =>
        ingest(sql, userId, crypto.randomUUID())
      );
      assertEquals((error as { code: string }).code, "42501");
      await sql`rollback to savepoint denied_ingest`;
      await sql`reset role`;
    }
    for (
      const signature of [
        "private.external_event_importer_identity(uuid)",
        "private.enqueue_external_event_proposal_if_needed(bigint,uuid,text,text)",
      ]
    ) {
      for (const role of ["anon", "authenticated", "service_role"]) {
        const [grant] =
          await sql`select has_function_privilege(${role}, ${signature}, 'EXECUTE') as allowed`;
        assertEquals(grant.allowed, false);
      }
    }
    const [grant] =
      await sql`select has_function_privilege('service_role', ${rpcSignature}, 'EXECUTE') as allowed`;
    assertEquals(grant.allowed, true);
    await sql`set local role service_role`;
    assertEquals(
      (await ingest(sql, userId, crypto.randomUUID())).outcome,
      "ingested",
    );
  }));

Deno.test("M2 overlapping first ingest waits on strong identity and produces one pending", async () => {
  const observer = postgres(databaseUrl, { max: 1 });
  const first = postgres(databaseUrl, { max: 1 });
  const second = postgres(databaseUrl, { max: 1 });
  const userId = crypto.randomUUID();
  const externalId = crypto.randomUUID();
  const applicationName = "external-ingest-race-" + crypto.randomUUID();
  let secondResult: Promise<postgres.Row> | undefined;
  let firstActive = false;
  let secondActive = false;
  try {
    await observer`insert into auth.users(id, email, raw_user_meta_data) values (${userId}, 'race@example.test', '{"display_name":"Race importer"}')`;
    await first`begin`;
    firstActive = true;
    await first`set local role service_role`;
    await first`set local statement_timeout = '10s'`;
    const winner = await ingest(first, userId, externalId);
    await second`select set_config('application_name', ${applicationName}, false)`;
    await second`begin`;
    secondActive = true;
    await second`set local role service_role`;
    await second`set local statement_timeout = '10s'`;
    secondResult = ingest(second, userId, externalId);
    let waiting = false;
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline) {
      const [activity] =
        await observer`select wait_event_type from pg_stat_activity where application_name = ${applicationName}`;
      if (activity?.wait_event_type === "Lock") {
        waiting = true;
        break;
      }
      await new Promise((resolve) => setTimeout(resolve, 10));
    }
    assert(
      waiting,
      "Concurrent ingest must overlap and wait for uncommitted identity winner",
    );
    await first`commit`;
    firstActive = false;
    const follower = await secondResult;
    await second`commit`;
    secondActive = false;
    assertEquals(winner.pending_created, true);
    assertEquals(follower.pending_created, false);
    assertEquals(follower.record_id, winner.record_id);
    assertEquals(follower.pending_submission_id, winner.pending_submission_id);
    const [counts] = await observer`select
      (select count(*)::integer from public.external_event_records where provider = 'fixture' and external_id = ${externalId}) as records,
      (select count(*)::integer from public.content_submissions where external_event_record_id = ${winner.record_id} and status = 'pending') as pending`;
    assertEquals(counts, { records: 1, pending: 1 });
  } finally {
    if (firstActive) await first`rollback`;
    // Await an outstanding blocked statement only after its blocker is released.
    if (secondResult) await secondResult.catch(() => {});
    if (secondActive) await second`rollback`;
    await observer`delete from public.content_submissions where external_event_record_id in (select id from public.external_event_records where provider = 'fixture' and external_id = ${externalId})`;
    await observer`delete from public.external_event_records where provider = 'fixture' and external_id = ${externalId}`;
    await observer`delete from auth.users where id = ${userId}`;
    await Promise.all([first.end(), second.end(), observer.end()]);
  }
});

Deno.test("M2 malformed service ingest missing/null start and inverted microsecond range leave no record", () =>
  ingestFixture(async (sql, userId) => {
    for (
      const patch of [{ start_date: null }, {
        end_date: "2026-10-02T10:00:00.123455Z",
      }]
    ) {
      const externalId = crypto.randomUUID();
      const state = { ...normalized, ...patch };
      const [result] =
        await sql`select * from public.ingest_external_event('fixture', ${externalId}, null, null,
      ${sql.json(state)}, 1, ${"a".repeat(64)}, '{}'::jsonb, 1, ${userId})`;
      assertEquals(
        result.outcome,
        patch.start_date === null
          ? "start_date_required"
          : "invalid_date_range",
      );
      assertEquals(result.record_id, null);
      assertEquals(result.pending_submission_id, null);
      const [count] =
        await sql`select count(*)::integer as count from public.external_event_records where provider = 'fixture' and external_id = ${externalId}`;
      assertEquals(count.count, 0);
    }
    const externalId = crypto.randomUUID();
    const [missing] =
      await sql`select * from public.ingest_external_event('fixture', ${externalId}, null, null,
    '{}'::jsonb, 1, ${"a".repeat(64)}, '{}'::jsonb, 1, ${userId})`;
    assertEquals(missing.outcome, "start_date_required");
    const [count] =
      await sql`select count(*)::integer as count from public.external_event_records where provider = 'fixture' and external_id = ${externalId}`;
    assertEquals(count.count, 0);
  }));

Deno.test("M2 unchanged current is reevaluated for enqueue; metadata-only observed state never proposes", () =>
  ingestFixture(async (sql, userId) => {
    const externalId = crypto.randomUUID();
    const first = await ingest(sql, userId, externalId);
    const current = { ...normalized, name: "Y current" };
    await ingest(sql, userId, externalId, current);
    // Prepare a handled-X/current-Y fixture; resolution orchestration is M3.
    await sql`select set_config('app.external_resolution', 'on', true)`;
    await sql`update public.content_submissions set status = 'rejected' where id = ${first.pending_submission_id}`;
    await sql`update public.external_event_records set proposed_normalized = ${
      sql.json(normalized)
    }, proposed_normalization_version = 1,
    proposed_hash = ${await hashNormalizedExternalEvent(
      normalized,
    )} where id = ${first.record_id}`;
    const [before] =
      await sql`select modified_at::text as token from public.external_event_records where id = ${first.record_id}`;
    const followup = await ingest(sql, userId, externalId, current);
    assertEquals(followup.pending_created, true);
    assert(followup.pending_submission_id !== first.pending_submission_id);
    const [after] =
      await sql`select modified_at::text as token from public.external_event_records where id = ${first.record_id}`;
    assertEquals(after.token, before.token);
    assertEquals(
      canonicalizeSubmission(
        await persistedProjection(sql, followup.pending_submission_id),
      ),
      current,
    );
    await sql`update public.content_submissions set status = 'rejected' where id = ${followup.pending_submission_id}`;
    await sql`update public.external_event_records set proposed_normalized = normalized, proposed_normalization_version = normalization_version, proposed_hash = moderation_hash where id = ${first.record_id}`;
    const metadataOnly = await ingest(sql, userId, externalId, current, {
      provider_status: "cancelled",
    });
    assertEquals(metadataOnly.pending_submission_id, null);
    assertEquals(metadataOnly.pending_created, false);
    const [metadata] =
      await sql`select normalized, moderation_hash, proposed_hash, metadata, modified_at::text as token from public.external_event_records where id = ${first.record_id}`;
    assertEquals(metadata.normalized, current);
    assertEquals(
      metadata.moderation_hash,
      await hashNormalizedExternalEvent(current),
    );
    assertEquals(metadata.proposed_hash, metadata.moderation_hash);
    assertEquals(metadata.metadata, { provider_status: "cancelled" });
    assert(metadata.token !== after.token);
    await ingest(sql, userId, externalId, current, {
      provider_status: "cancelled",
    });
    const [same] =
      await sql`select modified_at::text as token from public.external_event_records where id = ${first.record_id}`;
    assertEquals(same.token, metadata.token);
  }));

Deno.test("M2 separate PostgREST ingest transactions preserve successful sibling after failure", async () => {
  const sql = postgres(databaseUrl, { max: 1 });
  const userId = crypto.randomUUID();
  const externalId = crypto.randomUUID();
  let recordId: string | undefined;
  try {
    await sql`insert into auth.users(id, email, raw_user_meta_data) values (${userId}, 'separate@example.test', '{"display_name":"Separate importer"}')`;
    const args = {
      p_provider: "fixture",
      p_external_id: externalId,
      p_occurrence_key: null,
      p_source_url: null,
      p_normalized: normalized,
      p_normalization_version: 1,
      p_moderation_hash: await hashNormalizedExternalEvent(normalized),
      p_metadata: {},
      p_metadata_version: 1,
      p_importer_user_id: userId,
    };
    const success = await rest("rpc/ingest_external_event", {
      method: "POST",
      body: JSON.stringify(args),
    });
    assertEquals(success.status, 200);
    const [created] = await success.json();
    recordId = String(created.record_id);
    const failure = await rest("rpc/ingest_external_event", {
      method: "POST",
      body: JSON.stringify({ ...args, p_provider: "INVALID" }),
    });
    assert(failure.status >= 400);
    await failure.text();
    const [survivor] =
      await sql`select count(*)::integer as count from public.content_submissions where external_event_record_id = ${recordId}`;
    assertEquals(survivor.count, 1);
    const [failed] =
      await sql`select count(*)::integer as count from public.external_event_records where provider = 'INVALID' and external_id = ${externalId}`;
    assertEquals(failed.count, 0);
  } finally {
    if (recordId) {
      await sql`delete from public.content_submissions where external_event_record_id = ${recordId}`;
      await sql`delete from public.external_event_records where id = ${recordId}`;
    }
    await sql`delete from auth.users where id = ${userId}`;
    await sql.end();
  }
});

const projectionFixtures: Array<
  { name: string; state: NormalizedExternalEvent }
> = [
  { name: "nullable timed start-only microsecond", state: normalized },
  {
    name: "rich Unicode Delta, location and bounded schedule",
    state: canonicalizeExternalEvent({
      ...normalized,
      name: " Café ",
      city: " Isernia ",
      category: "history",
      description: "Cafe\u0301\nItem",
      description_delta: [
        {
          insert: "Cafe\u0301",
          attributes: {
            underline: true,
            link: "https://example.test/Cafe\u0301",
            italic: true,
            bold: true,
          },
        },
        { insert: "\n", attributes: { list: "ordered" } },
        { insert: "Item\n" },
      ],
      latitude: "41.123456789012344",
      longitude: "14.123456789012345",
      end_date: "2026-10-02T10:00:00.654321Z",
    }),
  },
  {
    name: "cross-operation combining mark, all-day DST last microsecond",
    state: canonicalizeExternalEvent({
      ...normalized,
      description: "é",
      description_delta: [{ insert: "e", attributes: { bold: true } }, {
        insert: "\u0301\n",
      }],
      all_day: true,
      start_date: "2026-10-24T22:00:00.000000Z",
      end_date: "2026-10-25T22:59:59.999999Z",
    }),
  },
  {
    name:
      "empty description distinct from null, negative zero and equal bounds",
    state: canonicalizeExternalEvent({
      ...normalized,
      description: "",
      latitude: "-0",
      longitude: "0",
      end_date: normalized.start_date,
    }),
  },
  {
    name:
      "single all-day civil start with nullable end and small scientific coordinates",
    state: canonicalizeExternalEvent({
      ...normalized,
      all_day: true,
      start_date: "2026-03-28T23:00:00.000000Z",
      latitude: "0.0000000012345678901234567",
      longitude: "-0.0000000008765432109876543",
    }),
  },
  ...([
    "unknown",
    "nature",
    "history",
    "folklore",
    "food",
    "allure",
    "experience",
  ] as const).map((category) => ({
    name: "category " + category,
    state: canonicalizeExternalEvent({ ...normalized, category }),
  })),
];
for (const fixture of projectionFixtures) {
  Deno.test(`M2 enqueue projection before any Admin load/Save: ${fixture.name}`, () =>
    ingestFixture(async (sql, userId) => {
      const state = fixture.state;
      const [source] = await sql`insert into public.external_event_records
      (provider, external_id, normalized, normalization_version, moderation_hash, metadata_version)
      values ('projection', ${crypto.randomUUID()}, ${
        sql.json(state)
      }, 1, ${await hashNormalizedExternalEvent(state)}, 1) returning id`;
      await sql`select id from public.external_event_records where id = ${source.id} for update`;
      const [proposal] =
        await sql`select * from private.enqueue_external_event_proposal_if_needed(${source.id}, ${userId}, 'importer@example.test', 'Importer fixture')`;
      assertEquals(proposal.pending_created, true);
      const row = await persistedProjection(
        sql,
        proposal.pending_submission_id,
      );
      // Assert raw projection too, so canonicalization cannot mask a SQL rewrite.
      for (
        const field of [
          "name",
          "category",
          "description",
          "description_delta",
          "city",
          "all_day",
        ] as const
      ) {
        assertEquals(row[field], state[field], `${fixture.name} raw ${field}`);
      }
      assertEquals(row.latitude === null, state.latitude === null);
      assertEquals(row.longitude === null, state.longitude === null);
      assertEquals(row.end_date === null, state.end_date === null);
      assertEquals(typeof row.start_date, "string");
      const canonical = canonicalizeSubmission(row);
      for (
        const field of [
          "name",
          "category",
          "description",
          "description_delta",
          "city",
          "latitude",
          "longitude",
          "all_day",
          "start_date",
          "end_date",
        ] as const
      ) {
        assertEquals(
          canonical[field],
          state[field],
          `${fixture.name} canonical ${field}`,
        );
      }
      assertEquals(canonical, state);
      assertEquals(
        await hashNormalizedExternalEvent(canonical),
        await hashNormalizedExternalEvent(state),
      );
    }));
}
