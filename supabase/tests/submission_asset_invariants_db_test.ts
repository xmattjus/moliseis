import { assertEquals } from "jsr:@std/assert@1";
import postgres, { type Sql } from "npm:postgres@3.4.5";

type Asset = {
  url: string;
  width: number;
  height: number;
  mime_type: string | null;
  duration_seconds: number | null;
};

type AddOutcome = {
  outcome: string;
};

type SubmissionFixture = {
  submissionId: number;
  userId: string;
};

function localDatabaseUrl(): string {
  let value: string | undefined;
  try {
    value = Deno.env.get("SUPABASE_DB_URL");
  } catch (error) {
    throw new Error(
      "Database invariant tests require --allow-env and SUPABASE_DB_URL. Run `bash supabase/tests/run_submission_asset_invariants_db_test.sh` after `supabase start`.",
      { cause: error },
    );
  }

  if (!value) {
    throw new Error(
      "Database invariant tests require SUPABASE_DB_URL. Run `bash supabase/tests/run_submission_asset_invariants_db_test.sh` after `supabase start`.",
    );
  }

  let hostname: string;
  try {
    hostname = new URL(value).hostname;
  } catch (error) {
    throw new Error("SUPABASE_DB_URL must be a valid local PostgreSQL URL.", {
      cause: error,
    });
  }

  if (hostname !== "127.0.0.1" && hostname !== "localhost") {
    throw new Error("SUPABASE_DB_URL must target a local PostgreSQL instance.");
  }

  return value;
}

const databaseUrl = localDatabaseUrl();

function client(): Sql {
  return postgres(databaseUrl, { max: 1 });
}

async function identifySession(sql: Sql, name: string): Promise<void> {
  await sql`select set_config('application_name', ${name}, false)`;
}

async function createSubmission(sql: Sql): Promise<SubmissionFixture> {
  const userId = crypto.randomUUID();
  const email = `asset-invariants-${userId}@example.test`;
  await sql`
    insert into auth.users (id, aud, role, email)
    values (${userId}, 'authenticated', 'authenticated', ${email})
  `;
  const [submission] = await sql<{ id: number }[]>`
    insert into public.content_submissions (
      user_id,
      user_email,
      user_name,
      city,
      name
    )
    values (${userId}, ${email}, 'Asset invariants test', 'Campobasso', 'Test submission')
    returning id
  `;
  return { submissionId: submission.id, userId };
}

