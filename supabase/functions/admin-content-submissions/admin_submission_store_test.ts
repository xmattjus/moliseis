import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.112.3";

import type { Database } from "../_shared/database.types.ts";
import {
  AdminSubmissionStoreError,
  createAdminSubmissionStore,
  type PromoteStoreResult,
  SUBMISSION_SELECT,
  type SubmissionRecord,
} from "./admin_submission_store.ts";

const record: SubmissionRecord = {
  id: 7,
  city: "Campobasso",
  name: "Teatro",
  description: "Description",
  description_delta: [{ insert: "Description\n" }],
  start_date: null,
  end_date: null,
  category: "history",
  user_name: "Contributor",
  user_email: "contributor@example.test",
  status: "pending",
  created_at: "2026-08-21T10:00:00.000Z",
  modified_at: "2026-08-21T10:00:00.000Z",
  latitude: null,
  longitude: null,
  promoted_place_id: null,
  promoted_event_id: null,
};

type RecordedQuery = {
  table: string;
  updateValues: Record<string, unknown> | null;
  selects: Array<string | undefined>;
  filters: Array<[column: string, value: unknown]>;
};

type QueryResponse = { data: unknown; error: unknown };
type RpcResponse = { data: unknown; error: unknown };

// Minimal thenable query-builder fake that RECORDS every filter pair and
// resolves canned results in call order; modeled on FakeImporterAdminClient.
class FakeQueryBuilder {
  readonly #recorded: RecordedQuery;
  readonly #client: FakeAdminClient;

  constructor(recorded: RecordedQuery, client: FakeAdminClient) {
    this.#recorded = recorded;
    this.#client = client;
  }

  update(values: Record<string, unknown>): this {
    this.#recorded.updateValues = values;
    return this;
  }

  select(columns?: string): this {
    this.#recorded.selects.push(columns);
    return this;
  }

  eq(column: string, value: unknown): this {
    this.#recorded.filters.push([column, value]);
    return this;
  }

  order(): this {
    return this;
  }

  insert(): this {
    return this;
  }

