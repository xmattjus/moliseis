import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.112.3";
import type { Database } from "../functions/_shared/database.types.ts";
import { importSourceAssetIfEligible } from "../functions/import-external-events/index.ts";
import { serveRequest as notifyRequest } from "../functions/notify-submission-status/index.ts";
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import postgres, { type Sql } from "npm:postgres@3.4.5";
import {
  canonicalizeExternalEvent,
  hashNormalizedExternalEvent,
} from "../functions/_shared/external_event_normalization.ts";
const databaseUrl = Deno.env.get("SUPABASE_DB_URL") ?? "";
assert(["localhost", "127.0.0.1"].includes(new URL(databaseUrl).hostname));
const normalized = canonicalizeExternalEvent({
  name: "Asset fixture",
  city: "City",
  description: null,
  description_delta: null,
  category: "experience",
  latitude: 41,
  longitude: 14,
  all_day: false,
  start_date: "2026-10-02T10:00:00.123456Z",
  end_date: null,
});
async function fixture(
  run: (
    sql: Sql,
    userId: string,
    source: Record<string, unknown>,
    eventId: string,
  ) => Promise<void>,
) {
  const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
  const userId = crypto.randomUUID();
  await sql`begin`;
  try {
    await sql`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'assets@example.test','{"display_name":"Assets"}')`;
    const [source] =
      await sql`select * from public.ingest_external_event('assets',${crypto.randomUUID()},null,null,${
        sql.json(normalized)
      },1,${await hashNormalizedExternalEvent(normalized)},'{}',1,${userId})`;
    const [event] =
      await sql`insert into public.events(name,start_date,latitude,longitude) values ('Existing Event','2026-10-02',41,14) returning id`;
    await run(sql, userId, source, String(event.id));
  } finally {
    await sql`rollback`;
    await sql.end();
  }
}

Deno.test("M7 structural trigger suppresses imported Link/Reject queues and preserves human Link webhook", () =>
  fixture(async (sql, userId, source, eventId) => {
    // Dummy configuration exists only in the rolled-back transaction. Uncommitted
    // pg_net queue rows cannot be delivered by its background worker.
    await sql`delete from vault.secrets where name in ('notify_submission_status_url','notify_submission_status_webhook_secret')`;
    const queueUrl = `http://127.0.0.1:1/fixture/${crypto.randomUUID()}`;
    await sql`select vault.create_secret(${queueUrl},'notify_submission_status_url')`;
    await sql`select vault.create_secret('dummy-fixture-secret','notify_submission_status_webhook_secret')`;
    const [{ count: initial }] =
      await sql`select count(*)::int as count from net.http_request_queue where url=${queueUrl}`;
    await sql`select * from public.link_content_submission_to_event(${
      String(source.pending_submission_id)
    },${eventId},${userId})`;
    const [second] =
      await sql`select * from public.ingest_external_event('assets',${crypto.randomUUID()},null,null,${
        sql.json(normalized)
      },1,${await hashNormalizedExternalEvent(normalized)},'{}',1,${userId})`;
    await sql`select * from public.reject_external_event_submission(${
      String(second.pending_submission_id)
    },${userId})`;
    assertEquals(
      (await sql`select count(*)::int as count from net.http_request_queue where url=${queueUrl}`)[
        0
      ]
        .count,
      initial,
    );
    const [human] =
      await sql`insert into public.content_submissions(user_id,user_email,user_name,city,name,start_date) values (${userId},'human@example.test','Human','City','Human Event','2026-10-02') returning id`;
    await sql`select * from public.link_content_submission_to_event(${human.id},${eventId},${userId})`;
    assertEquals(
      (await sql`select count(*)::int as count from net.http_request_queue where url=${queueUrl}`)[
        0
      ]
        .count,
      initial + 1,
    );
    const [queued] =
      await sql`select convert_from(body,'UTF8')::jsonb->'record' as record,convert_from(body,'UTF8')::jsonb->'old_record' as previous from net.http_request_queue where url=${queueUrl} and convert_from(body,'UTF8')::jsonb->'record'->>'id'=${
        String(human.id)
      }`;
    assertEquals(queued, {
      record: { id: Number(human.id), status: "accepted" },
      previous: { id: Number(human.id), status: "pending" },
    });
  }));

