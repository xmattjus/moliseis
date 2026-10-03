import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import type { Database } from "../functions/_shared/database.types.ts";
import { createAdminSubmissionStore } from "../functions/admin-content-submissions/admin_submission_store.ts";
import { createHandler } from "../functions/admin-content-submissions/index.ts";
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import postgres, { type Sql } from "npm:postgres@3.4.5";
import {
  hashNormalizedExternalEvent,
  type NormalizedExternalEvent,
} from "../functions/_shared/external_event_normalization.ts";

const databaseUrl = Deno.env.get("SUPABASE_DB_URL") ?? "";
assert(["localhost", "127.0.0.1"].includes(new URL(databaseUrl).hostname));
const state: NormalizedExternalEvent = {
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
async function fixture(
  run: (
    sql: Sql,
    userId: string,
    source: Record<string, unknown>,
  ) => Promise<void>,
) {
  const sql = postgres(databaseUrl, { max: 1 });
  const userId = crypto.randomUUID();
  try {
    await sql`begin`;
    await sql`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'importer@example.test','{"display_name":"Importer"}')`;
    const [source] =
      await sql`select * from public.ingest_external_event('moderation',${crypto.randomUUID()},null,null,${
        sql.json(state)
      },1,${await hashNormalizedExternalEvent(state)},'{}',1,${userId})`;
    await run(sql, userId, source);
  } finally {
    await sql`rollback`;
    await sql.end();
  }
}
async function enqueue(sql: Sql, recordId: unknown, userId: string) {
  const [row] =
    await sql`select * from private.enqueue_external_event_proposal_if_needed(${
      String(recordId)
    },${userId},'importer@example.test','Importer')`;
  return row;
}
Deno.test("M3 enqueue existing, ignored, equal, new and rollback branches", () =>
  fixture(async (sql, userId, source) => {
    assertEquals(await enqueue(sql, source.record_id, userId), {
      pending_submission_id: source.pending_submission_id,
      pending_created: false,
    });
    await sql`delete from public.content_submissions where id=${
      String(source.pending_submission_id)
    }`;
    await sql`update public.external_event_records set ignored_at=clock_timestamp() where id=${
      String(source.record_id)
    }`;
    assertEquals(await enqueue(sql, source.record_id, userId), {
      pending_submission_id: null,
      pending_created: false,
    });
    await sql`update public.external_event_records set ignored_at=null, proposed_normalized=normalized, proposed_hash=moderation_hash, proposed_normalization_version=normalization_version where id=${
      String(source.record_id)
    }`;
    assertEquals(await enqueue(sql, source.record_id, userId), {
      pending_submission_id: null,
      pending_created: false,
    });
    await sql`update public.external_event_records set proposed_normalized=null, proposed_hash=null, proposed_normalization_version=null where id=${
      String(source.record_id)
    }`;
    await sql`savepoint enqueue_atomic`;
    const created = await enqueue(sql, source.record_id, userId);
    assertEquals(created.pending_created, true);
    await sql`rollback to savepoint enqueue_atomic`;
    const [count] =
      await sql`select count(*)::int as count from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      }`;
    assertEquals(count.count, 0);
  }));
Deno.test("M3 enqueue linked soft-deleted Event suppresses pending without watermark", () =>
  fixture(async (sql, userId, source) => {
    await sql`delete from public.content_submissions where id=${
      String(source.pending_submission_id)
    }`;
    const [event] =
      await sql`insert into public.events(name,start_date,latitude,longitude,deleted_at) values ('Deleted fixture','2026-10-02T10:00:00Z',41,14,clock_timestamp()) returning id`;
    await sql`update public.external_event_records set event_id=${event.id} where id=${
      String(source.record_id)
    }`;
    assertEquals(await enqueue(sql, source.record_id, userId), {
      pending_submission_id: null,
      pending_created: false,
    });
    const [record] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(record.proposed_hash, null);
  }));

async function observeNewer(sql: Sql, source: Record<string, unknown>) {
  const newer = { ...state, name: "Nuovo concerto" };
  const hash = await hashNormalizedExternalEvent(newer);
  await sql`update public.external_event_records set normalized=${
    sql.json(newer)
  },moderation_hash=${hash} where id=${String(source.record_id)}`;
  return hash;
}
Deno.test("M3 reject X atomically watermarks X and enqueues current Y with inherited identity", () =>
  fixture(async (sql, userId, source) => {
    const hashY = await observeNewer(sql, source);
    await sql`set local role service_role`;
    const [result] =
      await sql`select * from public.reject_external_event_submission(${
        String(source.pending_submission_id)
      },${userId},false)`;
    assertEquals(result.outcome, "rejected");
    assert(result.pending_submission_id !== null);
    const [original] =
      await sql`select status,handled_by,handled_at,external_moderation_hash from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assertEquals(original.status, "rejected");
    assertEquals(original.handled_by, userId);
    assert(original.handled_at !== null);
    const [record] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(record.proposed_hash, original.external_moderation_hash);
    const [pending] =
      await sql`select user_id,user_email,user_name,external_moderation_hash from public.content_submissions where id=${result.pending_submission_id}`;
    assertEquals(pending, {
      user_id: userId,
      user_email: "importer@example.test",
      user_name: "Importer",
      external_moderation_hash: hashY,
    });
    assertEquals(
      (await sql`select * from public.reject_external_event_submission(${
        String(source.pending_submission_id)
      },${userId},false)`)[0].outcome,
      "not_pending",
    );
  }));
Deno.test("M3 reject ignore suppresses replacement; invalid inherited identity rolls back rejection", () =>
  fixture(async (sql, userId, source) => {
    await observeNewer(sql, source);
    await sql`savepoint resolution`;
    await sql`update public.content_submissions set user_name='' where id=${
      String(source.pending_submission_id)
    }`;
    await assertRejects(
      () =>
        sql`select * from public.reject_external_event_submission(${
          String(source.pending_submission_id)
        },${userId},false)`,
      Error,
      "external_importer_identity_invalid",
    );
    await sql`rollback to savepoint resolution`;
    const [unchanged] =
      await sql`select status from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    const [before] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(unchanged.status, "pending");
    assertEquals(before.proposed_hash, null);
    const [result] =
      await sql`select * from public.reject_external_event_submission(${
        String(source.pending_submission_id)
      },${userId},true)`;
    assertEquals(result, { outcome: "rejected", pending_submission_id: null });
    const [ignored] =
      await sql`select ignored_at from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assert(ignored.ignored_at !== null);
  }));

Deno.test("M3 acknowledgement rejects non-stale, missing and changed shown hashes without mutation", () =>
  fixture(async (sql, userId, source) => {
    const initialHash = await hashNormalizedExternalEvent(state);
    for (const expected of [initialHash, null]) {
      const [result] =
        await sql`select * from public.reject_external_event_submission(${
          String(source.pending_submission_id)
        },${userId},true,true,${expected})`;
      assertEquals(result, {
        outcome: "source_changed",
        pending_submission_id: null,
      });
    }
    const hashY = await observeNewer(sql, source);
    for (const expected of [initialHash, null]) {
      const [result] =
        await sql`select * from public.reject_external_event_submission(${
          String(source.pending_submission_id)
        },${userId},true,true,${expected})`;
      assertEquals(result.outcome, "source_changed");
    }
    const [record] =
      await sql`select proposed_hash,ignored_at from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(record, { proposed_hash: null, ignored_at: null });
    const [submission] =
      await sql`select status from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assertEquals(submission.status, "pending");
    const [success] =
      await sql`select * from public.reject_external_event_submission(${
        String(source.pending_submission_id)
      },${userId},false,true,${hashY})`;
    assertEquals(success, { outcome: "rejected", pending_submission_id: null });
    const [watermark] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(watermark.proposed_hash, hashY);
  }));

Deno.test("M3 un-ignore immediately enqueues newer source and missing historical identity rolls back", () =>
  fixture(async (sql, userId, source) => {
    const hashY = await observeNewer(sql, source);
    await sql`select * from public.reject_external_event_submission(${
      String(source.pending_submission_id)
    },${userId},true)`;
    await sql`savepoint identity`;
    await sql`update public.content_submissions set user_email='' where id=${
      String(source.pending_submission_id)
    }`;
    await assertRejects(
      () =>
        sql`select * from public.set_source_ignored(${
          String(source.record_id)
        },false)`,
      Error,
      "external_importer_identity_invalid",
    );
    await sql`rollback to savepoint identity`;
    const [ignored] =
      await sql`select ignored_at from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assert(ignored.ignored_at !== null);
    const [result] = await sql`select * from public.set_source_ignored(${
      String(source.record_id)
    },false)`;
    assertEquals(result.outcome, "unignored");
    assert(result.pending_submission_id !== null);
    const [pending] =
      await sql`select user_id,external_moderation_hash from public.content_submissions where id=${result.pending_submission_id}`;
    assertEquals(pending, { user_id: userId, external_moderation_hash: hashY });
    const [record] =
      await sql`select ignored_at,proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(record.ignored_at, null);
    assertEquals(
      record.proposed_hash,
      await hashNormalizedExternalEvent(state),
    );
  }));
Deno.test("M3 un-ignore chooses handled_at DESC NULLS LAST then id DESC usable history", () =>
  fixture(async (sql, userId, source) => {
    await sql`select * from public.reject_external_event_submission(${
      String(source.pending_submission_id)
    },${userId},true)`;
    await observeNewer(sql, source);
    await sql`insert into public.content_submissions(user_id,user_email,user_name,name,city,start_date,status,handled_at,external_event_record_id,external_normalized,external_normalization_version,external_moderation_hash)
    select user_id,'tie@example.test','Tie winner',name,city,start_date,'rejected',handled_at,external_event_record_id,external_normalized,external_normalization_version,external_moderation_hash from public.content_submissions where id=${
      String(source.pending_submission_id)
    }`;
    await sql`insert into public.content_submissions(user_id,user_email,user_name,name,city,start_date,status,handled_at,external_event_record_id,external_normalized,external_normalization_version,external_moderation_hash)
    select user_id,'null@example.test','Null last',name,city,start_date,'rejected',null,external_event_record_id,external_normalized,external_normalization_version,external_moderation_hash from public.content_submissions where id=${
      String(source.pending_submission_id)
    }`;
    const [result] = await sql`select * from public.set_source_ignored(${
      String(source.record_id)
    },false)`;
    const [pending] =
      await sql`select user_email,user_name from public.content_submissions where id=${result.pending_submission_id}`;
    assertEquals(pending, {
      user_email: "tie@example.test",
      user_name: "Tie winner",
    });
  }));

Deno.test("M3 handling current source produces no follow-up and un-ignore remains a no-op", () =>
  fixture(async (sql, userId, source) => {
    const [rejected] =
      await sql`select * from public.reject_external_event_submission(${
        String(source.pending_submission_id)
      },${userId},true)`;
    assertEquals(rejected, {
      outcome: "rejected",
      pending_submission_id: null,
    });
    assertEquals(
      (await sql`select * from public.set_source_ignored(${
        String(source.record_id)
      },false)`)[0],
      { outcome: "unignored", pending_submission_id: null },
    );
    const [count] =
      await sql`select count(*)::int as count from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      } and status='pending'`;
    assertEquals(count.count, 0);
  }));
Deno.test("M3 partial UNIQUE is structural fallback even for an unsupported duplicate writer", () =>
  fixture(async (sql, _userId, source) => {
    await sql`savepoint duplicate_pending`;
    const error = await assertRejects(() =>
      sql`insert into public.content_submissions(user_id,user_email,user_name,name,city,start_date,external_event_record_id,external_normalized,external_normalization_version,external_moderation_hash)
    select user_id,user_email,user_name,name,city,start_date,external_event_record_id,external_normalized,external_normalization_version,external_moderation_hash from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`
    );
    assertEquals((error as unknown as { code: string }).code, "23505");
    await sql`rollback to savepoint duplicate_pending`;
    const [count] =
      await sql`select count(*)::int as count from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      } and status='pending'`;
    assertEquals(count.count, 1);
  }));

async function waitForLock(observer: Sql, pid: number) {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const [activity] =
      await observer`select wait_event_type from pg_stat_activity where pid=${pid}`;
    if (activity?.wait_event_type === "Lock") return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error("Expected overlapping transaction to wait on a lock");
}
for (
  const order of [
    "reject-ingest",
    "ingest-reject",
    "unignore-reject",
    "ingest-unignore",
  ] as const
) {
  Deno.test(`M3 ${order} overlap follows submission-record prefix with one pending and no deadlock`, async () => {
    const a = postgres(databaseUrl, { max: 1, onnotice: () => {} });
    const b = postgres(databaseUrl, { max: 1, onnotice: () => {} });
    const observer = postgres(databaseUrl, { max: 1 });
    const userId = crypto.randomUUID();
    const externalId = crypto.randomUUID();
    let source: Record<string, unknown> | undefined;
    let activeA = false, activeB = false;
    let blocked: Promise<unknown> | undefined;
    try {
      await observer`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'overlap@example.test','{"display_name":"Overlap"}')`;
      [source] =
        await observer`select * from public.ingest_external_event('moderation',${externalId},null,null,${
          observer.json(state)
        },1,${await hashNormalizedExternalEvent(state)},'{}',1,${userId})`;
      assert(source);
      await observeNewer(observer, source);
      await a`begin`;
      activeA = true;
      await b`begin`;
      activeB = true;
      await a`set local statement_timeout='10s'`;
      await b`set local statement_timeout='10s'`;
      const [{ pid }] = await b`select pg_backend_pid() as pid`;
      if (order === "reject-ingest") {
        await a`select * from public.reject_external_event_submission(${
          String(source.pending_submission_id)
        },${userId},false)`;
        blocked =
          b`select * from public.ingest_external_event('moderation',${externalId},null,null,${
            b.json({ ...state, name: "Newest" })
          },1,${await hashNormalizedExternalEvent({
            ...state,
            name: "Newest",
          })},'{}',1,${userId})`;
      } else {
        if (order === "ingest-reject" || order === "ingest-unignore") {
          await a`select * from public.ingest_external_event('moderation',${externalId},null,null,${
            a.json({ ...state, name: "Newest" })
          },1,${await hashNormalizedExternalEvent({
            ...state,
            name: "Newest",
          })},'{}',1,${userId})`;
        } else {await a`select * from public.set_source_ignored(${
            String(source.record_id)
          },false)`;}
        blocked = order === "ingest-unignore"
          ? b`select * from public.set_source_ignored(${
            String(source.record_id)
          },false)`
          : b`select * from public.reject_external_event_submission(${
            String(source.pending_submission_id)
          },${userId},false)`;
      }
      const completion = Promise.resolve(blocked);
      blocked = completion;
      await waitForLock(observer, pid);
      if (order !== "reject-ingest" && order !== "ingest-unignore") {
        // Reject acquired the submission before waiting on the record. An
        // independent NOWAIT probe proves that first lock is already owned.
        await observer`begin`;
        const lockError = await assertRejects(() =>
          observer`select id from public.content_submissions where id=${
            String(source!.pending_submission_id)
          } for update nowait`
        );
        assertEquals((lockError as unknown as { code: string }).code, "55P03");
        await observer`rollback`;
      }
      if (order === "ingest-unignore") {
        // Both record-only operations leave the existing submission unlocked.
        await observer`begin`;
        await observer`select id from public.content_submissions where id=${
          String(source.pending_submission_id)
        } for update nowait`;
        await observer`rollback`;
      }
      await a`commit`;
      activeA = false;
      await completion;
      await b`commit`;
      activeB = false;
      const [count] =
        await observer`select count(*)::int as count from public.content_submissions where external_event_record_id=${
          String(source.record_id)
        } and status='pending'`;
      assertEquals(count.count, 1);
    } finally {
      if (activeA) await a`rollback`;
      if (blocked) await blocked.catch(() => {});
      if (activeB) await b`rollback`;
      if (source) {
        await observer`delete from public.content_submissions where external_event_record_id=${
          String(source.record_id)
        }`;
        await observer`delete from public.external_event_records where id=${
          String(source.record_id)
        }`;
      }
      await observer`delete from auth.users where id=${userId}`;
      await Promise.all([a.end(), b.end(), observer.end()]);
    }
  });
}
Deno.test("M3 unsupported direct imported resolution remains blocked", () =>
  fixture(async (sql, _userId, source) => {
    await sql`savepoint unsupported_resolution`;
    await assertRejects(
      () =>
        sql`update public.content_submissions set status='accepted' where id=${
          String(source.pending_submission_id)
        }`,
      Error,
      "external_requires_resolution",
    );
    await sql`rollback to savepoint unsupported_resolution`;
    const [row] =
      await sql`select status,promoted_event_id from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assertEquals(row, { status: "pending", promoted_event_id: null });
  }));

