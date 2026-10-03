import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import type { Database } from "../functions/_shared/database.types.ts";
import {
  importSourceAssetIfEligible,
  ingestExternalEvent,
  uploadAndPersistImportedAsset,
} from "../functions/import-external-events/index.ts";
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import postgres, { type Sql } from "npm:postgres@3.4.5";
import {
  type LegacySubmission,
  planVerifiedBackfill,
  type SnapshotEvidence,
} from "../tools/external_event_migration.ts";
import { backfillVerifiedPlans } from "../tools/backfill_external_events.ts";
import { prepareEvent } from "../functions/import-external-events/import_logic.ts";
import type { EventiMoliseEvent } from "../functions/import-external-events/eventimolise.ts";
const url = Deno.env.get("SUPABASE_DB_URL") ?? "";
assert(["localhost", "127.0.0.1"].includes(new URL(url).hostname));
async function fixture(
  run: (
    sql: Sql,
    userId: string,
    rows: LegacySubmission[],
    observation: EventiMoliseEvent,
    captures: SnapshotEvidence[],
  ) => Promise<void>,
  handled = true,
) {
  const sql = postgres(url, { max: 1, onnotice: () => {} });
  const userId = crypto.randomUUID();
  const sourceId = Math.floor(Math.random() * 1e12) + 1;
  const observation: EventiMoliseEvent = {
    id: sourceId,
    title: "Current source",
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
  };
  const normalized = prepareEvent(observation).normalized;
  const notes =
    `Imported from EventiMolise\nSource event ID: ${sourceId}\nSource URL: ${observation.url}`;
  let eventId: string | undefined;
  try {
    await sql`insert into auth.users(id,email,raw_user_meta_data) values(${userId},'migration@example.test','{"display_name":"Migration"}')`;
    const [event] =
      await sql`insert into public.events(name,start_date,latitude,longitude) values('Canonical untouched','2026-10-02',41,14) returning id`;
    eventId = String(event.id);
    if (handled) {
      await sql`insert into public.content_submissions(user_id,user_email,user_name,name,city,status,handled_at,promoted_event_id,start_date,internal_notes) values(${userId},'migration@example.test','Migration','Moderator-owned','City','accepted','2026-10-01T12:00:00.000001Z',${eventId},${normalized.start_date}::timestamptz,${notes})`;
    }
    await sql`insert into public.content_submissions(user_id,user_email,user_name,name,city,start_date,internal_notes) values(${userId},'migration@example.test','Migration','Pending edited','City',${normalized.start_date}::timestamptz,${notes})`;
    const entries =
      await sql`select to_jsonb(s) as row from public.content_submissions s where user_id=${userId} order by id`;
    const rows = entries.map((entry) => entry.row as LegacySubmission);
    const captures: SnapshotEvidence[] = rows.map((row, index) => ({
      submission_id: row.id,
      identity: {
        provider: "eventimolise",
        external_id: String(sourceId),
        occurrence_key: null,
      },
      origin: "verified_source_capture",
      evidence_ref: `capture/${index}`,
      normalized: index === 0 && handled
        ? { ...normalized, name: "Old source" }
        : normalized,
    }));
    await run(sql, userId, rows, observation, captures);
  } finally {
    await sql`delete from public.submissions_assets where content_submission_id in(select id from public.content_submissions where user_id=${userId})`;
    await sql`delete from public.content_submissions where user_id=${userId}`;
    await sql`delete from public.external_event_records where provider='eventimolise' and external_id=${
      String(sourceId)
    }`;
    if (eventId) await sql`delete from public.events where id=${eventId}`;
    await sql`delete from auth.users where id=${userId}`;
    await sql.end();
  }
}
const options = {
  migration_timestamp: "2026-10-02T15:00:00.123456Z",
  never_attempted: [],
  rollback: false,
};
async function plans(
  rows: LegacySubmission[],
  observation: EventiMoliseEvent,
  captures: SnapshotEvidence[],
) {
  return await planVerifiedBackfill(rows, [observation], captures, [{
    identity: captures[0].identity,
    classification: "verified_handled",
    evidence_ref: "classified-history",
    last_handled_submission_id: rows[0].id,
    handled_snapshot: {
      normalized: captures[0].normalized,
      evidence_ref: captures[0].evidence_ref,
    },
  }]);
}
Deno.test("M8 verified backfill preserves editorial content/resolution and newer pending; replay is idempotent", () =>
  fixture(async (sql, _userId, rows, observation, captures) => {
    const plan = await plans(rows, observation, captures);
    const [eventBefore] =
      await sql`select to_jsonb(e) as row from public.events e where id=${rows[
        0
      ].promoted_event_id!}`;
    const first = await backfillVerifiedPlans(sql, plan, options);
    assertEquals(first[0].pending_submission_id, rows[1].id);
    assertEquals(first[0].pending_created, false);
    const record =
      (await sql`select to_jsonb(r) as row from public.external_event_records r where id=${
        first[0].record_id
      }`)[0].row;
    assertEquals(record.proposed_normalized.name, "Old source");
    assertEquals(record.normalized.name, "Current source");
    const after =
      (await sql`select to_jsonb(s) as row from public.content_submissions s where id=${
        rows[1].id
      }`)[0].row;
    assertEquals(after.name, rows[1].name);
    assertEquals(after.status, "pending");
    assertEquals(after.external_normalized.name, "Current source");
    assertEquals(
      after.source_asset_import_claimed_at,
      "2026-10-02T15:00:00.123456+00:00",
    );
    assertEquals(
      (await sql`select to_jsonb(e) as row from public.events e where id=${rows[
        0
      ].promoted_event_id!}`)[0],
      eventBefore,
    );
    const replay = await backfillVerifiedPlans(sql, plan, options);
    assertEquals(replay, first);
    assertEquals(
      (await sql`select to_jsonb(s) as row from public.content_submissions s where id=${
        rows[1].id
      }`)[0].row,
      after,
    );
  }));
