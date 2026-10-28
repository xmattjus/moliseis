import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import postgres, { type Sql } from "npm:postgres@3.4.5";

type Identifier = string | number;
type CreateOutcome = { outcome: string; submission_id: Identifier };
type AssetOutcome = {
  outcome: string;
  id: Identifier | null;
  url: string | null;
  width: number | null;
  height: number | null;
};
type Receipt = {
  url: string;
  width: number;
  height: number;
  mime_type: string | null;
  duration_seconds: number | null;
};

function localDatabaseUrl(): string {
  const value = Deno.env.get("SUPABASE_DB_URL");
  if (!value || !["127.0.0.1", "localhost"].includes(new URL(value).hostname)) {
    throw new Error(
      "Admin Save tests require a local SUPABASE_DB_URL; run bash supabase/tests/run_admin_save_contracts_db_test.sh after supabase start.",
    );
  }
  return value;
}
const databaseUrl = localDatabaseUrl();
const client = () => postgres(databaseUrl, { max: 1 });
const input = (name = "Original Admin fields") => ({
  category: "nature",
  city: "Campobasso",
  name,
  description: "Admin description",
  description_delta: null,
  start_date: null,
  end_date: null,
  all_day: false,
  latitude: 41.5,
  longitude: 14.5,
});
const receipt = (suffix: string): Receipt => ({
  url: `https://res.cloudinary.com/test/image/upload/admin-save-${suffix}.jpg`,
  width: 100,
  height: 80,
  mime_type: "image/jpeg",
  duration_seconds: null,
});

async function createUser(sql: Sql): Promise<string> {
  const id = crypto.randomUUID();
  await sql`
    insert into auth.users (id, aud, role, email)
    values (${id}, 'authenticated', 'authenticated', ${`admin-save-${id}@example.test`})
  `;
  return id;
}
async function cleanup(sql: Sql, userId: string): Promise<void> {
  await sql`delete from public.content_submissions where user_id = ${userId}`;
  await sql`delete from public.submission_rate_limits where user_id = ${userId}`;
  await sql`delete from auth.users where id = ${userId}`;
}
async function create(
  sql: Sql,
  userId: string,
  key: string,
  name?: string,
): Promise<CreateOutcome> {
  const [row] = await sql<CreateOutcome[]>`
    select * from public.admin_create_submission(
      ${userId}::uuid, ${key}::uuid, ${`admin-save-${userId}@example.test`},
      'Admin Save test', ${sql.json(input(name))}
    )
  `;
  return row;
}
async function add(
  sql: Sql,
  id: Identifier,
  value: Receipt,
): Promise<AssetOutcome> {
  const [row] = await sql<AssetOutcome[]>`
    select * from public.add_admin_submission_asset_once(${id}, ${
    sql.json(value)
  })
  `;
  return row;
}
async function assetCount(sql: Sql, id: Identifier): Promise<number> {
  const [row] = await sql<{ count: number }[]>`
    select count(*)::integer as count from public.submissions_assets
    where content_submission_id = ${id}
  `;
  return row.count;
}
async function withSubmission(
  run: (sql: Sql, userId: string, key: string, id: Identifier) => Promise<void>,
): Promise<void> {
  const sql = client();
  const userId = await createUser(sql);
  const key = crypto.randomUUID();
  try {
    const created = await create(sql, userId, key);
    assertEquals(created.outcome, "created");
    await run(sql, userId, key, created.submission_id);
  } finally {
    await cleanup(sql, userId);
    await sql.end();
  }
}
async function identify(sql: Sql, name: string): Promise<void> {
  await sql`
    select set_config('application_name', ${name}, false),
           set_config('statement_timeout', '10000', false)
  `;
}
async function waitForLock(observer: Sql, name: string): Promise<void> {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    const [row] = await observer<{ wait_event_type: string | null }[]>`
      select wait_event_type from pg_stat_activity where application_name = ${name}
    `;
    if (row?.wait_event_type === "Lock") return;
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  throw new Error(`Database session ${name} did not wait on its lock`);
}
async function version(sql: Sql, id: Identifier): Promise<string> {
  const [row] = await sql<{ token: string }[]>`
    select modified_at::text as token from public.content_submissions where id = ${id}
  `;
  return row.token;
}
// Mirrors the store's atomic pending/version predicate; never read-then-write.
// Force text parameter transport: postgres-js otherwise serializes a parameter
// inferred as timestamptz through JavaScript Date and loses microseconds.
async function conditionalUpdate(
  sql: Sql,
  id: Identifier,
  token: string,
  name: string,
): Promise<number> {
  const rows = await sql`
    update public.content_submissions set name = ${name}
    where id = ${id} and status = 'pending' and modified_at = ${token}::text::timestamptz
    returning id
  `;
  return rows.length;
}