function localNotificationEnvironment() {
  const values: Record<string, string | undefined> = {
    SUPABASE_URL: Deno.env.get("API_URL"),
    SUPABASE_SERVICE_ROLE_KEY: Deno.env.get("SERVICE_ROLE_KEY"),
    SUPABASE_SECRET_KEYS: undefined,
    EXTERNAL_EVENTS_IMPORTER_USER_ID: crypto.randomUUID(),
    BREVO_SENDER_EMAIL: "sender@example.test",
    BREVO_API_KEY: "dummy-fixture-key",
    BREVO_SENDER_NAME: "Fixture sender",
    BREVO_REPLY_TO_EMAIL: "sender@example.test",
    BREVO_MONITOR_EMAIL: undefined,
  };
  assert(
    ["localhost", "127.0.0.1"].includes(new URL(values.SUPABASE_URL!).hostname),
  );
  const previous = Object.fromEntries(
    Object.keys(values).map((key) => [key, Deno.env.get(key)]),
  );
  for (const [key, value] of Object.entries(values)) {
    if (value === undefined) Deno.env.delete(key);
    else Deno.env.set(key, value);
  }
  return () => {
    for (const [key, value] of Object.entries(previous)) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  };
}

Deno.test("M7 actual notification webhook/manual retry structurally suppress imported rows before email claim", async () => {
  const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
  const userId = crypto.randomUUID();
  let source: Record<string, unknown> | undefined;
  const restoreEnvironment = localNotificationEnvironment();
  const originalFetch = globalThis.fetch;
  let emails = 0;
  globalThis.fetch = (input, init) => {
    const url = input instanceof Request ? input.url : String(input);
    if (url.startsWith("https://api.brevo.com/")) {
      emails++;
      return Promise.reject(new Error("Unexpected email transport"));
    }
    return originalFetch(input, init);
  };
  try {
    await sql`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'external@example.test','{"display_name":"External"}')`;
    [source] =
      await sql`select * from public.ingest_external_event('assets',${crypto.randomUUID()},null,null,${
        sql.json(normalized)
      },1,${await hashNormalizedExternalEvent(normalized)},'{}',1,${userId})`;
    assert(source);
    await sql`select * from public.reject_external_event_submission(${
      String(source.pending_submission_id)
    },${userId})`;
    for (
      const body of [{
        action: "retry",
        submission_id: Number(source.pending_submission_id),
      }, {
        type: "UPDATE",
        schema: "public",
        table: "content_submissions",
        record: {
          id: Number(source.pending_submission_id),
          status: "rejected",
        },
        old_record: { status: "pending" },
      }]
    ) {
      const response = await notifyRequest(
        new Request("http://localhost", {
          method: "POST",
          headers: { "x-webhook-secret": "dummy-secret" },
          body: JSON.stringify(body),
        }),
        "dummy-secret",
      );
      assertEquals(response.status, 200);
      assertEquals(
        (await response.json()).reason,
        "Submission has external provenance",
      );
    }
    assertEquals(emails, 0);
    assertEquals(
      (await sql`select status_email_state,status_email_key from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`)[0],
      { status_email_state: null, status_email_key: null },
    );
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnvironment();
    if (source) {
      await sql`delete from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      }`;
      await sql`delete from public.external_event_records where id=${
        String(source.record_id)
      }`;
    }
    await sql`delete from auth.users where id=${userId}`;
    await sql.end();
  }
});

