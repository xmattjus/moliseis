import { assertEquals } from "jsr:@std/assert@1";
import postgres, { type Sql } from "npm:postgres@3.4.5";

type SubmissionStatus = "pending" | "accepted" | "rejected";

type Json = string | number | boolean | null | Json[] | { [key: string]: Json };

/**
 * PostgreSQL bigint values as delivered across the postgres.js boundary.
 * The driver returns decimal strings by default to avoid precision loss;
 * driver configurations that parse bigint to number must keep working too,
 * so both shapes are accepted wherever ids flow through the driver.
 */
type DbBigint = string | number;

type Category =
  | "unknown"
  | "nature"
  | "history"
  | "folklore"
  | "food"
  | "allure"
  | "experience";

type SubmissionFixture = {
  submissionId: DbBigint;
  userId: string;
};

type SubmissionOverrides = {
  status?: SubmissionStatus;
  name?: string;
  city?: string;
  description?: string | null;
  descriptionDelta?: Json;
  latitude?: number | null;
  longitude?: number | null;
  address?: string | null;
  startDate?: Date | null;
  endDate?: Date | null;
  category?: Category;
  createdAt?: Date;
  modifiedAt?: Date;
};

type PromotionOutcome = {
  outcome: string;
  target_type: string | null;
  entity_id: DbBigint | null;
};

type FixtureRegistry = {
  submissionIds: DbBigint[];
  placeIds: DbBigint[];
  eventIds: DbBigint[];
  cityIds: DbBigint[];
  userIds: string[];
};

function newRegistry(): FixtureRegistry {
  return {
    submissionIds: [],
    placeIds: [],
    eventIds: [],
    cityIds: [],
    userIds: [],
  };
}

