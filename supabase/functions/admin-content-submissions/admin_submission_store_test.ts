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
  all_day: false,
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
  external_event_record_id: null,
  external_normalized: null,
  external_normalization_version: null,
  external_moderation_hash: null,
  target_event_id: null,
};

type RecordedQuery = {
  table: string;
  updateValues: Record<string, unknown> | null;
  insertValues: Record<string, unknown> | null;
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

  is(column: string, value: unknown): this {
    this.#recorded.filters.push([column, value]);
    return this;
  }
  not(column: string, operator: string, value: unknown): this {
    this.#recorded.filters.push([`${column}:${operator}`, value]);
    return this;
  }
  then(
    resolve: (value: QueryResponse) => unknown,
    reject?: (reason: unknown) => unknown,
  ) {
    return Promise.resolve(this.#client.nextQueryResult()).then(
      resolve,
      reject,
    );
  }
  in(column: string, values: unknown[]): this {
    this.#recorded.filters.push([column, values]);
    return this;
  }
  order(): this {
    return this;
  }

  insert(values: Record<string, unknown>): this {
    this.#recorded.insertValues = values;
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
      insertValues: null,
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
    all_day: false,
    latitude: null,
    longitude: null,
  }, "2026-08-21T11:00:00.000Z");

  assertEquals(result, { outcome: "updated", submission: record });
  const query = client.queries[0];
  assertEquals(query.table, "content_submissions");
  assert(query.updateValues !== null);
  // Both guards must be present on the UPDATE itself: the id predicate AND the
  // status predicate that blocks accepted/rejected sources.
  assertEquals(query.filters, [["id", 7], ["status", "pending"], [
    "external_event_record_id",
    null,
  ]]);
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
      all_day: false,
      latitude: null,
      longitude: null,
    }, "2026-08-21T11:00:00.000Z"),
    { outcome: "not_found" },
  );
  // The classification lookup queried only id and status by the requested id.
  assertEquals(absentClient.queries[1].selects, [
    "id,status,external_event_record_id",
  ]);
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
      all_day: false,
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
        all_day: false,
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
        all_day: false,
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

Deno.test("Admin create/update/read carry normalized all-day mode with the dates", async () => {
  for (const allDay of [false, true]) {
    const values = {
      category: "history" as const,
      city: "Campobasso",
      name: "Test",
      description: null,
      description_delta: null,
      all_day: allDay,
      start_date: allDay ? "2026-10-11T22:00:00.000Z" : null,
      end_date: allDay ? "2026-10-14T21:59:59.999999Z" : null,
      latitude: null,
      longitude: null,
    };
    const stored = { ...record, ...values };
    const client = new FakeAdminClient();
    const store = createAdminSubmissionStore(
      client as unknown as SupabaseClient<Database>,
    );
    client.queueQuery({ data: stored, error: null });
    assertEquals(
      await store.create({
        ...values,
        user_id: "00000000-0000-4000-8000-000000000002",
        user_email: "test@example.test",
        user_name: "Test",
      }),
      stored,
    );
    assertEquals(client.queries[0].insertValues?.all_day, allDay);
    assertEquals(client.queries[0].insertValues?.start_date, values.start_date);
    assertEquals(client.queries[0].insertValues?.end_date, values.end_date);
    client.queueQuery({ data: stored, error: null });
    assertEquals(await store.update(7, values, "2026-10-01T12:00:00Z"), {
      outcome: "updated",
      submission: stored,
    });
    assertEquals(client.queries[1].updateValues, {
      ...values,
    });
    assertEquals(client.queries[1].filters, [
      ["id", 7],
      ["status", "pending"],
      ...(values.start_date === null
        ? [["external_event_record_id", null] as [string, unknown]]
        : []),
    ]);
    client.queueQuery({ data: stored, error: null });
    client.queueQuery({ data: [], error: null });
    assertEquals(await store.getById(7), {
      submission: stored,
      assets: [],
      currentSource: null,
    });
    assert(SUBMISSION_SELECT.split(",").includes("all_day"));
  }
});