Deno.test("M7 notification claim excludes verified provenance backfilled after legacy row was fetched", async () => {
  const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
  const userId = crypto.randomUUID();
  let source: Record<string, unknown> | undefined,
    humanId: string | undefined,
    eventId: string | undefined;
  const restoreEnvironment = localNotificationEnvironment(),
    originalFetch = globalThis.fetch;
  let emails = 0, backfilled = false;
  try {
    await sql`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'legacy@example.test','{"display_name":"Legacy"}')`;
    [source] =
      await sql`select * from public.ingest_external_event('assets',${crypto.randomUUID()},null,null,${
        sql.json(normalized)
      },1,${await hashNormalizedExternalEvent(normalized)},'{}',1,${userId})`;
    const [event] =
      await sql`insert into public.events(name,start_date,latitude,longitude) values ('Human notification target','2026-10-02',41,14) returning id`;
    eventId = String(event.id);
    const [human] =
      await sql`insert into public.content_submissions(user_id,user_email,user_name,city,name,start_date) values (${userId},'human@example.test','Human','City','Human Event','2026-10-02') returning id`;
    humanId = String(human.id);
    await sql`select * from public.link_content_submission_to_event(${humanId},${eventId},${userId})`;
    globalThis.fetch = async (input, init) => {
      const url = input instanceof Request ? input.url : String(input);
      if (url.startsWith("https://api.brevo.com/")) {
        emails++;
        throw new Error("Unexpected email transport");
      }
      const response = await originalFetch(input, init);
      if (
        !backfilled && url.includes("/rest/v1/content_submissions") &&
        (init?.method ?? (input instanceof Request ? input.method : "GET")) ===
          "GET"
      ) {
        backfilled = true;
        await sql`update public.content_submissions set external_event_record_id=${
          String(source!.record_id)
        },external_normalized=${
          sql.json(normalized)
        },external_normalization_version=1,external_moderation_hash=${await hashNormalizedExternalEvent(
          normalized,
        )} where id=${humanId!}`;
      }
      return response;
    };
    const response = await notifyRequest(
      new Request("http://localhost", {
        method: "POST",
        headers: { "x-webhook-secret": "dummy-secret" },
        body: JSON.stringify({
          action: "retry",
          submission_id: Number(humanId),
        }),
      }),
      "dummy-secret",
    );
    assertEquals(response.status, 200);
    assertEquals((await response.json()).ignored, true);
    assertEquals(backfilled, true);
    assertEquals(emails, 0);
    assertEquals(
      (await sql`select status_email_state,status_email_key from public.content_submissions where id=${humanId}`)[
        0
      ],
      { status_email_state: null, status_email_key: null },
    );
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnvironment();
    if (source) {
      await sql`delete from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      }`;
      await sql`delete from public.external_event_records where id=${
        String(source.record_id)
      }`;
    } else if (humanId) {
      await sql`delete from public.content_submissions where id=${humanId}`;
    }
    if (eventId) await sql`delete from public.events where id=${eventId}`;
    await sql`delete from auth.users where id=${userId}`;
    await sql.end();
  }
});

