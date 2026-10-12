import { assert, assertEquals } from "jsr:@std/assert@1";
import postgres from "npm:postgres@3.4.5";

const url = Deno.env.get("SUPABASE_DB_URL") ?? "";
const parsedUrl = new URL(url);
assert(["localhost", "127.0.0.1"].includes(parsedUrl.hostname));
assertEquals(parsedUrl.port, "55432"); // Dedicated disposable historical stack.
const migration = await Deno.readTextFile(
  new URL(
    "../migrations/20261012165537_optimize_content_sync_delta_retrieval.sql",
    import.meta.url,
  ),
);

Deno.test("historical migrations upgrade repairs all tombstones exactly without touching active rows/creation metadata", async () => {
  const sql = postgres(url, { max: 1, onnotice: () => {} });
  try {
    const tables = ["cities", "events", "places", "media"];
    for (const table of tables) {
      const [legacy] =
        await sql`select pg_get_triggerdef(oid) as definition from pg_trigger where tgrelid=${`public.${table}`}::regclass and tgname='handle_modified_at'`;
      assert(legacy.definition.includes("WHEN"));
      assert(legacy.definition.includes("moddatetime"));
    }
    const [parent] =
      await sql`insert into public.events(name,start_date,latitude,longitude) values('Upgrade parent','2026-10-12',41,14) returning id`;
    for (const table of tables) {
      for (const relation of ["newer", "equal", "older", "active"]) {
        const marker = "2020-01-02T00:00:00Z";
        const deleted = relation === "active"
          ? null
          : relation === "newer"
          ? "2020-01-03T00:00:00Z"
          : relation === "equal"
          ? marker
          : "2020-01-01T00:00:00Z";
        const base = {
          created_at: "2019-01-01T00:00:00Z",
          modified_at: marker,
        };
        const values = table === "cities"
          ? { ...base, name: `Upgrade-${relation}` }
          : table === "media"
          ? {
            ...base,
            url: `https://example.test/${relation}.jpg`,
            width: 10,
            height: 10,
            event_id: parent.id,
          }
          : {
            ...base,
            name: `Upgrade-${relation}`,
            latitude: 41,
            longitude: 14,
            ...(table === "events" ? { start_date: "2026-10-12" } : {}),
          };
        const [inserted] = await sql`insert into ${sql(`public.${table}`)} ${
          sql(values)
        } returning id`;
        // Seed via the real legacy conditional trigger, proving its defect.
        if (deleted) {
          await sql`update ${
            sql(`public.${table}`)
          } set deleted_at=${deleted}::timestamptz where id=${inserted.id}`;
        }
        const [row] =
          await sql`select modified_at=${marker}::timestamptz as unchanged from ${
            sql(`public.${table}`)
          } where id=${inserted.id}`;
        assert(
          row.unchanged,
          "legacy lifecycle write must retain historical marker",
        );
      }
    }
    await sql`create temporary table original_markers(table_name text,id bigint,modified_at timestamptz,created_at timestamptz,deleted_at timestamptz)`;
    for (const table of tables) {
      await sql.unsafe(
        `insert into original_markers select '${table}',id,modified_at,created_at,deleted_at from public.${table}`,
      );
    }
    // Apply the single forward-only migration once to the actual old schema.
    await sql.begin(async (transaction) => {
      await transaction.unsafe(migration);
    });
    for (const table of tables) {
      const results = await sql.unsafe(
        `select n.modified_at = case when o.deleted_at is null then o.modified_at else greatest(o.deleted_at,o.modified_at+interval '1 microsecond') end as exact, n.created_at=o.created_at as created_preserved, o.deleted_at is null or n.modified_at>o.modified_at as newer from public.${table} n join original_markers o on o.id=n.id and o.table_name='${table}'`,
      );
      assert(results.length >= 4);
      assert(
        results.every((row) => row.exact && row.created_preserved && row.newer),
      );
      const [deletedRow] = await sql.unsafe(
        `select id,modified_at::text from public.${table} where deleted_at is not null limit 1`,
      );
      await sql.unsafe(
        `update public.${table} set deleted_at=null where id=${deletedRow.id}`,
      );
      assert(
        (await sql.unsafe(
          `select modified_at>'${deletedRow.modified_at}'::timestamptz as advanced from public.${table} where id=${deletedRow.id}`,
        ))[0].advanced,
      );
    }
  } finally {
    await sql.end();
  }
});
