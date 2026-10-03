import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import postgres, { type Sql } from "npm:postgres@3.4.5";

const databaseUrl = Deno.env.get("SUPABASE_DB_URL");
if (
  !databaseUrl ||
  !["localhost", "127.0.0.1"].includes(new URL(databaseUrl).hostname)
) {
  throw new Error(
    "Use run_external_event_provenance_db_test.sh with a local database.",
  );
}

async function fixture(run: (sql: Sql) => Promise<void>) {
  const sql = postgres(databaseUrl!, { max: 1 });
  try {
    await sql`begin`;
    await run(sql);
  } finally {
    await sql`rollback`;
    await sql.end();
  }
}

async function failure(sql: Sql, statement: string, code = "23514") {
  await sql`savepoint invalid_write`;
  try {
    const error = await assertRejects(() => sql.unsafe(statement));
    assertEquals((error as { code: string }).code, code);
  } finally {
    await sql`rollback to savepoint invalid_write`;
  }
}

async function record(sql: Sql) {
  const [row] = await sql`insert into public.external_event_records
    (provider, external_id, normalized, normalization_version, moderation_hash, metadata_version)
    values ('test', ${crypto.randomUUID()}, '{}'::jsonb, 1, ${
    "a".repeat(64)
  }, 1)
    returning id`;
  return String(row.id);
}

Deno.test("M1 external identity, object, version, hash and watermark constraints", () =>
  fixture(async (sql) => {
    const id = await record(sql);
    await failure(
      sql,
      `insert into public.external_event_records
    (provider, external_id, normalized, normalization_version, moderation_hash, metadata_version)
    select provider, external_id, normalized, normalization_version, moderation_hash, metadata_version
    from public.external_event_records where id = ${id}`,
      "23505",
    );
    await sql`insert into public.external_event_records
    (provider, external_id, occurrence_key, normalized, normalization_version, moderation_hash, metadata_version)
    select provider, external_id, 'second', normalized, normalization_version, moderation_hash, metadata_version
    from public.external_event_records where id = ${id}`;
    for (
      const assignment of [
        "provider = 'Bad-Provider'",
        "provider = ''",
        "external_id = '   '",
        "occurrence_key = ' '",
        "normalized = '[]'::jsonb",
        "normalized = 'null'::jsonb",
        "normalization_version = 0",
        "metadata = '[]'::jsonb",
        "metadata_version = 0",
        "moderation_hash = 'invalid'",
        "proposed_normalized = '{}'::jsonb",
        "proposed_normalization_version = 1",
        "proposed_hash = '" + "a".repeat(64) + "'",
        "proposed_normalized = '[]'::jsonb, proposed_normalization_version = 1, proposed_hash = '" +
        "a".repeat(64) + "'",
        "proposed_normalized = '{}'::jsonb, proposed_normalization_version = 0, proposed_hash = '" +
        "a".repeat(64) + "'",
        "proposed_normalized = '{}'::jsonb, proposed_normalization_version = 1, proposed_hash = 'wrong'",
      ]
    ) {
      await failure(
        sql,
        `update public.external_event_records set ${assignment} where id = ${id}`,
      );
    }
    for (let mask = 1; mask < 7; mask++) {
      await failure(
        sql,
        `update public.external_event_records set proposed_normalized = ${
          mask & 1 ? "'{}'::jsonb" : "null"
        },
        proposed_normalization_version = ${
          mask & 2 ? "1" : "null"
        }, proposed_hash = ${
          mask & 4 ? "'" + "a".repeat(64) + "'" : "null"
        } where id = ${id}`,
      );
    }
    await failure(
      sql,
      `update public.external_event_records set event_id = -1 where id = ${id}`,
      "23503",
    );
    await sql`update public.external_event_records set proposed_normalized = normalized,
    proposed_normalization_version = normalization_version, proposed_hash = moderation_hash where id = ${id}`;
  }));

async function submission(sql: Sql, externalId?: string) {
  const userId = crypto.randomUUID();
  await sql`insert into auth.users(id) values (${userId})`;
  const [row] = await sql`insert into public.content_submissions
    (name, city, user_id, user_name, user_email, external_event_record_id,
     external_normalized, external_normalization_version, external_moderation_hash)
    values ('Fixture event', 'Fixture city', ${userId}, 'Fixture user', 'fixture@example.test',
      ${externalId ?? null}, ${externalId ? sql.json({}) : null}, ${
    externalId ? 1 : null
  }, ${externalId ? "a".repeat(64) : null}) returning id`;
  return String(row.id);
}

