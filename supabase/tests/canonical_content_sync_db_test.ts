import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import postgres, { type Sql } from "npm:postgres@3.4.5";

const url = Deno.env.get("SUPABASE_DB_URL") ?? "";
assert(["localhost", "127.0.0.1"].includes(new URL(url).hostname));
const tables = ["cities", "events", "places", "media"] as const;
const rolledBack = new Error("fixture rollback");

async function fixture(run: (sql: Sql) => Promise<void>) {
  const sql = postgres(url, { max: 1, onnotice: () => {} });
  try {
    await sql.begin(async (transaction) => {
      await run(transaction as unknown as Sql);
      throw rolledBack;
    });
  } catch (error) {
    if (error !== rolledBack) throw error;
  } finally {
    await sql.end();
  }
}

async function seed(sql: Sql) {
  const [city] =
    await sql`insert into public.cities(name) values(${crypto.randomUUID()}) returning id`;
  const [place] =
    await sql`insert into public.places(name,latitude,longitude) values('Sync place',41,14) returning id`;
  const [place2] =
    await sql`insert into public.places(name,latitude,longitude) values('Other sync place',41,14) returning id`;
  const [event] =
    await sql`insert into public.events(name,start_date,latitude,longitude) values('Sync event','2026-10-12',41,14) returning id`;
  const [event2] =
    await sql`insert into public.events(name,start_date,latitude,longitude) values('Other sync event','2026-10-12',41,14) returning id`;
  const [media] =
    await sql`insert into public.media(url,width,height,event_id) values('https://example.test/sync.jpg',100,100,${event.id}) returning id`;
  return { city, place, place2, event, event2, media };
}

for (const table of tables) {
  Deno.test(`${table}: every semantic field/lifecycle advances; no-op and metadata do not`, () =>
    fixture(async (sql) => {
      const rows = await seed(sql);
      const id = rows[
        table === "cities"
          ? "city"
          : table === "places"
          ? "place"
          : table === "events"
          ? "event"
          : "media"
      ].id;
      const changes: string[] = table === "cities"
        ? [
          "name = name || '-changed'",
          "description_delta = '[]'::jsonb",
          "description_delta = null",
        ]
        : table === "media"
        ? [
          "url = 'https://example.test/changed.jpg'",
          "description = 'Changed'",
          "description = null",
          "author = 'Author'",
          "author = null",
          "license = 'CC0'",
          "license = null",
          "license_url = 'https://example.test/license'",
          "license_url = null",
          "width = width + 1",
          "height = height + 1",
          `event_id = ${rows.event2.id}`,
          `event_id = null, place_id = ${rows.place.id}`,
          `place_id = ${rows.place2.id}`,
        ]
        : [
          "name = name || '-changed'",
          "description = 'Changed'",
          "description = null",
          "description_delta = '[]'::jsonb",
          "description_delta = null",
          "latitude = latitude + 1",
          "longitude = longitude + 1",
          `city_id = ${rows.city.id}`,
          "city_id = null",
          "category = 'nature'",
          ...(table === "events"
            ? [
              "start_date = start_date + interval '1 hour'",
              "end_date = start_date + interval '1 hour'",
              "end_date = null",
              "all_day = not all_day",
            ]
            : []),
        ];
      changes.push(
        "deleted_at = '2026-10-12'::timestamptz",
        "deleted_at = '2026-10-13'::timestamptz",
        "deleted_at = null",
      );
      for (const change of changes) {
        const [before] = await sql.unsafe(
          `select modified_at::text, created_at::text from public.${table} where id = ${id}`,
        );
        await sql.unsafe(
          `update public.${table} set ${change}, modified_at = '1900-01-01' where id = ${id}`,
        );
        const [after] = await sql.unsafe(
          `select modified_at > '${before.modified_at}'::timestamptz as advanced, created_at::text from public.${table} where id = ${id}`,
        );
        assert(after.advanced, `${table}.${change} must advance`);
        assertEquals(after.created_at, before.created_at);
      }
      for (
        const change of [
          table === "media" ? "url = url" : "name = name",
          "modified_at = '2999-01-01'",
          "created_at = created_at + interval '1 day'",
          "deleted_at = deleted_at",
        ]
      ) {
        const [before] = await sql.unsafe(
          `select modified_at::text from public.${table} where id = ${id}`,
        );
        await sql.unsafe(
          `update public.${table} set ${change} where id = ${id}`,
        );
        assertEquals(
          (await sql.unsafe(
            `select modified_at::text from public.${table} where id = ${id}`,
          ))[0].modified_at,
          before.modified_at,
        );
      }
    }));

  Deno.test(`${table}: future INSERT marker yields strictly increasing immediate mutations`, () =>
    fixture(async (sql) => {
      const rows = await seed(sql);
      let inserted;
      if (table === "cities") {
        inserted =
          await sql`insert into public.cities(name,modified_at) values(${crypto.randomUUID()},'2999-01-01') returning id`;
      } else if (table === "events") {
        inserted =
          await sql`insert into public.events(name,start_date,latitude,longitude,modified_at) values('Future','2026-10-12',41,14,'2999-01-01') returning id`;
      } else if (table === "places") {
        inserted =
          await sql`insert into public.places(name,latitude,longitude,modified_at) values('Future',41,14,'2999-01-01') returning id`;
      } else {inserted =
          await sql`insert into public.media(url,width,height,event_id,modified_at) values('https://example.test/future.jpg',10,10,${rows.event.id},'2999-01-01') returning id`;}
      const field = table === "media" ? "description" : "name";
      for (const offset of [1, 2]) {
        const [row] = await sql.unsafe(
          `update public.${table} set ${field} = 'Mutation ${offset}' where id = ${
            inserted[0].id
          } returning modified_at = '2999-01-01'::timestamptz + interval '${offset} microsecond' as exact`,
        );
        assert(row.exact);
      }
    }));
}