Deno.test("M8 full exported-state and single-microsecond drift reject atomically without provenance or record creation", () =>
  fixture(async (sql, userId, rows, observation, captures) => {
    const plan = await plans(rows, observation, captures);
    await sql`update public.content_submissions set modified_at=modified_at+interval '1 microsecond' where id=${
      rows[1].id
    }`;
    await assertRejects(
      () => backfillVerifiedPlans(sql, plan, options),
      Error,
      "exported_submission_changed",
    );
    assertEquals(
      (await sql`select count(*)::int as count from public.external_event_records where provider='eventimolise' and external_id=${
        String(observation.id)
      }`)[0].count,
      0,
    );
    assertEquals(
      (await sql`select count(*)::int as count from public.content_submissions where user_id=${userId} and external_event_record_id is not null`)[
        0
      ].count,
      0,
    );
  }));
Deno.test("M8 transactional dry-run rolls back all verified backfill changes", () =>
  fixture(async (sql, userId, rows, observation, captures) => {
    const result = await backfillVerifiedPlans(
      sql,
      await plans(rows, observation, captures),
      { ...options, rollback: true },
    );
    assertEquals(result.length, 1);
    assertEquals(
      (await sql`select count(*)::int as count from public.content_submissions where user_id=${userId} and external_event_record_id is not null`)[
        0
      ].count,
      0,
    );
    assertEquals(
      (await sql`select count(*)::int as count from public.external_event_records where provider='eventimolise' and external_id=${
        String(observation.id)
      }`)[0].count,
      0,
    );
  }));

Deno.test("M8 replay rejects corrupt same-hash record snapshots without touching submission provenance", () =>
  fixture(async (sql, _userId, rows, observation, captures) => {
    const plan = await plans(rows, observation, captures);
    const [first] = await backfillVerifiedPlans(sql, plan, options);
    const before =
      (await sql`select to_jsonb(s) as row from public.content_submissions s where id=${
        rows[1].id
      }`)[0].row;
    await sql`update public.external_event_records set normalized=jsonb_set(normalized,'{name}','"Corrupt same hash"') where id=${first.record_id}`;
    await assertRejects(
      () => backfillVerifiedPlans(sql, plan, options),
      Error,
      "existing_record_changed",
    );
    assertEquals(
      (await sql`select to_jsonb(s) as row from public.content_submissions s where id=${
        rows[1].id
      }`)[0].row,
      before,
    );
  }));

