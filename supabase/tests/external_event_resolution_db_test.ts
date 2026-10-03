import { calculateExternalEventMerge } from "../functions/_shared/external_event_merge.ts";
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { createClient, type User } from "npm:@supabase/supabase-js@2.112.3";
import type { Database } from "../functions/_shared/database.types.ts";
import { createAdminSubmissionStore } from "../functions/admin-content-submissions/admin_submission_store.ts";
import { createHandler } from "../functions/admin-content-submissions/index.ts";
import postgres, { type Sql } from "npm:postgres@3.4.5";
import {
  canonicalizeExternalEvent,
  canonicalizeSubmission,
  hashNormalizedExternalEvent,
  type NormalizedExternalEvent,
} from "../functions/_shared/external_event_normalization.ts";
const databaseUrl = Deno.env.get("SUPABASE_DB_URL") ?? "";
assert(["localhost", "127.0.0.1"].includes(new URL(databaseUrl).hostname));
const state: NormalizedExternalEvent = {
  name: "Source concert",
  category: "experience",
  description: null,
  description_delta: null,
  city: "Fixture city",
  latitude: "41",
  longitude: "14",
  all_day: false,
  start_date: "2026-10-02T10:00:00.123456Z",
  end_date: null,
};
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
  try {
    await sql`begin`;
    await sql`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'resolution@example.test','{"display_name":"Resolution importer"}')`;
    const city = crypto.randomUUID();
    const [cityRow] =
      await sql`insert into public.cities(name) values (${city}) returning id`;
    const canonical = { ...state, city };
    const [source] =
      await sql`select * from public.ingest_external_event('resolution',${crypto.randomUUID()},null,null,${
        sql.json(canonical)
      },1,${await hashNormalizedExternalEvent(canonical)},'{}',1,${userId})`;
    const [event] =
      await sql`insert into public.events(name,start_date,latitude,longitude,city_id,category,modified_at) values ('Editorial event','2026-10-01',41,14,${cityRow.id},'history','2025-01-01') returning id`;
    await run(sql, userId, source, String(event.id));
  } finally {
    await sql`rollback`;
    await sql.end();
  }
}
Deno.test("M4 linked imported promotion returns source_already_linked with zero mutations", () =>
  fixture(async (sql, userId, source, eventId) => {
    await sql`update public.external_event_records set event_id=${eventId} where id=${
      String(source.record_id)
    }`;
    const [before] =
      await sql`select count(*)::int as count from public.events`;
    const [result] =
      await sql`select * from public.promote_content_submission(${
        String(source.pending_submission_id)
      },'event',${userId})`;
    assertEquals(result, {
      outcome: "source_already_linked",
      target_type: null,
      entity_id: null,
    });
    const [after] = await sql`select count(*)::int as count from public.events`;
    assertEquals(after, before);
    const [row] =
      await sql`select status,promoted_event_id from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assertEquals(row, { status: "pending", promoted_event_id: null });
    const [record] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(record.proposed_hash, null);
  }));

async function sourceNewer(sql: Sql, source: Record<string, unknown>) {
  const [record] =
    await sql`select normalized from public.external_event_records where id=${
      String(source.record_id)
    }`;
  const newer = { ...record.normalized, name: "Y newer provider" };
  const hash = await hashNormalizedExternalEvent(newer);
  await sql`update public.external_event_records set normalized=${
    sql.json(newer)
  },moderation_hash=${hash} where id=${String(source.record_id)}`;
  return hash;
}
Deno.test("M4 imported promotion creates reviewed Event, links source and immediately enqueues Y inherited identity", () =>
  fixture(async (sql, userId, source, _eventId) => {
    const hashY = await sourceNewer(sql, source);
    await sql`set local role service_role`;
    const [created] =
      await sql`select * from public.promote_content_submission(${
        String(source.pending_submission_id)
      },'event',${userId})`;
    assertEquals(created.outcome, "created");
    const [event] =
      await sql`select name from public.events where id=${created.entity_id}`;
    assertEquals(event.name, state.name);
    const [original] =
      await sql`select status,external_moderation_hash from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assertEquals(original.status, "accepted");
    const [record] =
      await sql`select event_id,proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(String(record.event_id), String(created.entity_id));
    assertEquals(record.proposed_hash, original.external_moderation_hash);
    const [pending] =
      await sql`select user_id,user_email,user_name,external_moderation_hash from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      } and status='pending'`;
    assertEquals(pending, {
      user_id: userId,
      user_email: "resolution@example.test",
      user_name: "Resolution importer",
      external_moderation_hash: hashY,
    });
    const [retry] = await sql`select * from public.promote_content_submission(${
      String(source.pending_submission_id)
    },'event',${userId},true,'wrong')`;
    assertEquals(retry, { ...created, outcome: "already_promoted" });
  }));
Deno.test("M4 promotion acknowledgement checks stale shown hash before publication and preserves reviewed Event fields", () =>
  fixture(async (sql, userId, source, _eventId) => {
    const [initial] =
      await sql`select external_moderation_hash from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    for (const expected of [initial.external_moderation_hash, null]) {
      const [result] =
        await sql`select * from public.promote_content_submission(${
          String(source.pending_submission_id)
        },'event',${userId},true,${expected})`;
      assertEquals(result.outcome, "source_changed");
    }
    const hashY = await sourceNewer(sql, source);
    const [before] =
      await sql`select count(*)::int as count from public.events`;
    for (const expected of [initial.external_moderation_hash, null]) {
      assertEquals(
        (await sql`select * from public.promote_content_submission(${
          String(source.pending_submission_id)
        },'event',${userId},true,${expected})`)[0].outcome,
        "source_changed",
      );
    }
    const [after] = await sql`select count(*)::int as count from public.events`;
    assertEquals(after, before);
    const [unresolved] =
      await sql`select status from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assertEquals(unresolved.status, "pending");
    const [noWatermark] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(noWatermark.proposed_hash, null);
    const [created] =
      await sql`select * from public.promote_content_submission(${
        String(source.pending_submission_id)
      },'event',${userId},true,${hashY})`;
    assertEquals(created.outcome, "created");
    const [event] =
      await sql`select name from public.events where id=${created.entity_id}`;
    assertEquals(event.name, state.name);
    const [record] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(record.proposed_hash, hashY);
    const [count] =
      await sql`select count(*)::int as count from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      } and status='pending'`;
    assertEquals(count.count, 0);
  }));

Deno.test("M4 legacy three-argument promotion PostgREST envelope stays unambiguous", async () => {
  const apiUrl = Deno.env.get("API_URL") ?? "";
  assert(["localhost", "127.0.0.1"].includes(new URL(apiUrl).hostname));
  const key = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
  const response = await fetch(
    `${apiUrl}/rest/v1/rpc/promote_content_submission`,
    {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        p_submission_id: 987654321,
        p_target: "event",
        p_handled_by: crypto.randomUUID(),
      }),
    },
  );
  assertEquals(response.status, 200);
  assertEquals(await response.json(), [{
    outcome: "not_found",
    target_type: null,
    entity_id: null,
  }]);
});

Deno.test("M4 human Place-like/end-only cannot link; valid human Event links without Event/media writes", () =>
  fixture(async (sql, userId, _source, eventId) => {
    await sql`alter table public.content_submissions drop constraint content_submissions_end_date_requires_start_date_check`;
    for (
      const [start, end] of [[null, null], [null, "2026-10-02T11:00:00Z"], [
        "2026-10-02T10:00:00Z",
        null,
      ]]
    ) {
      const [human] =
        await sql`insert into public.content_submissions(user_id,user_email,user_name,name,city,start_date,end_date) values (${userId},'human@example.test','Human','Human event','City',${start}::timestamptz,${end}::timestamptz) returning id`;
      const [before] =
        await sql`select row_to_json(e) as value from public.events e where id=${eventId}`;
      const [result] =
        await sql`select * from public.link_content_submission_to_event(${human.id},${eventId},${userId})`;
      assertEquals(
        result.outcome,
        start === null ? "not_event_submission" : "linked",
      );
      const [after] =
        await sql`select row_to_json(e) as value from public.events e where id=${eventId}`;
      assertEquals(after, before);
      const [row] =
        await sql`select status,target_event_id,promoted_event_id from public.content_submissions where id=${human.id}`;
      assertEquals(row, {
        status: start === null ? "pending" : "accepted",
        target_event_id: start === null ? null : eventId,
        promoted_event_id: null,
      });
      const [media] =
        await sql`select count(*)::int as count from public.media where event_id=${eventId}`;
      assertEquals(media.count, 0);
    }
  }));
Deno.test("M4 imported create/update Link preserves Event and rejects implicit relink; same-target replay precedes checks", () =>
  fixture(async (sql, userId, source, eventId) => {
    const hashY = await sourceNewer(sql, source);
    const [before] =
      await sql`select row_to_json(e) as value from public.events e where id=${eventId}`;
    const [linked] =
      await sql`select * from public.link_content_submission_to_event(${
        String(source.pending_submission_id)
      },${eventId},${userId})`;
    assertEquals(linked.outcome, "linked");
    assert(linked.pending_submission_id !== null);
    const [record] =
      await sql`select event_id,proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(String(record.event_id), eventId);
    assert(record.proposed_hash !== hashY);
    assertEquals(
      (await sql`select * from public.link_content_submission_to_event(${
        String(source.pending_submission_id)
      },${eventId},${userId},true,'wrong')`)[0].outcome,
      "already_resolved",
    );
    const [other] =
      await sql`insert into public.events(name,start_date,latitude,longitude) values ('Other','2026-10-02',41,14) returning id`;
    assertEquals(
      (await sql`select * from public.link_content_submission_to_event(${
        String(source.pending_submission_id)
      },${other.id},${userId})`)[0].outcome,
      "target_conflict",
    );
    assertEquals(
      (await sql`select * from public.link_content_submission_to_event(${linked.pending_submission_id},${other.id},${userId})`)[
        0
      ].outcome,
      "relink_conflict",
    );
    const [update] =
      await sql`select * from public.link_content_submission_to_event(${linked.pending_submission_id},${eventId},${userId})`;
    assertEquals(update.outcome, "linked");
    assertEquals(update.pending_submission_id, null);
    const [after] =
      await sql`select row_to_json(e) as value from public.events e where id=${eventId}`;
    assertEquals(after, before);
  }));
