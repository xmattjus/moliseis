import postgres, { type Sql } from "npm:postgres@3.4.5";

type DbBigint = string | number;

function localDatabaseUrl(): string {
  const value = Deno.env.get("SUPABASE_DB_URL");
  if (!value) {
    throw new Error(
      "Event temporal invariant tests require SUPABASE_DB_URL. Run `bash supabase/tests/run_event_temporal_invariants_db_test.sh` after `supabase start`.",
    );
  }

  const hostname = new URL(value).hostname;
  if (hostname !== "127.0.0.1" && hostname !== "localhost") {
    throw new Error("SUPABASE_DB_URL must target a local PostgreSQL instance.");
  }
  return value;
}

const databaseUrl = localDatabaseUrl();

function client(): Sql {
  return postgres(databaseUrl, { max: 1 });
}

async function assertPostgresError(
  run: () => Promise<unknown>,
  expectedCode: string,
): Promise<void> {
  try {
    await run();
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (code === expectedCode) return;
    throw new Error(
      `Expected PostgreSQL error ${expectedCode} but received ${
        code ?? String(error)
      }`,
      { cause: error },
    );
  }
  throw new Error(
    `Expected PostgreSQL error ${expectedCode}, but the statement succeeded`,
  );
}

async function createSubmissionUser(sql: Sql): Promise<string> {
  const userId = crypto.randomUUID();
  await sql`
    insert into auth.users (id, aud, role, email)
    values (
      ${userId},
      'authenticated',
      'authenticated',
      ${`event-temporal-${userId}@example.test`}
    )
  `;
  return userId;
}

async function insertSubmission(
  sql: Sql,
  userId: string,
  startDate: string | null,
  endDate: string | null,
): Promise<DbBigint> {
  const [submission] = await sql<{ id: DbBigint }[]>`
    insert into public.content_submissions (
      user_id,
      user_email,
      user_name,
      city,
      name,
      start_date,
      end_date
    )
    values (
      ${userId},
      ${`event-temporal-${userId}@example.test`},
      'Event temporal invariant test',
      'Campobasso',
      'Test submission',
      ${startDate}::timestamptz,
      ${endDate}::timestamptz
    )
    returning id
  `;
  return submission.id;
}

async function insertEvent(
  sql: Sql,
  startDate: string,
  endDate: string | null,
): Promise<DbBigint> {
  const [event] = await sql<{ id: DbBigint }[]>`
    insert into public.events (
      name,
      start_date,
      end_date,
      latitude,
      longitude
    )
    values (
      'Event temporal invariant test',
      ${startDate}::timestamptz,
      ${endDate}::timestamptz,
      41.5629::double precision,
      14.6697::double precision
    )
    returning id
  `;
  return event.id;
}

Deno.test("content submission date checks accept valid inserts and updates", async () => {
  const sql = client();
  const userId = await createSubmissionUser(sql);
  try {
    await insertSubmission(sql, userId, null, null);
    await insertSubmission(sql, userId, "2026-09-01T10:00:00Z", null);
    await insertSubmission(
      sql,
      userId,
      "2026-09-01T10:00:00Z",
      "2026-09-01T10:00:00Z",
    );
    const submissionId = await insertSubmission(
      sql,
      userId,
      "2026-09-01T10:00:00Z",
      "2026-09-01T10:00:00.000001Z",
    );

    await sql`
      update public.content_submissions
      set start_date = null, end_date = null
      where id = ${submissionId}
    `;
    await sql`
      update public.content_submissions
      set start_date = '2026-09-01T10:00:00Z'::timestamptz,
          end_date = null
      where id = ${submissionId}
    `;
    await sql`
      update public.content_submissions
      set end_date = '2026-09-01T10:00:00Z'::timestamptz
      where id = ${submissionId}
    `;
    await sql`
      update public.content_submissions
      set end_date = '2026-09-01T10:00:00.000001Z'::timestamptz
      where id = ${submissionId}
    `;
  } finally {
    await sql`delete from public.content_submissions where user_id = ${userId}`;
    await sql`delete from auth.users where id = ${userId}`;
    await sql.end();
  }
});