Deno.test("M8 drift comparison preserves date-shaped plaintext instead of parsing it as timestamps", () =>
  fixture(async (sql, userId, _rows, observation, captures) => {
    await sql`update public.content_submissions set name='2026-10-02T10:00:00Z is the event title',description='2026-10-02T10:00:00Z followed by literal notes' where user_id=${userId}`;
    const rows =
      (await sql`select to_jsonb(s) as row from public.content_submissions s where user_id=${userId} order by id`)
        .map((entry) => entry.row as LegacySubmission);
    await backfillVerifiedPlans(
      sql,
      await plans(rows, observation, captures),
      options,
    );
    const after =
      (await sql`select to_jsonb(s) as row from public.content_submissions s where id=${
        rows[1].id
      }`)[0].row;
    assertEquals(after.name, rows[1].name);
    assertEquals(after.description, rows[1].description);
  }));

Deno.test("M8 final dry-run uses real production ingest RPC and rejects every unexplained proposal atomically", () =>
  fixture(async (sql, userId, rows, observation, captures) => {
    const plan = await plans(rows, observation, captures);
    const prepared = prepareEvent(observation);
    const sourceHash = plan[0].tuples[1].external_moderation_hash;
    await assertRejects(
      () =>
        backfillVerifiedPlans(sql, plan, {
          ...options,
          rollback: true,
          verify_ingest: {
            observations: [prepared],
            importer_user_id: userId,
            explanations: [],
          },
        }),
      Error,
      "unexplained_dry_run_proposal",
    );
    const dry = await backfillVerifiedPlans(sql, plan, {
      ...options,
      rollback: true,
      verify_ingest: {
        observations: [prepared],
        importer_user_id: userId,
        explanations: [{
          identity: captures[0].identity,
          source_hash: sourceHash,
          evidence_ref: "verified-newer-pending-unhandled",
        }],
      },
    });
    assertEquals(dry[0].pending_submission_id, rows[1].id);
    assertEquals(
      (await sql`select count(*)::int as count from public.external_event_records where provider='eventimolise' and external_id=${
        String(observation.id)
      }`)[0].count,
      0,
    );
  }));

Deno.test("M8 prepared activation path preserves distinct strong identities despite same city/name/day", () =>
  fixture(async (sql, userId, rows, observation, captures) => {
    const plan = await plans(rows, observation, captures);
    const second = { ...observation, id: observation.id + 1 };
    const hash = plan[0].tuples[1].external_moderation_hash;
    const dry = await backfillVerifiedPlans(sql, plan, {
      ...options,
      rollback: true,
      verify_ingest: {
        observations: [prepareEvent(observation), prepareEvent(second)],
        importer_user_id: userId,
        explanations: [{
          identity: captures[0].identity,
          source_hash: hash,
          evidence_ref: "unhandled-pending",
        }, {
          identity: { ...captures[0].identity, external_id: String(second.id) },
          source_hash: hash,
          evidence_ref: "new-strong-identity",
        }],
      },
    });
    assertEquals(dry.length, 2);
    assertEquals(
      dry.filter((entry) => entry.pending_submission_id !== null).length,
      2,
    );
  }));

Deno.test("M8 release-date guard rolls back if lock/work crosses Europe/Rome midnight before commit", () =>
  fixture(async (sql, userId, rows, observation, captures) => {
    const plan = await plans(rows, observation, captures);
    let checks = 0;
    await assertRejects(
      () =>
        backfillVerifiedPlans(sql, plan, {
          ...options,
          release_guard: {
            t0: "2026-10-02T21:00:00Z",
            now: () =>
              ++checks === 1 ? "2026-10-02T21:59:59Z" : "2026-10-02T22:00:00Z",
          },
        }),
      Error,
      "invalid_quiescent_t0_or_rome_date",
    );
    assertEquals(checks, 2);
    assertEquals(
      (await sql`select count(*)::int as count from public.content_submissions where user_id=${userId} and external_event_record_id is not null`)[
        0
      ].count,
      0,
    );
    assertEquals(
      (await sql`select count(*)::int as count from public.external_event_records where provider='eventimolise' and external_id=${
        String(observation.id)
      }`)[0].count,
      0,
    );
  }));