Deno.test("M4 imported Link acknowledgement requires stale exact shown hash and accounts for current source", () =>
  fixture(async (sql, userId, source, eventId) => {
    for (const expected of [await hashNormalizedExternalEvent(state), null]) {
      assertEquals(
        (await sql`select * from public.link_content_submission_to_event(${
          String(source.pending_submission_id)
        },${eventId},${userId},true,${expected})`)[0].outcome,
        "source_changed",
      );
    }
    const hashY = await sourceNewer(sql, source);
    for (const expected of ["a".repeat(64), null]) {
      assertEquals(
        (await sql`select * from public.link_content_submission_to_event(${
          String(source.pending_submission_id)
        },${eventId},${userId},true,${expected})`)[0].outcome,
        "source_changed",
      );
    }
    const [unresolved] =
      await sql`select status from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assertEquals(unresolved.status, "pending");
    const [before] =
      await sql`select event_id,proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(before, { event_id: null, proposed_hash: null });
    const [linked] =
      await sql`select * from public.link_content_submission_to_event(${
        String(source.pending_submission_id)
      },${eventId},${userId},true,${hashY})`;
    assertEquals(linked.outcome, "linked");
    assertEquals(linked.pending_submission_id, null);
    const [after] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(after.proposed_hash, hashY);
  }));