Deno.test("content submission date checks reject invalid inserts and updates", async () => {
  const sql = client();
  const userId = await createSubmissionUser(sql);
  try {
    await assertPostgresError(
      () => insertSubmission(sql, userId, null, "2026-09-01T10:00:00Z"),
      "23514",
    );
    await assertPostgresError(
      () =>
        insertSubmission(
          sql,
          userId,
          "2026-09-01T10:00:01Z",
          "2026-09-01T10:00:00Z",
        ),
      "23514",
    );
    await assertPostgresError(
      () =>
        sql`
        insert into public.content_submissions (
          user_id,
          user_email,
          user_name,
          city,
          name,
          start_date,
          end_date
        )
        values (
          ${userId},
          ${`event-temporal-${userId}@example.test`},
          'Event temporal invariant test',
          'Campobasso',
          'Microsecond-inverted submission',
          '2026-09-01 10:00:00.000001+00'::timestamptz,
          '2026-09-01 10:00:00.000000+00'::timestamptz
        )
      `,
      "23514",
    );
    const submissionId = await insertSubmission(
      sql,
      userId,
      "2026-09-01T10:00:00Z",
      null,
    );
    await assertPostgresError(
      () =>
        sql`
        update public.content_submissions
        set start_date = null,
            end_date = '2026-09-01T10:00:00Z'::timestamptz
        where id = ${submissionId}
      `,
      "23514",
    );
    await assertPostgresError(
      () =>
        sql`
        update public.content_submissions
        set end_date = '2026-09-01T09:59:59.999999Z'::timestamptz
        where id = ${submissionId}
      `,
      "23514",
    );
  } finally {
    await sql`delete from public.content_submissions where user_id = ${userId}`;
    await sql`delete from auth.users where id = ${userId}`;
    await sql.end();
  }
});

Deno.test("event date checks accept valid inserts and updates", async () => {
  const sql = client();
  const eventIds: DbBigint[] = [];
  try {
    eventIds.push(await insertEvent(sql, "2026-09-01T10:00:00Z", null));
    eventIds.push(
      await insertEvent(
        sql,
        "2026-09-01T10:00:00Z",
        "2026-09-01T10:00:00Z",
      ),
    );
    const eventId = await insertEvent(
      sql,
      "2026-09-01T10:00:00Z",
      "2026-09-01T10:00:00.000001Z",
    );
    eventIds.push(eventId);

    await sql`
      update public.events
      set end_date = null
      where id = ${eventId}
    `;
    await sql`
      update public.events
      set end_date = start_date
      where id = ${eventId}
    `;
    await sql`
      update public.events
      set end_date = start_date + interval '1 microsecond'
      where id = ${eventId}
    `;
  } finally {
    await sql`delete from public.events where id = any(${eventIds})`;
    await sql.end();
  }
});

Deno.test("event date checks reject invalid inserts and updates", async () => {
  const sql = client();
  const eventIds: DbBigint[] = [];
  try {
    await assertPostgresError(
      () =>
        sql`
        insert into public.events (name, start_date, latitude, longitude)
        values (
          'Event without start date',
          null,
          41.5629::double precision,
          14.6697::double precision
        )
      `,
      "23502",
    );
    await assertPostgresError(
      () =>
        insertEvent(
          sql,
          "2026-09-01T10:00:01Z",
          "2026-09-01T10:00:00Z",
        ),
      "23514",
    );
    await assertPostgresError(
      () =>
        sql`
        insert into public.events (
          name,
          start_date,
          end_date,
          latitude,
          longitude
        )
        values (
          'Microsecond-inverted event',
          '2026-09-01 10:00:00.000001+00'::timestamptz,
          '2026-09-01 10:00:00.000000+00'::timestamptz,
          41.5629::double precision,
          14.6697::double precision
        )
      `,
      "23514",
    );
    const eventId = await insertEvent(sql, "2026-09-01T10:00:00Z", null);
    eventIds.push(eventId);
    await assertPostgresError(
      () =>
        sql`
        update public.events
        set end_date = '2026-09-01T09:59:59.999999Z'::timestamptz
        where id = ${eventId}
      `,
      "23514",
    );
    await assertPostgresError(
      () =>
        sql`
        update public.events
        set start_date = null
        where id = ${eventId}
      `,
      "23502",
    );
  } finally {
    await sql`delete from public.events where id = any(${eventIds})`;
    await sql.end();
  }
});