Deno.test("Admin Create replay is first-write-wins, response-loss safe and quota independent", async () => {
  await withSubmission(async (sql, userId, key, id) => {
    const [before] = await sql`
      select name, modified_at::text, created_at::text, status::text
      from public.content_submissions where id = ${id}
    `;
    const replay = await create(sql, userId, key, "Changed replay fields");
    assertEquals(replay, { outcome: "replayed", submission_id: id });
    assertEquals(
      (await sql`
        select name, modified_at::text, created_at::text, status::text
        from public.content_submissions where id = ${id}
      `)[0],
      before,
    );
    assertEquals(
      (await sql`select count(*)::integer as count from public.submission_rate_limits where user_id = ${userId}`)[
        0
      ].count,
      0,
    );
    assertEquals(
      (await sql`select count(*)::integer as count from public.content_submissions where user_id = ${userId}`)[
        0
      ].count,
      1,
    );
  });
});

for (const status of ["accepted", "rejected"]) {
  Deno.test(`Admin Create and exact receipt replay preserve ${status} moderation`, async () => {
    await withSubmission(async (sql, userId, key, id) => {
      const value = receipt(`${id}-moderated`);
      const associated = await add(sql, id, value);
      await sql`update public.content_submissions set status = ${status}::public.submission_status where id = ${id}`;
      const [before] = await sql`
        select name, status::text, handled_at::text, handled_by, modified_at::text,
               status_email_state, status_email_key
        from public.content_submissions where id = ${id}
      `;
      assertEquals(
        (await create(sql, userId, key, "Do not undo moderation"))
          .submission_id,
        id,
      );
      assertEquals(await add(sql, id, value), {
        ...associated,
        outcome: "replayed",
      });
      assertEquals(
        (await sql`
          select name, status::text, handled_at::text, handled_by, modified_at::text,
                 status_email_state, status_email_key
          from public.content_submissions where id = ${id}
        `)[0],
        before,
      );
      assertEquals(
        (await add(sql, id, receipt(`${id}-new-final`))).outcome,
        "not_pending",
      );
    });
  });
}

Deno.test("Admin Create uses account-scoped UUID and rejects invalid or null keys", async () => {
  await withSubmission(async (sql, userId, key, id) => {
    const anotherUser = await createUser(sql);
    try {
      const another = await create(sql, anotherUser, key);
      assert(another.submission_id !== id);
      for (const invalid of [null, "11111111-1111-3111-8111-111111111111"]) {
        await assertRejects(() =>
          sql`
          select * from public.admin_create_submission(
            ${userId}::uuid, ${invalid}::uuid, 'test@example.test', 'Admin', ${
            sql.json(input())
          }
          )
        `
        );
      }
    } finally {
      await cleanup(sql, anotherUser);
    }
  });
});