Deno.test("canonical catalogs preserve defaults/comments/index shape and least-privileged RPC", () =>
  fixture(async (sql) => {
    for (const table of tables) {
      const columns =
        await sql`select a.attname, pg_get_expr(d.adbin,d.adrelid) as default_value, col_description(a.attrelid,a.attnum) as comment from pg_attribute a left join pg_attrdef d on d.adrelid=a.attrelid and d.adnum=a.attnum where a.attrelid=${`public.${table}`}::regclass and a.attname in ('modified_at','created_at')`;
      assertEquals(
        columns.find((row) => row.attname === "modified_at")!.default_value,
        "clock_timestamp()",
      );
      assertEquals(
        columns.find((row) => row.attname === "created_at")!.default_value,
        "now()",
      );
      const comment = columns.find((row) =>
        row.attname === "modified_at"
      )!.comment;
      assert(comment.includes("last semantically relevant change"));
      assert(comment.includes("table-specific"));
      assert(comment.includes("every SQL UPDATE"));
      assert(comment.includes("deleted_at lifecycle"));
      const [index] =
        await sql`select i.indnkeyatts, i.indpred is null as whole_table, am.amname, a.attname from pg_index i join pg_class c on c.oid=i.indexrelid join pg_am am on am.oid=c.relam join pg_attribute a on a.attrelid=i.indrelid and a.attnum=i.indkey[0] where c.oid=${`public.${table}_modified_at_idx`}::regclass`;
      assertEquals(index, {
        indnkeyatts: 1,
        whole_table: true,
        amname: "btree",
        attname: "modified_at",
      });
      const [trigger] =
        await sql`select t.tgtype, t.tgqual is null as unconditional, p.prosecdef, p.proconfig from pg_trigger t join pg_proc p on p.oid=t.tgfoid where t.tgrelid=${`public.${table}`}::regclass and t.tgname='handle_modified_at'`;
      assertEquals(trigger.tgtype, 19); // ROW | BEFORE | UPDATE
      assert(trigger.unconditional);
      assertEquals(trigger.prosecdef, false);
      assertEquals(trigger.proconfig, ['search_path=""']);
      const grants =
        await sql`select has_function_privilege(r,${`private.set_${table}_modified_at()`},'execute') as allowed from unnest(array['anon','authenticated','service_role']) r`;
      assert(grants.every((row) => !row.allowed));
    }
    const [rpc] =
      await sql`select p.pronargs, p.provolatile,p.prosecdef,p.proconfig,l.lanname,pg_get_function_result(p.oid) as result from pg_proc p join pg_language l on l.oid=p.prolang where p.oid='public.get_content_sync_cursor()'::regprocedure`;
    assertEquals(rpc, {
      pronargs: 0,
      provolatile: "v",
      prosecdef: false,
      proconfig: ['search_path=""'],
      lanname: "sql",
      result: "timestamp with time zone",
    });
    const [publicGrant] =
      await sql`select count(*)::int as count from pg_proc p cross join lateral aclexplode(p.proacl) a where p.oid='public.get_content_sync_cursor()'::regprocedure and a.grantee=0 and a.privilege_type='EXECUTE'`;
    assertEquals(publicGrant.count, 0);
    assertEquals(
      (await sql`select has_function_privilege('service_role','public.get_content_sync_cursor()','execute') as allowed`)[
        0
      ].allowed,
      false,
    );
    for (const role of ["anon", "authenticated"]) {
      await sql.unsafe(`set local role ${role}`);
      assert(
        (await sql`select public.get_content_sync_cursor() between clock_timestamp()-interval '1 minute' and clock_timestamp()+interval '1 minute' as valid`)[
          0
        ].valid,
      );
      await sql`reset role`;
    }
    await sql`savepoint denied_rpc`;
    await sql`set local role service_role`;
    await assertRejects(() => sql`select public.get_content_sync_cursor()`);
    await sql`rollback to savepoint denied_rpc`;
    await sql`reset role`;
  }));

