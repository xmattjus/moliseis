import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import postgres, { type Sql } from "npm:postgres@3.4.5";

type DbBigint = string | number;
type Outcome = { outcome: string; submission_id: DbBigint | null };
type Asset = {
  url: string;
  width: number;
  height: number;
  mime_type: string | null;
  duration_seconds: number | null;
};
type SubmissionInput = {
  userId: string;
  key: string;
  name?: string;
  city?: string;
  category?: "nature" | "history" | "unknown" | null;
  assets?: Asset[];
};

function localDatabaseUrl(): string {
  const value = Deno.env.get("SUPABASE_DB_URL");
  if (!value) {
    throw new Error(
      "Submission idempotency tests require SUPABASE_DB_URL. Run `bash supabase/tests/run_submission_idempotency_db_test.sh` after `supabase start`.",
    );
  }
  const hostname = new URL(value).hostname;
  if (hostname !== "127.0.0.1" && hostname !== "localhost") {
    throw new Error("SUPABASE_DB_URL must target a local PostgreSQL instance.");
  }
  return value;
}

const databaseUrl = localDatabaseUrl();
const racingStatementTimeoutMs = 10_000;

function client(): Sql {
  return postgres(databaseUrl, { max: 1 });
}

function asset(suffix: string): Asset {
  return {
    url: `https://res.cloudinary.com/test/image/upload/${suffix}.jpg`,
    width: 100,
    height: 80,
    mime_type: "image/jpeg",
    duration_seconds: null,
  };
}

async function createUser(sql: Sql): Promise<string> {
  const id = crypto.randomUUID();
  await sql`
    insert into auth.users (id, aud, role, email)
    values (${id}, 'authenticated', 'authenticated', ${`idempotency-${id}@example.test`})
  `;
  return id;
}

async function cleanupUser(sql: Sql, userId: string): Promise<void> {
  await sql`delete from public.content_submissions where user_id = ${userId}`;
  await sql`delete from public.submission_rate_limits where user_id = ${userId}`;
  await sql`delete from auth.users where id = ${userId}`;
}

async function submit(sql: Sql, input: SubmissionInput): Promise<Outcome> {
  const [result] = await sql<Outcome[]>`
    select outcome, submission_id
    from public.submit_content(
      ${input.userId}::uuid,
      ${input.key}::uuid,
      ${input.city ?? "Campobasso"},
      ${input.name ?? "First committed name"},
      ${"First committed description"},
      ${null}::jsonb,
      ${41.5629},
      ${14.6697},
      ${"Via Roma"},
      ${null}::timestamptz,
      ${null}::timestamptz,
      ${input.category ?? null}::public.content_category,
      ${`idempotency-${input.userId}@example.test`},
      ${"Idempotency test user"},
      ${sql.json(input.assets ?? [])}
    )
  `;
  return result;
}

async function submissionCount(sql: Sql, userId: string): Promise<number> {
  const [row] = await sql<{ count: number }[]>`
    select count(*)::integer as count
    from public.content_submissions
    where user_id = ${userId}
  `;
  return row.count;
}

async function quota(sql: Sql, userId: string): Promise<{
  count: number;
  startedAt: string;
}> {
  const [row] = await sql<{ count: number; started_at: string }[]>`
    select submission_count as count, window_started_at::text as started_at
    from public.submission_rate_limits
    where user_id = ${userId}
  `;
  return { count: row.count, startedAt: row.started_at };
}

async function storedAssets(
  sql: Sql,
  submissionId: DbBigint,
): Promise<Asset[]> {
  return [
    ...await sql<Asset[]>`
    select url, width, height, mime_type, duration_seconds
    from public.submissions_assets
    where content_submission_id = ${submissionId}
    order by id
  `,
  ];
}

async function prepareRacingSession(sql: Sql, name: string): Promise<void> {
  await sql`
    select set_config('application_name', ${name}, false),
           set_config('statement_timeout', ${
    String(racingStatementTimeoutMs)
  }, false)
  `;
}