Deno.test("same-key concurrent Admin Create waits for winner and returns its ID", async () => {
  const setup = client();
  const first = client();
  const second = client();
  const userId = await createUser(setup);
  const key = crypto.randomUUID();
  let pending: Promise<CreateOutcome> | undefined;
  try {
    await identify(second, `admin-create-${userId}`);
    const winner = await first.begin(async (tx) => {
      const result = await create(tx, userId, key, "Winner");
      pending = create(second, userId, key, "Loser");
      await waitForLock(setup, `admin-create-${userId}`);
      return result;
    });
    assertEquals(await pending, {
      outcome: "replayed",
      submission_id: winner.submission_id,
    });
    assertEquals(
      (await setup`select name from public.content_submissions where id = ${winner.submission_id}`)[
        0
      ].name,
      "Winner",
    );
  } finally {
    await pending?.catch(() => {});
    await cleanup(setup, userId);
    await Promise.all([setup.end(), first.end(), second.end()]);
  }
});

Deno.test("concurrent identical fifth receipt creates one row then replays at capacity", async () => {
  await withSubmission(async (sql, _userId, _key, id) => {
    const first = client();
    const second = client();
    const value = receipt(`${id}-fifth`);
    let pending: Promise<AssetOutcome> | undefined;
    try {
      for (let n = 0; n < 4; n++) {
        await add(sql, id, receipt(`${id}-seed-${n}`));
      }
      await identify(second, `admin-receipt-${id}`);
      const winner = await first.begin(async (tx) => {
        const result = await add(tx, id, value);
        pending = add(second, id, value);
        await waitForLock(sql, `admin-receipt-${id}`);
        return result;
      });
      assertEquals(winner.outcome, "created");
      assertEquals(await pending, { ...winner, outcome: "replayed" });
      assertEquals(await assetCount(sql, id), 5);
      assertEquals(
        (await add(sql, id, receipt(`${id}-sixth`))).outcome,
        "limit_reached",
      );
    } finally {
      await pending?.catch(() => {});
      await Promise.all([first.end(), second.end()]);
    }
  });
});

Deno.test("Admin receipt replay is null-safe, rejects metadata conflict and retains legacy duplicates", async () => {
  await withSubmission(async (sql, _userId, _key, id) => {
    const value = { ...receipt(`${id}-nullable`), mime_type: null };
    const first = await add(sql, id, value);
    const [duplicate] = await sql<AssetOutcome[]>`
      select * from public.add_submission_assets(${id}, ${sql.json([value])})
    `;
    assert(duplicate.id !== first.id);
    assertEquals(await add(sql, id, value), { ...first, outcome: "replayed" });
    assertEquals(
      (await add(sql, id, { ...value, width: 101 })).outcome,
      "metadata_conflict",
    );
    assertEquals(await assetCount(sql, id), 2);
  });
});

Deno.test("legacy batch and Admin singleton share concurrent final-slot enforcement", async () => {
  await withSubmission(async (sql, _userId, _key, id) => {
    const first = client();
    const second = client();
    let pending: Promise<AssetOutcome[]> | undefined;
    try {
      for (let n = 0; n < 4; n++) await add(sql, id, receipt(`${id}-cap-${n}`));
      await identify(second, `admin-legacy-cap-${id}`);
      const winner = await first.begin(async (tx) => {
        const result = await add(tx, id, receipt(`${id}-admin-winner`));
        pending = (async () =>
          await second<AssetOutcome[]>`
            select * from public.add_submission_assets(${id}, ${
            sql.json([receipt(`${id}-legacy-loser`)])
          })
          `)();
        await waitForLock(sql, `admin-legacy-cap-${id}`);
        return result;
      });
      assertEquals(winner.outcome, "created");
      assertEquals((await pending!)[0].outcome, "limit_reached");
      assertEquals(await assetCount(sql, id), 5);
    } finally {
      await pending?.catch(() => {});
      await Promise.all([first.end(), second.end()]);
    }
  });
});

