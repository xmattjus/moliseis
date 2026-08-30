import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import type { User } from "npm:@supabase/supabase-js@2.112.3";

import {
  type AddAssetStoreResult,
  type AdminSubmissionStore,
  AdminSubmissionStoreError,
  type ChangeStatusStoreResult,
  type DeleteAssetStoreResult,
  type PromoteStoreResult,
  type SubmissionRecord,
  type UpdateStoreResult,
} from "./admin_submission_store.ts";
import {
  createHandler,
  type HandlerDependencies,
  resolveNamedOrLegacyKey,
} from "./index.ts";

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

const adminUser = (overrides: Partial<User> = {}): User => ({
  id: "00000000-0000-4000-8000-000000000001",
  app_metadata: { admin: true },
  user_metadata: { name: " Plan Admin " },
  aud: "authenticated",
  created_at: "2026-08-21T10:00:00.000Z",
  email: " admin@example.test ",
  ...overrides,
});

const input = () => ({
  category: "unknown",
  city: "Campobasso",
  name: "Plan A",
  description: null,
  description_delta: null,
  start_date: null,
  end_date: null,
  latitude: null,
  longitude: null,
});

class FakeStore implements AdminSubmissionStore {
  calls: string[] = [];
  createValues: unknown;
  updateValues: unknown;
  statusValues: unknown;
  promoteValues: unknown;
  addAssetValues: unknown;
  deleteAssetValues: unknown;
  listResult = [record];
  getResult: Awaited<ReturnType<AdminSubmissionStore["getById"]>> = {
    submission: record,
    assets: [{
      id: 2,
      url: "https://example.test/a.jpg",
      width: 100,
      height: 80,
    }],
  };
  createResult = { ...record, status: "pending" as const };
  updateResults: UpdateStoreResult[] = [
    { outcome: "updated", submission: { ...record, status: "pending" } },
  ];
  statusResults: ChangeStatusStoreResult[] = ["updated"];
  promoteResults: PromoteStoreResult[] = [];
  promoteCalls: Array<Parameters<AdminSubmissionStore["promote"]>[0]> = [];
  addAssetResults: AddAssetStoreResult[] = [{
    outcome: "created",
    asset: {
      id: 3,
      url: "https://res.cloudinary.com/demo/image/upload/v1/new.jpg",
      width: 1600,
      height: 1200,
    },
  }];
  deleteAssetResults: DeleteAssetStoreResult[] = ["deleted"];
  error: Error | null = null;

  async list(): Promise<SubmissionRecord[]> {
    this.calls.push("list");
    if (this.error) throw this.error;
    return this.listResult;
  }

  async getById(): ReturnType<AdminSubmissionStore["getById"]> {
    this.calls.push("getById");
    if (this.error) throw this.error;
    return this.getResult;
  }

  async create(
    values: Parameters<AdminSubmissionStore["create"]>[0],
  ): Promise<SubmissionRecord> {
    this.calls.push("create");
    this.createValues = values;
    if (this.error) throw this.error;
    return this.createResult;
  }

  async update(
    ...args: Parameters<AdminSubmissionStore["update"]>
  ): Promise<UpdateStoreResult> {
    this.calls.push("update");
    this.updateValues = args;
    if (this.error) throw this.error;
    return this.updateResults.shift() ??
      { outcome: "not_found" };
  }

  async changeStatus(
    params: Parameters<AdminSubmissionStore["changeStatus"]>[0],
  ): Promise<ChangeStatusStoreResult> {
    this.calls.push("changeStatus");
    this.statusValues = params;
    if (this.error) throw this.error;
    return this.statusResults.shift() ?? "not_pending";
  }

  async promote(
    params: Parameters<AdminSubmissionStore["promote"]>[0],
  ): Promise<PromoteStoreResult> {
    this.calls.push("promote");
    this.promoteCalls.push(params);
    this.promoteValues = params;
    if (this.error) throw this.error;
    return this.promoteResults.shift() ?? { outcome: "not_pending" };
  }