Deno.test("M7 claim checks persisted imported/pending/unlinked/zero-assets state and consumes immutable budget", () =>
  fixture(async (sql, userId, source, eventId) => {
    const id = String(source.pending_submission_id);
    assertEquals(
      (await sql`select * from public.claim_external_event_source_asset(987654321)`)[
        0
      ].outcome,
      "not_found",
    );
    const [human] =
      await sql`insert into public.content_submissions(user_id,user_email,user_name,city,name) values (${userId},'human@example.test','Human','City','Human') returning id`;
    assertEquals(
      (await sql`select * from public.claim_external_event_source_asset(${human.id})`)[
        0
      ].outcome,
      "not_imported",
    );
    await sql`savepoint linked`;
    await sql`update public.external_event_records set event_id=${eventId} where id=${
      String(source.record_id)
    }`;
    assertEquals(
      (await sql`select * from public.claim_external_event_source_asset(${id})`)[
        0
      ].outcome,
      "source_already_linked",
    );
    assertEquals(
      (await sql`select source_asset_import_claimed_at from public.content_submissions where id=${id}`)[
        0
      ].source_asset_import_claimed_at,
      null,
    );
    await sql`rollback to savepoint linked`;
    await sql`savepoint assets`;
    await sql`select * from public.add_submission_assets(${id},'[ {"url":"https://res.cloudinary.com/test/image/upload/v1/asset.png","width":100,"height":100,"mime_type":"image/png","duration_seconds":null} ]')`;
    assertEquals(
      (await sql`select * from public.claim_external_event_source_asset(${id})`)[
        0
      ].outcome,
      "assets_present",
    );
    assertEquals(
      (await sql`select source_asset_import_claimed_at from public.content_submissions where id=${id}`)[
        0
      ].source_asset_import_claimed_at,
      null,
    );
    await sql`rollback to savepoint assets`;
    for (const role of ["anon", "authenticated"]) {
      await sql`savepoint denied`;
      await sql.unsafe(`set local role ${role}`);
      const error = await assertRejects(() =>
        sql`select * from public.claim_external_event_source_asset(${id})`
      );
      assertEquals((error as unknown as { code: string }).code, "42501");
      await sql`rollback to savepoint denied`;
    }
    const [before] =
      await sql`select modified_at::text as token from public.content_submissions where id=${id}`;
    await sql`set local role service_role`;
    assertEquals(
      (await sql`select * from public.claim_external_event_source_asset(${id})`)[
        0
      ].outcome,
      "claimed",
    );
    const [claimed] =
      await sql`select source_asset_import_claimed_at::text as claimed,modified_at::text as token from public.content_submissions where id=${id}`;
    assert(claimed.claimed !== null);
    assertEquals(claimed.token, before.token);
    assertEquals(
      (await sql`select * from public.claim_external_event_source_asset(${id})`)[
        0
      ].outcome,
      "already_claimed",
    );
    await sql`reset role`;
    for (const reset of [null, "2000-01-01"]) {
      await sql`savepoint no_reset`;
      const error = await assertRejects(() =>
        sql`update public.content_submissions set source_asset_import_claimed_at=${reset}::timestamptz where id=${id}`
      );
      assertEquals((error as Error).message, "source_asset_claim_irreversible");
      await sql`rollback to savepoint no_reset`;
    }
    assertEquals(
      (await sql`select source_asset_import_claimed_at::text as claimed from public.content_submissions where id=${id}`)[
        0
      ].claimed,
      claimed.claimed,
    );
    await sql`select * from public.reject_external_event_submission(${id},${userId})`;
    assertEquals(
      (await sql`select * from public.claim_external_event_source_asset(${id})`)[
        0
      ].outcome,
      "not_pending",
    );
  }));