Deno.test("delete and replay serialize and explicit reassociation creates a new pending row", async () => {
  await withSubmission(async (sql, _userId, _key, id) => {
    const first = client();
    const second = client();
    const value = receipt(`${id}-delete`);
    const original = await add(sql, id, value);
    let pending: Promise<AssetOutcome> | undefined;
    try {
      await identify(second, `admin-delete-${id}`);
      await first.begin(async (tx) => {
        await tx`select public.delete_submission_asset(${id}, ${original.id!})`;
        pending = add(second, id, value);
        await waitForLock(sql, `admin-delete-${id}`);
      });
      const recreated = await pending!;
      assertEquals(recreated.outcome, "created");
      assert(recreated.id !== original.id);
      assertEquals(await assetCount(sql, id), 1);
    } finally {
      await pending?.catch(() => {});
      await Promise.all([first.end(), second.end()]);
    }
  });
});

Deno.test("Admin RPC grants deny public/anon/authenticated and allow service_role", async () => {
  const sql = client();
  try {
    for (
      const signature of [
        "public.admin_create_submission(uuid,uuid,text,text,jsonb)",
        "public.add_admin_submission_asset_once(bigint,jsonb)",
      ]
    ) {
      for (const role of ["anon", "authenticated"]) {
        const [row] = await sql<{ allowed: boolean }[]>`
          select has_function_privilege(${role}, ${signature}, 'execute') as allowed
        `;
        assertEquals(row.allowed, false);
      }
      const [service] = await sql<{ allowed: boolean }[]>`
        select has_function_privilege('service_role', ${signature}, 'execute') as allowed
      `;
      assertEquals(service.allowed, true);
      const [acl] = await sql<{ public_allowed: boolean }[]>`
        select exists(select 1 from aclexplode(coalesce(proacl, acldefault('f', proowner)))
          where grantee = 0 and privilege_type = 'EXECUTE') as public_allowed
        from pg_proc where oid = ${signature}::regprocedure
      `;
      assertEquals(acl.public_allowed, false);
    }
    await withSubmission(async (owner, userId, key, id) => {
      await assertRejects(() =>
        sql.begin(async (tx) => {
          await tx`set local role authenticated`;
          await create(tx, userId, key);
        })
      );
      await assertRejects(() =>
        sql.begin(async (tx) => {
          await tx`set local role anon`;
          await add(tx, id, receipt(`${id}-denied`));
        })
      );
      assertEquals(await assetCount(owner, id), 0);
    });
  } finally {
    await sql.end();
  }
});

Deno.test("exact microsecond token advances only for changed fields and fences stale writes", async () => {
  await withSubmission(async (sql, _userId, _key, id) => {
    await sql`update public.content_submissions set modified_at = '2026-10-01 00:00:00.123456+00' where id = ${id}`;
    const before = await version(sql, id);
    assert(before.includes(".123456"));
    assertEquals(
      await conditionalUpdate(sql, id, before, "Original Admin fields"),
      1,
    );
    assertEquals(await version(sql, id), before);
    assertEquals(await conditionalUpdate(sql, id, before, "New B"), 1);
    const after = await version(sql, id);
    assert(after !== before);
    assertEquals(await conditionalUpdate(sql, id, before, "Stale A"), 0);
    assertEquals(
      (await sql`select name from public.content_submissions where id = ${id}`)[
        0
      ].name,
      "New B",
    );
    await sql`update public.content_submissions set status = 'rejected' where id = ${id}`;
    assertEquals(await conditionalUpdate(sql, id, after, "Not pending"), 0);
  });
});

for (const oldIsNoOp of [false, true]) {
  Deno.test(`outstanding process-era ${oldIsNoOp ? "no-op" : "changed"} A cannot overwrite committed B`, async () => {
    await withSubmission(async (sql, _userId, _key, id) => {
      const first = client();
      const second = client();
      let pending: Promise<number> | undefined;
      try {
        const token = await version(sql, id);
        await identify(second, `admin-update-${id}`);
        await first.begin(async (tx) => {
          await tx`select id from public.content_submissions where id = ${id} for update`;
          pending = conditionalUpdate(
            second,
            id,
            token,
            oldIsNoOp ? "Original Admin fields" : "Old A",
          );
          await waitForLock(sql, `admin-update-${id}`);
          assertEquals(await conditionalUpdate(tx, id, token, "New B"), 1);
        });
        assertEquals(await pending, 0);
        assertEquals(
          (await sql`select name from public.content_submissions where id = ${id}`)[
            0
          ].name,
          "New B",
        );
      } finally {
        await pending?.catch(() => {});
        await Promise.all([first.end(), second.end()]);
      }
    });
  });
}