async function waitForLock(sql: Sql, applicationName: string): Promise<void> {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    const [activity] = await sql<{
      state: string;
      wait_event_type: string | null;
    }[]>`
      select state, wait_event_type
      from pg_stat_activity
      where application_name = ${applicationName}
    `;
    if (activity?.state === "active" && activity.wait_event_type === "Lock") {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(
    `Session ${applicationName} did not block on a database lock`,
  );
}

async function assertPostgresError(run: () => Promise<unknown>): Promise<void> {
  await assertRejects(run);
}

Deno.test("nullable legacy keys and user-scoped canonical UUID-v4 constraints", async () => {
  const sql = client();
  const firstUser = await createUser(sql);
  const secondUser = await createUser(sql);
  const key = crypto.randomUUID();
  try {
    await sql`
      insert into public.content_submissions (user_id, user_email, user_name, city, name)
      values (${firstUser}, ${`idempotency-${firstUser}@example.test`}, 'Legacy import', 'Campobasso', 'Legacy row')
    `;
    await assertPostgresError(() =>
      sql`
        insert into public.content_submissions (user_id, client_submission_id, user_email, user_name, city, name)
        values (${firstUser}, '11111111-1111-3111-8111-111111111111'::uuid, ${`idempotency-${firstUser}@example.test`}, 'Admin', 'Campobasso', 'Wrong version')
      `
    );
    await assertPostgresError(() =>
      sql`
        insert into public.content_submissions (user_id, client_submission_id, user_email, user_name, city, name)
        values (${firstUser}, '11111111-1111-4111-7111-111111111111'::uuid, ${`idempotency-${firstUser}@example.test`}, 'Admin', 'Campobasso', 'Wrong variant')
      `
    );
    await sql`
      insert into public.content_submissions (user_id, client_submission_id, user_email, user_name, city, name)
      values (${firstUser}, ${key}::uuid, ${`idempotency-${firstUser}@example.test`}, 'Admin', 'Campobasso', 'Keyed row')
    `;
    await assertPostgresError(() =>
      sql`
        insert into public.content_submissions (user_id, client_submission_id, user_email, user_name, city, name)
        values (${firstUser}, ${key}::uuid, ${`idempotency-${firstUser}@example.test`}, 'Admin', 'Campobasso', 'Duplicate key')
      `
    );
    await sql`
      insert into public.content_submissions (user_id, client_submission_id, user_email, user_name, city, name)
      values (${secondUser}, ${key}::uuid, ${`idempotency-${secondUser}@example.test`}, 'Admin', 'Campobasso', 'Other owner key')
    `;
    assertEquals(await submissionCount(sql, firstUser), 2);
    assertEquals(await submissionCount(sql, secondUser), 1);
  } finally {
    await cleanupUser(sql, firstUser);
    await cleanupUser(sql, secondUser);
    await sql.end();
  }
});

Deno.test("first commits persist no assets, assets, and unknown null category", async () => {
  const sql = client();
  const users: string[] = [];
  try {
    const noAssetsUser = await createUser(sql);
    const assetsUser = await createUser(sql);
    const unknownUser = await createUser(sql);
    users.push(noAssetsUser, assetsUser, unknownUser);
    const noAssetsKey = crypto.randomUUID();
    const assetsKey = crypto.randomUUID();
    const unknownKey = crypto.randomUUID();

    const noAssets = await submit(sql, {
      userId: noAssetsUser,
      key: noAssetsKey,
      category: "nature",
    });
    const withAssets = await submit(sql, {
      userId: assetsUser,
      key: assetsKey,
      assets: [asset("first-a"), asset("first-b")],
      category: "history",
    });
    const nullCategory = await submit(sql, {
      userId: unknownUser,
      key: unknownKey,
      category: null,
    });

    for (const result of [noAssets, withAssets, nullCategory]) {
      assertEquals(result.outcome, "created");
      assert(Number(result.submission_id) > 0);
    }
    const rows = await sql<{
      id: DbBigint;
      user_id: string;
      client_submission_id: string;
      category: string;
    }[]>`
      select id, user_id, client_submission_id::text, category::text as category
      from public.content_submissions
      where user_id = any(${[noAssetsUser, assetsUser, unknownUser]})
      order by user_id
    `;
    assertEquals(rows.length, 3);
    for (
      const [userId, key, result, expectedCategory] of [
        [noAssetsUser, noAssetsKey, noAssets, "nature"],
        [assetsUser, assetsKey, withAssets, "history"],
        [unknownUser, unknownKey, nullCategory, "unknown"],
      ] as const
    ) {
      const row = rows.find((candidate) =>
        candidate.id === result.submission_id
      );
      assertEquals(row?.user_id, userId);
      assertEquals(row?.client_submission_id, key);
      assertEquals(row?.category, expectedCategory);
      assertEquals(await submissionCount(sql, userId), 1);
      assertEquals((await quota(sql, userId)).count, 1);
    }
    assertEquals(await storedAssets(sql, noAssets.submission_id!), []);
    assertEquals(await storedAssets(sql, withAssets.submission_id!), [
      asset("first-a"),
      asset("first-b"),
    ]);
    assertEquals(await storedAssets(sql, nullCategory.submission_id!), []);
  } finally {
    for (const user of users) await cleanupUser(sql, user);
    await sql.end();
  }
});

Deno.test("same-user replay is first-write-wins and does not charge quota", async () => {
  const sql = client();
  const userId = await createUser(sql);
  const key = crypto.randomUUID();
  try {
    const created = await submit(sql, {
      userId,
      key,
      name: "First body",
      assets: [asset("first-write")],
      category: "nature",
    });
    const beforeQuota = await quota(sql, userId);
    const identicalReplay = await submit(sql, {
      userId,
      key,
      name: "First body",
      assets: [asset("first-write")],
      category: "nature",
    });
    const changedReplay = await submit(sql, {
      userId,
      key,
      name: "Changed retry body",
      city: "Isernia",
      assets: [asset("changed-retry")],
      category: "history",
    });
    const [stored] = await sql<
      { name: string; city: string; category: string; assets: number }[]
    >`
      select submissions.name, submissions.city, submissions.category::text as category,
             count(assets.id)::integer as assets
      from public.content_submissions as submissions
      left join public.submissions_assets as assets
        on assets.content_submission_id = submissions.id
      where submissions.id = ${created.submission_id}
      group by submissions.id
    `;
    assertEquals(created.outcome, "created");
    assertEquals(identicalReplay.outcome, "replayed");
    assertEquals(identicalReplay.submission_id, created.submission_id);
    assertEquals(changedReplay.outcome, "replayed");
    assertEquals(changedReplay.submission_id, created.submission_id);
    assertEquals(stored, {
      name: "First body",
      city: "Campobasso",
      category: "nature",
      assets: 1,
    });
    assertEquals(await storedAssets(sql, created.submission_id!), [
      asset("first-write"),
    ]);
    assertEquals(await quota(sql, userId), beforeQuota);
  } finally {
    await cleanupUser(sql, userId);
    await sql.end();
  }
});

Deno.test("replay preserves accepted and rejected moderation state", async () => {
  const sql = client();
  const users: string[] = [];
  try {
    for (const status of ["accepted", "rejected"] as const) {
      const userId = await createUser(sql);
      users.push(userId);
      const key = crypto.randomUUID();
      const created = await submit(sql, { userId, key });
      await sql`
        update public.content_submissions
        set status = ${status}::public.submission_status
        where id = ${created.submission_id}
      `;
      const [beforeReplay] = await sql<{
        status: string;
        handled_at: string | null;
        handled_by: string | null;
        promoted_place_id: DbBigint | null;
        promoted_event_id: DbBigint | null;
      }[]>`
        select status::text as status, handled_at::text, handled_by::text,
               promoted_place_id, promoted_event_id
        from public.content_submissions
        where id = ${created.submission_id}
      `;
      const replayed = await submit(sql, {
        userId,
        key,
        name: "Late changed body",
      });
      const [afterReplay] = await sql<{
        status: string;
        handled_at: string | null;
        handled_by: string | null;
        promoted_place_id: DbBigint | null;
        promoted_event_id: DbBigint | null;
      }[]>`
        select status::text as status, handled_at::text, handled_by::text,
               promoted_place_id, promoted_event_id
        from public.content_submissions
        where id = ${created.submission_id}
      `;
      assertEquals(replayed, {
        outcome: "replayed",
        submission_id: created.submission_id,
      });
      assertEquals(beforeReplay.status, status);
      assertEquals(afterReplay, beforeReplay);
    }
  } finally {
    for (const user of users) await cleanupUser(sql, user);
    await sql.end();
  }
});

Deno.test("same-key race commits once and converges to one id", async () => {
  const setup = client();
  const first = client();
  const second = client();
  const observer = client();
  const userId = await createUser(setup);
  const key = crypto.randomUUID();
  try {
    await prepareRacingSession(second, "submission-idempotency-same-key");
    let secondRequest: Promise<Outcome> | null = null;
    const firstResult = await first.begin(async (transaction) => {
      const result = await submit(transaction, {
        userId,
        key,
        name: "First racer",
        assets: [asset("race-first")],
      });
      secondRequest = submit(second, {
        userId,
        key,
        name: "Second racer",
        assets: [asset("race-second")],
      });
      await waitForLock(observer, "submission-idempotency-same-key");
      return result;
    });
    const secondResult = await secondRequest!;
    assertEquals(firstResult.outcome, "created");
    assertEquals(secondResult.outcome, "replayed");
    assertEquals(secondResult.submission_id, firstResult.submission_id);
    assertEquals(await submissionCount(setup, userId), 1);
    assertEquals((await quota(setup, userId)).count, 1);
    const [stored] = await setup<{ name: string }[]>`
      select name from public.content_submissions
      where id = ${firstResult.submission_id}
    `;
    assertEquals(stored.name, "First racer");
    assertEquals(await storedAssets(setup, firstResult.submission_id!), [
      asset("race-first"),
    ]);
  } finally {
    await cleanupUser(setup, userId);
    await Promise.all([setup.end(), first.end(), second.end(), observer.end()]);
  }
});

Deno.test("different-key fifth-slot race permits one commit and replay at limit", async () => {
  const setup = client();
  const first = client();
  const second = client();
  const observer = client();
  const userId = await createUser(setup);
  try {
    for (let index = 0; index < 4; index += 1) {
      assertEquals(
        (await submit(setup, { userId, key: crypto.randomUUID() })).outcome,
        "created",
      );
    }
    const firstKey = crypto.randomUUID();
    const secondKey = crypto.randomUUID();
    await prepareRacingSession(second, "submission-idempotency-fifth-slot");
    let secondRequest: Promise<Outcome> | null = null;
    const firstResult = await first.begin(async (transaction) => {
      const result = await submit(transaction, {
        userId,
        key: firstKey,
        name: "Fifth first",
      });
      secondRequest = submit(second, {
        userId,
        key: secondKey,
        name: "Fifth second",
      });
      await waitForLock(observer, "submission-idempotency-fifth-slot");
      return result;
    });
    const secondResult = await secondRequest!;
    assertEquals([firstResult.outcome, secondResult.outcome].sort(), [
      "created",
      "rate_limited",
    ]);
    assertEquals(await submissionCount(setup, userId), 5);
    assertEquals((await quota(setup, userId)).count, 5);
    const committedKey = firstResult.outcome === "created"
      ? firstKey
      : secondKey;
    const replayed = await submit(setup, {
      userId,
      key: committedKey,
      name: "Replay at limit",
    });
    assertEquals(replayed.outcome, "replayed");
    assertEquals((await quota(setup, userId)).count, 5);
  } finally {
    await cleanupUser(setup, userId);
    await Promise.all([setup.end(), first.end(), second.end(), observer.end()]);
  }
});

Deno.test("keys are user-scoped and public roles cannot execute the RPC", async () => {
  const sql = client();
  const firstUser = await createUser(sql);
  const secondUser = await createUser(sql);
  const serviceRoleUser = await createUser(sql);
  const key = crypto.randomUUID();
  try {
    assertEquals(
      (await submit(sql, { userId: firstUser, key })).outcome,
      "created",
    );
    assertEquals(
      (await submit(sql, { userId: secondUser, key })).outcome,
      "created",
    );
    assertEquals(await submissionCount(sql, firstUser), 1);
    assertEquals(await submissionCount(sql, secondUser), 1);
    const [privileges] = await sql<
      { anon: boolean; authenticated: boolean; service_role: boolean }[]
    >`
      select has_function_privilege('anon', 'public.submit_content(uuid, uuid, text, text, text, jsonb, double precision, double precision, text, timestamp with time zone, timestamp with time zone, public.content_category, text, text, jsonb)', 'execute') as anon,
             has_function_privilege('authenticated', 'public.submit_content(uuid, uuid, text, text, text, jsonb, double precision, double precision, text, timestamp with time zone, timestamp with time zone, public.content_category, text, text, jsonb)', 'execute') as authenticated,
             has_function_privilege('service_role', 'public.submit_content(uuid, uuid, text, text, text, jsonb, double precision, double precision, text, timestamp with time zone, timestamp with time zone, public.content_category, text, text, jsonb)', 'execute') as service_role
    `;
    assertEquals(privileges, {
      anon: false,
      authenticated: false,
      service_role: true,
    });
    const beforeDeniedCalls = await submissionCount(sql, firstUser);
    for (const role of ["anon", "authenticated"]) {
      await assertPostgresError(() =>
        sql.begin(async (transaction) => {
          await transaction.unsafe(`set local role ${role}`);
          await submit(transaction, {
            userId: firstUser,
            key: crypto.randomUUID(),
          });
        })
      );
    }
    assertEquals(await submissionCount(sql, firstUser), beforeDeniedCalls);
    const serviceRoleResult = await sql.begin(async (transaction) => {
      await transaction.unsafe("set local role service_role");
      return await submit(transaction, {
        userId: serviceRoleUser,
        key: crypto.randomUUID(),
      });
    });
    assertEquals(serviceRoleResult.outcome, "created");
    assertEquals(await submissionCount(sql, serviceRoleUser), 1);
  } finally {
    await cleanupUser(sql, firstUser);
    await cleanupUser(sql, secondUser);
    await cleanupUser(sql, serviceRoleUser);
    await sql.end();
  }
});

Deno.test("asset failure rolls back content and quota", async () => {
  const sql = client();
  const userId = await createUser(sql);
  try {
    const [before] = await sql<{
      submissions: number;
      assets: number;
      quota_rows: number;
    }[]>`
      select
        (select count(*)::integer from public.content_submissions where user_id = ${userId}) as submissions,
        (select count(*)::integer from public.submissions_assets as assets
          join public.content_submissions as submissions
            on submissions.id = assets.content_submission_id
          where submissions.user_id = ${userId}) as assets,
        (select count(*)::integer from public.submission_rate_limits where user_id = ${userId}) as quota_rows
    `;
    await assertPostgresError(() =>
      submit(sql, {
        userId,
        key: crypto.randomUUID(),
        assets: Array.from({ length: 6 }, (_, index) =>
          asset(`overflow-${index}`)),
      })
    );
    const [after] = await sql<{
      submissions: number;
      assets: number;
      quota_rows: number;
    }[]>`
      select
        (select count(*)::integer from public.content_submissions where user_id = ${userId}) as submissions,
        (select count(*)::integer from public.submissions_assets as assets
          join public.content_submissions as submissions
            on submissions.id = assets.content_submission_id
          where submissions.user_id = ${userId}) as assets,
        (select count(*)::integer from public.submission_rate_limits where user_id = ${userId}) as quota_rows
    `;
    assertEquals(after, before);
  } finally {
    await cleanupUser(sql, userId);
    await sql.end();
  }
});

Deno.test("fixed-window boundary is strict and replay precedes an expired reset", async () => {
  const sql = client();
  const newerUser = await createUser(sql);
  const exactUser = await createUser(sql);
  const olderUser = await createUser(sql);
  const replayUser = await createUser(sql);
  try {
    for (
      const [userId, offset, expectedCount, shouldRetainStart] of [
        [newerUser, "23 hours 59 minutes", 5, true],
        [exactUser, "24 hours", 1, false],
        [olderUser, "25 hours", 1, false],
      ] as const
    ) {
      await sql.begin(async (transaction) => {
        const [seeded] = await transaction<{ started_at: string }[]>`
          insert into public.submission_rate_limits (user_id, submission_count, window_started_at)
          values (${userId}, 4, transaction_timestamp() - ${offset}::interval)
          returning window_started_at::text as started_at
        `;
        assertEquals(
          (await submit(transaction, { userId, key: crypto.randomUUID() }))
            .outcome,
          "created",
        );
        const after = await quota(transaction, userId);
        assertEquals(after.count, expectedCount);
        if (shouldRetainStart) {
          assertEquals(after.startedAt, seeded.started_at);
        } else {
          assert(new Date(after.startedAt) > new Date(seeded.started_at));
        }
      });
    }

    const replayKey = crypto.randomUUID();
    const created = await submit(sql, { userId: replayUser, key: replayKey });
    await sql.begin(async (transaction) => {
      await transaction`
        update public.submission_rate_limits
        set submission_count = 5,
            window_started_at = transaction_timestamp() - interval '25 hours'
        where user_id = ${replayUser}
      `;
      const beforeReplay = await quota(transaction, replayUser);
      const replayed = await submit(transaction, {
        userId: replayUser,
        key: replayKey,
      });
      assertEquals(replayed, {
        outcome: "replayed",
        submission_id: created.submission_id,
      });
      assertEquals(await quota(transaction, replayUser), beforeReplay);
    });
  } finally {
    for (const user of [newerUser, exactUser, olderUser, replayUser]) {
      await cleanupUser(sql, user);
    }
    await sql.end();
  }
});