Deno.test("M8 editorial-only baseline links historical Event with current=proposed and leaves unverifiable accepted row legacy", () =>
  fixture(async (sql, _userId, rows, observation, captures) => {
    await sql`delete from public.content_submissions where id=${rows[1].id}`;
    const history = [rows[0]];
    const [plan] = await planVerifiedBackfill(history, [observation], [], [{
      identity: captures[0].identity,
      classification: "editorial_baseline",
      evidence_ref: "editorial-classification",
      baseline_authorization_ref: "baseline-operator-authorization",
    }], [{
      submission_id: rows[0].id,
      kind: "editorial_moderation_enrichment",
      evidence_ref: "editorial-comparison",
    }]);
    const [result] = await backfillVerifiedPlans(sql, [plan], options);
    assertEquals(result.pending_submission_id, null);
    const [record] =
      await sql`select to_jsonb(r) as row from public.external_event_records r where id=${result.record_id}`;
    assertEquals(record.row.normalized, record.row.proposed_normalized);
    assertEquals(record.row.event_id, rows[0].promoted_event_id);
    assertEquals(
      (await sql`select to_jsonb(s) as row from public.content_submissions s where id=${
        rows[0].id
      }`)[0].row,
      rows[0],
    );
  }));

for (const ignored of [false, true]) {
  Deno.test(`M8 real ${ignored ? "ignored" : "rejected"} baseline uses non-null current watermark and leaves unverifiable rejected history legacy`, () =>
    fixture(async (sql, userId, rows, observation, captures) => {
      await sql`delete from public.content_submissions where id=${rows[1].id}`;
      await sql`update public.content_submissions set status='rejected',promoted_event_id=null where id=${
        rows[0].id
      }`;
      const history =
        (await sql`select to_jsonb(s) as row from public.content_submissions s where user_id=${userId}`)
          .map((entry) => entry.row as LegacySubmission);
      const [plan] = await planVerifiedBackfill(history, [observation], [], [{
        identity: captures[0].identity,
        classification: ignored ? "ignored_baseline" : "rejected_baseline",
        evidence_ref: "observable-rejection",
        baseline_authorization_ref: "explicit-rejected-baseline",
        ...(ignored
          ? { ignore_authorization_ref: "operator-permanent-ignore" }
          : {}),
      }]);
      const [result] = await backfillVerifiedPlans(sql, [plan], options);
      const record =
        (await sql`select to_jsonb(r) as row from public.external_event_records r where id=${result.record_id}`)[
          0
        ].row;
      assertEquals(record.normalized, record.proposed_normalized);
      assertEquals(record.proposed_hash === null, false);
      assertEquals(record.ignored_at !== null, ignored);
      assertEquals(result.pending_submission_id, null);
      assertEquals(
        (await sql`select to_jsonb(s) as row from public.content_submissions s where id=${
          rows[0].id
        }`)[0].row,
        history[0],
      );
    }));
}