Deno.test("M1 submission provenance shape, claim and RESTRICT FKs", () =>
  fixture(async (sql) => {
    const recordId = await record(sql);
    const id = await submission(sql, recordId);
    const humanId = await submission(sql);
    for (
      const [column, value] of [
        ["external_normalized", "'[]'::jsonb"],
        ["external_normalized", "'null'::jsonb"],
        ["external_normalization_version", "0"],
        ["external_moderation_hash", "'incorrect'"],
        ["external_event_record_id", "-1"],
      ]
    ) {
      await failure(
        sql,
        clonedSubmission(id, { [column]: value }),
        column === "external_event_record_id" ? "23503" : "23514",
      );
    }
    await failure(
      sql,
      `update public.content_submissions set source_asset_import_claimed_at = now() where id = ${humanId}`,
    );
    await sql`update public.content_submissions set source_asset_import_claimed_at = now() where id = ${id}`;
    await failure(
      sql,
      `delete from public.external_event_records where id = ${recordId}`,
      "23503",
    );
    await failure(
      sql,
      clonedSubmission(humanId, {
        target_event_id: "-1",
        status: "'accepted'",
      }),
      "23503",
    );
    const [event] =
      await sql`insert into public.events(name, start_date, latitude, longitude)
    values ('Target', now(), 41, 14) returning id`;
    await sql`update public.content_submissions set status = 'accepted', target_event_id = ${event.id} where id = ${humanId}`;
    await failure(
      sql,
      `delete from public.events where id = ${event.id}`,
      "23503",
    );
    await sql`update public.external_event_records set event_id = ${event.id} where id = ${recordId}`;
    await sql`update public.content_submissions set target_event_id = null where id = ${humanId}`;
    await failure(
      sql,
      `delete from public.events where id = ${event.id}`,
      "23503",
    );
  }));

Deno.test("M1 all-or-none provenance and accepted existing-Event target", () =>
  fixture(async (sql) => {
    const recordId = await record(sql);
    const humanId = await submission(sql);
    for (let mask = 1; mask < 15; mask++) {
      const tuple = [
        mask & 1 ? recordId : "null",
        mask & 2 ? "'{}'::jsonb" : "null",
        mask & 4 ? "1" : "null",
        mask & 8 ? "'" + "a".repeat(64) + "'" : "null",
      ];
      await failure(
        sql,
        `insert into public.content_submissions (name, city, user_id, user_name, user_email,
      external_event_record_id, external_normalized, external_normalization_version, external_moderation_hash)
      select name, city, user_id, user_name, user_email, ${
          tuple.join(",")
        } from public.content_submissions where id = ${humanId}`,
      );
    }
    await submission(sql, recordId);
    const [event] =
      await sql`insert into public.events(name, start_date, latitude, longitude)
    values ('Target', now(), 41, 14) returning id`;
    await failure(
      sql,
      `update public.content_submissions set target_event_id = ${event.id} where id = ${humanId}`,
    );
    await failure(
      sql,
      `update public.content_submissions set status = 'rejected', target_event_id = ${event.id} where id = ${humanId}`,
    );
    await sql`update public.content_submissions set status = 'accepted', target_event_id = ${event.id} where id = ${humanId}`;
    await failure(
      sql,
      `update public.content_submissions set promoted_event_id = ${event.id} where id = ${humanId}`,
    );
  }));

function clonedSubmission(id: string, overrides: Record<string, string>) {
  const fields = [
    "name",
    "city",
    "user_id",
    "user_name",
    "user_email",
    "status",
    "target_event_id",
    "external_event_record_id",
    "external_normalized",
    "external_normalization_version",
    "external_moderation_hash",
  ];
  return `insert into public.content_submissions (${fields.join(",")}) select ${
    fields.map((field) => overrides[field] ?? field).join(",")
  } from public.content_submissions where id = ${id}`;
}

Deno.test("M1 one external pending, with multiple final and human rows allowed", () =>
  fixture(async (sql) => {
    const recordId = await record(sql);
    const id = await submission(sql, recordId);
    await failure(sql, clonedSubmission(id, {}), "23505");
    await sql.unsafe(clonedSubmission(id, { status: "'rejected'" }));
    await sql.unsafe(clonedSubmission(id, { status: "'accepted'" }));
    const humanId = await submission(sql);
    await sql.unsafe(clonedSubmission(humanId, {}));
    const [row] =
      await sql`select count(*)::integer as count from public.content_submissions
    where external_event_record_id = ${recordId} and status = 'pending'`;
    assertEquals(row.count, 1);
  }));