  maybeSingle(): Promise<QueryResponse> {
    return Promise.resolve(this.#client.nextQueryResult());
  }

  single(): Promise<QueryResponse> {
    return Promise.resolve(this.#client.nextQueryResult());
  }
}

class FakeAdminClient {
  readonly queries: RecordedQuery[] = [];
  readonly rpcCalls: Array<{ functionName: string; args: unknown }> = [];
  readonly #queryResults: QueryResponse[] = [];
  readonly #rpcResults: RpcResponse[] = [];

  queueQuery(response: QueryResponse): void {
    this.#queryResults.push(response);
  }

  queueRpc(response: RpcResponse): void {
    this.#rpcResults.push(response);
  }

  nextQueryResult(): QueryResponse {
    return this.#queryResults.shift() ?? { data: null, error: null };
  }

  from(table: string): FakeQueryBuilder {
    const recorded: RecordedQuery = {
      table,
      updateValues: null,
      selects: [],
      filters: [],
    };
    this.queries.push(recorded);
    return new FakeQueryBuilder(recorded, this);
  }

  rpc(functionName: string, args: unknown): Promise<RpcResponse> {
    this.rpcCalls.push({ functionName, args });
    return Promise.resolve(
      this.#rpcResults.shift() ?? { data: null, error: null },
    );
  }
}

function promotionRow(
  outcome: string,
  targetType: unknown,
  entityId: unknown,
): Record<string, unknown> {
  return { outcome, target_type: targetType, entity_id: entityId };
}

Deno.test("update applies the pending-only guarded predicate", async () => {
  const client = new FakeAdminClient();
  client.queueQuery({ data: record, error: null });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );

  const result = await store.update(7, {
    category: "history",
    city: " Campobasso ",
    name: "Teatro",
    description: null,
    description_delta: null,
    start_date: null,
    end_date: null,
    latitude: null,
    longitude: null,
  }, "2026-08-21T11:00:00.000Z");

  assertEquals(result, { outcome: "updated", submission: record });
  const query = client.queries[0];
  assertEquals(query.table, "content_submissions");
  assert(query.updateValues !== null);
  // Both guards must be present on the UPDATE itself: the id predicate AND the
  // status predicate that blocks accepted/rejected sources.
  assertEquals(query.filters, [["id", 7], ["status", "pending"]]);
  assertEquals(query.selects, [SUBMISSION_SELECT]);
});

Deno.test("update classifies an empty guarded result as not_found or not_pending", async () => {
  const absentClient = new FakeAdminClient();
  absentClient.queueQuery({ data: null, error: null });
  absentClient.queueQuery({ data: null, error: null });
  const absentStore = createAdminSubmissionStore(
    absentClient as unknown as SupabaseClient<Database>,
  );
  assertEquals(
    await absentStore.update(8, {
      category: "history",
      city: "Campobasso",
      name: "Teatro",
      description: null,
      description_delta: null,
      start_date: null,
      end_date: null,
      latitude: null,
      longitude: null,
    }, "2026-08-21T11:00:00.000Z"),
    { outcome: "not_found" },
  );
  // The classification lookup queried only id and status by the requested id.
  assertEquals(absentClient.queries[1].selects, ["id,status"]);
  assertEquals(absentClient.queries[1].filters, [["id", 8]]);

  const moderatedClient = new FakeAdminClient();
  moderatedClient.queueQuery({ data: null, error: null });
  moderatedClient.queueQuery({
    data: { id: 7, status: "accepted" },
    error: null,
  });
  const moderatedStore = createAdminSubmissionStore(
    moderatedClient as unknown as SupabaseClient<Database>,
  );
  assertEquals(
    await moderatedStore.update(7, {
      category: "history",
      city: "Campobasso",
      name: "Teatro",
      description: null,
      description_delta: null,
      start_date: null,
      end_date: null,
      latitude: null,
      longitude: null,
    }, "2026-08-21T11:00:00.000Z"),
    { outcome: "not_pending" },
  );
});

Deno.test("update normalizes a failing guarded update query", async () => {
  const client = new FakeAdminClient();
  client.queueQuery({ data: null, error: { message: "update boom" } });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );

  await assertRejects(
    () =>
      store.update(7, {
        category: "history",
        city: "Campobasso",
        name: "Teatro",
        description: null,
        description_delta: null,
        start_date: null,
        end_date: null,
        latitude: null,
        longitude: null,
      }, "2026-08-21T11:00:00.000Z"),
    AdminSubmissionStoreError,
  );
});

Deno.test("update wraps a failing classification query", async () => {
  const client = new FakeAdminClient();
  client.queueQuery({ data: null, error: null });
  client.queueQuery({ data: null, error: { message: "classification boom" } });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );

  await assertRejects(
    () =>
      store.update(7, {
        category: "history",
        city: "Campobasso",
        name: "Teatro",
        description: null,
        description_delta: null,
        start_date: null,
        end_date: null,
        latitude: null,
        longitude: null,
      }, "2026-08-21T11:00:00.000Z"),
    AdminSubmissionStoreError,
  );
});

Deno.test("promote passes the exact RPC params and parses created rows", async () => {
  for (const target of ["place", "event"] as const) {
    const entityId = target === "place" ? 42 : 43;
    const client = new FakeAdminClient();
    client.queueRpc({
      data: [promotionRow("created", target, entityId)],
      error: null,
    });
    const store = createAdminSubmissionStore(
      client as unknown as SupabaseClient<Database>,
    );

    const result = await store.promote({
      id: 7,
      target,
      handledBy: "00000000-0000-4000-8000-000000000001",
    });

    assertEquals(result, { outcome: "created", target, entityId });
    assertEquals(client.rpcCalls, [{
      functionName: "promote_content_submission",
      args: {
        p_submission_id: 7,
        p_target: target,
        p_handled_by: "00000000-0000-4000-8000-000000000001",
      },
    }]);
  }
});