Deno.test("changeStatus routes immutable imported provenance to authoritative reject without generic write", async () => {
  const client = new FakeAdminClient();
  client.queueQuery({
    data: { id: 7, external_event_record_id: 19 },
    error: null,
  });
  client.queueRpc({
    data: [{ outcome: "rejected", pending_submission_id: 8 }],
    error: null,
  });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  assertEquals(
    await store.changeStatus({
      id: 7,
      status: "rejected",
      handledBy: "admin",
      modifiedAt: "now",
    }),
    { outcome: "updated", pendingSubmissionId: 8 },
  );
  assertEquals(client.rpcCalls, [{
    functionName: "reject_external_event_submission",
    args: { p_submission_id: 7, p_handled_by: "admin" },
  }]);
  assertEquals(client.queries.length, 1);
  assertEquals(client.queries[0].updateValues, null);
});
Deno.test("changeStatus retains human pending-only rejection", async () => {
  const client = new FakeAdminClient();
  client.queueQuery({
    data: { id: 7, external_event_record_id: null },
    error: null,
  });
  client.queueQuery({ data: { id: 7 }, error: null });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  assertEquals(
    await store.changeStatus({
      id: 7,
      status: "rejected",
      handledBy: "admin",
      modifiedAt: "now",
    }),
    "updated",
  );
  assertEquals(client.rpcCalls, []);
  assertEquals(client.queries[1].updateValues, {
    status: "rejected",
    handled_by: "admin",
    modified_at: "now",
  });
  assertEquals(client.queries[1].filters, [["id", 7], ["status", "pending"], [
    "external_event_record_id",
    null,
  ]]);
});

Deno.test("Reject ignore option reaches RPC and is inapplicable to human content", async () => {
  const client = new FakeAdminClient();
  client.queueQuery({
    data: { id: 7, external_event_record_id: 19 },
    error: null,
  });
  client.queueRpc({
    data: [{ outcome: "rejected", pending_submission_id: null }],
    error: null,
  });
  client.queueQuery({
    data: { id: 8, external_event_record_id: null },
    error: null,
  });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  assertEquals(
    await store.changeStatus({
      id: 7,
      status: "rejected",
      handledBy: "verified-admin",
      modifiedAt: "now",
      ignoreSource: true,
    }),
    { outcome: "updated", pendingSubmissionId: null },
  );
  assertEquals(client.rpcCalls[0], {
    functionName: "reject_external_event_submission",
    args: {
      p_submission_id: 7,
      p_handled_by: "verified-admin",
      p_ignore_source: true,
    },
  });
  assertEquals(
    await store.changeStatus({
      id: 8,
      status: "rejected",
      handledBy: "verified-admin",
      modifiedAt: "now",
      ignoreSource: true,
    }),
    "not_imported",
  );
  assertEquals(client.queries[1].updateValues, null);
});

Deno.test("Ignored source list needs no pending and un-ignore parses pending outcome", async () => {
  const client = new FakeAdminClient();
  client.queueQuery({
    data: [{
      id: 19,
      provider: "eventimolise",
      external_id: "2",
      occurrence_key: null,
      normalized: { name: "Source name" },
      ignored_at: "now",
      event_id: null,
    }],
    error: null,
  });
  client.queueRpc({
    data: [{ outcome: "unignored", pending_submission_id: 9 }],
    error: null,
  });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  assertEquals(await store.listIgnoredSources(), [{
    id: 19,
    provider: "eventimolise",
    external_id: "2",
    occurrence_key: null,
    name: "Source name",
    ignored_at: "now",
    event_id: null,
  }]);
  assertEquals(client.queries[0].filters, [["ignored_at:is", null]]);
  assertEquals(await store.unIgnoreSource(19), {
    outcome: "unignored",
    pendingSubmissionId: 9,
  });
  assertEquals(client.rpcCalls[0], {
    functionName: "set_source_ignored",
    args: { p_external_event_record_id: 19, p_ignored: false },
  });
});