async function knownBase(
  sql: Sql,
  source: Record<string, unknown>,
  eventId: string,
) {
  await sql`update public.external_event_records set event_id=${eventId},proposed_normalized=normalized,proposed_hash=moderation_hash,proposed_normalization_version=normalization_version where id=${
    String(source.record_id)
  }`;
}
async function apply(
  sql: Sql,
  userId: string,
  source: Record<string, unknown>,
  eventId: string,
  groups: string[] = [],
  ack = false,
  hash: string | null = null,
  tokens?: { submission?: string | null; event?: string | null },
) {
  const [row] =
    await sql`select s.modified_at::text as submission,e.modified_at::text as event from public.content_submissions s cross join public.events e where s.id=${
      String(source.pending_submission_id)
    } and e.id=${eventId}`;
  const [result] =
    await sql`select * from public.apply_external_event_submission(${
      String(source.pending_submission_id)
    },${eventId},${userId},${groups},${tokens?.submission ?? row.submission},${
      tokens?.event ?? row.event
    },${ack},${hash})`;
  return result;
}
Deno.test("M4 Apply validates imported/pending/link/base/version/active target preconditions without mutations", () =>
  fixture(async (sql, userId, source, eventId) => {
    assertEquals(
      (await apply(sql, userId, source, eventId)).outcome,
      "source_not_linked",
    );
    await sql`update public.external_event_records set event_id=${eventId} where id=${
      String(source.record_id)
    }`;
    assertEquals(
      (await apply(sql, userId, source, eventId)).outcome,
      "base_required",
    );
    await knownBase(sql, source, eventId);
    await sql`savepoint invalid_apply`;
    await sql`update public.external_event_records set proposed_normalization_version=2 where id=${
      String(source.record_id)
    }`;
    assertEquals(
      (await apply(sql, userId, source, eventId)).outcome,
      "normalization_mismatch",
    );
    await sql`rollback to savepoint invalid_apply`;
    await sql`update public.events set deleted_at=clock_timestamp() where id=${eventId}`;
    assertEquals(
      (await apply(sql, userId, source, eventId)).outcome,
      "event_inactive",
    );
    await sql`rollback to savepoint invalid_apply`;
    const [human] =
      await sql`insert into public.content_submissions(user_id,user_email,user_name,name,city,start_date) values (${userId},'human@example.test','Human','Human','City','2026-10-02') returning id`;
    assertEquals(
      (await apply(sql, userId, { pending_submission_id: human.id }, eventId))
        .outcome,
      "not_imported",
    );
    const [row] =
      await sql`select status,target_event_id from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assertEquals(row, { status: "pending", target_event_id: null });
  }));
Deno.test("M4 Apply checks exact preview microsecond tokens and stale acknowledgement before any mutations", () =>
  fixture(async (sql, userId, source, eventId) => {
    await knownBase(sql, source, eventId);
    const [tokens] =
      await sql`select s.modified_at::text as submission,e.modified_at::text as event from public.content_submissions s cross join public.events e where s.id=${
        String(source.pending_submission_id)
      } and e.id=${eventId}`;
    assertEquals(
      (await apply(sql, userId, source, eventId, [], false, null, {
        ...tokens,
        submission: "2000-01-01",
      })).outcome,
      "submission_changed",
    );
    assertEquals(
      (await apply(sql, userId, source, eventId, [], false, null, {
        ...tokens,
        event: "2000-01-01",
      })).outcome,
      "event_changed",
    );
    assertEquals(
      (await apply(sql, userId, source, eventId, [], true, "a".repeat(64)))
        .outcome,
      "source_changed",
    );
    const hashY = await sourceNewer(sql, source);
    for (const expected of ["a".repeat(64), null]) {
      assertEquals(
        (await apply(sql, userId, source, eventId, ["name"], true, expected))
          .outcome,
        "source_changed",
      );
    }
    const [before] =
      await sql`select name,modified_at::text as token from public.events where id=${eventId}`;
    assertEquals(before.name, "Editorial event");
    assertEquals(before.token, tokens.event);
    const [applied] = [
      await apply(sql, userId, source, eventId, ["name"], true, hashY),
    ];
    assertEquals(applied.outcome, "applied");
    assertEquals(applied.pending_submission_id, null);
    const [after] =
      await sql`select name from public.events where id=${eventId}`;
    assertEquals(after.name, state.name);
    const [record] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(record.proposed_hash, hashY);
    assertEquals(
      (await apply(sql, userId, source, eventId, ["unknown"], true, "wrong", {
        submission: "bad",
        event: "bad",
      })).outcome,
      "already_resolved",
    );
  }));

Deno.test("M4 Apply copies complete atomic groups from reviewed fields, owns Event sync token, and leaves media intact", () =>
  fixture(async (sql, userId, source, eventId) => {
    await knownBase(sql, source, eventId);
    const cityName = crypto.randomUUID();
    const [city] =
      await sql`insert into public.cities(name) values (${cityName}) returning id`;
    await sql`insert into public.media(url,width,height,event_id) values ('https://example.test/editorial.jpg',100,80,${eventId})`;
    await sql`insert into public.submissions_assets(url,width,height,content_submission_id) values ('https://example.test/reviewed.jpg',100,80,${
      String(source.pending_submission_id)
    })`;
    const [before] =
      await sql`select modified_at::text as token from public.events where id=${eventId}`;
    const mediaBefore =
      await sql`select row_to_json(m) as value from public.media m where event_id=${eventId}`;
    const assetsBefore =
      await sql`select row_to_json(a) as value from public.submissions_assets a where content_submission_id=${
        String(source.pending_submission_id)
      }`;
    await sql`update public.content_submissions set name='Moderated title',category='food',description=' Reviewed text ',description_delta='[{"insert":" Reviewed text \\n"}]',
    start_date='2026-10-01T22:00:00Z',end_date='2026-10-02T21:59:59.999999Z',all_day=true,
    city=${cityName},latitude=41.55,longitude=14.66 where id=${
      String(source.pending_submission_id)
    }`;
    const result = await apply(sql, userId, source, eventId, [
      "name",
      "category",
      "description",
      "schedule",
      "location",
    ]);
    assertEquals(result.outcome, "applied");
    const [event] =
      await sql`select name,category,description,description_delta,start_date::text as start_date,end_date::text as end_date,all_day,city_id,latitude,longitude,modified_at::text as token from public.events where id=${eventId}`;
    assertEquals({ ...event, token: undefined }, {
      name: "Moderated title",
      category: "food",
      description: " Reviewed text ",
      description_delta: [{ insert: " Reviewed text \n" }],
      start_date: "2026-10-01 22:00:00+00",
      end_date: "2026-10-02 21:59:59.999999+00",
      all_day: true,
      city_id: String(city.id),
      latitude: 41.55,
      longitude: 14.66,
      token: undefined,
    });
    assert(event.token !== before.token);
    assertEquals(
      await sql`select row_to_json(m) as value from public.media m where event_id=${eventId}`,
      mediaBefore,
    );
    assertEquals(
      await sql`select row_to_json(a) as value from public.submissions_assets a where content_submission_id=${
        String(source.pending_submission_id)
      }`,
      assetsBefore,
    );
  }));
Deno.test("M4 Apply writes only requested complete description group", () =>
  fixture(async (sql, userId, source, eventId) => {
    await knownBase(sql, source, eventId);
    const [before] =
      await sql`select name,category,start_date::text as start_date,end_date::text as end_date,all_day,city_id,latitude,longitude from public.events where id=${eventId}`;
    await sql`update public.content_submissions set description='New description',description_delta='[{"insert":"New description\\n"}]' where id=${
      String(source.pending_submission_id)
    }`;
    assertEquals(
      (await apply(sql, userId, source, eventId, ["description"])).outcome,
      "applied",
    );
    const [after] =
      await sql`select name,category,start_date::text as start_date,end_date::text as end_date,all_day,city_id,latitude,longitude from public.events where id=${eventId}`;
    assertEquals(after, before);
    const [description] =
      await sql`select description,description_delta from public.events where id=${eventId}`;
    assertEquals(description, {
      description: "New description",
      description_delta: [{ insert: "New description\n" }],
    });
  }));
Deno.test("M4 Apply unresolved location city fails all groups without Event/resolution/watermark mutations", () =>
  fixture(async (sql, userId, source, eventId) => {
    await knownBase(sql, source, eventId);
    await sql`update public.content_submissions set city=${crypto.randomUUID()},name='Would change name' where id=${
      String(source.pending_submission_id)
    }`;
    const [before] =
      await sql`select row_to_json(e) as value from public.events e where id=${eventId}`;
    const [watermark] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(
      (await apply(sql, userId, source, eventId, ["name", "location"])).outcome,
      "city_not_found",
    );
    assertEquals(
      (await sql`select row_to_json(e) as value from public.events e where id=${eventId}`)[
        0
      ],
      before,
    );
    assertEquals(
      (await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`)[0],
      watermark,
    );
    assertEquals(
      (await sql`select status,target_event_id from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`)[0],
      { status: "pending", target_event_id: null },
    );
  }));