function localDatabaseUrl(): string {
  let value: string | undefined;
  try {
    value = Deno.env.get("SUPABASE_DB_URL");
  } catch (error) {
    throw new Error(
      "Database promotion tests require --allow-env and SUPABASE_DB_URL. Run `bash supabase/tests/run_submission_promotion_db_test.sh` after `supabase start`.",
      { cause: error },
    );
  }

  if (!value) {
    throw new Error(
      "Database promotion tests require SUPABASE_DB_URL. Run `bash supabase/tests/run_submission_promotion_db_test.sh` after `supabase start`.",
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

const racingStatementTimeoutMs = 10_000;

async function prepareRacingSession(sql: Sql, name: string): Promise<void> {
  await sql`
    select set_config('application_name', ${name}, false),
           set_config(
             'statement_timeout',
             ${String(racingStatementTimeoutMs)},
             false
           )
  `;
}

async function createCity(
  sql: Sql,
  registry: FixtureRegistry,
  options: { deletedAt?: Date } = {},
): Promise<{ id: DbBigint; name: string }> {
  const name = `Promotion test city ${crypto.randomUUID()}`;
  const [city] = await sql<{ id: DbBigint }[]>`
    insert into public.cities (name, deleted_at)
    values (${name}, ${options.deletedAt ?? null})
    returning id
  `;
  registry.cityIds.push(city.id);
  return { id: city.id, name };
}

async function createPlace(
  sql: Sql,
  registry: FixtureRegistry,
): Promise<DbBigint> {
  const [place] = await sql<{ id: DbBigint }[]>`
    insert into public.places (name, latitude, longitude)
    values (${"Link integrity place"}::text, 41.5629::double precision, 14.6697::double precision)
    returning id
  `;
  registry.placeIds.push(place.id);
  return place.id;
}

async function createEvent(
  sql: Sql,
  registry: FixtureRegistry,
): Promise<DbBigint> {
  const [event] = await sql<{ id: DbBigint }[]>`
    insert into public.events (
      name, start_date, latitude, longitude
    )
    values (
      ${"Link integrity event"}::text,
      ${new Date("2026-09-01T10:00:00.000Z")},
      41.5629::double precision,
      14.6697::double precision
    )
    returning id
  `;
  registry.eventIds.push(event.id);
  return event.id;
}

async function createSubmission(
  sql: Sql,
  registry: FixtureRegistry,
  overrides: SubmissionOverrides = {},
): Promise<SubmissionFixture> {
  const userId = crypto.randomUUID();
  const email = `submission-promotion-${userId}@example.test`;
  await sql`
    insert into auth.users (id, aud, role, email)
    values (${userId}, 'authenticated', 'authenticated', ${email})
  `;
  registry.userIds.push(userId);

  const deltaParameter = overrides.descriptionDelta == null
    ? null
    : sql.json(overrides.descriptionDelta);

  const [submission] = await sql<{ id: DbBigint }[]>`
    insert into public.content_submissions (
      user_id,
      user_email,
      user_name,
      city,
      name,
      description,
      description_delta,
      latitude,
      longitude,
      address,
      start_date,
      end_date,
      category,
      status,
      created_at,
      modified_at
    )
    values (
      ${userId},
      ${email},
      'Submission promotion test',
      ${overrides.city ?? "Unknowable City"},
      ${overrides.name ?? "Test submission"},
      ${overrides.description ?? null},
      ${deltaParameter},
      ${overrides.latitude ?? null},
      ${overrides.longitude ?? null},
      ${overrides.address ?? null},
      ${overrides.startDate ?? null},
      ${overrides.endDate ?? null},
      ${overrides.category ?? "unknown"}::public.content_category,
      ${overrides.status ?? "pending"}::public.submission_status,
      ${overrides.createdAt ?? new Date("2026-08-01T09:00:00.000Z")},
      ${overrides.modifiedAt ?? new Date("2026-08-01T09:00:00.000Z")}
    )
    returning id
  `;
  registry.submissionIds.push(submission.id);
  return { submissionId: submission.id, userId };
}

async function promote(
  sql: Sql,
  submissionId: DbBigint,
  target: string | null,
  handledBy: string | null,
): Promise<PromotionOutcome> {
  const [outcome] = await sql<PromotionOutcome[]>`
    select outcome, target_type, entity_id
    from public.promote_content_submission(
      ${submissionId},
      ${target},
      ${handledBy}
    )
  `;
  return outcome;
}

const handledByUser = "11111111-1111-4111-8111-111111111111";

async function assertPostgresError(
  run: () => Promise<unknown>,
  expectedCode: string,
): Promise<void> {
  try {
    await run();
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (code !== expectedCode) {
      throw new Error(
        `Expected PostgreSQL error ${expectedCode} but received ${
          code ?? String(error)
        }`,
        { cause: error },
      );
    }
    return;
  }
  throw new Error(
    `Expected PostgreSQL error ${expectedCode}, but the statement succeeded`,
  );
}

async function deleteFixtures(
  sql: Sql,
  registry: FixtureRegistry,
): Promise<void> {
  // Strict order imposed by the RESTRICT promotion links: submissions first
  // (releasing links, cascading source assets), then published targets
  // (cascading media), then cities, then auth users.
  if (registry.submissionIds.length > 0) {
    await sql`
      delete from public.content_submissions
      where id = any(${registry.submissionIds})
    `;
  }
  if (registry.placeIds.length > 0) {
    await sql`
      delete from public.places
      where id = any(${registry.placeIds})
    `;
  }
  if (registry.eventIds.length > 0) {
    await sql`
      delete from public.events
      where id = any(${registry.eventIds})
    `;
  }
  if (registry.cityIds.length > 0) {
    await sql`
      delete from public.cities
      where id = any(${registry.cityIds})
    `;
  }
  if (registry.userIds.length > 0) {
    await sql`
      delete from auth.users
      where id = any(${registry.userIds})
    `;
  }
}

/**
 * Runs a single-client fixture scenario without allowing teardown to replace
 * its primary failure or fixture deletion to skip client closure.
 */
async function runFixtureScenario(
  body: () => Promise<void>,
  sql: Sql,
  registry: FixtureRegistry,
): Promise<void> {
  let bodyFailed = false;
  let bodyError: unknown;
  const cleanupErrors: unknown[] = [];

  try {
    await body();
  } catch (error) {
    bodyFailed = true;
    bodyError = error;
  }

  try {
    await deleteFixtures(sql, registry);
  } catch (error) {
    cleanupErrors.push(new Error("Fixture deletion failed", { cause: error }));
  } finally {
    const [closure] = await Promise.allSettled([
      Promise.resolve().then(() => sql.end()),
    ]);
    if (closure.status === "rejected") {
      cleanupErrors.push(
        new Error("Failed to close fixture client", { cause: closure.reason }),
      );
    }
  }

  const failures = bodyFailed ? [bodyError, ...cleanupErrors] : cleanupErrors;
  if (failures.length === 1) {
    throw failures[0];
  }
  if (failures.length > 1) {
    throw new AggregateError(
      failures,
      "Fixture scenario and/or teardown failed",
    );
  }
}

Deno.test(
  "legacy accepted submissions survive with both promotion links null",
  async () => {
    const setup = client();
    const registry = newRegistry();

    await runFixtureScenario(
      async () => {
        const fixture = await createSubmission(setup, registry, {
          status: "accepted",
        });

        const [row] = await setup<{ status: string }[]>`
        select status::text as status
        from public.content_submissions
        where id = ${fixture.submissionId}
      `;

        assertEquals(row.status, "accepted");
      },
      setup,
      registry,
    );
  },
);

Deno.test(
  "setting both promoted target links violates the single-target check",
  async () => {
    const setup = client();
    const registry = newRegistry();

    await runFixtureScenario(
      async () => {
        const fixture = await createSubmission(setup, registry, {
          status: "accepted",
        });
        const placeId = await createPlace(setup, registry);
        const eventId = await createEvent(setup, registry);

        await assertPostgresError(
          () =>
            setup`
            update public.content_submissions
            set promoted_place_id = ${placeId},
                promoted_event_id = ${eventId}
            where id = ${fixture.submissionId}
          `,
          "23514",
        );
      },
      setup,
      registry,
    );
  },
);

Deno.test(
  "linking a promotion target while not accepted violates the check",
  async () => {
    const setup = client();
    const registry = newRegistry();

    await runFixtureScenario(
      async () => {
        const pendingFixture = await createSubmission(setup, registry, {
          status: "pending",
        });
        const rejectedFixture = await createSubmission(setup, registry, {
          status: "rejected",
        });
        const placeId = await createPlace(setup, registry);

        await assertPostgresError(
          () =>
            setup`
            update public.content_submissions
            set promoted_place_id = ${placeId}
            where id = ${pendingFixture.submissionId}
          `,
          "23514",
        );

        await assertPostgresError(
          () =>
            setup`
            update public.content_submissions
            set promoted_place_id = ${placeId}
            where id = ${rejectedFixture.submissionId}
          `,
          "23514",
        );
      },
      setup,
      registry,
    );
  },
);

Deno.test(
  "the same published entity cannot be linked from two submissions",
  async () => {
    const setup = client();
    const registry = newRegistry();

    await runFixtureScenario(
      async () => {
        const first = await createSubmission(setup, registry, {
          status: "accepted",
        });
        const second = await createSubmission(setup, registry, {
          status: "accepted",
        });
        const placeId = await createPlace(setup, registry);

        await setup`
        update public.content_submissions
        set promoted_place_id = ${placeId}
        where id = ${first.submissionId}
      `;

        await assertPostgresError(
          () =>
            setup`
            update public.content_submissions
            set promoted_place_id = ${placeId}
            where id = ${second.submissionId}
          `,
          "23505",
        );
      },
      setup,
      registry,
    );
  },
);

Deno.test(
  "physical deletion of a linked promotion target is restricted",
  async () => {
    const setup = client();
    const registry = newRegistry();

    await runFixtureScenario(
      async () => {
        const placeSource = await createSubmission(setup, registry, {
          status: "accepted",
        });
        const placeId = await createPlace(setup, registry);
        await setup`
        update public.content_submissions
        set promoted_place_id = ${placeId}
        where id = ${placeSource.submissionId}
      `;

        const eventSource = await createSubmission(setup, registry, {
          status: "accepted",
        });
        const eventId = await createEvent(setup, registry);
        await setup`
        update public.content_submissions
        set promoted_event_id = ${eventId}
        where id = ${eventSource.submissionId}
      `;

        await assertPostgresError(
          () => setup`delete from public.places where id = ${placeId}`,
          "23503",
        );
        await assertPostgresError(
          () => setup`delete from public.events where id = ${eventId}`,
          "23503",
        );
      },
      setup,
      registry,
    );
  },
);

// ---------------------------------------------------------------------------
// Success-path helpers (function declarations are hoisted module-wide).
// ---------------------------------------------------------------------------

type SeededAsset = {
  id: DbBigint;
  url: string;
  width: number;
  height: number;
  mime_type: string | null;
  duration_seconds: number | null;
};

type AssetSeed = {
  url?: string;
  width?: number;
  height?: number;
  mimeType?: string | null;
  durationSeconds?: number | null;
};

async function seedAsset(
  sql: Sql,
  submissionId: DbBigint,
  overrides: AssetSeed = {},
): Promise<SeededAsset> {
  const value = {
    url: overrides.url ??
      `https://res.cloudinary.com/test/image/upload/promo-${crypto.randomUUID()}.jpg`,
    width: overrides.width ?? 100,
    height: overrides.height ?? 80,
    mime_type: overrides.mimeType === undefined
      ? "image/jpeg"
      : overrides.mimeType,
    duration_seconds: overrides.durationSeconds === undefined
      ? null
      : overrides.durationSeconds,
  };
  const [asset] = await sql<SeededAsset[]>`
    insert into public.submissions_assets (
      content_submission_id, url, width, height, mime_type, duration_seconds
    )
    values (
      ${submissionId},
      ${value.url},
      ${value.width},
      ${value.height},
      ${value.mime_type},
      ${value.duration_seconds}
    )
    returning id, url, width, height, mime_type, duration_seconds
  `;
  return asset;
}

async function fetchAssets(
  sql: Sql,
  submissionId: DbBigint,
): Promise<SeededAsset[]> {
  return await sql<SeededAsset[]>`
    select id, url, width, height, mime_type, duration_seconds
    from public.submissions_assets
    where content_submission_id = ${submissionId}
    order by id
  `;
}

type SourceRow = {
  status: string;
  promoted_place_id: DbBigint | null;
  promoted_event_id: DbBigint | null;
  handled_by: string | null;
  handled_at: Date | null;
  modified_at: Date;
  address: string | null;
};

async function fetchSource(
  sql: Sql,
  submissionId: DbBigint,
): Promise<SourceRow> {
  const [row] = await sql<SourceRow[]>`
    select status::text as status,
           promoted_place_id,
           promoted_event_id,
           handled_by,
           handled_at,
           modified_at,
           address
    from public.content_submissions
    where id = ${submissionId}
  `;
  return row;
}

type PublishedPlace = {
  name: string;
  description: string | null;
  description_delta: Json | null;
  latitude: number;
  longitude: number;
  city_id: DbBigint;
  category: string;
  created_at: Date;
  modified_at: Date;
};

async function fetchPublishedPlace(
  sql: Sql,
  placeId: DbBigint,
): Promise<PublishedPlace> {
  const [row] = await sql<PublishedPlace[]>`
    select name,
           description,
           description_delta,
           latitude::double precision,
           longitude::double precision,
           city_id,
           category::text as category,
           created_at,
           modified_at
    from public.places
    where id = ${placeId}
  `;
  return row;
}

type PublishedEvent = PublishedPlace & {
  start_date: Date;
  end_date: Date | null;
};

async function fetchPublishedEvent(
  sql: Sql,
  eventId: DbBigint,
): Promise<PublishedEvent> {
  const [row] = await sql<PublishedEvent[]>`
    select name,
           description,
           description_delta,
           start_date,
           end_date,
           latitude::double precision,
           longitude::double precision,
           city_id,
           category::text as category,
           created_at,
           modified_at
    from public.events
    where id = ${eventId}
  `;
  return row;
}

type MediaRow = {
  url: string;
  width: number;
  height: number;
  place_id: DbBigint | null;
  event_id: DbBigint | null;
};

async function fetchMediaForPlace(
  sql: Sql,
  placeId: DbBigint,
): Promise<MediaRow[]> {
  return await sql<MediaRow[]>`
    select url, width, height, place_id, event_id
    from public.media
    where place_id = ${placeId}
    order by id
  `;
}

async function fetchMediaForEvent(
  sql: Sql,
  eventId: DbBigint,
): Promise<MediaRow[]> {
  return await sql<MediaRow[]>`
    select url, width, height, place_id, event_id
    from public.media
    where event_id = ${eventId}
    order by id
  `;
}

async function countMediaForPlace(
  sql: Sql,
  placeId: DbBigint,
): Promise<number> {
  const [row] = await sql<{ count: number }[]>`
    select count(*)::integer as count
    from public.media
    where place_id = ${placeId}
  `;
  return row.count;
}

async function countMediaForEvent(
  sql: Sql,
  eventId: DbBigint,
): Promise<number> {
  const [row] = await sql<{ count: number }[]>`
    select count(*)::integer as count
    from public.media
    where event_id = ${eventId}
  `;
  return row.count;
}

/**
 * Reads both durable promotion links of a submission straight from the
 * database and registers any committed target for teardown. Use this instead
 * of trusting the RPC's returned entity id: if a regression returns a null or
 * malformed id after committing, cleanup still discovers the real link.
 */
async function registerDurableLinks(
  sql: Sql,
  registry: FixtureRegistry,
  submissionId: DbBigint,
): Promise<void> {
  const [link] = await sql<{
    promoted_place_id: DbBigint | null;
    promoted_event_id: DbBigint | null;
  }[]>`
    select promoted_place_id, promoted_event_id
    from public.content_submissions
    where id = ${submissionId}
  `;
  if (link?.promoted_place_id != null) {
    registry.placeIds.push(link.promoted_place_id);
  }
  if (link?.promoted_event_id != null) {
    registry.eventIds.push(link.promoted_event_id);
  }
}

/**
 * Concurrency-teardown recovery. Every racing session has a finite database
 * statement_timeout, so a blocked request either completes after the owning
 * transaction ends or PostgreSQL cancels it. Awaiting all requests prevents
 * teardown from racing or blocking on auxiliary sessions. Afterwards durable
 * links are rediscovered so a racing request that committed an unregistered
 * target cannot make fixture cleanup fail.
 */
async function recoverRacingRequests(
  sql: Sql,
  registry: FixtureRegistry,
  submissionId: DbBigint | null,
  requests: (Promise<unknown> | null)[],
): Promise<void> {
  const pending = requests.filter(
    (request): request is Promise<unknown> => request != null,
  );
  const settlements = await Promise.allSettled(pending);
  const recoveryErrors: unknown[] = settlements.flatMap((settlement) =>
    settlement.status === "rejected" ? [settlement.reason] : []
  );

  if (submissionId != null) {
    try {
      await registerDurableLinks(sql, registry, submissionId);
    } catch (error) {
      recoveryErrors.push(
        new Error("Failed to rediscover a durable promotion link", {
          cause: error,
        }),
      );
    }
  }

  if (recoveryErrors.length === 1) {
    throw recoveryErrors[0];
  }
  if (recoveryErrors.length > 1) {
    throw new AggregateError(
      recoveryErrors,
      "Multiple racing-request recovery operations failed",
    );
  }
}

type NamedClient = { name: string; sql: Sql };

/**
 * Runs one concurrency scenario and preserves its primary failure while still
 * attempting request recovery, fixture deletion, and every client closure.
 */
async function runConcurrencyScenario(
  body: () => Promise<void>,
  recover: () => Promise<void>,
  deleteFixtureRows: () => Promise<void>,
  clients: NamedClient[],
): Promise<void> {
  let bodyFailed = false;
  let bodyError: unknown;
  const cleanupErrors: unknown[] = [];

  try {
    await body();
  } catch (error) {
    bodyFailed = true;
    bodyError = error;
  }

  try {
    try {
      await recover();
    } catch (error) {
      cleanupErrors.push(
        new Error("Concurrency request recovery failed", { cause: error }),
      );
    }
  } finally {
    try {
      try {
        await deleteFixtureRows();
      } catch (error) {
        cleanupErrors.push(
          new Error("Concurrency fixture deletion failed", { cause: error }),
        );
      }
    } finally {
      const closureResults = await Promise.allSettled(
        clients.map(({ sql }) => Promise.resolve().then(() => sql.end())),
      );
      for (let index = 0; index < closureResults.length; index++) {
        const result = closureResults[index];
        if (result.status === "rejected") {
          cleanupErrors.push(
            new Error(`Failed to close ${clients[index].name} client`, {
              cause: result.reason,
            }),
          );
        }
      }
    }
  }

  const failures = bodyFailed ? [bodyError, ...cleanupErrors] : cleanupErrors;
  if (failures.length === 1) {
    throw failures[0];
  }
  if (failures.length > 1) {
    throw new AggregateError(
      failures,
      "Concurrency scenario and/or teardown failed",
    );
  }
}

/**
 * Promotes and requires the created outcome. The RPC has committed by the time
 * it returns, so the durable link is discovered straight from the database and
 * registered for teardown before any assertion that can fail: cleanup keeps
 * working even when a regression makes the returned row inconsistent. A
 * created outcome must carry a numeric entity id.
 */
async function promoteCreated(
  sql: Sql,
  registry: FixtureRegistry,
  submissionId: DbBigint,
  target: "place" | "event",
): Promise<PromotionOutcome> {
  const result = await promote(sql, submissionId, target, handledByUser);

  await registerDurableLinks(sql, registry, submissionId);

  assertEquals(result.outcome, "created");
  assertEquals(result.target_type, target);
  // A created outcome must carry a non-null numeric entity id. postgres.js
  // surfaces bigint columns as decimal strings to avoid precision loss.
  if (result.entity_id == null || !/^\d+$/.test(String(result.entity_id))) {
    throw new Error(
      "created outcome must carry a non-null numeric entity id",
    );
  }

  return result;
}

// ---------------------------------------------------------------------------
// Basic outcomes
// ---------------------------------------------------------------------------

Deno.test("promotion reports not_found and not_pending without mutating", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const missing = await promote(setup, 987654321, "place", handledByUser);
      assertEquals(missing, {
        outcome: "not_found",
        target_type: null,
        entity_id: null,
      });

      const rejected = await createSubmission(setup, registry, {
        status: "rejected",
      });
      assertEquals(
        await promote(setup, rejected.submissionId, "event", handledByUser),
        {
          outcome: "not_pending",
          target_type: null,
          entity_id: null,
        },
      );

      // Historical accepted rows without promotion links must not be guessed at.
      const legacyAccepted = await createSubmission(setup, registry, {
        status: "accepted",
      });
      assertEquals(
        await promote(
          setup,
          legacyAccepted.submissionId,
          "place",
          handledByUser,
        ),
        {
          outcome: "not_pending",
          target_type: null,
          entity_id: null,
        },
      );

      const rejectedSource = await fetchSource(setup, rejected.submissionId);
      assertEquals(rejectedSource.status, "rejected");
      assertEquals(rejectedSource.promoted_place_id, null);
      assertEquals(rejectedSource.promoted_event_id, null);
    },
    setup,
    registry,
  );
});