async function waitForAssetLock(sql: Sql, pid: number) {
  const until = Date.now() + 5000;
  while (Date.now() < until) {
    if (
      (await sql`select wait_event_type from pg_stat_activity where pid=${pid}`)[
        0
      ]?.wait_event_type === "Lock"
    ) return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error("Expected real asset-claim lock overlap");
}
Deno.test("M7 overlapping claims have exactly one winner with submission→record locks", async () => {
  const observer = postgres(databaseUrl, { max: 1, onnotice: () => {} }),
    first = postgres(databaseUrl, { max: 1, onnotice: () => {} }),
    second = postgres(databaseUrl, { max: 1, onnotice: () => {} });
  const userId = crypto.randomUUID();
  let source: Record<string, unknown> | undefined,
    firstActive = false,
    secondActive = false;
  let claiming: Promise<postgres.RowList<postgres.Row[]>> | undefined;
  try {
    await observer`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'race@example.test','{"display_name":"Race"}')`;
    [source] =
      await observer`select * from public.ingest_external_event('assets',${crypto.randomUUID()},null,null,${
        observer.json(normalized)
      },1,${await hashNormalizedExternalEvent(normalized)},'{}',1,${userId})`;
    assert(source);
    await first`begin`;
    firstActive = true;
    assertEquals(
      (await first`select * from public.claim_external_event_source_asset(${
        String(source.pending_submission_id)
      })`)[0].outcome,
      "claimed",
    );
    for (
      const query of [
        `select id from public.content_submissions where id=${
          Number(source.pending_submission_id)
        } for update nowait`,
        `select id from public.external_event_records where id=${
          Number(source.record_id)
        } for update nowait`,
      ]
    ) {
      const error = await assertRejects(() => observer.unsafe(query));
      assertEquals((error as unknown as { code: string }).code, "55P03");
    }
    await second`begin`;
    secondActive = true;
    await second`set local statement_timeout='10s'`;
    const [{ pid }] = await second`select pg_backend_pid() as pid`;
    claiming = Promise.resolve(
      second`select * from public.claim_external_event_source_asset(${
        String(source.pending_submission_id)
      })`,
    );
    await waitForAssetLock(observer, pid);
    await first`commit`;
    firstActive = false;
    assertEquals((await claiming)[0].outcome, "already_claimed");
    await second`commit`;
    secondActive = false;
    assert(
      (await observer`select source_asset_import_claimed_at from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`)[0].source_asset_import_claimed_at !== null,
    );
  } finally {
    if (firstActive) await first`rollback`;
    if (claiming) await claiming.catch(() => {});
    if (secondActive) await second`rollback`;
    if (source) {
      await observer`delete from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      }`;
      await observer`delete from public.external_event_records where id=${
        String(source.record_id)
      }`;
    }
    await observer`delete from auth.users where id=${userId}`;
    await Promise.all([observer.end(), first.end(), second.end()]);
  }
});

const imageUrl = "https://eventimolise.it/wp-content/uploads/fixture.png";
const cloudinaryFixture = {
  cloudName: "fixture",
  apiKey: "dummy",
  apiSecret: "dummy",
};
const uploadedFixture = {
  url: "https://res.cloudinary.com/fixture/image/upload/v1/source.png",
  width: 100,
  height: 100,
  mimeType: "image/png",
  publicId: "fixture/source",
};
async function committedAssetFixture(
  run: (
    sql: Sql,
    client: SupabaseClient<Database>,
    userId: string,
    source: Record<string, unknown>,
    eventIds: string[],
  ) => Promise<void>,
) {
  const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} }),
    userId = crypto.randomUUID(),
    eventIds: string[] = [];
  let source: Record<string, unknown> | undefined;
  try {
    await sql`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'image@example.test','{"display_name":"Image"}')`;
    [source] =
      await sql`select * from public.ingest_external_event('assets',${crypto.randomUUID()},null,null,${
        sql.json(normalized)
      },1,${await hashNormalizedExternalEvent(normalized)},'{}',1,${userId})`;
    assert(source);
    const url = Deno.env.get("API_URL")!;
    assert(["localhost", "127.0.0.1"].includes(new URL(url).hostname));
    const client = createClient<Database>(
      url,
      Deno.env.get("SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    await run(sql, client, userId, source, eventIds);
  } finally {
    if (source) {
      await sql`delete from public.submissions_assets where content_submission_id in (select id from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      })`;
      await sql`delete from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      }`;
      await sql`delete from public.external_event_records where id=${
        String(source.record_id)
      }`;
    }
    for (const id of eventIds) {
      await sql`delete from public.events where id=${id}`;
    }
    await sql`delete from auth.users where id=${userId}`;
    await sql.end();
  }
}
function assetParams(source: Record<string, unknown>) {
  return {
    event: { imageUrl },
    observation: {
      record_id: Number(source.record_id),
      event_id: source.event_id === null ? null : Number(source.event_id),
      pending_submission_id: source.pending_submission_id === null
        ? null
        : Number(source.pending_submission_id),
      pending_created: false,
    },
    cloudinary: cloudinaryFixture,
  };
}
Deno.test("M7 failed automatic upload consumes real committed claim and later observation never retries", () =>
  committedAssetFixture(async (sql, client, userId, source) => {
    let uploads = 0;
    const dependencies = {
      uploadRemoteImage: () => {
        uploads++;
        return Promise.reject(new Error("Source permanently unavailable"));
      },
      destroyCloudinaryImage: () => Promise.resolve(),
    };
    await assertRejects(
      () =>
        importSourceAssetIfEligible(client, assetParams(source), dependencies),
      Error,
      "Source permanently unavailable",
    );
    const [claim] =
      await sql`select source_asset_import_claimed_at::text as value from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assert(claim.value !== null);
    assertEquals(
      await importSourceAssetIfEligible(
        client,
        assetParams(await reobserveAssetSource(sql, userId, source)),
        dependencies,
      ),
      "skipped",
    );
    assertEquals(uploads, 1);
    assertEquals(
      (await sql`select source_asset_import_claimed_at::text as value from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`)[0],
      claim,
    );
  }));
Deno.test("M7 finalization after source upload claim cleans orphan and keeps irreversible budget", () =>
  committedAssetFixture(async (sql, client, userId, source, eventIds) => {
    const destroyed: string[] = [];
    await assertRejects(
      () =>
        importSourceAssetIfEligible(client, assetParams(source), {
          uploadRemoteImage: async () => {
            const [event] =
              await sql`insert into public.events(name,start_date,latitude,longitude) values ('Finalize during image upload','2026-10-02',41,14) returning id`;
            eventIds.push(String(event.id));
            await sql`select * from public.link_content_submission_to_event(${
              String(source.pending_submission_id)
            },${event.id},${userId})`;
            return uploadedFixture;
          },
          destroyCloudinaryImage: ({ publicId }) => {
            destroyed.push(publicId);
            return Promise.resolve();
          },
        }),
      Error,
      "not_pending",
    );
    assertEquals(destroyed, [uploadedFixture.publicId]);
    const [row] =
      await sql`select source_asset_import_claimed_at,status from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assert(row.source_asset_import_claimed_at !== null);
    assertEquals(row.status, "accepted");
    assertEquals(
      (await sql`select count(*)::int as count from public.submissions_assets where content_submission_id=${
        String(source.pending_submission_id)
      }`)[0].count,
      0,
    );
  }));

async function reobserveAssetSource(
  sql: Sql,
  userId: string,
  source: Record<string, unknown>,
) {
  const [record] =
    await sql`select external_id from public.external_event_records where id=${
      String(source.record_id)
    }`;
  return (await sql`select * from public.ingest_external_event('assets',${record.external_id},null,null,${
    sql.json(normalized)
  },1,${await hashNormalizedExternalEvent(normalized)},'{}',1,${userId})`)[0];
}
Deno.test("M7 overlapping Edge runs upload once; successful moderator removal is permanent across ingest", () =>
  committedAssetFixture(async (sql, client, userId, source) => {
    let uploads = 0;
    const dependencies = {
      uploadRemoteImage: () => {
        uploads++;
        return Promise.resolve(uploadedFixture);
      },
      destroyCloudinaryImage: () => Promise.resolve(),
    };
    const results = await Promise.all([
      importSourceAssetIfEligible(client, assetParams(source), dependencies),
      importSourceAssetIfEligible(client, assetParams(source), dependencies),
    ]);
    assertEquals([...results].sort(), ["skipped", "uploaded"]);
    assertEquals(uploads, 1);
    const [asset] =
      await sql`select id from public.submissions_assets where content_submission_id=${
        String(source.pending_submission_id)
      }`;
    assert(asset);
    assertEquals(
      (await client.rpc("delete_submission_asset", {
        p_submission_id: Number(source.pending_submission_id),
        p_asset_id: Number(asset.id),
      })).data,
      "deleted",
    );
    const repeated = await reobserveAssetSource(sql, userId, source);
    assertEquals(repeated.pending_created, false);
    assertEquals(
      Number(repeated.pending_submission_id),
      Number(source.pending_submission_id),
    );
    assertEquals(
      await importSourceAssetIfEligible(
        client,
        assetParams(repeated),
        dependencies,
      ),
      "skipped",
    );
    assertEquals(uploads, 1);
    assertEquals(
      (await sql`select count(*)::int as count from public.submissions_assets where content_submission_id=${
        String(source.pending_submission_id)
      }`)[0].count,
      0,
    );
  }));
Deno.test("M7 conservative migrated legacy budget blocks fresh import despite zero assets", () =>
  committedAssetFixture(async (sql, client, userId, source) => {
    // Migration-time suppression of a failed/unverifiable prior attempt, never a
    // fabricated historical upload timestamp. M8 owns audited classification.
    await sql`update public.content_submissions set source_asset_import_claimed_at=clock_timestamp() where id=${
      String(source.pending_submission_id)
    }`;
    const [before] =
      await sql`select source_asset_import_claimed_at::text as value from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    const repeated = await reobserveAssetSource(sql, userId, source);
    let uploads = 0;
    assertEquals(
      await importSourceAssetIfEligible(client, assetParams(repeated), {
        uploadRemoteImage: () => {
          uploads++;
          return Promise.resolve(uploadedFixture);
        },
        destroyCloudinaryImage: () => Promise.resolve(),
      }),
      "skipped",
    );
    assertEquals(uploads, 0);
    assertEquals(
      (await sql`select source_asset_import_claimed_at::text as value from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`)[0],
      before,
    );
  }));
Deno.test("M7 linked source observations never import images for update pending", () =>
  committedAssetFixture(async (sql, client, userId, source, eventIds) => {
    const [event] =
      await sql`insert into public.events(name,start_date,latitude,longitude) values ('Already linked image target','2026-10-02',41,14) returning id`;
    eventIds.push(String(event.id));
    await sql`select * from public.link_content_submission_to_event(${
      String(source.pending_submission_id)
    },${event.id},${userId})`;
    const [record] =
      await sql`select external_id from public.external_event_records where id=${
        String(source.record_id)
      }`;
    const changed = { ...normalized, name: "Provider source update" };
    const [update] =
      await sql`select * from public.ingest_external_event('assets',${record.external_id},null,null,${
        sql.json(changed)
      },1,${await hashNormalizedExternalEvent(changed)},'{}',1,${userId})`;
    assert(update.pending_submission_id !== null);
    assertEquals(Number(update.event_id), Number(event.id));
    assertEquals(
      await importSourceAssetIfEligible(client, assetParams(update), {
        uploadRemoteImage: () =>
          Promise.reject(new Error("Linked update must never upload")),
        destroyCloudinaryImage: () => Promise.resolve(),
      }),
      "skipped",
    );
    assertEquals(
      (await sql`select source_asset_import_claimed_at from public.content_submissions where id=${
        String(update.pending_submission_id)
      }`)[0].source_asset_import_claimed_at,
      null,
    );
  }));
Deno.test("M7 existing-asset writer serializes with claim and denies fresh budget after commit", () =>
  committedAssetFixture(async (sql, _client, _userId, source) => {
    const writer = postgres(databaseUrl, { max: 1, onnotice: () => {} }),
      claimer = postgres(databaseUrl, { max: 1, onnotice: () => {} });
    let writerActive = false,
      claimerActive = false,
      claiming: Promise<postgres.RowList<postgres.Row[]>> | undefined;
    try {
      await writer`begin`;
      writerActive = true;
      await writer`select * from public.add_submission_assets(${
        String(source.pending_submission_id)
      },'[ {"url":"https://res.cloudinary.com/test/image/upload/v1/moderator.png","width":100,"height":100,"mime_type":"image/png","duration_seconds":null} ]')`;
      await claimer`begin`;
      claimerActive = true;
      await claimer`set local statement_timeout='10s'`;
      const [{ pid }] = await claimer`select pg_backend_pid() as pid`;
      claiming = Promise.resolve(
        claimer`select * from public.claim_external_event_source_asset(${
          String(source.pending_submission_id)
        })`,
      );
      await waitForAssetLock(sql, pid);
      await writer`commit`;
      writerActive = false;
      assertEquals((await claiming)[0].outcome, "assets_present");
      await claimer`commit`;
      claimerActive = false;
      assertEquals(
        (await sql`select source_asset_import_claimed_at from public.content_submissions where id=${
          String(source.pending_submission_id)
        }`)[0].source_asset_import_claimed_at,
        null,
      );
    } finally {
      if (writerActive) await writer`rollback`;
      if (claiming) await claiming.catch(() => {});
      if (claimerActive) await claimer`rollback`;
      await Promise.all([writer.end(), claimer.end()]);
    }
  }));

Deno.test("M7 human Event Link retains ordinary accepted email without promoted ID; legacy UUID skip remains distinct", async () => {
  const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} }),
    userId = crypto.randomUUID();
  let humanId: string | undefined, eventId: string | undefined;
  const restoreEnvironment = localNotificationEnvironment(),
    originalFetch = globalThis.fetch;
  const payloads: Array<Record<string, unknown>> = [];
  globalThis.fetch = (input, init) => {
    const url = input instanceof Request ? input.url : String(input);
    if (url === "https://api.brevo.com/v3/smtp/email") {
      payloads.push(JSON.parse(String(init?.body)));
      return Promise.resolve(
        new Response(JSON.stringify({ messageId: "fixture-message-id" }), {
          status: 201,
          headers: { "Content-Type": "application/json" },
        }),
      );
    }
    assert(["localhost", "127.0.0.1"].includes(new URL(url).hostname));
    return originalFetch(input, init);
  };
  try {
    await sql`insert into auth.users(id,email) values (${userId},'human@example.test')`;
    const [event] =
      await sql`insert into public.events(name,start_date,latitude,longitude) values ('Existing canonical Event','2026-10-02',41,14) returning id`;
    eventId = String(event.id);
    const [beforeEvent] =
      await sql`select to_jsonb(e) as value from public.events e where id=${eventId}`;
    const [human] =
      await sql`insert into public.content_submissions(user_id,user_email,user_name,city,name,start_date) values (${userId},'human@example.test','Persona & Utente','Città di Prova','Concerto & Test','2026-10-02') returning id`;
    humanId = String(human.id);
    const [linked] =
      await sql`select * from public.link_content_submission_to_event(${humanId},${eventId},${userId})`;
    assertEquals(linked.outcome, "linked");
    assertEquals(
      (await sql`select status,target_event_id,promoted_event_id,external_event_record_id from public.content_submissions where id=${humanId}`)[
        0
      ],
      {
        status: "accepted",
        target_event_id: eventId,
        promoted_event_id: null,
        external_event_record_id: null,
      },
    );
    const request = (body: unknown) =>
      notifyRequest(
        new Request("http://localhost", {
          method: "POST",
          headers: { "x-webhook-secret": "dummy-secret" },
          body: JSON.stringify(body),
        }),
        "dummy-secret",
      );
    const sent = await request({
      type: "UPDATE",
      schema: "public",
      table: "content_submissions",
      record: { id: Number(humanId), status: "accepted" },
      old_record: { status: "pending" },
    });
    assertEquals(sent.status, 200);
    assertEquals((await sent.json()).sent, true);
    assertEquals(payloads.length, 1);
    const payload = payloads[0];
    assertEquals(payload.to, [{
      email: "human@example.test",
      name: "Persona & Utente",
    }]);
    assertEquals(
      payload.subject,
      "La tua proposta “Concerto & Test” è stata approvata",
    );
    assert(String(payload.textContent).includes("Ciao Persona & Utente,"));
    assert(String(payload.textContent).includes("comune di Città di Prova"));
    assert(String(payload.htmlContent).includes("Concerto &amp; Test"));
    assert(String(payload.htmlContent).includes("Persona &amp; Utente"));
    assert(String(payload.htmlContent).includes("Città di Prova"));
    assertEquals(payload.tags, ["content-submission", "status-accepted"]);
    assertEquals(
      (await sql`select status_email_state,status_email_message_id from public.content_submissions where id=${humanId}`)[
        0
      ],
      {
        status_email_state: "sent",
        status_email_message_id: "fixture-message-id",
      },
    );
    assertEquals(
      (await sql`select to_jsonb(e) as value from public.events e where id=${eventId}`)[
        0
      ],
      beforeEvent,
    );
    assertEquals(
      (await sql`select count(*)::int as count from public.media where event_id=${eventId}`)[
        0
      ].count,
      0,
    );
    Deno.env.set("EXTERNAL_EVENTS_IMPORTER_USER_ID", userId);
    const legacy = await request({
      action: "retry",
      submission_id: Number(humanId),
    });
    assertEquals(
      (await legacy.json()).reason,
      "Submission belongs to the external-events importer",
    );
    assertEquals(payloads.length, 1);
  } finally {
    globalThis.fetch = originalFetch;
    restoreEnvironment();
    if (humanId) {
      await sql`delete from public.content_submissions where id=${humanId}`;
    }
    if (eventId) await sql`delete from public.events where id=${eventId}`;
    await sql`delete from auth.users where id=${userId}`;
    await sql.end();
  }
});