Deno.test("promote keeps the actual returned target for already_promoted", async () => {
  // Same-target retry.
  const sameTargetClient = new FakeAdminClient();
  sameTargetClient.queueRpc({
    data: [promotionRow("already_promoted", "place", 42)],
    error: null,
  });
  const sameTargetStore = createAdminSubmissionStore(
    sameTargetClient as unknown as SupabaseClient<Database>,
  );
  assertEquals(
    await sameTargetStore.promote({
      id: 7,
      target: "place",
      handledBy: "00000000-0000-4000-8000-000000000001",
    }),
    { outcome: "already_promoted", target: "place", entityId: 42 },
  );

  // Different-target retry: the ACTUAL returned target is preserved so the
  // handler can distinguish a same-target retry from a conflict.
  const otherTargetClient = new FakeAdminClient();
  otherTargetClient.queueRpc({
    data: [promotionRow("already_promoted", "event", 43)],
    error: null,
  });
  const otherTargetStore = createAdminSubmissionStore(
    otherTargetClient as unknown as SupabaseClient<Database>,
  );
  assertEquals(
    await otherTargetStore.promote({
      id: 7,
      target: "place",
      handledBy: "00000000-0000-4000-8000-000000000001",
    }),
    { outcome: "already_promoted", target: "event", entityId: 43 },
  );
});

Deno.test("promote maps every domain failure without treating payloads as success", async () => {
  const failures = [
    "not_found",
    "not_pending",
    "invalid_name",
    "coordinates_required",
    "invalid_coordinates",
    "city_not_found",
    "place_has_event_dates",
    "start_date_required",
    "invalid_date_range",
    "invalid_asset",
    "category_required",
  ] as const;
  for (const outcome of failures) {
    const client = new FakeAdminClient();
    client.queueRpc({ data: [promotionRow(outcome, null, null)], error: null });
    const store = createAdminSubmissionStore(
      client as unknown as SupabaseClient<Database>,
    );

    const result: PromoteStoreResult = await store.promote({
      id: 7,
      target: "place",
      handledBy: "00000000-0000-4000-8000-000000000001",
    });

    assertEquals(result, { outcome }, `outcome ${outcome}`);
  }
});

Deno.test("promote fails closed when created target differs from the request", async () => {
  const client = new FakeAdminClient();
  client.queueRpc({
    data: [promotionRow("created", "event", 43)],
    error: null,
  });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );

  await assertRejects(
    () =>
      store.promote({
        id: 7,
        target: "place",
        handledBy: "00000000-0000-4000-8000-000000000001",
      }),
    AdminSubmissionStoreError,
  );
});

Deno.test("promote requires exactly one outcome row", async () => {
  // Empty response.
  const emptyClient = new FakeAdminClient();
  emptyClient.queueRpc({ data: [], error: null });
  const emptyStore = createAdminSubmissionStore(
    emptyClient as unknown as SupabaseClient<Database>,
  );
  await assertRejects(
    () =>
      emptyStore.promote({
        id: 7,
        target: "place",
        handledBy: "00000000-0000-4000-8000-000000000001",
      }),
    AdminSubmissionStoreError,
  );

  // Null response.
  const nullClient = new FakeAdminClient();
  nullClient.queueRpc({ data: null, error: null });
  const nullStore = createAdminSubmissionStore(
    nullClient as unknown as SupabaseClient<Database>,
  );
  await assertRejects(
    () =>
      nullStore.promote({
        id: 7,
        target: "place",
        handledBy: "00000000-0000-4000-8000-000000000001",
      }),
    AdminSubmissionStoreError,
  );

  // Multiple rows are impossible legitimate data and fail closed.
  const multiClient = new FakeAdminClient();
  multiClient.queueRpc({
    data: [
      promotionRow("created", "place", 42),
      promotionRow("created", "place", 42),
    ],
    error: null,
  });
  const multiStore = createAdminSubmissionStore(
    multiClient as unknown as SupabaseClient<Database>,
  );
  await assertRejects(
    () =>
      multiStore.promote({
        id: 7,
        target: "place",
        handledBy: "00000000-0000-4000-8000-000000000001",
      }),
    AdminSubmissionStoreError,
  );
});