Deno.test("programmer argument errors raise 22023 before locking", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const fixture = await createSubmission(setup, registry);

      // Invalid target values on an existing row.
      await assertPostgresError(
        () => promote(setup, fixture.submissionId, "poi", handledByUser),
        "22023",
      );

      // Pre-lock proof: a nonexistent id with a bad target still raises the
      // argument error instead of returning not_found.
      await assertPostgresError(
        () => promote(setup, 987654321, "bogus", handledByUser),
        "22023",
      );

      await assertPostgresError(
        () => promote(setup, fixture.submissionId, null, handledByUser),
        "22023",
      );

      await assertPostgresError(
        () => promote(setup, fixture.submissionId, "place", null),
        "22023",
      );

      const source = await fetchSource(setup, fixture.submissionId);
      assertEquals(source.status, "pending");
      assertEquals(source.handled_by, null);
    },
    setup,
    registry,
  );
});

// ---------------------------------------------------------------------------
// Readiness checks
// ---------------------------------------------------------------------------

Deno.test("valid zero-asset place promotion succeeds", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
      });

      const result = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "place",
      );

      assertEquals(await countMediaForPlace(setup, result.entity_id!), 0);
    },
    setup,
    registry,
  );
});

Deno.test("place promotion rejects stored event dates", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const withStart = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
        startDate: new Date("2026-09-01T10:00:00.000Z"),
      });
      const endOnly = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
        endDate: new Date("2026-09-03T18:00:00.000Z"),
      });

      assertEquals(
        await promote(setup, withStart.submissionId, "place", handledByUser),
        {
          outcome: "place_has_event_dates",
          target_type: null,
          entity_id: null,
        },
      );
      assertEquals(
        await promote(setup, endOnly.submissionId, "place", handledByUser),
        {
          outcome: "place_has_event_dates",
          target_type: null,
          entity_id: null,
        },
      );
    },
    setup,
    registry,
  );
});