Deno.test("M3 reject follow-up inherits reviewed identity despite other newer history/config identity", () =>
  fixture(async (sql, userId, source) => {
    await sql`insert into public.content_submissions(user_id,user_email,user_name,name,city,start_date,status,handled_at,external_event_record_id,external_normalized,external_normalization_version,external_moderation_hash)
    select user_id,'other@example.test','Other history',name,city,start_date,'rejected',clock_timestamp()+interval '1 day',external_event_record_id,external_normalized,external_normalization_version,external_moderation_hash from public.content_submissions where id=${
      String(source.pending_submission_id)
    }`;
    await observeNewer(sql, source);
    const [result] =
      await sql`select * from public.reject_external_event_submission(${
        String(source.pending_submission_id)
      },${userId},false)`;
    const [pending] =
      await sql`select user_id,user_name,user_email from public.content_submissions where id=${result.pending_submission_id}`;
    assertEquals(pending, {
      user_id: userId,
      user_name: "Importer",
      user_email: "importer@example.test",
    });
  }));
Deno.test("M3 un-ignore prefers newest handled timestamp and skips unusable imported history", () =>
  fixture(async (sql, userId, source) => {
    await sql`select * from public.reject_external_event_submission(${
      String(source.pending_submission_id)
    },${userId},true)`;
    await observeNewer(sql, source);
    for (
      const [email, name, day] of [["new@example.test", "Newest usable", 2], [
        "old@example.test",
        "Later id older time",
        1,
      ], ["", "Unusable latest", 3]] as const
    ) {
      await sql`insert into public.content_submissions(user_id,user_email,user_name,name,city,start_date,status,handled_at,external_event_record_id,external_normalized,external_normalization_version,external_moderation_hash)
      select user_id,${email},${name},name,city,start_date,'rejected',handled_at+${day}*interval '1 day',external_event_record_id,external_normalized,external_normalization_version,external_moderation_hash from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    }
    const [result] = await sql`select * from public.set_source_ignored(${
      String(source.record_id)
    },false)`;
    const [pending] =
      await sql`select user_name,user_email from public.content_submissions where id=${result.pending_submission_id}`;
    assertEquals(pending, {
      user_name: "Newest usable",
      user_email: "new@example.test",
    });
  }));

Deno.test("M3 ingest retains newer current and metadata but deleted linked Event suppresses enqueue and preserves watermark", () =>
  fixture(async (sql, userId, source) => {
    await sql`select * from public.reject_external_event_submission(${
      String(source.pending_submission_id)
    },${userId},false)`;
    const [event] =
      await sql`insert into public.events(name,start_date,latitude,longitude,deleted_at) values ('Deleted linked','2026-10-02',41,14,clock_timestamp()) returning id`;
    await sql`update public.external_event_records set event_id=${event.id} where id=${
      String(source.record_id)
    }`;
    const [before] =
      await sql`select external_id,proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    const current = { ...state, name: "Changed after deletion" };
    const hash = await hashNormalizedExternalEvent(current);
    const [result] =
      await sql`select * from public.ingest_external_event('moderation',${before.external_id},null,null,${
        sql.json(current)
      },1,${hash},'{"provider_status":"cancelled"}',1,${userId})`;
    assertEquals(result.pending_submission_id, null);
    assertEquals(result.pending_created, false);
    const [after] =
      await sql`select moderation_hash,proposed_hash,metadata from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(after, {
      moderation_hash: hash,
      proposed_hash: before.proposed_hash,
      metadata: { provider_status: "cancelled" },
    });
  }));
Deno.test("M3 equal hash with incompatible proposed version does not suppress unhandled enqueue", () =>
  fixture(async (sql, userId, source) => {
    await sql`delete from public.content_submissions where id=${
      String(source.pending_submission_id)
    }`;
    await sql`update public.external_event_records set proposed_hash=moderation_hash,proposed_normalized=normalized,proposed_normalization_version=normalization_version+1 where id=${
      String(source.record_id)
    }`;
    const result = await enqueue(sql, source.record_id, userId);
    assertEquals(result.pending_created, true);
  }));

Deno.test("M3 resolution RPC ACL denies public API roles and grants service role only", () =>
  fixture(async (sql, _userId, source) => {
    for (const role of ["anon", "authenticated"]) {
      await sql`savepoint denied_resolution`;
      await sql.unsafe(`set local role ${role}`);
      const error = await assertRejects(() =>
        sql`select * from public.set_source_ignored(${
          String(source.record_id)
        },false)`
      );
      assertEquals((error as unknown as { code: string }).code, "42501");
      await sql`rollback to savepoint denied_resolution`;
      await sql`savepoint denied_reject`;
      await sql.unsafe(`set local role ${role}`);
      const rejectError = await assertRejects(() =>
        sql`select * from public.reject_external_event_submission(${
          String(source.pending_submission_id)
        },${crypto.randomUUID()},false)`
      );
      assertEquals((rejectError as unknown as { code: string }).code, "42501");
      await sql`rollback to savepoint denied_reject`;
    }
    await sql`set local role service_role`;
    assertEquals(
      (await sql`select * from public.set_source_ignored(${
        String(source.record_id)
      },false)`)[0],
      {
        outcome: "unignored",
        pending_submission_id: source.pending_submission_id,
      },
    );
  }));

Deno.test("M3 actual Admin store/PostgREST stale acknowledgement preserves observed hash and rejects source drift atomically", async () => {
  const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
  const userId = crypto.randomUUID();
  let source: Record<string, unknown> | undefined;
  const apiUrl = Deno.env.get("API_URL") ?? "";
  assert(["localhost", "127.0.0.1"].includes(new URL(apiUrl).hostname));
  const client = createClient<Database>(
    apiUrl,
    Deno.env.get("SERVICE_ROLE_KEY") ?? "",
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const handler = createHandler({
    authenticate: () =>
      Promise.resolve({
        id: userId,
        app_metadata: { admin: true },
        user_metadata: {},
        aud: "authenticated",
        created_at: "2026-10-02T10:00:00Z",
      }),
    createStore: () => createAdminSubmissionStore(client),
    nowIso: () => "2026-10-02T10:00:00Z",
  });
  const request = (body: unknown) =>
    new Request("http://localhost", {
      method: "POST",
      headers: { Authorization: "Bearer verified-test-admin" },
      body: JSON.stringify(body),
    });
  try {
    await sql`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'integration@example.test','{"display_name":"Integration"}')`;
    [source] =
      await sql`select * from public.ingest_external_event('moderation',${crypto.randomUUID()},null,null,${
        sql.json(state)
      },1,${await hashNormalizedExternalEvent(state)},'{}',1,${userId})`;
    assert(source);
    await sql`notify pgrst,'reload schema'`;
    await observeNewer(sql, source);
    const detail = await handler(
      request({
        operation: "getById",
        submission_id: Number(source.pending_submission_id),
      }),
    );
    assertEquals(detail.status, 200);
    const { submission: shown } = await detail.json();
    assertEquals(
      shown.external_moderation_hash,
      await hashNormalizedExternalEvent(state),
    );
    assertEquals(shown.current_source_normalized.name, "Nuovo concerto");
    const newest = { ...state, name: "Z after observation" };
    const hashZ = await hashNormalizedExternalEvent(newest);
    await sql`update public.external_event_records set normalized=${
      sql.json(newest)
    },moderation_hash=${hashZ} where id=${String(source.record_id)}`;
    const body = {
      operation: "changeStatus",
      submission_id: Number(source.pending_submission_id),
      status: "rejected",
      acknowledge_current_source: true,
      expected_source_hash: shown.moderation_hash,
    };
    const drift = await handler(request(body));
    assertEquals(drift.status, 409);
    assertEquals((await drift.json()).code, "SOURCE_CHANGED");
    const [unchanged] =
      await sql`select status from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assertEquals(unchanged.status, "pending");
    const [record] =
      await sql`select proposed_hash,ignored_at from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(record, { proposed_hash: null, ignored_at: null });
    const refreshed = await handler(
      request({
        operation: "getById",
        submission_id: Number(source.pending_submission_id),
      }),
    );
    const { submission: reviewed } = await refreshed.json();
    assertEquals(reviewed.moderation_hash, hashZ);
    const success = await handler(
      request({ ...body, expected_source_hash: reviewed.moderation_hash }),
    );
    assertEquals(success.status, 200);
    assertEquals(await success.json(), {
      ok: true,
      status: "rejected",
      pending_submission_id: null,
    });
    const [handled] =
      await sql`select status,handled_by from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assertEquals(handled, { status: "rejected", handled_by: userId });
    const [watermark] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(watermark.proposed_hash, hashZ);
  } finally {
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