Deno.test("INSERT wall-clock defaults and old full-row reads preserve tombstone visibility for both client roles", () =>
  fixture(async (sql) => {
    const [before] = await sql`select clock_timestamp()::text as timestamp`;
    const rows = await seed(sql);
    const [after] = await sql`select clock_timestamp()::text as timestamp`;
    const ids = {
      cities: rows.city.id,
      places: rows.place.id,
      events: rows.event.id,
      media: rows.media.id,
    };
    const keys = {
      cities: [
        "id",
        "name",
        "description_delta",
        "created_at",
        "modified_at",
        "deleted_at",
      ],
      events: [
        "id",
        "name",
        "description",
        "description_delta",
        "start_date",
        "end_date",
        "all_day",
        "latitude",
        "longitude",
        "city_id",
        "category",
        "created_at",
        "modified_at",
        "deleted_at",
      ],
      places: [
        "id",
        "name",
        "description",
        "description_delta",
        "latitude",
        "longitude",
        "city_id",
        "category",
        "created_at",
        "modified_at",
        "deleted_at",
      ],
      media: [
        "id",
        "url",
        "description",
        "author",
        "license",
        "license_url",
        "width",
        "height",
        "event_id",
        "place_id",
        "created_at",
        "modified_at",
        "deleted_at",
      ],
    };
    for (const table of tables) {
      const [inserted] =
        await sql`select modified_at between ${before.timestamp}::timestamptz and ${after.timestamp}::timestamptz as live_default, created_at=transaction_timestamp() as transaction_creation from ${
          sql(`public.${table}`)
        } where id=${ids[table]}`;
      assert(inserted.live_default);
      assert(inserted.transaction_creation);
      await sql`update ${
        sql(`public.${table}`)
      } set deleted_at='2026-10-12' where id=${ids[table]}`;
    }
    for (const role of ["anon", "authenticated"]) {
      await sql.unsafe(`set local role ${role}`);
      for (const table of tables) {
        // SELECT * is the installed full-sync client's unchanged wire contract.
        const [wire] = await sql`select to_jsonb(t) as row from ${
          sql(`public.${table}`)
        } t where id=${ids[table]}`;
        assertEquals(Object.keys(wire.row).sort(), keys[table].sort());
        assert(typeof wire.row.created_at === "string");
        assert(typeof wire.row.modified_at === "string");
        assert(typeof wire.row.deleted_at === "string");
        const denied = await sql`update ${
          sql(`public.${table}`)
        } set deleted_at=null where id=${ids[table]} returning id`;
        assertEquals(denied.length, 0); // Existing write-denying RLS is unchanged.
      }
      await sql`reset role`;
    }
  }));