Deno.test("valid start-only, ranged and equal-bound event promotions succeed", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const base = {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
      };

      const startOnly = await createSubmission(setup, registry, {
        ...base,
        startDate: new Date("2026-09-01T10:00:00.000Z"),
      });
      const startOnlyResult = await promoteCreated(
        setup,
        registry,
        startOnly.submissionId,
        "event",
      );
      assertEquals(startOnlyResult.target_type, "event");

      const ranged = await createSubmission(setup, registry, {
        ...base,
        startDate: new Date("2026-09-01T10:00:00.000Z"),
        endDate: new Date("2026-09-03T18:00:00.000Z"),
      });
      const rangedResult = await promoteCreated(
        setup,
        registry,
        ranged.submissionId,
        "event",
      );
      assertEquals(rangedResult.target_type, "event");

      const equalBounds = await createSubmission(setup, registry, {
        ...base,
        startDate: new Date("2026-09-05T09:00:00.000Z"),
        endDate: new Date("2026-09-05T09:00:00.000Z"),
      });
      const equalResult = await promoteCreated(
        setup,
        registry,
        equalBounds.submissionId,
        "event",
      );
      assertEquals(equalResult.target_type, "event");
    },
    setup,
    registry,
  );
});

Deno.test("event promotion rejects missing start and inverted ranges", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const noStart = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      const inverted = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
        startDate: new Date("2026-09-03T18:00:00.000Z"),
        endDate: new Date("2026-09-01T10:00:00.000Z"),
      });

      assertEquals(
        await promote(setup, noStart.submissionId, "event", handledByUser),
        {
          outcome: "start_date_required",
          target_type: null,
          entity_id: null,
        },
      );
      assertEquals(
        await promote(setup, inverted.submissionId, "event", handledByUser),
        {
          outcome: "invalid_date_range",
          target_type: null,
          entity_id: null,
        },
      );

      const noStartSource = await fetchSource(setup, noStart.submissionId);
      assertEquals(noStartSource.status, "pending");
      assertEquals(noStartSource.promoted_event_id, null);
    },
    setup,
    registry,
  );
});

Deno.test("event promotion rejects an inverted sub-millisecond SQL timestamp range", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
      });

      // Keep this precision entirely in PostgreSQL: JavaScript Date and its
      // getTime() representation cannot prove microsecond ordering.
      await setup`
        update public.content_submissions
        set start_date = '2026-09-03 18:00:00.123457+00'::timestamptz,
            end_date = '2026-09-03 18:00:00.123456+00'::timestamptz
        where id = ${fixture.submissionId}
      `;

      assertEquals(
        await promote(setup, fixture.submissionId, "event", handledByUser),
        {
          outcome: "invalid_date_range",
          target_type: null,
          entity_id: null,
        },
      );
    },
    setup,
    registry,
  );
});

Deno.test("incomplete coordinate pairs report coordinates_required", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const bothNull = await createSubmission(setup, registry, {
        name: "Coords A",
      });
      const halfPair = await createSubmission(setup, registry, {
        name: "Coords B",
        latitude: 41.5629,
      });

      assertEquals(
        await promote(setup, bothNull.submissionId, "place", handledByUser),
        {
          outcome: "coordinates_required",
          target_type: null,
          entity_id: null,
        },
      );
      assertEquals(
        await promote(setup, halfPair.submissionId, "place", handledByUser),
        {
          outcome: "coordinates_required",
          target_type: null,
          entity_id: null,
        },
      );
    },
    setup,
    registry,
  );
});

Deno.test("out-of-range, NaN and infinite coordinates report invalid_coordinates", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const cases: [string, SubmissionOverrides][] = [
        ["out of range latitude", { latitude: 91, longitude: 14 }],
        ["NaN latitude", { latitude: Number.NaN, longitude: 14 }],
        ["positive infinity longitude", {
          latitude: 41,
          longitude: Number.POSITIVE_INFINITY,
        }],
        ["negative infinity latitude", {
          latitude: Number.NEGATIVE_INFINITY,
          longitude: 14,
        }],
      ];

      for (const [label, overrides] of cases) {
        const fixture = await createSubmission(setup, registry, overrides);
        assertEquals(
          await promote(setup, fixture.submissionId, "place", handledByUser),
          {
            outcome: "invalid_coordinates",
            target_type: null,
            entity_id: null,
          },
          label,
        );
      }
    },
    setup,
    registry,
  );
});