Deno.test("promote fails closed on malformed success payloads", async () => {
  for (
    const row of [
      // Unknown / malformed target type.
      promotionRow("created", "venue", 42),
      promotionRow("created", null, 42),
      promotionRow("already_promoted", "places", 42),
      // Malformed entity IDs: numeric string, zero, negative, fractional,
      // unsafe beyond 2^53.
      promotionRow("created", "place", "42"),
      promotionRow("created", "place", 0),
      promotionRow("created", "place", -1),
      promotionRow("created", "place", 42.5),
      promotionRow("created", "place", Number.MAX_SAFE_INTEGER + 1),
      promotionRow("already_promoted", "event", null),
    ]
  ) {
    const client = new FakeAdminClient();
    client.queueRpc({ data: [row], error: null });
    const store = createAdminSubmissionStore(
      client as unknown as SupabaseClient<Database>,
    );

    await assertRejects(
      () =>
        store.promote({
          id: 7,
          target: "place",
          handledBy: "00000000-0000-4000-8000-000000000001",
        }),
      AdminSubmissionStoreError,
    );
  }
});

Deno.test("promote fails closed when a domain failure carries a payload", async () => {
  for (
    const row of [
      // Non-success outcomes must carry NULL target_type AND entity_id; any
      // populated payload is malformed contract data.
      promotionRow("not_pending", "place", null),
      promotionRow("invalid_name", null, 42),
      promotionRow("coordinates_required", "place", 42),
      promotionRow("city_not_found", "", null),
      promotionRow("category_required", null, 42),
    ]
  ) {
    const client = new FakeAdminClient();
    client.queueRpc({ data: [row], error: null });
    const store = createAdminSubmissionStore(
      client as unknown as SupabaseClient<Database>,
    );

    await assertRejects(
      () =>
        store.promote({
          id: 7,
          target: "place",
          handledBy: "00000000-0000-4000-8000-000000000001",
        }),
      AdminSubmissionStoreError,
    );
  }
});

Deno.test("promote fails closed when a failure row omits its payload", async () => {
  for (
    const row of [
      { outcome: "not_pending", entity_id: null },
      { outcome: "not_pending", target_type: null },
      { outcome: "not_pending" },
      { outcome: "category_required", entity_id: null },
    ]
  ) {
    const client = new FakeAdminClient();
    client.queueRpc({ data: [row], error: null });
    const store = createAdminSubmissionStore(
      client as unknown as SupabaseClient<Database>,
    );

    await assertRejects(
      () =>
        store.promote({
          id: 7,
          target: "place",
          handledBy: "00000000-0000-4000-8000-000000000001",
        }),
      AdminSubmissionStoreError,
    );
  }
});

Deno.test("promote fails closed when its outcome row is not an object", async () => {
  for (const row of [null, "not-an-object", ["not-an-object"]]) {
    const client = new FakeAdminClient();
    client.queueRpc({ data: [row], error: null });
    const store = createAdminSubmissionStore(
      client as unknown as SupabaseClient<Database>,
    );

    await assertRejects(
      () =>
        store.promote({
          id: 7,
          target: "place",
          handledBy: "00000000-0000-4000-8000-000000000001",
        }),
      AdminSubmissionStoreError,
    );
  }
});

Deno.test("promote rejects unknown outcomes and RPC errors", async () => {
  const unknownOutcomeClient = new FakeAdminClient();
  unknownOutcomeClient.queueRpc({
    data: [promotionRow("exploded", null, null)],
    error: null,
  });
  const unknownOutcomeStore = createAdminSubmissionStore(
    unknownOutcomeClient as unknown as SupabaseClient<Database>,
  );
  await assertRejects(
    () =>
      unknownOutcomeStore.promote({
        id: 7,
        target: "place",
        handledBy: "00000000-0000-4000-8000-000000000001",
      }),
    AdminSubmissionStoreError,
  );

  const rpcErrorClient = new FakeAdminClient();
  rpcErrorClient.queueRpc({ data: null, error: { message: "rpc boom" } });
  const rpcErrorStore = createAdminSubmissionStore(
    rpcErrorClient as unknown as SupabaseClient<Database>,
  );
  await assertRejects(
    () =>
      rpcErrorStore.promote({
        id: 7,
        target: "place",
        handledBy: "00000000-0000-4000-8000-000000000001",
      }),
    AdminSubmissionStoreError,
  );
});