  async addAsset(
    ...args: Parameters<AdminSubmissionStore["addAsset"]>
  ): Promise<AddAssetStoreResult> {
    this.calls.push("addAsset");
    this.addAssetValues = args;
    if (this.error) throw this.error;
    return this.addAssetResults.shift() ?? { outcome: "not_pending" };
  }

  async deleteAsset(
    ...args: Parameters<AdminSubmissionStore["deleteAsset"]>
  ): Promise<DeleteAssetStoreResult> {
    this.calls.push("deleteAsset");
    this.deleteAssetValues = args;
    if (this.error) throw this.error;
    return this.deleteAssetResults.shift() ?? "not_pending";
  }
}

function testHandler(
  user: User | null = adminUser(),
  store = new FakeStore(),
): {
  handler: (request: Request) => Promise<Response>;
  store: FakeStore;
  created: () => number;
} {
  let storeCreations = 0;
  const dependencies: HandlerDependencies = {
    authenticate: async () => user,
    createStore: () => {
      storeCreations += 1;
      return store;
    },
    nowIso: () => "2026-08-21T11:00:00.000Z",
  };
  return {
    handler: createHandler(dependencies),
    store,
    created: () => storeCreations,
  };
}

function request(body: unknown, authorization = "Bearer valid-token"): Request {
  return new Request("https://example.test/admin-content-submissions", {
    method: "POST",
    headers: {
      Authorization: authorization,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

async function responseJson(
  response: Response,
): Promise<Record<string, unknown>> {
  assertEquals(response.headers.get("cache-control"), "no-store");
  assert(response.headers.get("access-control-allow-origin") !== null);
  return await response.json();
}

Deno.test("handles OPTIONS and non-POST requests before auth or store construction", async () => {
  const { handler, created, store } = testHandler(null);
  const options = await handler(
    new Request("https://example.test", { method: "OPTIONS" }),
  );
  assertEquals(options.status, 200);
  assertEquals(await responseJson(options), { ok: true });

  const method = await handler(
    new Request("https://example.test", { method: "GET" }),
  );
  assertEquals(method.status, 405);
  assertEquals(method.headers.get("allow"), "POST, OPTIONS");
  assertEquals((await responseJson(method)).code, "METHOD_NOT_ALLOWED");
  assertEquals(created(), 0);
  assertEquals(store.calls, []);
});

Deno.test("rejects invalid, anonymous, and non-admin authorization before store construction", async () => {
  for (
    const authorization of [
      "",
      "Bearer ",
      "Bearer token extra",
      "Bearer token,other",
    ]
  ) {
    const { handler, created, store } = testHandler();
    const response = await handler(
      request({ operation: "list" }, authorization),
    );
    assertEquals(response.status, 401);
    assertEquals((await responseJson(response)).code, "UNAUTHORIZED");
    assertEquals(created(), 0);
    assertEquals(store.calls, []);
  }
  for (
    const user of [
      null,
      adminUser({ is_anonymous: true }),
      adminUser({ app_metadata: { admin: false } }),
      adminUser({ app_metadata: { admin: "true" } }),
    ]
  ) {
    const { handler, created, store } = testHandler(user);
    const response = await handler(request({ operation: "list" }));
    assertEquals(response.status, user === null ? 401 : 403);
    assertEquals(created(), 0);
    assertEquals(store.calls, []);
  }
});

Deno.test("rejects malformed and oversized requests before store construction", async () => {
  const malformed = testHandler();
  const malformedResponse = await malformed.handler(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer valid-token" },
      body: "not-json",
    }),
  );
  assertEquals(malformedResponse.status, 400);
  assertEquals((await responseJson(malformedResponse)).code, "INVALID_JSON");
  assertEquals(malformed.created(), 0);

  const oversized = testHandler();
  const oversizedResponse = await oversized.handler(
    new Request("https://example.test", {
      method: "POST",
      headers: { Authorization: "Bearer valid-token" },
      body: "x".repeat(131073),
    }),
  );
  assertEquals(oversizedResponse.status, 413);
  assertEquals(
    (await responseJson(oversizedResponse)).code,
    "REQUEST_TOO_LARGE",
  );
  assertEquals(oversized.created(), 0);
});

Deno.test("maps list and detail DTOs without exposing internal fields", async () => {
  const list = testHandler();
  const listResponse = await list.handler(request({ operation: "list" }));
  assertEquals(listResponse.status, 200);
  const listBody = await responseJson(listResponse);
  assertEquals(list.created(), 1);
  assertEquals(
    (listBody.submissions as Array<Record<string, unknown>>)[0].assets,
    [],
  );
  assertEquals(
    Object.keys((listBody.submissions as Array<Record<string, unknown>>)[0])
      .sort(),
    [
      "assets",
      "category",
      "city",
      "created_at",
      "description",
      "description_delta",
      "end_date",
      "id",
      "latitude",
      "longitude",
      "modified_at",
      "name",
      "promoted_event_id",
      "promoted_place_id",
      "start_date",
      "status",
      "user_email",
      "user_name",
    ],
  );

  const detail = testHandler();
  const detailResponse = await detail.handler(
    request({ operation: "getById", submission_id: 7 }),
  );
  const detailBody = await responseJson(detailResponse);
  assertEquals(detail.created(), 1);
  assertEquals((detailBody.submission as Record<string, unknown>).assets, [{
    id: 2,
    url: "https://example.test/a.jpg",
    width: 100,
    height: 80,
  }]);
  detail.store.getResult = null;
  const missing = await detail.handler(
    request({ operation: "getById", submission_id: 8 }),
  );
  assertEquals(missing.status, 404);
});

Deno.test("passes validated coordinates to the store and round-trips them", async () => {
  const locatedRecord = {
    ...record,
    latitude: 41.5575078,
    longitude: 14.6485406,
  };

  const listedStore = new FakeStore();
  listedStore.listResult = [locatedRecord];
  const listed = testHandler(adminUser(), listedStore);
  const listResponse = await listed.handler(request({ operation: "list" }));
  assertEquals(listResponse.status, 200);
  assertEquals(
    (await responseJson(listResponse)).submissions,
    [{ ...locatedRecord, assets: [] }],
  );

  const detailedStore = new FakeStore();
  detailedStore.getResult = { submission: locatedRecord, assets: [] };
  const detailed = testHandler(adminUser(), detailedStore);
  const detailResponse = await detailed.handler(
    request({ operation: "getById", submission_id: 7 }),
  );
  assertEquals(detailResponse.status, 200);
  assertEquals(
    await responseJson(detailResponse),
    { submission: { ...locatedRecord, assets: [] } },
  );

  const createdInput = {
    category: "unknown",
    city: "Campobasso",
    name: "Plan A",
    description: null,
    description_delta: null,
    start_date: null,
    end_date: null,
    latitude: 41.5575078,
    longitude: 14.6485406,
  };
  const createdStore = new FakeStore();
  createdStore.createResult = { ...locatedRecord, status: "pending" as const };
  const created = testHandler(adminUser(), createdStore);
  const createResponse = await created.handler(
    request({ operation: "create", input: createdInput }),
  );
  assertEquals(createResponse.status, 200);
  assertEquals(created.store.createValues, {
    ...createdInput,
    user_id: "00000000-0000-4000-8000-000000000001",
    user_email: "admin@example.test",
    user_name: "Plan Admin",
  });
  assertEquals(
    await responseJson(createResponse),
    { submission: { ...locatedRecord, assets: [] } },
  );

  const updatedInput = {
    ...createdInput,
    latitude: null,
    longitude: null,
  };
  const clearedRecord = { ...record, status: "pending" as const };
  const updatedStore = new FakeStore();
  updatedStore.updateResults = [
    { outcome: "updated", submission: clearedRecord },
  ];
  const updated = testHandler(adminUser(), updatedStore);
  const updateResponse = await updated.handler(
    request({
      operation: "update",
      submission_id: 7,
      input: updatedInput,
    }),
  );
  assertEquals(updateResponse.status, 200);
  assertEquals(updated.store.updateValues, [
    7,
    updatedInput,
    "2026-08-21T11:00:00.000Z",
  ]);
  assertEquals(
    await responseJson(updateResponse),
    { submission: { ...clearedRecord, assets: [] } },
  );
});

Deno.test("creates with server-authoritative identity and validates the admin profile first", async () => {
  const success = testHandler();
  const response = await success.handler(
    request({ operation: "create", input: input() }),
  );
  assertEquals(response.status, 200);
  assertEquals(success.created(), 1);
  assertEquals(success.store.createValues, {
    ...input(),
    user_id: "00000000-0000-4000-8000-000000000001",
    user_email: "admin@example.test",
    user_name: "Plan Admin",
  });
  assertEquals(
    ((await responseJson(response)).submission as Record<string, unknown>)
      .assets,
    [],
  );

  for (
    const user of [
      adminUser({ email: undefined }),
      adminUser({ email: "invalid" }),
      adminUser({ user_metadata: { name: " " } }),
      adminUser({ user_metadata: { name: "a".repeat(101) } }),
    ]
  ) {
    const incomplete = testHandler(user);
    const incompleteResponse = await incomplete.handler(
      request({ operation: "create", input: input() }),
    );
    assertEquals(incompleteResponse.status, 422);
    assertEquals(
      (await responseJson(incompleteResponse)).code,
      "ADMIN_PROFILE_INCOMPLETE",
    );
    assertEquals(incomplete.created(), 0);
  }
});

Deno.test("maps pending-guarded update outcomes without collapsing 409", async () => {
  const updated = testHandler();
  const updatedResponse = await updated.handler(
    request({ operation: "update", submission_id: 7, input: input() }),
  );
  assertEquals(updatedResponse.status, 200);
  assertEquals(updated.created(), 1);
  assertEquals(updated.store.updateValues, [
    7,
    input(),
    "2026-08-21T11:00:00.000Z",
  ]);
  assertEquals(await responseJson(updatedResponse), {
    submission: { ...record, status: "pending", assets: [] },
  });

  const missing = testHandler();
  missing.store.updateResults = [{ outcome: "not_found" }];
  const missingResponse = await missing.handler(
    request({ operation: "update", submission_id: 8, input: input() }),
  );
  assertEquals(missingResponse.status, 404);
  assertEquals((await responseJson(missingResponse)).code, "NOT_FOUND");

  const moderated = testHandler();
  moderated.store.updateResults = [{ outcome: "not_pending" }];
  const moderatedResponse = await moderated.handler(
    request({ operation: "update", submission_id: 7, input: input() }),
  );
  assertEquals(moderatedResponse.status, 409);
  assertEquals(
    (await responseJson(moderatedResponse)).code,
    "INVALID_STATUS_TRANSITION",
  );
});

Deno.test("rejects clean pending submissions and maps failure outcomes", async () => {
  const rejected = testHandler();
  rejected.store.statusResults = ["updated"];
  const rejectedResponse = await rejected.handler(
    request({
      operation: "changeStatus",
      submission_id: 7,
      status: "rejected",
    }),
  );
  assertEquals(rejectedResponse.status, 200);
  assertEquals(await responseJson(rejectedResponse), {
    ok: true,
    status: "rejected",
  });
  assertEquals(rejected.store.statusValues, {
    id: 7,
    status: "rejected",
    handledBy: "00000000-0000-4000-8000-000000000001",
    modifiedAt: "2026-08-21T11:00:00.000Z",
  });

  for (
    const [result, status, code] of [
      ["not_found", 404, "NOT_FOUND"],
      ["not_pending", 409, "INVALID_STATUS_TRANSITION"],
    ] as const
  ) {
    const failed = testHandler();
    failed.store.statusResults = [result];
    const failedResponse = await failed.handler(
      request({
        operation: "changeStatus",
        submission_id: 7,
        status: "rejected",
      }),
    );
    assertEquals(failedResponse.status, status);
    assertEquals((await responseJson(failedResponse)).code, code);
  }
});

Deno.test("rejects accepted-status requests before store construction", async () => {
  const { handler, created, store } = testHandler();
  const response = await handler(
    request({
      operation: "changeStatus",
      submission_id: 7,
      status: "accepted",
    }),
  );
  assertEquals(response.status, 400);
  assertEquals((await responseJson(response)).code, "VALIDATION_ERROR");
  assertEquals(created(), 0);
  assertEquals(store.calls, []);
});

Deno.test("promotes with the authenticated handler and returns the envelope", async () => {
  const created = testHandler();
  created.store.promoteResults = [{
    outcome: "created",
    target: "place",
    entityId: 42,
  }];
  const createdResponse = await created.handler(
    request({ operation: "promote", submission_id: 7, target: "place" }),
  );
  assertEquals(createdResponse.status, 200);
  assertEquals(await responseJson(createdResponse), {
    promotion: { target_type: "place", entity_id: 42 },
  });
  assertEquals(created.store.promoteValues, {
    id: 7,
    target: "place",
    handledBy: "00000000-0000-4000-8000-000000000001",
  });

  // Same-target already_promoted retry is idempotent success with the same
  // response envelope.
  const retried = testHandler();
  retried.store.promoteResults = [{
    outcome: "already_promoted",
    target: "event",
    entityId: 43,
  }];
  const retriedResponse = await retried.handler(
    request({ operation: "promote", submission_id: 7, target: "event" }),
  );
  assertEquals(retriedResponse.status, 200);
  assertEquals(await responseJson(retriedResponse), {
    promotion: { target_type: "event", entity_id: 43 },
  });
});

Deno.test("conflicts when a promoted submission is retried with another target", async () => {
  const conflict = testHandler();
  conflict.store.promoteResults = [{
    outcome: "already_promoted",
    target: "event",
    entityId: 43,
  }];
  const conflictResponse = await conflict.handler(
    request({ operation: "promote", submission_id: 7, target: "place" }),
  );
  assertEquals(conflictResponse.status, 409);
  assertEquals(
    (await responseJson(conflictResponse)).code,
    "PROMOTION_TARGET_CONFLICT",
  );
});

Deno.test("maps every promotion readiness outcome to a stable error", async () => {
  const outcomes: Array<[PromoteStoreResult, number, string]> = [
    [{ outcome: "not_found" }, 404, "NOT_FOUND"],
    [{ outcome: "not_pending" }, 409, "INVALID_STATUS_TRANSITION"],
    [{ outcome: "invalid_name" }, 422, "PROMOTION_INVALID_NAME"],
    [
      { outcome: "coordinates_required" },
      422,
      "PROMOTION_COORDINATES_REQUIRED",
    ],
    [
      { outcome: "invalid_coordinates" },
      422,
      "PROMOTION_INVALID_COORDINATES",
    ],
    [{ outcome: "city_not_found" }, 422, "PROMOTION_CITY_NOT_FOUND"],
    [
      { outcome: "place_has_event_dates" },
      422,
      "PROMOTION_PLACE_HAS_EVENT_DATES",
    ],
    [
      { outcome: "start_date_required" },
      422,
      "PROMOTION_START_DATE_REQUIRED",
    ],
    [{ outcome: "invalid_date_range" }, 422, "PROMOTION_INVALID_DATE_RANGE"],
    [{ outcome: "invalid_asset" }, 422, "PROMOTION_INVALID_ASSET"],
    [
      { outcome: "category_required" },
      422,
      "PROMOTION_CATEGORY_REQUIRED",
    ],
  ];
  for (const [result, status, code] of outcomes) {
    const test = testHandler();
    test.store.promoteResults = [result];
    const response = await test.handler(
      request({ operation: "promote", submission_id: 7, target: "place" }),
    );
    assertEquals(response.status, status);
    const responseBody = await responseJson(response);
    assertEquals(responseBody.code, code);
    if (result.outcome === "category_required") {
      assertEquals(
        responseBody.message,
        "The submission requires a category before publication.",
      );
    }
  }
});

Deno.test("adds assets and maps expected asset-add outcomes", async () => {
  const success = testHandler();
  const asset = {
    url: "https://res.cloudinary.com/demo/image/upload/v1/new.jpg",
    width: 1600,
    height: 1200,
    mime_type: "image/jpeg",
    duration_seconds: null,
  };
  const response = await success.handler(
    request({ operation: "addAsset", submission_id: 7, asset }),
  );
  assertEquals(response.status, 200);
  assertEquals(await responseJson(response), {
    asset: {
      id: 3,
      url: asset.url,
      width: asset.width,
      height: asset.height,
    },
  });
  assertEquals(success.store.addAssetValues, [7, asset]);

  for (
    const [result, status, code] of [
      [{ outcome: "not_found" }, 404, "NOT_FOUND"],
      [{ outcome: "not_pending" }, 409, "INVALID_STATUS_TRANSITION"],
      [{ outcome: "limit_reached" }, 409, "ASSET_LIMIT_REACHED"],
    ] as const
  ) {
    const test = testHandler();
    test.store.addAssetResults = [result];
    const failedResponse = await test.handler(
      request({ operation: "addAsset", submission_id: 7, asset }),
    );
    assertEquals(failedResponse.status, status);
    assertEquals((await responseJson(failedResponse)).code, code);
  }
});

Deno.test("deletes assets and maps expected asset-delete outcomes", async () => {
  const success = testHandler();
  const response = await success.handler(
    request({ operation: "deleteAsset", submission_id: 7, asset_id: 3 }),
  );
  assertEquals(response.status, 200);
  assertEquals(await responseJson(response), { ok: true });
  assertEquals(success.store.deleteAssetValues, [7, 3]);

  for (
    const [result, status, code] of [
      ["not_found", 404, "NOT_FOUND"],
      ["asset_not_found", 404, "ASSET_NOT_FOUND"],
      ["not_pending", 409, "INVALID_STATUS_TRANSITION"],
    ] as const
  ) {
    const test = testHandler();
    test.store.deleteAssetResults = [result];
    const failedResponse = await test.handler(
      request({ operation: "deleteAsset", submission_id: 7, asset_id: 3 }),
    );
    assertEquals(failedResponse.status, status);
    assertEquals((await responseJson(failedResponse)).code, code);
  }
});

Deno.test("rejects non-admin asset mutations before store construction", async () => {
  const { handler, created, store } = testHandler(
    adminUser({ app_metadata: { admin: false } }),
  );

  const response = await handler(
    request({
      operation: "addAsset",
      submission_id: 7,
      asset: {
        url: "https://res.cloudinary.com/demo/image/upload/v1/new.jpg",
        width: 1600,
        height: 1200,
        mime_type: null,
        duration_seconds: null,
      },
    }),
  );

  assertEquals(response.status, 403);
  assertEquals(created(), 0);
  assertEquals(store.calls, []);
});

Deno.test("sanitizes database and unexpected errors", async () => {
  const database = testHandler();
  database.store.error = new AdminSubmissionStoreError({
    message: "database details",
  });
  const databaseResponse = await database.handler(
    request({ operation: "list" }),
  );
  assertEquals(databaseResponse.status, 500);
  assertEquals(await responseJson(databaseResponse), {
    code: "DATABASE_ERROR",
    message: "The submission database operation failed.",
  });

  const dependencies: HandlerDependencies = {
    authenticate: async () => {
      throw new Error("unexpected");
    },
    createStore: () => new FakeStore(),
    nowIso: () => "2026-08-21T11:00:00.000Z",
  };
  const internalResponse = await createHandler(dependencies)(
    request({ operation: "list" }),
  );
  assertEquals(internalResponse.status, 500);
  assertEquals((await responseJson(internalResponse)).code, "INTERNAL_ERROR");
});

Deno.test("resolves named and legacy keys without environment access", () => {
  assertEquals(
    resolveNamedOrLegacyKey({
      namedKeysJson: '{"default":" named "}',
      legacyKey: "legacy",
      keyName: "default",
    }),
    "named",
  );
  assertEquals(
    resolveNamedOrLegacyKey({
      namedKeysJson: " ",
      legacyKey: " legacy ",
      keyName: "default",
    }),
    "legacy",
  );
  for (
    const namedKeysJson of ["{", "[]", "{}", '{"default":1}', '{"default":" "}']
  ) {
    assertThrows(() =>
      resolveNamedOrLegacyKey({
        namedKeysJson,
        legacyKey: "legacy",
        keyName: "default",
      })
    );
  }
  assertThrows(() =>
    resolveNamedOrLegacyKey({
      namedKeysJson: null,
      legacyKey: " ",
      keyName: "default",
    })
  );
});