Deno.test("blank names report invalid_name", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const fixture = await createSubmission(setup, registry, {
        name: "   ",
        latitude: 41.5629,
        longitude: 14.6697,
      });

      assertEquals(
        await promote(setup, fixture.submissionId, "place", handledByUser),
        {
          outcome: "invalid_name",
          target_type: null,
          entity_id: null,
        },
      );
    },
    setup,
    registry,
  );
});

Deno.test("city resolution is exact and active-only", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      // Exact active-city success is proven by every successful promotion above;
      // here the negative paths are pinned down.
      const unknownCity = await createSubmission(setup, registry, {
        city: "Comune Inesistente",
        latitude: 41.5629,
        longitude: 14.6697,
      });
      assertEquals(
        await promote(setup, unknownCity.submissionId, "place", handledByUser),
        {
          outcome: "city_not_found",
          target_type: null,
          entity_id: null,
        },
      );

      const softDeleted = await createCity(setup, registry, {
        deletedAt: new Date("2026-07-01T00:00:00.000Z"),
      });
      const deletedCityFixture = await createSubmission(setup, registry, {
        city: softDeleted.name,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      assertEquals(
        await promote(
          setup,
          deletedCityFixture.submissionId,
          "place",
          handledByUser,
        ),
        {
          outcome: "city_not_found",
          target_type: null,
          entity_id: null,
        },
      );
    },
    setup,
    registry,
  );
});

Deno.test("unknown category is a valid publication value", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        category: "unknown",
        latitude: 41.5629,
        longitude: 14.6697,
      });

      const result = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "place",
      );
      const published = await fetchPublishedPlace(setup, result.entity_id!);
      assertEquals(published.category, "unknown");
    },
    setup,
    registry,
  );
});

Deno.test("malformed historical assets block promotion without mutation", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const insecureUrl = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      await seedAsset(setup, insecureUrl.submissionId, {
        url: "http://insecure.example/image.jpg",
      });

      const nonPositiveWidth = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
        startDate: new Date("2026-09-01T10:00:00.000Z"),
      });
      await seedAsset(setup, nonPositiveWidth.submissionId, {
        url: "https://res.cloudinary.com/test/image/upload/zero-width.jpg",
        width: 0,
      });

      const nonPositiveHeight = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      await seedAsset(setup, nonPositiveHeight.submissionId, {
        url: "https://res.cloudinary.com/test/image/upload/negative-height.jpg",
        height: -1,
      });

      assertEquals(
        await promote(setup, insecureUrl.submissionId, "place", handledByUser),
        {
          outcome: "invalid_asset",
          target_type: null,
          entity_id: null,
        },
      );
      assertEquals(
        await promote(
          setup,
          nonPositiveWidth.submissionId,
          "event",
          handledByUser,
        ),
        {
          outcome: "invalid_asset",
          target_type: null,
          entity_id: null,
        },
      );
      assertEquals(
        await promote(
          setup,
          nonPositiveHeight.submissionId,
          "place",
          handledByUser,
        ),
        {
          outcome: "invalid_asset",
          target_type: null,
          entity_id: null,
        },
      );

      assertEquals(
        (await fetchSource(setup, insecureUrl.submissionId)).status,
        "pending",
      );
      assertEquals(
        (await fetchSource(setup, nonPositiveWidth.submissionId)).status,
        "pending",
      );
      assertEquals(
        (await fetchSource(setup, nonPositiveHeight.submissionId)).status,
        "pending",
      );
    },
    setup,
    registry,
  );
});

// ---------------------------------------------------------------------------
// Mapping
// ---------------------------------------------------------------------------

Deno.test("place promotion copies exactly the approved fields", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const delta = [{ insert: "A historic palazzo" }];
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        name: "Palazzo Test",
        description: "A historic palazzo",
        descriptionDelta: delta,
        latitude: 41.1234,
        longitude: 14.5678,
        address: "Via Roma 1",
        category: "history",
      });

      const result = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "place",
      );
      const published = await fetchPublishedPlace(setup, result.entity_id!);

      assertEquals(published.name, "Palazzo Test");
      assertEquals(published.description, "A historic palazzo");
      assertEquals(published.description_delta, delta);
      assertEquals(published.latitude, 41.1234);
      assertEquals(published.longitude, 14.5678);
      assertEquals(published.city_id, city.id);
      assertEquals(published.category, "history");

      // The address is deliberately unmapped; the source retains it for audit.
      const source = await fetchSource(setup, fixture.submissionId);
      assertEquals(source.address, "Via Roma 1");
    },
    setup,
    registry,
  );
});

Deno.test("event promotion additionally copies dates losslessly", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const start = new Date("2026-09-01T10:00:00.000Z");
      const end = new Date("2026-09-03T18:30:00.000Z");
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        name: "Festival Test",
        description: "Three days of music",
        latitude: 41.7,
        longitude: 14.8,
        startDate: start,
        endDate: end,
        category: "folklore",
      });

      const result = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "event",
      );
      const published = await fetchPublishedEvent(setup, result.entity_id!);

      assertEquals(published.name, "Festival Test");
      assertEquals(published.description, "Three days of music");
      assertEquals(published.start_date.getTime(), start.getTime());
      assertEquals(published.end_date?.getTime(), end.getTime());
      assertEquals(published.latitude, 41.7);
      assertEquals(published.longitude, 14.8);
      assertEquals(published.city_id, city.id);
      assertEquals(published.category, "folklore");
      assertEquals(await countMediaForEvent(setup, result.entity_id!), 0);

      // Durable linkage: the created event id is recorded on the accepted
      // source and the opposite promotion link stays null.
      const source = await fetchSource(setup, fixture.submissionId);
      assertEquals(source.status, "accepted");
      assertEquals(source.promoted_event_id, result.entity_id);
      assertEquals(source.promoted_place_id, null);

      // The address is not invented anywhere in the event mapping either.
      assertEquals(source.address, null);
    },
    setup,
    registry,
  );
});

Deno.test("event promotion preserves sub-millisecond SQL timestamp precision", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.7,
        longitude: 14.8,
      });

      // Direct PostgreSQL literals retain the six-digit fractional seconds
      // that cannot safely travel through JavaScript Date.
      await setup`
        update public.content_submissions
        set start_date = '2026-09-01 10:00:00.123456+00'::timestamptz,
            end_date = '2026-09-01 10:00:00.123457+00'::timestamptz
        where id = ${fixture.submissionId}
      `;
      const [source] = await setup<{ start: string; end: string }[]>`
        select to_char(start_date at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') as start,
               to_char(end_date at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') as end
        from public.content_submissions
        where id = ${fixture.submissionId}
      `;
      assertEquals(source, {
        start: "2026-09-01 10:00:00.123456",
        end: "2026-09-01 10:00:00.123457",
      });

      const result = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "event",
      );
      const [published] = await setup<{ start: string; end: string }[]>`
        select to_char(start_date at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') as start,
               to_char(end_date at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS.US') as end
        from public.events
        where id = ${result.entity_id}
      `;
      assertEquals(published, source);
    },
    setup,
    registry,
  );
});