Deno.test("Imported detail shows current hash/snapshot but Reject passes original shown hash despite reread", async () => {
  const client = new FakeAdminClient();
  const shown = "a".repeat(64), current = "b".repeat(64);
  const imported = {
    ...record,
    external_event_record_id: 19,
    external_moderation_hash: "c".repeat(64),
  };
  client.queueQuery({ data: imported, error: null });
  client.queueQuery({ data: [], error: null });
  client.queueQuery({
    data: { moderation_hash: current, normalized: { name: "Current source" } },
    error: null,
  });
  client.queueQuery({
    data: { id: 7, external_event_record_id: 19 },
    error: null,
  });
  client.queueRpc({
    data: [{ outcome: "source_changed", pending_submission_id: null }],
    error: null,
  });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  assertEquals((await store.getById(7))?.currentSource, {
    moderation_hash: current,
    normalized: { name: "Current source" },
  });
  assertEquals(
    await store.changeStatus({
      id: 7,
      status: "rejected",
      handledBy: "verified-admin",
      modifiedAt: "now",
      acknowledgeCurrentSource: true,
      expectedSourceHash: shown,
    }),
    "source_changed",
  );
  assertEquals(client.rpcCalls[0], {
    functionName: "reject_external_event_submission",
    args: {
      p_submission_id: 7,
      p_handled_by: "verified-admin",
      p_acknowledge_current_source: true,
      p_expected_source_hash: shown,
    },
  });
  const human = new FakeAdminClient();
  human.queueQuery({
    data: { id: 8, external_event_record_id: null },
    error: null,
  });
  assertEquals(
    await createAdminSubmissionStore(
      human as unknown as SupabaseClient<Database>,
    ).changeStatus({
      id: 8,
      status: "rejected",
      handledBy: "admin",
      modifiedAt: "now",
      acknowledgeCurrentSource: true,
    }),
    "source_changed",
  );
  assertEquals(human.queries[0].updateValues, null);
});

Deno.test("Human rejection is guarded against concurrent verified provenance backfill", async () => {
  const client = new FakeAdminClient();
  client.queueQuery({
    data: { id: 7, external_event_record_id: null },
    error: null,
  });
  client.queueQuery({ data: null, error: null });
  client.queueQuery({
    data: { id: 7, status: "pending", external_event_record_id: 19 },
    error: null,
  });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  assertEquals(
    await store.changeStatus({
      id: 7,
      status: "rejected",
      handledBy: "admin",
      modifiedAt: "now",
    }),
    "external_requires_resolution",
  );
  assertEquals(client.queries[1].filters, [["id", 7], ["status", "pending"], [
    "external_event_record_id",
    null,
  ]]);
  assertEquals(client.queries[2].selects, [
    "id,status,external_event_record_id",
  ]);
  assertEquals(client.rpcCalls, []);
});

Deno.test("Linked source promotion failure is a closed domain result, never promotion success", async () => {
  const client = new FakeAdminClient();
  client.queueRpc({
    data: [promotionRow("source_already_linked", null, null)],
    error: null,
  });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  assertEquals(
    await store.promote({ id: 7, target: "event", handledBy: "admin" }),
    { outcome: "source_already_linked" },
  );
});

Deno.test("Link RPC receives verified actor/original hash and parses only closed outcome rows", async () => {
  const client = new FakeAdminClient();
  const hash = "a".repeat(64);
  client.queueRpc({
    data: [{ outcome: "linked", event_id: 19, pending_submission_id: 8 }],
    error: null,
  });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  assertEquals(
    await store.link({
      id: 7,
      targetEventId: 19,
      handledBy: "verified-admin",
      acknowledgeCurrentSource: true,
      expectedSourceHash: hash,
    }),
    { outcome: "linked", eventId: 19, pendingSubmissionId: 8 },
  );
  assertEquals(client.rpcCalls[0], {
    functionName: "link_content_submission_to_event",
    args: {
      p_submission_id: 7,
      p_target_event_id: 19,
      p_handled_by: "verified-admin",
      p_acknowledge_current_source: true,
      p_expected_source_hash: hash,
    },
  });
  for (
    const outcome of [
      "not_event_submission",
      "source_changed",
      "relink_conflict",
      "event_inactive",
    ] as const
  ) {
    client.queueRpc({
      data: [{ outcome, event_id: null, pending_submission_id: null }],
      error: null,
    });
    assertEquals(
      await store.link({ id: 7, targetEventId: 19, handledBy: "admin" }),
      { outcome },
    );
  }
  client.queueRpc({
    data: [{ outcome: "linked", event_id: 20, pending_submission_id: null }],
    error: null,
  });
  await assertRejects(
    () => store.link({ id: 7, targetEventId: 19, handledBy: "admin" }),
    AdminSubmissionStoreError,
  );
});