Deno.test("M8 no-longer-observable verified handled state is current=proposed; unverifiable absence creates no record", () =>
  fixture(async (sql, userId, rows, _observation, captures) => {
    await sql`delete from public.content_submissions where id=${rows[1].id}`;
    const history = [rows[0]];
    const identity = captures[0].identity;
    const retained = await planVerifiedBackfill(history, [], [], [{
      identity,
      classification: "retain_legacy",
      evidence_ref: "unverifiable-history",
      availability_evidence_ref: "audited-provider-absence",
    }]);
    assertEquals(await backfillVerifiedPlans(sql, retained, options), []);
    assertEquals(
      (await sql`select count(*)::int as count from public.external_event_records where provider='eventimolise' and external_id=${identity.external_id}`)[
        0
      ].count,
      0,
    );
    const [plan] = await planVerifiedBackfill(history, [], [], [{
      identity,
      classification: "verified_no_longer_observable",
      evidence_ref: "verified-handled-history",
      availability_evidence_ref: "audited-provider-absence",
      last_handled_submission_id: rows[0].id,
      handled_snapshot: {
        normalized: captures[0].normalized,
        evidence_ref: captures[0].evidence_ref,
      },
    }]);
    const [result] = await backfillVerifiedPlans(sql, [plan], options);
    const [record] =
      await sql`select to_jsonb(r) as row from public.external_event_records r where id=${result.record_id}`;
    assertEquals(record.row.normalized, record.row.proposed_normalized);
    assertEquals(record.row.normalized.name, "Old source");
    assertEquals(result.pending_submission_id, null);
    assertEquals(
      (await sql`select to_jsonb(s) as row from public.content_submissions s where user_id=${userId}`)[
        0
      ].row,
      rows[0],
    );
  }));