Deno.test("published timestamps are fresh, not reused from the source", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const seededAt = new Date("2026-08-01T09:00:00.000Z");
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
        createdAt: seededAt,
        modifiedAt: seededAt,
      });

      const result = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "place",
      );
      const published = await fetchPublishedPlace(setup, result.entity_id!);

      assertEquals(published.created_at.getTime() > seededAt.getTime(), true);
      assertEquals(published.modified_at.getTime() > seededAt.getTime(), true);
    },
    setup,
    registry,
  );
});

// ---------------------------------------------------------------------------
// Media copy and source preservation
// ---------------------------------------------------------------------------

Deno.test("all valid assets become media for the selected parent only", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      // MIME and duration are set on purpose: they are neither required nor
      // copied (media has no destination columns for them).
      const first = await seedAsset(setup, fixture.submissionId, {
        durationSeconds: null,
      });
      const second = await seedAsset(setup, fixture.submissionId, {
        mimeType: "video/mp4",
        durationSeconds: 12,
      });
      const before = await fetchAssets(setup, fixture.submissionId);

      const result = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "place",
      );

      const media = await fetchMediaForPlace(setup, result.entity_id!);
      assertEquals(media.length, 2);
      assertEquals(
        new Set(media.map((row) => row.url)),
        new Set([first.url, second.url]),
      );
      for (const row of media) {
        assertEquals(row.place_id, result.entity_id);
        assertEquals(row.event_id, null);
        if (row.url === first.url) {
          assertEquals([row.width, row.height], [first.width, first.height]);
        } else {
          assertEquals([row.width, row.height], [second.width, second.height]);
        }
      }

      // Source assets remain unchanged as the immutable audit record.
      const after = await fetchAssets(setup, fixture.submissionId);
      assertEquals(after, before);
    },
    setup,
    registry,
  );
});

Deno.test("event media rows reference only the created event", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
        startDate: new Date("2026-09-01T10:00:00.000Z"),
      });
      const asset = await seedAsset(setup, fixture.submissionId);

      const result = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "event",
      );

      const media = await fetchMediaForEvent(setup, result.entity_id!);
      assertEquals(media.length, 1);
      assertEquals(media[0].url, asset.url);
      assertEquals(media[0].event_id, result.entity_id);
      assertEquals(media[0].place_id, null);
    },
    setup,
    registry,
  );
});

// ---------------------------------------------------------------------------
// Final source state
// ---------------------------------------------------------------------------

Deno.test("promotion finalizes source status, linkage and handled metadata", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const modifiedBefore = new Date("2026-08-01T09:00:00.000Z");
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
        modifiedAt: modifiedBefore,
      });

      const result = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "place",
      );

      const source = await fetchSource(setup, fixture.submissionId);
      assertEquals(source.status, "accepted");
      assertEquals(source.promoted_place_id, result.entity_id);
      assertEquals(source.promoted_event_id, null);
      assertEquals(source.handled_by, handledByUser);
      // handled_at stays owned by the handle_handled_at trigger.
      assertEquals(typeof source.handled_at?.getTime(), "number");
      // modified_at is advanced explicitly by the RPC (no maintaining trigger).
      assertEquals(
        source.modified_at.getTime() > modifiedBefore.getTime(),
        true,
      );
    },
    setup,
    registry,
  );
});

Deno.test("controlled readiness failure leaves no writes behind", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      // Valid assets and fields except the unknown city, so the failure happens
      // after every earlier check but before any write.
      const uniqueName = `Failed promotion ${crypto.randomUUID()}`;
      const fixture = await createSubmission(setup, registry, {
        city: "Comune Inesistente",
        name: uniqueName,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      const asset = await seedAsset(setup, fixture.submissionId);

      assertEquals(
        await promote(setup, fixture.submissionId, "place", handledByUser),
        {
          outcome: "city_not_found",
          target_type: null,
          entity_id: null,
        },
      );

      // No orphan place or event may exist for the failed promotion.
      const [counts] = await setup<{ places: number; events: number }[]>`
      select
        (select count(*)::integer from public.places where name = ${uniqueName}) as places,
        (select count(*)::integer from public.events where name = ${uniqueName}) as events
    `;
      assertEquals(counts.places, 0);
      assertEquals(counts.events, 0);

      const [mediaCount] = await setup<{ count: number }[]>`
      select count(*)::integer as count from public.media where url = ${asset.url}
    `;
      assertEquals(mediaCount.count, 0);

      const source = await fetchSource(setup, fixture.submissionId);
      assertEquals(source.status, "pending");
      assertEquals(source.promoted_place_id, null);
      assertEquals(source.promoted_event_id, null);
      assertEquals(source.handled_by, null);
      assertEquals(source.handled_at, null);
      assertEquals((await fetchAssets(setup, fixture.submissionId)).length, 1);
    },
    setup,
    registry,
  );
});

// ---------------------------------------------------------------------------
// Atomicity — genuine rollback proof
// ---------------------------------------------------------------------------

Deno.test("aborted outer transaction rolls back target, media, linkage and status", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const uniqueName = `Rollback place ${crypto.randomUUID()}`;
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        name: uniqueName,
        latitude: 41.5629,
        longitude: 14.6697,
        modifiedAt: new Date("2026-08-01T09:00:00.000Z"),
      });
      const asset = await seedAsset(setup, fixture.submissionId);

      try {
        await setup.begin(async (transaction) => {
          const outcome = await promote(
            transaction,
            fixture.submissionId,
            "place",
            handledByUser,
          );
          assertEquals(outcome.outcome, "created");
          throw new Error("deliberate outer abort");
        });
        throw new Error("the outer transaction should have rejected");
      } catch (error) {
        assertEquals((error as Error).message, "deliberate outer abort");
      }

      const [placeCount] = await setup<{ count: number }[]>`
      select count(*)::integer as count from public.places where name = ${uniqueName}
    `;
      assertEquals(placeCount.count, 0);

      const [mediaCount] = await setup<{ count: number }[]>`
      select count(*)::integer as count from public.media where url = ${asset.url}
    `;
      assertEquals(mediaCount.count, 0);

      const source = await fetchSource(setup, fixture.submissionId);
      assertEquals(source.status, "pending");
      assertEquals(source.promoted_place_id, null);
      assertEquals(source.promoted_event_id, null);
      assertEquals(source.handled_by, null);
      assertEquals(source.handled_at, null);
      assertEquals(
        source.modified_at.getTime(),
        new Date("2026-08-01T09:00:00.000Z").getTime(),
      );
    },
    setup,
    registry,
  );
});

// ---------------------------------------------------------------------------
// Idempotency
// ---------------------------------------------------------------------------

Deno.test("same-target retry returns already_promoted without duplicating content", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const uniqueName = `Idempotent place ${crypto.randomUUID()}`;
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        name: uniqueName,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      await seedAsset(setup, fixture.submissionId);

      const first = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "place",
      );
      const retry = await promote(
        setup,
        fixture.submissionId,
        "place",
        handledByUser,
      );

      assertEquals(retry, {
        outcome: "already_promoted",
        target_type: "place",
        entity_id: first.entity_id,
      });

      const [placeCount] = await setup<{ count: number }[]>`
      select count(*)::integer as count from public.places where name = ${uniqueName}
    `;
      assertEquals(placeCount.count, 1);
      assertEquals(await countMediaForPlace(setup, first.entity_id!), 1);
    },
    setup,
    registry,
  );
});