Deno.test("all-day defaults preserve real midnight and require submission start on insert/update", async () => {
  const sql = client();
  const userId = await createSubmissionUser(sql);
  let eventId: DbBigint | undefined;
  try {
    const submissionId = await insertSubmission(sql, userId, null, null);
    eventId = await insertEvent(sql, "2026-10-12T00:00:00Z", null);
    const [defaults] = await sql<
      {
        submission_mode: boolean;
        event_mode: boolean;
        midnight_unchanged: boolean;
      }[]
    >`
      select s.all_day as submission_mode, e.all_day as event_mode,
        e.start_date = '2026-10-12T00:00:00Z'::timestamptz as midnight_unchanged
      from public.content_submissions s cross join public.events e
      where s.id = ${submissionId} and e.id = ${eventId}
    `;
    if (
      defaults.submission_mode || defaults.event_mode ||
      !defaults.midnight_unchanged
    ) {
      throw new Error(
        "Default mode must be false without reinterpreting midnight",
      );
    }
    await assertPostgresError(
      () =>
        sql`update public.content_submissions set all_day = true where id = ${submissionId}`,
      "23514",
    );
    await assertPostgresError(
      () =>
        sql`update public.content_submissions set all_day = null where id = ${submissionId}`,
      "23502",
    );
    await assertPostgresError(
      () => sql`update public.events set all_day = null where id = ${eventId!}`,
      "23502",
    );
    await assertPostgresError(() =>
      sql`
      insert into public.content_submissions (user_id, user_email, user_name, city, name, all_day)
      values (${userId}, 'all-day@example.test', 'Test', 'Campobasso', 'Test', true)
    `, "23514");
    await assertPostgresError(() =>
      sql`
      insert into public.content_submissions (user_id, user_email, user_name, city, name, all_day)
      values (${userId}, 'all-day@example.test', 'Test', 'Campobasso', 'Test', null)
    `, "23502");
    await sql`update public.content_submissions set all_day = true, start_date = '2026-10-11T22:00:00Z' where id = ${submissionId}`;
    await assertPostgresError(
      () =>
        sql`update public.content_submissions set start_date = null where id = ${submissionId}`,
      "23514",
    );
    await sql`update public.content_submissions set all_day = false, start_date = null where id = ${submissionId}`;
  } finally {
    await sql`delete from public.content_submissions where user_id = ${userId}`;
    if (eventId !== undefined) {
      await sql`delete from public.events where id = ${eventId}`;
    }
    await sql`delete from auth.users where id = ${userId}`;
    await sql.end();
  }
});

Deno.test("flag-only event update advances the existing modified_at marker", async () => {
  const sql = client();
  const id = await insertEvent(sql, "2026-10-11T22:00:00Z", null);
  try {
    const [before] = await sql<
      { modified_at: string; start_date: string }[]
    >`select modified_at::text, start_date::text from public.events where id = ${id}`;
    await sql`update public.events set all_day = true where id = ${id}`;
    const [after] = await sql<
      { changed: boolean; all_day: boolean; start_date: string }[]
    >`select modified_at > ${before.modified_at}::text::timestamptz as changed, all_day, start_date::text from public.events where id = ${id}`;
    if (
      !after.changed || !after.all_day || after.start_date !== before.start_date
    ) {
      throw new Error(
        "Flag-only update must advance modified_at without changing the dates",
      );
    }
  } finally {
    await sql`delete from public.events where id = ${id}`;
    await sql.end();
  }
});