Deno.test("Apply store forwards closed server groups and original opaque preview tokens unchanged", async () => {
  const client = new FakeAdminClient();
  client.queueRpc({
    data: [{ outcome: "applied", event_id: 19, pending_submission_id: 8 }],
    error: null,
  });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  const params = {
    id: 7,
    targetEventId: 19,
    handledBy: "verified-admin",
    groupsToApply: [
      "description",
      "schedule",
    ] as ("description" | "schedule")[],
    submissionVersionToken: "2026-10-02T10:00:00.123456+00:00",
    eventVersionToken: "2026-10-02 11:00:00.654321+00",
    acknowledgeCurrentSource: true,
    expectedSourceHash: "a".repeat(64),
  };
  assertEquals(await store.apply(params), {
    outcome: "applied",
    eventId: 19,
    pendingSubmissionId: 8,
  });
  assertEquals(client.rpcCalls[0], {
    functionName: "apply_external_event_submission",
    args: {
      p_submission_id: 7,
      p_target_event_id: 19,
      p_handled_by: "verified-admin",
      p_groups_to_apply: params.groupsToApply,
      p_submission_version_token: params.submissionVersionToken,
      p_event_version_token: params.eventVersionToken,
      p_acknowledge_current_source: true,
      p_expected_source_hash: params.expectedSourceHash,
    },
  });
  for (
    const outcome of [
      "normalization_mismatch",
      "source_changed",
      "base_required",
      "event_changed",
      "submission_changed",
    ] as const
  ) {
    client.queueRpc({
      data: [{ outcome, event_id: null, pending_submission_id: null }],
      error: null,
    });
    assertEquals(await store.apply(params), { outcome });
  }
});

Deno.test("Promote transports original acknowledgement hash and parses source_changed", async () => {
  const client = new FakeAdminClient();
  client.queueRpc({
    data: [promotionRow("source_changed", null, null)],
    error: null,
  });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  const hash = "a".repeat(64);
  assertEquals(
    await store.promote({
      id: 7,
      target: "event",
      handledBy: "admin",
      acknowledgeCurrentSource: true,
      expectedSourceHash: hash,
    }),
    { outcome: "source_changed" },
  );
  assertEquals(client.rpcCalls[0], {
    functionName: "promote_content_submission",
    args: {
      p_submission_id: 7,
      p_target: "event",
      p_handled_by: "admin",
      p_acknowledge_current_source: true,
      p_expected_source_hash: hash,
    },
  });
});

Deno.test("Imported Save cannot remove Event start; persisted predicate covers human-to-imported race", async () => {
  const client = new FakeAdminClient();
  client.queueQuery({ data: null, error: null });
  client.queueQuery({
    data: { id: 7, status: "pending", external_event_record_id: 19 },
    error: null,
  });
  const store = createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  const input = {
    category: "history" as const,
    city: "Campobasso",
    name: "Human then imported",
    description: null,
    description_delta: null,
    start_date: null,
    end_date: null,
    all_day: false,
    latitude: null,
    longitude: null,
  };
  assertEquals(await store.update(7, input, "ignored"), {
    outcome: "start_date_required",
  });
  assertEquals(client.queries[0].filters, [["id", 7], ["status", "pending"], [
    "external_event_record_id",
    null,
  ]]);
  assertEquals(client.queries[1].selects, [
    "id,status,external_event_record_id",
  ]);
});

Deno.test("Apply store preserves stable temporal readiness failures from RPC", async () => {
  for (
    const outcome of ["start_date_required", "invalid_date_range"] as const
  ) {
    const client = new FakeAdminClient();
    client.queueRpc({
      data: [{ outcome, event_id: null, pending_submission_id: null }],
      error: null,
    });
    const store = createAdminSubmissionStore(
      client as unknown as SupabaseClient<Database>,
    );
    assertEquals(
      await store.apply({
        id: 7,
        targetEventId: 19,
        handledBy: "admin",
        groupsToApply: ["name"],
        submissionVersionToken: "2026-10-02T10:00:00.000001Z",
        eventVersionToken: "2026-10-02T10:00:00.000002Z",
      }),
      { outcome },
    );
  }
});

Deno.test("list batch-loads source mode and current state for create/update/human rows", async () => {
  const client = new FakeAdminClient();
  client.queueQuery({
    data: [{ id: 1, external_event_record_id: 12 }, {
      id: 2,
      external_event_record_id: 13,
    }, { id: 3, external_event_record_id: null }],
    error: null,
  });
  client.queueQuery({
    data: [{
      id: 12,
      moderation_hash: "x",
      normalized: { name: "Create" },
      event_id: null,
    }, {
      id: 13,
      moderation_hash: "y",
      normalized: { name: "Update" },
      event_id: 42,
    }],
    error: null,
  });
  const rows = await createAdminSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  ).list();
  assertEquals(rows[0].currentSource?.event_id, null);
  assertEquals(rows[1].currentSource?.event_id, 42);
  assertEquals(rows[2].currentSource, null);
  assertEquals(client.queries.length, 2);
  assertEquals(client.queries[1].filters, [["id", [12, 13]]]);
});