Deno.test("different-target retry returns the actual original target and id", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const uniqueName = `Conflict-free place ${crypto.randomUUID()}`;
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        name: uniqueName,
        latitude: 41.5629,
        longitude: 14.6697,
      });

      const first = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "place",
      );

      const conflictingRetry = await promote(
        setup,
        fixture.submissionId,
        "event",
        handledByUser,
      );
      assertEquals(conflictingRetry, {
        outcome: "already_promoted",
        target_type: "place",
        entity_id: first.entity_id,
      });

      const [placeCount] = await setup<{ count: number }[]>`
      select count(*)::integer as count from public.places where name = ${uniqueName}
    `;
      assertEquals(placeCount.count, 1);
      const [eventCount] = await setup<{ count: number }[]>`
      select count(*)::integer as count from public.events where name = ${uniqueName}
    `;
      assertEquals(eventCount.count, 0);
    },
    setup,
    registry,
  );
});

Deno.test("event-origin retries return the original event for every target", async () => {
  const setup = client();
  const registry = newRegistry();

  await runFixtureScenario(
    async () => {
      const city = await createCity(setup, registry);
      const uniqueName = `Idempotent event ${crypto.randomUUID()}`;
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        name: uniqueName,
        latitude: 41.5629,
        longitude: 14.6697,
        startDate: new Date("2026-09-01T10:00:00.000Z"),
      });
      await seedAsset(setup, fixture.submissionId);

      const first = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "event",
      );

      // Durable linkage: the created event id is recorded, the place link null.
      const promoted = await fetchSource(setup, fixture.submissionId);
      assertEquals(promoted.promoted_event_id, first.entity_id);
      assertEquals(promoted.promoted_place_id, null);

      const sameTargetRetry = await promote(
        setup,
        fixture.submissionId,
        "event",
        handledByUser,
      );
      assertEquals(sameTargetRetry, {
        outcome: "already_promoted",
        target_type: "event",
        entity_id: first.entity_id,
      });

      // A conflicting place retry must still discover the actual event.
      const conflictingRetry = await promote(
        setup,
        fixture.submissionId,
        "place",
        handledByUser,
      );
      assertEquals(conflictingRetry, {
        outcome: "already_promoted",
        target_type: "event",
        entity_id: first.entity_id,
      });

      const [eventCount] = await setup<{ count: number }[]>`
      select count(*)::integer as count from public.events where name = ${uniqueName}
    `;
      assertEquals(eventCount.count, 1);
      const [placeCount] = await setup<{ count: number }[]>`
      select count(*)::integer as count from public.places where name = ${uniqueName}
    `;
      assertEquals(placeCount.count, 0);
      assertEquals(await countMediaForEvent(setup, first.entity_id!), 1);
    },
    setup,
    registry,
  );
});

// ---------------------------------------------------------------------------
// Concurrency (separate real sessions, deterministic lock observation)
// ---------------------------------------------------------------------------

function assetPayload(
  suffix: string,
): { url: string; width: number; height: number } {
  return {
    url: `https://res.cloudinary.com/test/image/upload/${suffix}.jpg`,
    width: 100,
    height: 80,
  };
}

async function addAssets(
  sql: Sql,
  submissionId: DbBigint,
  assets: { url: string; width: number; height: number }[],
): Promise<{ outcome: string }[]> {
  return await sql<{ outcome: string }[]>`
    select outcome
    from public.add_submission_assets(
      ${submissionId},
      ${sql.json(assets)}
    )
  `;
}