Deno.test("M1 populated source provenance remains immutable under privileged Admin writes", () =>
  fixture(async (sql) => {
    const recordId = await record(sql);
    const otherRecordId = await record(sql);
    const id = await submission(sql, recordId);
    await sql`set local role service_role`;
    for (
      const assignment of [
        `external_event_record_id = ${otherRecordId}`,
        'external_normalized = \'{"name":"new"}\'::jsonb',
        "external_normalization_version = 2",
        "external_moderation_hash = '" + "b".repeat(64) + "'",
        "external_event_record_id = null, external_normalized = null, external_normalization_version = null, external_moderation_hash = null",
      ]
    ) {
      await sql`savepoint immutable`;
      const error = await assertRejects(() =>
        sql.unsafe(
          `update public.content_submissions set ${assignment} where id = ${id}`,
        )
      );
      assertEquals(
        (error as { message: string }).message,
        "external_provenance_immutable",
      );
      await sql`rollback to savepoint immutable`;
    }
    await sql`update public.content_submissions set name = 'Moderator name', external_normalized = external_normalized where id = ${id}`;
    const [row] =
      await sql`select external_event_record_id::text, external_moderation_hash, name from public.content_submissions where id = ${id}`;
    assertEquals(row.external_event_record_id, recordId);
    assertEquals(row.external_moderation_hash, "a".repeat(64));
    assertEquals(row.name, "Moderator name");
  }));

Deno.test("M1 DB-owned merge tokens cover every column, microsecond advance and no-op Save", () =>
  fixture(async (sql) => {
    const id = await submission(sql);
    await sql`update public.content_submissions set modified_at = '2099-01-01T00:00:00.123456Z' where id = ${id}`;
    for (
      const assignment of [
        "name = 'Changed name'",
        "category = 'nature'",
        "description = 'Description'",
        'description_delta = \'[{"insert":"Description\\n"}]\'::jsonb',
        "start_date = '2026-10-02T10:00:00.123456Z'",
        "end_date = '2026-10-02T11:00:00.654321Z'",
        "all_day = true",
        "city = 'Changed city'",
        "latitude = 41.5",
        "longitude = 14.5",
      ]
    ) {
      const [before] =
        await sql`select modified_at::text as token from public.content_submissions where id = ${id}`;
      await sql.unsafe(
        `update public.content_submissions set ${assignment}, modified_at = '2000-01-01Z' where id = ${id}`,
      );
      const [after] = await sql`select modified_at::text as token,
      modified_at = ${before.token}::text::timestamptz as old_token_matches,
      modified_at = ${before.token}::text::timestamptz + interval '1 microsecond' as advanced_exactly
      from public.content_submissions where id = ${id}`;
      assertEquals(after.old_token_matches, false);
      assertEquals(
        after.advanced_exactly,
        true,
        `${assignment}: ${before.token} => ${after.token}`,
      );
      const [noOp] = await sql`update public.content_submissions set
      name = name, category = category, description = description, description_delta = description_delta,
      start_date = start_date, end_date = end_date, all_day = all_day, city = city,
      latitude = latitude, longitude = longitude, modified_at = '2000-01-01Z'
      where id = ${id} returning modified_at::text as token`;
      assertEquals(noOp.token, after.token);
    }
    // A wall-clock timestamp wins when OLD is in the past, rather than now()'s transaction start.
    await sql`update public.content_submissions set modified_at = '2000-01-01Z' where id = ${id}`;
    const [clock] =
      await sql`update public.content_submissions set name = 'Clock advanced'
    where id = ${id} returning modified_at > transaction_timestamp() as after_transaction_start`;
    assertEquals(clock.after_transaction_start, true);
  }));