async function deleteFixture(
  sql: Sql,
  fixture: SubmissionFixture,
): Promise<void> {
  await sql`
    delete from public.content_submissions
    where id = ${fixture.submissionId}
  `;
  await sql`delete from auth.users where id = ${fixture.userId}`;
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

async function seedAssets(
  sql: Sql,
  submissionId: number,
  count: number,
): Promise<void> {
  for (let index = 0; index < count; index += 1) {
    const value = asset(`seed-${submissionId}-${index}`);
    await sql`
      insert into public.submissions_assets (
        content_submission_id,
        url,
        width,
        height,
        mime_type,
        duration_seconds
      )
      values (
        ${submissionId},
        ${value.url},
        ${value.width},
        ${value.height},
        ${value.mime_type},
        ${value.duration_seconds}
      )
    `;
  }
}

async function addAssets(
  sql: Sql,
  submissionId: number,
  assets: Asset[],
): Promise<AddOutcome[]> {
  return await sql<AddOutcome[]>`
    select outcome
    from public.add_submission_assets(
      ${submissionId},
      ${sql.json(assets)}
    )
  `;
}

async function deleteAsset(
  sql: Sql,
  submissionId: number,
  assetId: number,
): Promise<string> {
  const [result] = await sql<{ outcome: string }[]>`
    select public.delete_submission_asset(${submissionId}, ${assetId}) as outcome
  `;
  return result.outcome;
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

async function assetCount(sql: Sql, submissionId: number): Promise<number> {
  const [result] = await sql<{ count: number }[]>`
    select count(*)::integer as count
    from public.submissions_assets
    where content_submission_id = ${submissionId}
  `;
  return result.count;
}

Deno.test(
  "concurrent asset additions cannot create a sixth row",
  async () => {
    const setup = client();
    const first = client();
    const second = client();
    const observer = client();
    let fixture: SubmissionFixture | null = null;

    try {
      fixture = await createSubmission(setup);
      await seedAssets(setup, fixture.submissionId, 4);
      await identifySession(second, "asset-invariants-concurrent-add");

      let secondRequest: Promise<AddOutcome[]> | null = null;
      const firstResult = await first.begin(async (transaction) => {
        await transaction`
        select id
        from public.content_submissions
        where id = ${fixture!.submissionId}
        for update
      `;
        secondRequest = addAssets(second, fixture!.submissionId, [
          asset("second"),
        ]);
        await waitForLock(observer, "asset-invariants-concurrent-add");
        return await addAssets(transaction, fixture!.submissionId, [
          asset("first"),
        ]);
      });
      const secondResult = await secondRequest!;

      assertEquals(firstResult.map((result) => result.outcome), ["created"]);
      assertEquals(secondResult.map((result) => result.outcome), [
        "limit_reached",
      ]);
      assertEquals(await assetCount(setup, fixture.submissionId), 5);
    } finally {
      if (fixture) await deleteFixture(setup, fixture);
      await Promise.all([
        setup.end(),
        first.end(),
        second.end(),
        observer.end(),
      ]);
    }
  },
);

Deno.test(
  "moderation committed before add makes the add not_pending",
  async () => {
    const setup = client();
    const moderator = client();
    const adder = client();
    const observer = client();
    let fixture: SubmissionFixture | null = null;

    try {
      fixture = await createSubmission(setup);
      await identifySession(adder, "asset-invariants-moderation-add");

      let addRequest: Promise<AddOutcome[]> | null = null;
      await moderator.begin(async (transaction) => {
        await transaction`
        select id
        from public.content_submissions
        where id = ${fixture!.submissionId}
        for update
      `;
        await transaction`
        update public.content_submissions
        set status = 'accepted'
        where id = ${fixture!.submissionId}
      `;
        addRequest = addAssets(adder, fixture!.submissionId, [
          asset("racing-add"),
        ]);
        await waitForLock(observer, "asset-invariants-moderation-add");
      });
      const addResult = await addRequest!;

      assertEquals(addResult.map((result) => result.outcome), ["not_pending"]);
      assertEquals(await assetCount(setup, fixture.submissionId), 0);
    } finally {
      if (fixture) await deleteFixture(setup, fixture);
      await Promise.all([
        setup.end(),
        moderator.end(),
        adder.end(),
        observer.end(),
      ]);
    }
  },
);

Deno.test(
  "moderation committed before delete makes the delete not_pending",
  async () => {
    const setup = client();
    const moderator = client();
    const deleter = client();
    const observer = client();
    let fixture: SubmissionFixture | null = null;

    try {
      fixture = await createSubmission(setup);
      await seedAssets(setup, fixture.submissionId, 1);
      const [seededAsset] = await setup<{ id: number }[]>`
      select id
      from public.submissions_assets
      where content_submission_id = ${fixture.submissionId}
    `;
      await identifySession(deleter, "asset-invariants-moderation-delete");

      let deleteRequest: Promise<string> | null = null;
      await moderator.begin(async (transaction) => {
        await transaction`
        select id
        from public.content_submissions
        where id = ${fixture!.submissionId}
        for update
      `;
        await transaction`
        update public.content_submissions
        set status = 'rejected'
        where id = ${fixture!.submissionId}
      `;
        deleteRequest = deleteAsset(
          deleter,
          fixture!.submissionId,
          seededAsset.id,
        );
        await waitForLock(observer, "asset-invariants-moderation-delete");
      });
      const outcome = await deleteRequest!;

      assertEquals(outcome, "not_pending");
      assertEquals(await assetCount(setup, fixture.submissionId), 1);
    } finally {
      if (fixture) await deleteFixture(setup, fixture);
      await Promise.all([
        setup.end(),
        moderator.end(),
        deleter.end(),
        observer.end(),
      ]);
    }
  },
);

Deno.test(
  "wrong-parent deletion leaves the original asset association intact",
  async () => {
    const setup = client();
    let firstFixture: SubmissionFixture | null = null;
    let secondFixture: SubmissionFixture | null = null;

    try {
      firstFixture = await createSubmission(setup);
      secondFixture = await createSubmission(setup);
      await seedAssets(setup, firstFixture.submissionId, 1);
      const [assetRow] = await setup<{ id: number }[]>`
      select id
      from public.submissions_assets
      where content_submission_id = ${firstFixture.submissionId}
    `;

      const outcome = await deleteAsset(
        setup,
        secondFixture.submissionId,
        assetRow.id,
      );

      assertEquals(outcome, "asset_not_found");
      assertEquals(await assetCount(setup, firstFixture.submissionId), 1);
      assertEquals(await assetCount(setup, secondFixture.submissionId), 0);
    } finally {
      if (firstFixture) await deleteFixture(setup, firstFixture);
      if (secondFixture) await deleteFixture(setup, secondFixture);
      await setup.end();
    }
  },
);