const sourceImage = "https://eventimolise.it/wp-content/uploads/fixture.png";
const cloudinary = {
  cloudName: "fixture",
  apiKey: "dummy",
  apiSecret: "dummy",
};
const uploaded = {
  url: "https://res.cloudinary.com/fixture/image/upload/v1/legacy.png",
  width: 100,
  height: 100,
  mimeType: "image/png",
  publicId: "fixture/legacy",
};
function localClient() {
  const api = Deno.env.get("API_URL") ?? "";
  assert(["localhost", "127.0.0.1"].includes(new URL(api).hostname));
  return createClient<Database>(api, Deno.env.get("SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}
async function unhandledPlan(
  rows: LegacySubmission[],
  observation: EventiMoliseEvent,
  captures: SnapshotEvidence[],
) {
  return await planVerifiedBackfill(rows, [observation], captures, [{
    identity: captures[0].identity,
    classification: "verified_unhandled",
    evidence_ref: "complete-unhandled-history",
    never_handled_evidence_ref: "verified-no-handled-revisions",
  }]);
}

for (const priorAttempt of ["removed", "failed", "unknown"] as const) {
  Deno.test(`M8 legacy ${priorAttempt} automatic attempt consumes migration-time budget despite zero assets; ingest never re-adds`, () =>
    fixture(async (sql, userId, rows, observation, captures) => {
      const pending = rows[0];
      if (priorAttempt === "removed") {
        let legacyUploads = 0;
        await uploadAndPersistImportedAsset(localClient(), {
          submissionId: pending.id,
          sourceUrl: sourceImage,
          cloudinary,
        }, {
          uploadRemoteImage: () => {
            legacyUploads++;
            return Promise.resolve(uploaded);
          },
          destroyCloudinaryImage: () => Promise.resolve(),
        });
        assertEquals(legacyUploads, 1);
        const [asset] =
          await sql`select id from public.submissions_assets where content_submission_id=${pending.id}`;
        const [deleted] =
          await sql`select public.delete_submission_asset(${pending.id},${asset.id}) as outcome`;
        assertEquals(deleted.outcome, "deleted");
      }
      if (priorAttempt === "failed") {
        let legacyAttempts = 0;
        await assertRejects(
          () =>
            uploadAndPersistImportedAsset(localClient(), {
              submissionId: pending.id,
              sourceUrl: sourceImage,
              cloudinary,
            }, {
              uploadRemoteImage: () => {
                legacyAttempts++;
                return Promise.reject(new Error("Legacy upload failed"));
              },
              destroyCloudinaryImage: () => Promise.resolve(),
            }),
          Error,
          "Legacy upload failed",
        );
        assertEquals(legacyAttempts, 1);
      }
      assertEquals(
        (await sql`select count(*)::int as count from public.submissions_assets where content_submission_id=${pending.id}`)[
          0
        ].count,
        0,
      );
      const plan = await unhandledPlan(rows, observation, captures);
      const [result] = await backfillVerifiedPlans(sql, plan, options);
      const before =
        (await sql`select to_jsonb(s) as row from public.content_submissions s where id=${pending.id}`)[
          0
        ].row;
      assertEquals(
        before.source_asset_import_claimed_at,
        "2026-10-02T15:00:00.123456+00:00",
      );
      const client = localClient();
      const repeated = await ingestExternalEvent(
        client,
        prepareEvent({ ...observation, image: sourceImage }),
        userId,
      );
      assertEquals(repeated.pending_submission_id, pending.id);
      assertEquals(repeated.pending_created, false);
      let uploads = 0;
      const outcome = await importSourceAssetIfEligible(client, {
        event: { imageUrl: sourceImage },
        observation: repeated,
        cloudinary,
      }, {
        uploadRemoteImage: () => {
          uploads++;
          return Promise.resolve(uploaded);
        },
        destroyCloudinaryImage: () => Promise.resolve(),
      });
      assertEquals(outcome, "skipped");
      assertEquals(uploads, 0);
      assertEquals(
        (await client.rpc("claim_external_event_source_asset", {
          p_submission_id: pending.id,
        })).data?.[0].outcome,
        "already_claimed",
      );
      assertEquals(
        (await backfillVerifiedPlans(sql, plan, options))[0].record_id,
        result.record_id,
      );
      assertEquals(
        (await sql`select to_jsonb(s) as row from public.content_submissions s where id=${pending.id}`)[
          0
        ].row,
        before,
      );
    }, false));
}

Deno.test("M8 positive never-attempted proof alone leaves fresh eligibility; missing/invalid replay proof blocks; removal after claim remains final", () =>
  fixture(async (sql, userId, rows, observation, captures) => {
    const pending = rows[0];
    const plan = await unhandledPlan(rows, observation, captures);
    const exemption = {
      ...options,
      never_attempted: [{
        submission_id: pending.id,
        evidence_ref: "positive-source-observation-never-offered-an-image",
      }],
    };
    await backfillVerifiedPlans(sql, plan, exemption);
    assertEquals(
      (await sql`select source_asset_import_claimed_at from public.content_submissions where id=${pending.id}`)[
        0
      ].source_asset_import_claimed_at,
      null,
    );
    await backfillVerifiedPlans(sql, plan, exemption);
    await assertRejects(
      () => backfillVerifiedPlans(sql, plan, options),
      Error,
      "missing_legacy_asset_budget_consumption",
    );
    for (
      const never_attempted of [
        [{ submission_id: pending.id + 99999, evidence_ref: "typo" }],
        [{ submission_id: pending.id, evidence_ref: "" }],
        [...exemption.never_attempted, ...exemption.never_attempted],
      ]
    ) {
      await assertRejects(
        () => backfillVerifiedPlans(sql, plan, { ...options, never_attempted }),
        Error,
        "invalid_never_attempted_evidence",
      );
    }
    const client = localClient();
    let uploads = 0;
    const deps = {
      uploadRemoteImage: () => {
        uploads++;
        return Promise.resolve(uploaded);
      },
      destroyCloudinaryImage: () => Promise.resolve(),
    };
    const repeated = await ingestExternalEvent(
      client,
      prepareEvent({ ...observation, image: sourceImage }),
      userId,
    );
    assertEquals(
      await importSourceAssetIfEligible(client, {
        event: { imageUrl: sourceImage },
        observation: repeated,
        cloudinary,
      }, deps),
      "uploaded",
    );
    const [asset] =
      await sql`select id from public.submissions_assets where content_submission_id=${pending.id}`;
    assertEquals(
      (await client.rpc("delete_submission_asset", {
        p_submission_id: pending.id,
        p_asset_id: Number(asset.id),
      })).data,
      "deleted",
    );
    const reobserved = await ingestExternalEvent(
      client,
      prepareEvent({ ...observation, image: sourceImage }),
      userId,
    );
    assertEquals(
      await importSourceAssetIfEligible(client, {
        event: { imageUrl: sourceImage },
        observation: reobserved,
        cloudinary,
      }, deps),
      "skipped",
    );
    assertEquals(uploads, 1);
    assertEquals(
      (await sql`select count(*)::int as count from public.submissions_assets where content_submission_id=${pending.id}`)[
        0
      ].count,
      0,
    );
  }, false));