Deno.test("M1 imported status and every durable link require resolution context", () =>
  fixture(async (sql) => {
    const recordId = await record(sql);
    const id = await submission(sql, recordId);
    await sql`set local role service_role`;
    for (
      const assignment of [
        "status = 'accepted'",
        "status = 'rejected'",
        "target_event_id = -1",
        "promoted_event_id = -1",
        "promoted_place_id = -1",
      ]
    ) {
      await sql`savepoint denied_resolution`;
      const error = await assertRejects(() =>
        sql.unsafe(
          `update public.content_submissions set ${assignment} where id = ${id}`,
        )
      );
      assertEquals((error as Error).message, "external_requires_resolution");
      await sql`rollback to savepoint denied_resolution`;
    }
    await sql`update public.content_submissions set status = status, target_event_id = target_event_id where id = ${id}`;
    // Privileged SQL can set the GUC: it proves consistency, not RPC authorization.
    await sql`savepoint local_resolution`;
    await sql`select set_config('app.external_resolution', 'on', true)`;
    await sql`update public.content_submissions set status = 'rejected' where id = ${id}`;
    await sql`update public.content_submissions set status = 'pending' where id = ${id}`;
    await sql`rollback to savepoint local_resolution`;
    const [setting] =
      await sql`select coalesce(current_setting('app.external_resolution', true), '') as value`;
    assertEquals(setting.value, "");
    // A populated final row is guarded too; reopening must not evade pending uniqueness.
    const [final] = await sql.unsafe(
      clonedSubmission(id, { status: "'accepted'" }) + " returning id",
    );
    await sql`savepoint cannot_reopen`;
    const error = await assertRejects(() =>
      sql`update public.content_submissions set status = 'pending' where id = ${final.id}`
    );
    assertEquals((error as Error).message, "external_requires_resolution");
    await sql`rollback to savepoint cannot_reopen`;
    const [row] =
      await sql`select status, target_event_id, promoted_event_id, promoted_place_id from public.content_submissions where id = ${id}`;
    assertEquals(row, {
      status: "pending",
      target_event_id: null,
      promoted_event_id: null,
      promoted_place_id: null,
    });
  }));

Deno.test("M1 resolution GUC does not survive transaction commit", async () => {
  const sql = postgres(databaseUrl!, { max: 1 });
  try {
    await sql`begin`;
    await sql`select set_config('app.external_resolution', 'on', true)`;
    await sql`commit`;
    const [setting] =
      await sql`select coalesce(current_setting('app.external_resolution', true), '') as value`;
    assertEquals(setting.value, "");
  } finally {
    await sql.end();
  }
});

Deno.test("M1 external records are client-closed through RLS and explicit ACLs", () =>
  fixture(async (sql) => {
    const recordId = await record(sql);
    const [table] =
      await sql`select relrowsecurity from pg_class where oid = 'public.external_event_records'::regclass`;
    assertEquals(table.relrowsecurity, true);
    const [policies] =
      await sql`select count(*)::integer as count from pg_policy where polrelid = 'public.external_event_records'::regclass`;
    assertEquals(policies.count, 0);
    for (const role of ["anon", "authenticated"]) {
      for (
        const privilege of [
          "SELECT",
          "INSERT",
          "UPDATE",
          "DELETE",
          "TRUNCATE",
          "REFERENCES",
          "TRIGGER",
        ]
      ) {
        const [acl] =
          await sql`select has_table_privilege(${role}, 'public.external_event_records', ${privilege}) as allowed`;
        assertEquals(acl.allowed, false);
      }
      const [sequence] =
        await sql`select has_sequence_privilege(${role}, 'public.external_event_records_id_seq', 'USAGE') as allowed`;
      assertEquals(sequence.allowed, false);
      await sql.unsafe(`set local role ${role}`);
      for (
        const statement of [
          "select * from public.external_event_records",
          `update public.external_event_records set ignored_at = now() where id = ${recordId}`,
          `delete from public.external_event_records where id = ${recordId}`,
          "insert into public.external_event_records(provider, external_id, normalized, normalization_version, moderation_hash, metadata_version) values ('test', 'denied', '{}', 1, '" +
          "a".repeat(64) + "', 1)",
          "select nextval('public.external_event_records_id_seq')",
        ]
      ) {
        await failure(sql, statement, "42501");
      }
      await sql`reset role`;
    }
    for (
      const functionName of [
        "guard_submission_external_provenance",
        "guard_submission_external_resolution",
        "maintain_submission_merge_modified_at",
      ]
    ) {
      for (const role of ["anon", "authenticated", "service_role"]) {
        const [acl] = await sql`select has_function_privilege(${role}, ${
          "private." + functionName + "()"
        }, 'EXECUTE') as allowed`;
        assertEquals(acl.allowed, false);
      }
    }
    await sql`set local role service_role`;
    const newRecord = await record(sql);
    await sql`update public.external_event_records set ignored_at = now() where id = ${newRecord}`;
    const [read] =
      await sql`select provider from public.external_event_records where id = ${newRecord}`;
    assertEquals(read.provider, "test");
    await sql`delete from public.external_event_records where id = ${newRecord}`;
  }));