for (const oldIsNoOp of [false, true]) {
  Deno.test(`first process-era ${oldIsNoOp ? "no-op" : "changed"} A gives later B only compatible authority`, async () => {
    await withSubmission(async (sql, _userId, _key, id) => {
      const first = client();
      const second = client();
      let pending: Promise<number> | undefined;
      try {
        const token = await version(sql, id);
        await identify(second, `admin-update-first-${id}`);
        await first.begin(async (tx) => {
          await tx`select id from public.content_submissions where id = ${id} for update`;
          pending = conditionalUpdate(second, id, token, "New B");
          await waitForLock(sql, `admin-update-first-${id}`);
          assertEquals(
            await conditionalUpdate(
              tx,
              id,
              token,
              oldIsNoOp ? "Original Admin fields" : "Old A",
            ),
            1,
          );
        });
        assertEquals(await pending, oldIsNoOp ? 1 : 0);
        assertEquals(
          (await sql`select name from public.content_submissions where id = ${id}`)[
            0
          ].name,
          oldIsNoOp ? "New B" : "Old A",
        );
      } finally {
        await pending?.catch(() => {});
        await Promise.all([first.end(), second.end()]);
      }
    });
  });
}

for (const winner of ["original", "explicit retry"]) {
  Deno.test(`unchanged V permits captured A/V retry when ${winner} commits first`, async () => {
    await withSubmission(async (sql, _userId, _key, id) => {
      const first = client();
      const second = client();
      let pending: Promise<number> | undefined;
      try {
        // A restored intent exists in the client, but observing V does not
        // establish whether its original HTTP request is still outstanding.
        const token = await version(sql, id);
        assertEquals(
          (await sql`select name from public.content_submissions where id = ${id}`)[
            0
          ].name,
          "Original Admin fields",
        );
        const waiting = winner === "original" ? "retry" : "original";
        await identify(second, `admin-same-a-${waiting}-${id}`);
        await first.begin(async (tx) => {
          await tx`select id from public.content_submissions where id = ${id} for update`;
          pending = conditionalUpdate(second, id, token, "Captured A");
          await waitForLock(sql, `admin-same-a-${waiting}-${id}`);
          assertEquals(await conditionalUpdate(tx, id, token, "Captured A"), 1);
        });
        assertEquals(await pending, 0);
        const observedToken = await version(sql, id);
        assert(observedToken !== token);
        assertEquals(
          (await sql`select name from public.content_submissions where id = ${id}`)[
            0
          ].name,
          "Captured A",
        );
        // Read-back can confirm observed A, with the actual new token, rather
        // than guessing which request won. Later B still fences every old A/V.
        assertEquals(
          await conditionalUpdate(sql, id, observedToken, "New B"),
          1,
        );
        assertEquals(
          await conditionalUpdate(second, id, token, "Captured A"),
          0,
        );
        assertEquals(
          (await sql`select name from public.content_submissions where id = ${id}`)[
            0
          ].name,
          "New B",
        );
      } finally {
        await pending?.catch(() => {});
        await Promise.all([first.end(), second.end()]);
      }
    });
  });
}

Deno.test("Admin receipt rejects malformed requests and missing parent without inserting", async () => {
  await withSubmission(async (sql, _userId, _key, id) => {
    for (
      const malformed of [null, [], {}, {
        ...receipt(`${id}-invalid`),
        width: 0,
      }]
    ) {
      await assertRejects(() =>
        sql`
        select * from public.add_admin_submission_asset_once(${id}, ${
          sql.json(malformed)
        })
      `
      );
    }
    assertEquals(
      (await add(sql, -1, receipt("absent-parent"))).outcome,
      "not_found",
    );
    assertEquals(await assetCount(sql, id), 0);
  });
});