Deno.test("M4 Apply enqueue failure rolls back prior group and resolution writes atomically", () =>
  fixture(async (sql, userId, source, eventId) => {
    await knownBase(sql, source, eventId);
    await sourceNewer(sql, source);
    await sql`update public.content_submissions set name='Would apply',user_name='' where id=${
      String(source.pending_submission_id)
    }`;
    const [before] =
      await sql`select row_to_json(e) as value from public.events e where id=${eventId}`;
    const [watermark] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    await sql`savepoint failed_apply`;
    await assertRejects(
      () => apply(sql, userId, source, eventId, ["name"]),
      Error,
      "external_importer_identity_invalid",
    );
    await sql`rollback to savepoint failed_apply`;
    assertEquals(
      (await sql`select row_to_json(e) as value from public.events e where id=${eventId}`)[
        0
      ],
      before,
    );
    assertEquals(
      (await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`)[0],
      watermark,
    );
    assertEquals(
      (await sql`select status,target_event_id from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`)[0],
      { status: "pending", target_event_id: null },
    );
  }));

Deno.test("M4 Apply invalid/duplicate groups and relink conflict leave every owned state unchanged", () =>
  fixture(async (sql, userId, source, eventId) => {
    await knownBase(sql, source, eventId);
    const [before] =
      await sql`select row_to_json(e) as value from public.events e where id=${eventId}`;
    for (const groups of [["unknown"], ["name", "name"]]) {
      assertEquals(
        (await apply(sql, userId, source, eventId, groups)).outcome,
        "invalid_groups",
      );
    }
    const [other] =
      await sql`insert into public.events(name,start_date,latitude,longitude) values ('Other target','2026-10-02',41,14) returning id`;
    assertEquals(
      (await apply(sql, userId, source, String(other.id), ["name"])).outcome,
      "relink_conflict",
    );
    assertEquals(
      (await sql`select row_to_json(e) as value from public.events e where id=${eventId}`)[
        0
      ],
      before,
    );
    assertEquals(
      (await sql`select status,target_event_id from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`)[0],
      { status: "pending", target_event_id: null },
    );
  }));
Deno.test("M4 Link and Apply follow-up inherit reviewed technical identity and immutable source snapshot", () =>
  fixture(async (sql, userId, source, eventId) => {
    await knownBase(sql, source, eventId);
    const hashY = await sourceNewer(sql, source);
    const linked =
      await sql`select * from public.link_content_submission_to_event(${
        String(source.pending_submission_id)
      },${eventId},${userId})`;
    const [pendingY] =
      await sql`select user_id,user_email,user_name,external_moderation_hash from public.content_submissions where id=${
        linked[0].pending_submission_id
      }`;
    assertEquals(pendingY, {
      user_id: userId,
      user_email: "resolution@example.test",
      user_name: "Resolution importer",
      external_moderation_hash: hashY,
    });
    const pendingSource = {
      ...source,
      pending_submission_id: linked[0].pending_submission_id,
    };
    const [current] =
      await sql`select normalized from public.external_event_records where id=${
        String(source.record_id)
      }`;
    const newest = { ...current.normalized, name: "Z after Y" };
    const hashZ = await hashNormalizedExternalEvent(newest);
    await sql`update public.external_event_records set normalized=${
      sql.json(newest)
    },moderation_hash=${hashZ} where id=${String(source.record_id)}`;
    const applied = await apply(sql, userId, pendingSource, eventId, ["name"]);
    assertEquals(applied.outcome, "applied");
    assert(applied.pending_submission_id !== null);
    const [pendingZ] =
      await sql`select user_id,user_email,user_name,external_moderation_hash from public.content_submissions where id=${applied.pending_submission_id}`;
    assertEquals(pendingZ, {
      user_id: userId,
      user_email: "resolution@example.test",
      user_name: "Resolution importer",
      external_moderation_hash: hashZ,
    });
    const [watermark] =
      await sql`select proposed_hash from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(watermark.proposed_hash, hashY);
  }));
async function waitForLock(sql: Sql, pid: number) {
  const deadline = Date.now() + 5000;
  while (Date.now() < deadline) {
    const [row] =
      await sql`select wait_event_type from pg_stat_activity where pid=${pid}`;
    if (row?.wait_event_type === "Lock") return;
    await new Promise((resolve) => setTimeout(resolve, 20));
  }
  throw new Error("Expected real overlapping lock wait");
}
for (const operation of ["link", "apply"] as const) {
  Deno.test(`M4 ${operation} owns submission→record while waiting Event; ingest overlaps without deadlock/duplicate pending`, async () => {
    const observer = postgres(databaseUrl, { max: 1, onnotice: () => {} }),
      blocker = postgres(databaseUrl, { max: 1, onnotice: () => {} }),
      resolver = postgres(databaseUrl, { max: 1, onnotice: () => {} }),
      ingester = postgres(databaseUrl, { max: 1, onnotice: () => {} });
    const userId = crypto.randomUUID(),
      externalId = crypto.randomUUID(),
      cityName = crypto.randomUUID();
    let source: Record<string, unknown> | undefined,
      eventId: string | undefined,
      cityId: string | undefined;
    let activeBlocker = false, activeResolver = false, activeIngester = false;
    let resolving: Promise<unknown> | undefined,
      ingesting: Promise<unknown> | undefined;
    try {
      await observer`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'overlap@example.test','{"display_name":"Overlap"}')`;
      const [city] =
        await observer`insert into public.cities(name) values (${cityName}) returning id`;
      cityId = String(city.id);
      const normalized = { ...state, city: cityName };
      const hash = await hashNormalizedExternalEvent(normalized);
      [source] =
        await observer`select * from public.ingest_external_event('resolution',${externalId},null,null,${
          observer.json(normalized)
        },1,${hash},'{}',1,${userId})`;
      assert(source);
      const [event] =
        await observer`insert into public.events(name,start_date,latitude,longitude,city_id) values ('Overlap target','2026-10-02',41,14,${cityId}) returning id`;
      eventId = String(event.id);
      if (operation === "apply") await knownBase(observer, source, eventId);
      await blocker`begin`;
      activeBlocker = true;
      await blocker`select id from public.events where id=${eventId} for update`;
      await resolver`begin`;
      activeResolver = true;
      await resolver`set local statement_timeout='10s'`;
      const [{ pid: resolverPid }] =
        await resolver`select pg_backend_pid() as pid`;
      resolving = operation === "link"
        ? Promise.resolve(
          resolver`select * from public.link_content_submission_to_event(${
            String(source.pending_submission_id)
          },${eventId},${userId})`,
        )
        : apply(resolver, userId, source, eventId, ["name"]);
      await waitForLock(observer, resolverPid);
      for (
        const table of [
          "content_submissions",
          "external_event_records",
        ] as const
      ) {
        await observer`begin`;
        const id = table === "content_submissions"
          ? source.pending_submission_id
          : source.record_id;
        const error = await assertRejects(() =>
          observer.unsafe(
            `select id from public.${table} where id=$1 for update nowait`,
            [String(id)],
          )
        );
        assertEquals((error as unknown as { code: string }).code, "55P03");
        await observer`rollback`;
      }
      await ingester`begin`;
      activeIngester = true;
      await ingester`set local statement_timeout='10s'`;
      const [{ pid: ingestPid }] =
        await ingester`select pg_backend_pid() as pid`;
      const newer = { ...normalized, name: "Overlapping newer source" };
      ingesting = Promise.resolve(
        ingester`select * from public.ingest_external_event('resolution',${externalId},null,null,${
          ingester.json(newer)
        },1,${await hashNormalizedExternalEvent(newer)},'{}',1,${userId})`,
      );
      await waitForLock(observer, ingestPid);
      await blocker`commit`;
      activeBlocker = false;
      await resolving;
      await resolver`commit`;
      activeResolver = false;
      await ingesting;
      await ingester`commit`;
      activeIngester = false;
      const [count] =
        await observer`select count(*)::int as count from public.content_submissions where external_event_record_id=${
          String(source.record_id)
        } and status='pending'`;
      assertEquals(count.count, 1);
    } finally {
      if (activeBlocker) await blocker`rollback`;
      if (resolving) await resolving.catch(() => {});
      if (activeResolver) await resolver`rollback`;
      if (ingesting) await ingesting.catch(() => {});
      if (activeIngester) await ingester`rollback`;
      if (source) {
        await observer`delete from public.content_submissions where external_event_record_id=${
          String(source.record_id)
        }`;
        await observer`delete from public.external_event_records where id=${
          String(source.record_id)
        }`;
      }
      if (eventId) {
        await observer`delete from public.events where id=${eventId}`;
      }
      if (cityId) await observer`delete from public.cities where id=${cityId}`;
      await observer`delete from auth.users where id=${userId}`;
      await Promise.all([
        observer.end(),
        blocker.end(),
        resolver.end(),
        ingester.end(),
      ]);
    }
  });
}

Deno.test("M4 Link rejects missing/deleted Event without resolution and service-only RPC ACLs stay closed", () =>
  fixture(async (sql, userId, source, eventId) => {
    assertEquals(
      (await sql`select * from public.link_content_submission_to_event(${
        String(source.pending_submission_id)
      },987654321,${userId})`)[0].outcome,
      "event_not_found",
    );
    await sql`savepoint deleted_target`;
    await sql`update public.events set deleted_at=clock_timestamp() where id=${eventId}`;
    assertEquals(
      (await sql`select * from public.link_content_submission_to_event(${
        String(source.pending_submission_id)
      },${eventId},${userId})`)[0].outcome,
      "event_inactive",
    );
    await sql`rollback to savepoint deleted_target`;
    for (const role of ["anon", "authenticated"]) {
      for (const operation of ["link", "apply"]) {
        await sql`savepoint denied_rpc`;
        await sql.unsafe(`set local role ${role}`);
        const error = await assertRejects(() =>
          operation === "link"
            ? sql`select * from public.link_content_submission_to_event(${
              String(source.pending_submission_id)
            },${eventId},${userId})`
            : sql`select * from public.apply_external_event_submission(${
              String(source.pending_submission_id)
            },${eventId},${userId},array[]::text[],null,null)`
        );
        assertEquals((error as unknown as { code: string }).code, "42501");
        await sql`rollback to savepoint denied_rpc`;
      }
    }
    await sql`set local role service_role`;
    await knownBase(sql, source, eventId);
    assertEquals(
      (await apply(sql, userId, source, eventId, ["name"])).outcome,
      "applied",
    );
  }));
Deno.test("M4 overlapping imported promotions and ingest create one Event and one next pending without deadlock", async () => {
  const observer = postgres(databaseUrl, { max: 1, onnotice: () => {} }),
    first = postgres(databaseUrl, { max: 1, onnotice: () => {} }),
    retry = postgres(databaseUrl, { max: 1, onnotice: () => {} }),
    ingester = postgres(databaseUrl, { max: 1, onnotice: () => {} });
  const userId = crypto.randomUUID(),
    externalId = crypto.randomUUID(),
    cityName = crypto.randomUUID(),
    title = crypto.randomUUID();
  let source: Record<string, unknown> | undefined,
    eventId: string | undefined,
    cityId: string | undefined;
  let activeFirst = false, activeRetry = false, activeIngest = false;
  let retrying: Promise<postgres.RowList<postgres.Row[]>> | undefined,
    ingesting: Promise<unknown> | undefined;
  try {
    await observer`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'promotion-overlap@example.test','{"display_name":"Promotion overlap"}')`;
    const [city] =
      await observer`insert into public.cities(name) values (${cityName}) returning id`;
    cityId = String(city.id);
    const normalized = { ...state, name: title, city: cityName };
    [source] =
      await observer`select * from public.ingest_external_event('resolution',${externalId},null,null,${
        observer.json(normalized)
      },1,${await hashNormalizedExternalEvent(normalized)},'{}',1,${userId})`;
    assert(source);
    await first`begin`;
    activeFirst = true;
    const [created] =
      await first`select * from public.promote_content_submission(${
        String(source.pending_submission_id)
      },'event',${userId})`;
    assertEquals(created.outcome, "created");
    eventId = String(created.entity_id);
    await retry`begin`;
    activeRetry = true;
    await retry`set local statement_timeout='10s'`;
    const [{ pid: retryPid }] = await retry`select pg_backend_pid() as pid`;
    retrying = Promise.resolve(
      retry`select * from public.promote_content_submission(${
        String(source.pending_submission_id)
      },'event',${userId})`,
    );
    await waitForLock(observer, retryPid);
    await ingester`begin`;
    activeIngest = true;
    await ingester`set local statement_timeout='10s'`;
    const [{ pid: ingestPid }] = await ingester`select pg_backend_pid() as pid`;
    const newer = { ...normalized, name: "Newer overlapping observation" };
    ingesting = Promise.resolve(
      ingester`select * from public.ingest_external_event('resolution',${externalId},null,null,${
        ingester.json(newer)
      },1,${await hashNormalizedExternalEvent(newer)},'{}',1,${userId})`,
    );
    await waitForLock(observer, ingestPid);
    await first`commit`;
    activeFirst = false;
    const [replayed] = await retrying;
    assertEquals(replayed, { ...created, outcome: "already_promoted" });
    await retry`commit`;
    activeRetry = false;
    await ingesting;
    await ingester`commit`;
    activeIngest = false;
    const [events] =
      await observer`select count(*)::int as count from public.events where name=${title}`;
    assertEquals(events.count, 1);
    const [pending] =
      await observer`select count(*)::int as count from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      } and status='pending'`;
    assertEquals(pending.count, 1);
    const [record] =
      await observer`select event_id from public.external_event_records where id=${
        String(source.record_id)
      }`;
    assertEquals(String(record.event_id), eventId);
  } finally {
    if (activeFirst) await first`rollback`;
    if (retrying) await retrying.catch(() => {});
    if (activeRetry) await retry`rollback`;
    if (ingesting) await ingesting.catch(() => {});
    if (activeIngest) await ingester`rollback`;
    if (source) {
      await observer`delete from public.content_submissions where external_event_record_id=${
        String(source.record_id)
      }`;
      await observer`delete from public.external_event_records where id=${
        String(source.record_id)
      }`;
    }
    if (eventId) await observer`delete from public.events where id=${eventId}`;
    if (cityId) await observer`delete from public.cities where id=${cityId}`;
    await observer`delete from auth.users where id=${userId}`;
    await Promise.all([
      observer.end(),
      first.end(),
      retry.end(),
      ingester.end(),
    ]);
  }
});

Deno.test("M4 Apply detects one microsecond token mismatches and content edits invalidate the observed token", () =>
  fixture(async (sql, userId, source, eventId) => {
    await knownBase(sql, source, eventId);
    const [tokens] =
      await sql`select s.modified_at::text as submission,e.modified_at::text as event,(s.modified_at+interval '1 microsecond')::text as shifted_submission,(e.modified_at+interval '1 microsecond')::text as shifted_event from public.content_submissions s cross join public.events e where s.id=${
        String(source.pending_submission_id)
      } and e.id=${eventId}`;
    assertEquals(
      (await apply(sql, userId, source, eventId, ["name"], false, null, {
        submission: tokens.shifted_submission,
        event: tokens.event,
      })).outcome,
      "submission_changed",
    );
    assertEquals(
      (await apply(sql, userId, source, eventId, ["name"], false, null, {
        submission: tokens.submission,
        event: tokens.shifted_event,
      })).outcome,
      "event_changed",
    );
    await sql`update public.content_submissions set name='Edit after preview' where id=${
      String(source.pending_submission_id)
    }`;
    assertEquals(
      (await apply(sql, userId, source, eventId, ["name"], false, null, {
        submission: tokens.submission,
        event: tokens.event,
      })).outcome,
      "submission_changed",
    );
    const [row] =
      await sql`select status,target_event_id from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assertEquals(row, { status: "pending", target_event_id: null });
  }));

Deno.test("M4 lost Link/Apply response replays same-target without any owned-state writes", async () => {
  for (const mode of ["link", "apply"] as const) {
    await fixture(async (sql, userId, source, eventId) => {
      if (mode === "apply") await knownBase(sql, source, eventId);
      await sourceNewer(sql, source);
      const first = mode === "link"
        ? (await sql`select * from public.link_content_submission_to_event(${
          String(source.pending_submission_id)
        },${eventId},${userId})`)[0]
        : await apply(sql, userId, source, eventId, ["name"]);
      assertEquals(first.outcome, mode === "link" ? "linked" : "applied");
      const snapshot = () =>
        sql`select row_to_json(e) as event,row_to_json(r) as record,(select jsonb_agg(to_jsonb(s) order by s.id) from public.content_submissions s where external_event_record_id=r.id) as submissions from public.events e cross join public.external_event_records r where e.id=${eventId} and r.id=${
          String(source.record_id)
        }`;
      const before = await snapshot();
      // Initial HTTP response is lost; source/hash and preview tokens may now be stale.
      const replay = mode === "link"
        ? (await sql`select * from public.link_content_submission_to_event(${
          String(source.pending_submission_id)
        },${eventId},${userId},true,'wrong')`)[0]
        : await apply(
          sql,
          userId,
          source,
          eventId,
          ["unknown"],
          true,
          "wrong",
          { submission: "old", event: "old" },
        );
      assertEquals(replay.outcome, "already_resolved");
      assertEquals(await snapshot(), before);
      const [other] =
        await sql`insert into public.events(name,start_date,latitude,longitude) values ('Retry other','2026-10-02',41,14) returning id`;
      const conflict = mode === "link"
        ? (await sql`select * from public.link_content_submission_to_event(${
          String(source.pending_submission_id)
        },${other.id},${userId})`)[0]
        : await apply(sql, userId, source, String(other.id), []);
      assertEquals(conflict.outcome, "target_conflict");
      assertEquals(await snapshot(), before);
    });
  }
});

Deno.test("M4 imported Event retains Place temporal denial and first-link is link-only without a base", () =>
  fixture(async (sql, userId, source, eventId) => {
    const [submission] =
      await sql`select start_date::text as start from public.content_submissions where id=${
        String(source.pending_submission_id)
      }`;
    assert(submission.start !== null);
    const [before] =
      await sql`select row_to_json(e) as value from public.events e where id=${eventId}`;
    const [place] = await sql`select * from public.promote_content_submission(${
      String(source.pending_submission_id)
    },'place',${userId})`;
    assertEquals(place.outcome, "place_has_event_dates");
    const [linked] =
      await sql`select * from public.link_content_submission_to_event(${
        String(source.pending_submission_id)
      },${eventId},${userId})`;
    assertEquals(linked.outcome, "linked");
    assertEquals(
      (await sql`select row_to_json(e) as value from public.events e where id=${eventId}`)[
        0
      ],
      before,
    );
    // A linked source without proposed base cannot use Apply; it can only link.
    await sourceNewer(sql, source);
    await sql`update public.external_event_records set proposed_normalized=null,proposed_normalization_version=null,proposed_hash=null where id=${
      String(source.record_id)
    }`;
    const [next] =
      await sql`select * from private.enqueue_external_event_proposal_if_needed(${
        String(source.record_id)
      },${userId},'importer@example.test','Importer')`;
    const result = await apply(
      sql,
      userId,
      { ...source, pending_submission_id: next.pending_submission_id },
      eventId,
      ["name"],
    );
    assertEquals(result.outcome, "base_required");
    assertEquals(
      (await sql`select row_to_json(e) as value from public.events e where id=${eventId}`)[
        0
      ],
      before,
    );
  }));

Deno.test("M4 committed real Link handler/store and Apply RPC recover lost responses without repeated mutation", async () => {
  const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
  const client = createClient<Database>(
    Deno.env.get("API_URL")!,
    Deno.env.get("SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  for (const mode of ["link", "apply"] as const) {
    const userId = crypto.randomUUID(), externalId = crypto.randomUUID();
    let source: Record<string, unknown> | undefined,
      eventId: string | undefined,
      otherId: string | undefined;
    try {
      await sql`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'retry@example.test','{"display_name":"Retry"}')`;
      [source] =
        await sql`select * from public.ingest_external_event('resolution',${externalId},null,null,${
          sql.json(state)
        },1,${await hashNormalizedExternalEvent(state)},'{}',1,${userId})`;
      assert(source);
      const [event] =
        await sql`insert into public.events(name,start_date,latitude,longitude) values ('Committed retry event','2026-10-02',41,14) returning id`;
      eventId = String(event.id);
      if (mode === "apply") {
        await knownBase(sql, source, eventId);
        await sql`update public.content_submissions set name='Reviewed Apply value' where id=${
          String(source.pending_submission_id)
        }`;
      }
      const shownHash = await sourceNewer(sql, source);
      const handler = createHandler({
        authenticate: () =>
          Promise.resolve(
            {
              id: userId,
              aud: "authenticated",
              created_at: "2026-10-02T00:00:00Z",
              app_metadata: { admin: true },
              user_metadata: {},
            } as User,
          ),
        createStore: () => createAdminSubmissionStore(client),
        nowIso: () => new Date().toISOString(),
      });
      const [beforeSave] =
        await sql`select to_jsonb(s) as row from public.content_submissions s where id=${
          String(source.pending_submission_id)
        }`;
      const nullSave = await handler(
        new Request("http://localhost", {
          method: "POST",
          headers: { Authorization: "Bearer verified-test-admin" },
          body: JSON.stringify({
            operation: "update",
            submission_id: Number(source.pending_submission_id),
            input: {
              ...state,
              description_delta: null,
              latitude: 41,
              longitude: 14,
              start_date: null,
              end_date: null,
              all_day: false,
              start_calendar_date: null,
              end_calendar_date: null,
            },
          }),
        }),
      );
      assertEquals(nullSave.status, 422);
      assertEquals((await nullSave.json()).code, "START_DATE_REQUIRED");
      assertEquals(
        (await sql`select to_jsonb(s) as row from public.content_submissions s where id=${
          String(source.pending_submission_id)
        }`)[0],
        beforeSave,
      );
      const request = (target: string) =>
        new Request("http://localhost", {
          method: "POST",
          headers: {
            Authorization: "Bearer verified-test-admin",
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            operation: "link",
            submission_id: Number(source!.pending_submission_id),
            target_event_id: Number(target),
            acknowledge_current_source: true,
            expected_source_hash: shownHash,
          }),
        });
      const tokens =
        (await sql`select s.modified_at::text as submission,e.modified_at::text as event from public.content_submissions s cross join public.events e where s.id=${
          String(source.pending_submission_id)
        } and e.id=${eventId}`)[0];
      if (mode === "apply") {
        const previewResponse = await handler(
          new Request("http://localhost", {
            method: "POST",
            headers: { Authorization: "Bearer verified-test-admin" },
            body: JSON.stringify({
              operation: "mergePreview",
              submission_id: Number(source.pending_submission_id),
              target_event_id: Number(eventId),
            }),
          }),
        );
        assertEquals(previewResponse.status, 200);
        const preview = (await previewResponse.json()).preview;
        const observedSubmission = await client.from("content_submissions")
          .select("modified_at").eq("id", Number(source.pending_submission_id))
          .single();
        const observedEvent = await client.from("events").select("modified_at")
          .eq("id", Number(eventId)).single();
        assertEquals(
          preview.submission_version_token,
          observedSubmission.data!.modified_at,
        );
        assertEquals(
          preview.event_version_token,
          observedEvent.data!.modified_at,
        );
        assertEquals(preview.groups[4].current.city, null);
      }
      const rpc = (target: string, retry: boolean) =>
        client.rpc("apply_external_event_submission", {
          p_submission_id: Number(source!.pending_submission_id),
          p_target_event_id: Number(target),
          p_handled_by: userId,
          p_groups_to_apply: retry ? ["unknown"] : ["name"],
          p_submission_version_token: retry ? "old" : tokens.submission,
          p_event_version_token: retry ? "old" : tokens.event,
          p_acknowledge_current_source: true,
          p_expected_source_hash: retry ? "wrong" : shownHash,
        });
      const applyRequest = (target: string, replay: boolean) =>
        new Request("http://localhost", {
          method: "POST",
          headers: { Authorization: "Bearer verified-test-admin" },
          body: JSON.stringify({
            operation: "apply",
            submission_id: Number(source!.pending_submission_id),
            target_event_id: Number(target),
            submission_version_token: replay ? "old" : tokens.submission,
            event_version_token: replay ? "old" : tokens.event,
            acknowledge_current_source: true,
            expected_source_hash: replay ? null : shownHash,
          }),
        });
      if (mode === "apply") {
        const beforeFailure = () =>
          sql`select row_to_json(e) as event,row_to_json(r) as record,(select jsonb_agg(to_jsonb(s) order by s.id) from public.content_submissions s where external_event_record_id=r.id) as submissions from public.events e cross join public.external_event_records r where e.id=${eventId!} and r.id=${
            String(source!.record_id)
          }`;
        const assertAckFailure = async (
          expected: string | null | undefined,
        ) => {
          const before = await beforeFailure();
          const failed = await handler(
            new Request("http://localhost", {
              method: "POST",
              headers: { Authorization: "Bearer verified-test-admin" },
              body: JSON.stringify({
                operation: "apply",
                submission_id: Number(source!.pending_submission_id),
                target_event_id: Number(eventId),
                submission_version_token: tokens.submission,
                event_version_token: tokens.event,
                acknowledge_current_source: true,
                ...(expected === undefined
                  ? {}
                  : { expected_source_hash: expected }),
              }),
            }),
          );
          assertEquals(failed.status, 409);
          assertEquals((await failed.json()).code, "SOURCE_CHANGED");
          assertEquals(await beforeFailure(), before);
        };
        await assertAckFailure(undefined);
        await assertAckFailure("a".repeat(64));
        const [observed] =
          await sql`select normalized,moderation_hash from public.external_event_records where id=${
            String(source.record_id)
          }`;
        await sourceNewer(sql, source);
        // Distinct drift after the source version displayed to the moderator.
        const drift = {
          ...observed.normalized,
          name: "Unexpected newer observation",
        };
        await sql`update public.external_event_records set normalized=${
          sql.json(drift)
        },moderation_hash=${await hashNormalizedExternalEvent(
          drift,
        )} where id=${String(source.record_id)}`;
        await assertAckFailure(shownHash);
        await sql`update public.external_event_records r set normalized=s.external_normalized,moderation_hash=s.external_moderation_hash from public.content_submissions s where r.id=${
          String(source.record_id)
        } and s.id=${String(source.pending_submission_id)}`;
        await assertAckFailure(shownHash);
        await sql`update public.external_event_records set normalized=${
          sql.json(observed.normalized)
        },moderation_hash=${observed.moderation_hash} where id=${
          String(source.record_id)
        }`;
        for (const invalidToken of ["submission", "event"] as const) {
          const before = await beforeFailure();
          const stale = await handler(
            new Request("http://localhost", {
              method: "POST",
              headers: { Authorization: "Bearer verified-test-admin" },
              body: JSON.stringify({
                operation: "apply",
                submission_id: Number(source.pending_submission_id),
                target_event_id: Number(eventId),
                submission_version_token: invalidToken === "submission"
                  ? "2000-01-01T00:00:00.000001Z"
                  : tokens.submission,
                event_version_token: invalidToken === "event"
                  ? "2000-01-01T00:00:00.000002Z"
                  : tokens.event,
                acknowledge_current_source: true,
                expected_source_hash: shownHash,
              }),
            }),
          );
          assertEquals(stale.status, 409);
          assertEquals(
            (await stale.json()).code,
            invalidToken === "submission"
              ? "SUBMISSION_CHANGED"
              : "EVENT_CHANGED",
          );
          assertEquals(await beforeFailure(), before);
        }
      }
      if (mode === "link") {
        const response = await handler(request(eventId));
        assertEquals(response.status, 200);
        assertEquals((await response.json()).resolution.outcome, "linked");
      } else {
        const initial = await handler(applyRequest(eventId, false));
        assertEquals(initial.status, 200);
        assertEquals((await initial.json()).resolution.outcome, "applied");
        assertEquals(
          (await sql`select name from public.events where id=${eventId}`)[0]
            .name,
          "Reviewed Apply value",
        );
      }
      // PostgREST completed and committed the first RPC; discard its response.
      const snapshot = () =>
        sql`select row_to_json(e) as event,row_to_json(r) as record,(select jsonb_agg(to_jsonb(s) order by s.id) from public.content_submissions s where external_event_record_id=r.id) as submissions from public.events e cross join public.external_event_records r where e.id=${eventId!} and r.id=${
          String(source!.record_id)
        }`;
      const before = await snapshot();
      if (mode === "link") {
        const response = await handler(request(eventId));
        assertEquals(response.status, 200);
        assertEquals(
          (await response.json()).resolution.outcome,
          "already_resolved",
        );
      } else {
        const replay = await rpc(eventId, true);
        assertEquals(replay.error, null);
        assertEquals(replay.data![0].outcome, "already_resolved");
        const handlerReplay = await handler(applyRequest(eventId, true));
        assertEquals(handlerReplay.status, 200);
        assertEquals(
          (await handlerReplay.json()).resolution.outcome,
          "already_resolved",
        );
      }
      assertEquals(await snapshot(), before);
      const [other] =
        await sql`insert into public.events(name,start_date,latitude,longitude) values ('Other retry','2026-10-02',41,14) returning id`;
      otherId = String(other.id);
      if (mode === "link") {
        const conflict = await handler(request(otherId));
        assertEquals(conflict.status, 409);
        assertEquals((await conflict.json()).code, "TARGET_CONFLICT");
      } else {
        const conflict = await rpc(otherId, true);
        assertEquals(conflict.error, null);
        assertEquals(conflict.data![0].outcome, "target_conflict");
        const handlerConflict = await handler(applyRequest(otherId, true));
        assertEquals(handlerConflict.status, 409);
        assertEquals((await handlerConflict.json()).code, "TARGET_CONFLICT");
      }
      assertEquals(await snapshot(), before);
    } finally {
      if (source) {
        await sql`delete from public.content_submissions where external_event_record_id=${
          String(source.record_id)
        }`;
        await sql`delete from public.external_event_records where id=${
          String(source.record_id)
        }`;
      }
      if (eventId) await sql`delete from public.events where id=${eventId}`;
      if (otherId) await sql`delete from public.events where id=${otherId}`;
      await sql`delete from auth.users where id=${userId}`;
    }
  }
  await sql.end();
});

Deno.test("M4 locked Apply temporal readiness rejects null/inverted schedule regardless requested groups with zero mutation", async () => {
  for (const invalid of ["null", "inverted"] as const) {
    await fixture(async (sql, userId, source, eventId) => {
      await knownBase(sql, source, eventId);
      // Malformed legacy chronology is represented only in this rolled-back fixture.
      if (invalid === "inverted") {
        await sql`alter table public.content_submissions drop constraint content_submissions_end_date_not_before_start_date_check`;
      }
      await sql`update public.content_submissions set start_date=${
        invalid === "null" ? null : "2026-10-03T10:00:00Z"
      }::timestamptz,end_date=${
        invalid === "null" ? null : "2026-10-02T10:00:00Z"
      }::timestamptz,all_day=false where id=${
        String(source.pending_submission_id)
      }`;
      const snapshot = () =>
        sql`select row_to_json(e) as event,row_to_json(r) as record,(select jsonb_agg(to_jsonb(s) order by s.id) from public.content_submissions s where external_event_record_id=r.id) as submissions,(select jsonb_agg(to_jsonb(m) order by m.id) from public.media m where event_id=e.id) as media,(select jsonb_agg(to_jsonb(a) order by a.id) from public.submissions_assets a where content_submission_id=${
          String(source.pending_submission_id)
        }) as assets from public.events e cross join public.external_event_records r where e.id=${eventId} and r.id=${
          String(source.record_id)
        }`;
      const before = await snapshot();
      for (const groups of [["name"], ["schedule"], []]) {
        const result = await apply(sql, userId, source, eventId, groups);
        assertEquals(
          result.outcome,
          invalid === "null" ? "start_date_required" : "invalid_date_range",
        );
        assertEquals(await snapshot(), before);
      }
    });
  }
});

Deno.test("M5 source snapshot→enqueue→actual Admin load→no-op Save yields zero moderator changes", async () => {
  const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
  const userId = crypto.randomUUID(), externalId = crypto.randomUUID();
  let source: Record<string, unknown> | undefined;
  try {
    await sql`insert into auth.users(id,email,raw_user_meta_data) values (${userId},'noop@example.test','{"display_name":"No-op"}')`;
    const snapshot = canonicalizeExternalEvent({
      ...state,
      name: "  Cafe\u0301  ",
      latitude: 41.123456789012345,
      description: "é",
      description_delta: [{ insert: "e", attributes: { bold: true } }, {
        insert: "\u0301\n",
      }],
    });
    [source] =
      await sql`select * from public.ingest_external_event('resolution',${externalId},null,null,${
        sql.json(snapshot)
      },1,${await hashNormalizedExternalEvent(snapshot)},'{}',1,${userId})`;
    assert(source);
    const client = createClient<Database>(
      Deno.env.get("API_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const handler = createHandler({
      authenticate: () =>
        Promise.resolve(
          {
            id: userId,
            app_metadata: { admin: true },
            user_metadata: {},
            aud: "authenticated",
            created_at: "2026-10-02T00:00:00Z",
          } as User,
        ),
      createStore: () => createAdminSubmissionStore(client),
      nowIso: () => new Date().toISOString(),
    });
    const send = (body: unknown) =>
      handler(
        new Request("http://localhost", {
          method: "POST",
          headers: { Authorization: "Bearer verified-test-admin" },
          body: JSON.stringify(body),
        }),
      );
    const loaded = await send({
      operation: "getById",
      submission_id: Number(source.pending_submission_id),
    });
    assertEquals(loaded.status, 200);
    const detail = await loaded.json();
    const fields = [
      "name",
      "category",
      "description",
      "description_delta",
      "city",
      "latitude",
      "longitude",
      "start_date",
      "end_date",
      "all_day",
    ];
    const input = Object.fromEntries(
      fields.map((key) => [key, detail.submission[key]]),
    );
    const saved = await send({
      operation: "update",
      submission_id: Number(source.pending_submission_id),
      input: { ...input, start_calendar_date: null, end_calendar_date: null },
    });
    assertEquals(saved.status, 200);
    const persisted = (await saved.json()).submission;
    const moderated = canonicalizeSubmission(persisted);
    assertEquals(moderated, snapshot);
    assertEquals(
      calculateExternalEventMerge(snapshot, snapshot, moderated, snapshot)
        .groups.map((group) => group.moderator_changed),
      [false, false, false, false, false],
    );
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

Deno.test("M5 actual Admin candidates separate active canonical targets from pending warnings and permit manual fallback", async () => {
  const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
  const userId = crypto.randomUUID(),
    cityName = crypto.randomUUID(),
    title = crypto.randomUUID();
  let cityId: number | undefined,
    submissionId: number | undefined,
    warningId: number | undefined;
  const eventIds: number[] = [];
  try {
    await sql`insert into auth.users(id,email) values (${userId},'candidate@example.test')`;
    const [city] =
      await sql`insert into public.cities(name) values (${cityName}) returning id`;
    cityId = Number(city.id);
    const [submission] =
      await sql`insert into public.content_submissions(user_id,user_email,user_name,city,name,start_date) values (${userId},'candidate@example.test','Candidate',${cityName},${title},'2026-10-02T22:30:00Z') returning id`;
    submissionId = Number(submission.id);
    const [warning] =
      await sql`insert into public.content_submissions(user_id,user_email,user_name,city,name,start_date) values (${userId},'candidate@example.test','Candidate',${cityName},${title.toUpperCase()},'2026-10-03T10:00:00Z') returning id`;
    warningId = Number(warning.id);
    for (
      const [name, city, start, deleted] of [
        [title, cityId, "2026-10-03T10:00:00Z", null],
        [title, cityId, "2026-10-03T10:00:00Z", "2026-10-04"],
        [title + " manual", null, "2026-11-01T10:00:00Z", null],
      ] as const
    ) {
      const [event] =
        await sql`insert into public.events(name,city_id,start_date,latitude,longitude,deleted_at) values (${name},${city},${start}::timestamptz,41,14,${deleted}::timestamptz) returning id`;
      eventIds.push(Number(event.id));
    }
    const client = createClient<Database>(
      Deno.env.get("API_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const handler = createHandler({
      authenticate: () =>
        Promise.resolve(
          {
            id: userId,
            app_metadata: { admin: true },
            user_metadata: {},
            aud: "authenticated",
            created_at: "2026-10-02T00:00:00Z",
          } as User,
        ),
      createStore: () => createAdminSubmissionStore(client),
      nowIso: () => "unused",
    });
    const send = (extra: object = {}) =>
      handler(
        new Request("http://localhost", {
          method: "POST",
          headers: { Authorization: "Bearer verified-admin" },
          body: JSON.stringify({
            operation: "eventCandidates",
            submission_id: submissionId,
            ...extra,
          }),
        }),
      );
    const automatic = await send();
    assertEquals(automatic.status, 200);
    const candidates = (await automatic.json()).candidates;
    assertEquals(candidates.events.map((e: { id: number }) => e.id), [
      eventIds[0],
    ]);
    assertEquals(candidates.events[0].name_match, true);
    assertEquals(candidates.pending_warnings.map((s: { id: number }) => s.id), [
      warningId,
    ]);
    const manualId = await send({ target_event_id: eventIds[2] });
    assertEquals(manualId.status, 200);
    const manual = (await manualId.json()).candidates.events;
    assertEquals(manual.map((e: { id: number }) => e.id), [eventIds[2]]);
    assertEquals(manual[0].city, null);
    const manualName = await send({ search_name: title + " manual" });
    assertEquals(
      (await manualName.json()).candidates.events.map((e: { id: number }) =>
        e.id
      ),
      [eventIds[2]],
    );
    await sql`update public.events set deleted_at=clock_timestamp() where id=${
      eventIds[0]
    }`;
    assertEquals((await (await send()).json()).candidates.events, []);
  } finally {
    if (submissionId) {
      await sql`delete from public.content_submissions where id=${submissionId}`;
    }
    if (warningId) {
      await sql`delete from public.content_submissions where id=${warningId}`;
    }
    for (const id of eventIds) {
      await sql`delete from public.events where id=${id}`;
    }
    if (cityId) await sql`delete from public.cities where id=${cityId}`;
    await sql`delete from auth.users where id=${userId}`;
    await sql.end();
  }
});