async function deleteAssetViaRpc(
  sql: Sql,
  submissionId: DbBigint,
  assetId: DbBigint,
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

Deno.test("concurrent double promotion creates exactly one target", async () => {
  const setup = client();
  const first = client();
  const second = client();
  const observer = client();
  const registry = newRegistry();
  let submissionId: DbBigint | null = null;
  let secondRequest: Promise<PromotionOutcome> | null = null;

  await runConcurrencyScenario(
    async () => {
      const city = await createCity(setup, registry);
      const uniqueName = `Concurrent place ${crypto.randomUUID()}`;
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        name: uniqueName,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      submissionId = fixture.submissionId;
      await seedAsset(setup, fixture.submissionId);
      await prepareRacingSession(second, "promotion-double-promote-second");

      const firstResult = await first.begin(async (transaction) => {
        const outcome = await promote(
          transaction,
          fixture.submissionId,
          "place",
          handledByUser,
        );
        assertEquals(outcome.outcome, "created");
        secondRequest = promote(
          second,
          fixture.submissionId,
          "place",
          handledByUser,
        );
        await waitForLock(observer, "promotion-double-promote-second");
        return outcome;
      });
      // The transaction has committed: register the durable link before
      // inspecting the returned outcome.
      await registerDurableLinks(setup, registry, fixture.submissionId);
      const retry = await secondRequest!;

      assertEquals(firstResult.outcome, "created");
      assertEquals(retry, {
        outcome: "already_promoted",
        target_type: "place",
        entity_id: firstResult.entity_id,
      });

      const [counts] = await setup<{ places: number; media: number }[]>`
      select
        (select count(*)::integer from public.places where name = ${uniqueName}) as places,
        (
          select count(*)::integer from public.media
          where place_id = ${firstResult.entity_id!}
        ) as media
    `;
      assertEquals(counts.places, 1);
      assertEquals(counts.media, 1);
    },
    () =>
      recoverRacingRequests(
        setup,
        registry,
        submissionId,
        [secondRequest],
      ),
    () => deleteFixtures(setup, registry),
    [
      { name: "setup", sql: setup },
      { name: "first promoter", sql: first },
      { name: "second promoter", sql: second },
      { name: "observer", sql: observer },
    ],
  );
});

Deno.test("promotion wins against a racing asset addition", async () => {
  const setup = client();
  const promoter = client();
  const adder = client();
  const observer = client();
  const registry = newRegistry();
  let submissionId: DbBigint | null = null;
  let addRequest: Promise<{ outcome: string }[]> | null = null;

  await runConcurrencyScenario(
    async () => {
      const city = await createCity(setup, registry);
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      submissionId = fixture.submissionId;
      const committedAsset = await seedAsset(setup, fixture.submissionId);
      await prepareRacingSession(adder, "promotion-add-vs-promote");

      const promotion = await promoter.begin(async (transaction) => {
        const outcome = await promote(
          transaction,
          fixture.submissionId,
          "place",
          handledByUser,
        );
        assertEquals(outcome.outcome, "created");
        addRequest = addAssets(adder, fixture.submissionId, [
          assetPayload(`racing-${fixture.submissionId}`),
        ]);
        await waitForLock(observer, "promotion-add-vs-promote");
        return outcome;
      });
      // The transaction has committed: register the durable link before
      // inspecting the returned outcome.
      await registerDurableLinks(setup, registry, fixture.submissionId);
      const addOutcome = await addRequest!;

      assertEquals(addOutcome.map((result) => result.outcome), ["not_pending"]);

      // Media exactly reflects the pre-promotion committed asset set.
      const media = await fetchMediaForPlace(setup, promotion.entity_id!);
      assertEquals(media.length, 1);
      assertEquals(media[0].url, committedAsset.url);

      const source = await fetchSource(setup, fixture.submissionId);
      assertEquals(source.status, "accepted");
    },
    () =>
      recoverRacingRequests(
        setup,
        registry,
        submissionId,
        [addRequest],
      ),
    () => deleteFixtures(setup, registry),
    [
      { name: "setup", sql: setup },
      { name: "promoter", sql: promoter },
      { name: "adder", sql: adder },
      { name: "observer", sql: observer },
    ],
  );
});

Deno.test("asset addition committing before promotion is copied into media", async () => {
  const setup = client();
  const adder = client();
  const observer = client();
  const registry = newRegistry();
  let submissionId: DbBigint | null = null;
  let addRequest: Promise<{ outcome: string }[]> | null = null;

  await runConcurrencyScenario(
    async () => {
      const city = await createCity(setup, registry);
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      submissionId = fixture.submissionId;
      const racingAsset = assetPayload(`add-wins-${fixture.submissionId}`);
      await prepareRacingSession(adder, "promotion-add-wins");

      await setup.begin(async (transaction) => {
        await transaction`
        select id
        from public.content_submissions
        where id = ${fixture.submissionId}
        for update
      `;
        addRequest = addAssets(adder, fixture.submissionId, [racingAsset]);
        await waitForLock(observer, "promotion-add-wins");
      });
      const addOutcome = await addRequest!;
      assertEquals(addOutcome.map((result) => result.outcome), ["created"]);

      const result = await promoteCreated(
        setup,
        registry,
        fixture.submissionId,
        "place",
      );

      const media = await fetchMediaForPlace(setup, result.entity_id!);
      assertEquals(media.length, 1);
      assertEquals(media[0].url, racingAsset.url);
    },
    () =>
      recoverRacingRequests(
        setup,
        registry,
        submissionId,
        [addRequest],
      ),
    () => deleteFixtures(setup, registry),
    [
      { name: "setup", sql: setup },
      { name: "adder", sql: adder },
      { name: "observer", sql: observer },
    ],
  );
});

Deno.test("promotion wins against a racing asset deletion", async () => {
  const setup = client();
  const promoter = client();
  const deleter = client();
  const observer = client();
  const registry = newRegistry();
  let submissionId: DbBigint | null = null;
  let deleteRequest: Promise<string> | null = null;

  await runConcurrencyScenario(
    async () => {
      const city = await createCity(setup, registry);
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      submissionId = fixture.submissionId;
      const seededAsset = await seedAsset(setup, fixture.submissionId);
      await prepareRacingSession(deleter, "promotion-delete-vs-promote");

      const promotion = await promoter.begin(async (transaction) => {
        const outcome = await promote(
          transaction,
          fixture.submissionId,
          "place",
          handledByUser,
        );
        assertEquals(outcome.outcome, "created");
        deleteRequest = deleteAssetViaRpc(
          deleter,
          fixture.submissionId,
          seededAsset.id,
        );
        await waitForLock(observer, "promotion-delete-vs-promote");
        return outcome;
      });
      // The transaction has committed: register the durable link before
      // inspecting the returned outcome.
      await registerDurableLinks(setup, registry, fixture.submissionId);
      const deleteOutcome = await deleteRequest!;

      assertEquals(deleteOutcome, "not_pending");

      // Copied media still contains the deleted-after-publication asset.
      const media = await fetchMediaForPlace(setup, promotion.entity_id!);
      assertEquals(media.length, 1);
      assertEquals(media[0].url, seededAsset.url);
      assertEquals((await fetchAssets(setup, fixture.submissionId)).length, 1);
    },
    () =>
      recoverRacingRequests(
        setup,
        registry,
        submissionId,
        [deleteRequest],
      ),
    () => deleteFixtures(setup, registry),
    [
      { name: "setup", sql: setup },
      { name: "promoter", sql: promoter },
      { name: "deleter", sql: deleter },
      { name: "observer", sql: observer },
    ],
  );
});

Deno.test("rejection committing before promotion leaves no published content", async () => {
  const setup = client();
  const moderator = client();
  const promoter = client();
  const observer = client();
  const registry = newRegistry();
  let submissionId: DbBigint | null = null;
  let promotionRequest: Promise<PromotionOutcome> | null = null;

  await runConcurrencyScenario(
    async () => {
      const city = await createCity(setup, registry);
      const uniqueName = `Rejected source ${crypto.randomUUID()}`;
      const fixture = await createSubmission(setup, registry, {
        city: city.name,
        name: uniqueName,
        latitude: 41.5629,
        longitude: 14.6697,
      });
      submissionId = fixture.submissionId;
      await prepareRacingSession(promoter, "promotion-rejection-wins");

      await moderator.begin(async (transaction) => {
        await transaction`
        update public.content_submissions
        set status = 'rejected'
        where id = ${fixture.submissionId}
      `;
        promotionRequest = promote(
          promoter,
          fixture.submissionId,
          "place",
          handledByUser,
        );
        await waitForLock(observer, "promotion-rejection-wins");
      });
      const promotion = await promotionRequest!;

      assertEquals(promotion, {
        outcome: "not_pending",
        target_type: null,
        entity_id: null,
      });

      const [counts] = await setup<{ places: number; events: number }[]>`
      select
        (select count(*)::integer from public.places where name = ${uniqueName}) as places,
        (select count(*)::integer from public.events where name = ${uniqueName}) as events
    `;
      assertEquals(counts.places, 0);
      assertEquals(counts.events, 0);

      const source = await fetchSource(setup, fixture.submissionId);
      assertEquals(source.status, "rejected");
      assertEquals(source.promoted_place_id, null);
      assertEquals(source.promoted_event_id, null);
    },
    () => {
      // If the rejection transaction failed after the racing promotion was
      // issued, the rollback un-rejects the source and the promotion can still
      // commit a target; settle it and rediscover its durable link before
      // cleanup.
      return recoverRacingRequests(
        setup,
        registry,
        submissionId,
        [promotionRequest],
      );
    },
    () => deleteFixtures(setup, registry),
    [
      { name: "setup", sql: setup },
      { name: "moderator", sql: moderator },
      { name: "promoter", sql: promoter },
      { name: "observer", sql: observer },
    ],
  );
});

// ---------------------------------------------------------------------------
// Security (role emulation inside transactions)
// ---------------------------------------------------------------------------

Deno.test("promotion executes only as service_role", async () => {
  const setup = client();

  try {
    // Optional corroboration: the RPC must not be SECURITY DEFINER.
    const [proc] = await setup<{ prosecdef: boolean }[]>`
      select prosecdef
      from pg_catalog.pg_proc
      where proname = 'promote_content_submission'
    `;
    assertEquals(proc.prosecdef, false);

    try {
      await setup.begin(async (transaction) => {
        await transaction`set local role anon`;
        await promote(transaction, 987654321, "place", handledByUser);
      });
      throw new Error("anon must not be able to execute the promotion RPC");
    } catch (error) {
      assertEquals((error as { code?: string }).code, "42501");
    }

    try {
      await setup.begin(async (transaction) => {
        await transaction`set local role authenticated`;
        await promote(transaction, 987654321, "place", handledByUser);
      });
      throw new Error(
        "authenticated must not be able to execute the promotion RPC",
      );
    } catch (error) {
      assertEquals((error as { code?: string }).code, "42501");
    }

    await setup.begin(async (transaction) => {
      await transaction`set local role service_role`;
      const outcome = await promote(
        transaction,
        987654321,
        "place",
        handledByUser,
      );
      assertEquals(outcome.outcome, "not_found");
    });
  } finally {
    await setup.end();
  }
});
