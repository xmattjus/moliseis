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
  eventResolutionResponse,
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
  all_day: false,
  start_calendar_date: null,
  end_calendar_date: null,
  start_date: null,
  end_date: null,
  latitude: null,
  longitude: null,
});

function persistedInput<
  T extends { start_calendar_date: unknown; end_calendar_date: unknown },
>(value: T) {
  const { start_calendar_date: _start, end_calendar_date: _end, ...values } =
    value;
  return values;
}

class FakeStore implements AdminSubmissionStore {
  calls: string[] = [];
  applyValues: unknown;
  applyResult: Awaited<ReturnType<AdminSubmissionStore["apply"]>> = {
    outcome: "applied",
    eventId: 19,
    pendingSubmissionId: null,
  };
  apply(params: Parameters<AdminSubmissionStore["apply"]>[0]) {
    this.calls.push("apply");
    this.applyValues = params;
    return Promise.resolve(this.applyResult);
  }

  linkValues: unknown;
  linkResult: Awaited<ReturnType<AdminSubmissionStore["link"]>> = {
    outcome: "linked",
    eventId: 19,
    pendingSubmissionId: null,
  };
  link(params: Parameters<AdminSubmissionStore["link"]>[0]) {
    this.calls.push("link");
    this.linkValues = params;
    return Promise.resolve(this.linkResult);
  }

  ignoredSources: Awaited<
    ReturnType<AdminSubmissionStore["listIgnoredSources"]>
  > = [];
  unIgnoreResult: Awaited<ReturnType<AdminSubmissionStore["unIgnoreSource"]>> =
    { outcome: "unignored", pendingSubmissionId: 9 };
  listIgnoredSources() {
    this.calls.push("listIgnoredSources");
    return this.error
      ? Promise.reject(this.error)
      : Promise.resolve(this.ignoredSources);
  }
  unIgnoreSource(id: number) {
    this.calls.push(`unIgnoreSource:${id}`);
    return this.error
      ? Promise.reject(this.error)
      : Promise.resolve(this.unIgnoreResult);
  }

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

  externalRecordResult: Awaited<
    ReturnType<AdminSubmissionStore["getExternalRecord"]>
  > = null;
  eventResult: Awaited<ReturnType<AdminSubmissionStore["getEvent"]>> = null;
  getExternalRecord(): ReturnType<AdminSubmissionStore["getExternalRecord"]> {
    this.calls.push("getExternalRecord");
    return Promise.resolve(this.externalRecordResult);
  }
  getEvent(): ReturnType<AdminSubmissionStore["getEvent"]> {
    this.calls.push("getEvent");
    return Promise.resolve(this.eventResult);
  }
  findEventCandidates(): ReturnType<
    AdminSubmissionStore["findEventCandidates"]
  > {
    this.calls.push("findEventCandidates");
    return Promise.resolve({ events: [], pending_warnings: [] });
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
      "all_day",
      "assets",
      "category",
      "city",
      "created_at",
      "current_source_normalized",
      "description",
      "description_delta",
      "end_date",
      "external_event_id",
      "external_event_record_id",
      "external_mode",
      "external_moderation_hash",
      "external_normalization_version",
      "external_normalized",
      "id",
      "latitude",
      "longitude",
      "moderation_hash",
      "modified_at",
      "name",
      "promoted_event_id",
      "promoted_place_id",
      "start_date",
      "status",
      "target_event_id",
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
    [{
      ...locatedRecord,
      assets: [],
      moderation_hash: null,
      current_source_normalized: null,
      external_mode: null,
      external_event_id: null,
    }],
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
    {
      submission: {
        ...locatedRecord,
        assets: [],
        moderation_hash: null,
        current_source_normalized: null,
        external_mode: null,
        external_event_id: null,
      },
    },
  );

  const createdInput = {
    category: "unknown",
    city: "Campobasso",
    name: "Plan A",
    description: null,
    description_delta: null,
    all_day: false,
    start_calendar_date: null,
    end_calendar_date: null,
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
    ...persistedInput(createdInput),
    user_id: "00000000-0000-4000-8000-000000000001",
    user_email: "admin@example.test",
    user_name: "Plan Admin",
  });
  assertEquals(
    await responseJson(createResponse),
    {
      submission: {
        ...locatedRecord,
        assets: [],
        moderation_hash: null,
        current_source_normalized: null,
        external_mode: null,
        external_event_id: null,
      },
    },
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
    persistedInput(updatedInput),
    "2026-08-21T11:00:00.000Z",
  ]);
  assertEquals(
    await responseJson(updateResponse),
    {
      submission: {
        ...clearedRecord,
        assets: [],
        moderation_hash: null,
        current_source_normalized: null,
        external_mode: null,
        external_event_id: null,
      },
    },
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
    ...persistedInput(input()),
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
    persistedInput(input()),
    "2026-08-21T11:00:00.000Z",
  ]);
  assertEquals(await responseJson(updatedResponse), {
    submission: {
      ...record,
      status: "pending",
      assets: [],
      moderation_hash: null,
      current_source_normalized: null,
      external_mode: null,
      external_event_id: null,
    },
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

Deno.test("Admin handler creates, reads and updates both temporal modes without civil columns", async () => {
  for (const allDay of [false, true]) {
    const harness = testHandler(adminUser());
    const temporal = {
      ...input(),
      all_day: allDay,
      start_calendar_date: allDay ? "2026-03-29" : null,
      end_calendar_date: allDay ? "2026-03-29" : null,
    };
    const createResponse = await harness.handler(
      request({ operation: "create", input: temporal }),
    );
    assertEquals(createResponse.status, 200);
    const created = harness.store.createValues as Record<string, unknown>;
    assertEquals(created.all_day, allDay);
    assertEquals(
      created.start_date,
      allDay ? "2026-03-28T23:00:00.000Z" : null,
    );
    assertEquals(
      created.end_date,
      allDay ? "2026-03-29T21:59:59.999999Z" : null,
    );
    assertEquals(Object.hasOwn(created, "start_calendar_date"), false);
    const updateResponse = await harness.handler(
      request({ operation: "update", submission_id: 7, input: temporal }),
    );
    assertEquals(updateResponse.status, 200);
    const updatedInput = (harness.store.updateValues as unknown[])[1] as Record<
      string,
      unknown
    >;
    assertEquals(updatedInput.all_day, allDay);
    assertEquals(updatedInput.start_date, created.start_date);
    assertEquals(updatedInput.end_date, created.end_date);
    harness.store.getResult = {
      submission: {
        ...record,
        all_day: allDay,
        start_date: created.start_date as string | null,
        end_date: created.end_date as string | null,
      },
      assets: [],
    };
    const readResponse = await harness.handler(
      request({ operation: "getById", submission_id: 7 }),
    );
    assertEquals(readResponse.status, 200);
    const detail = (await responseJson(readResponse)).submission as Record<
      string,
      unknown
    >;
    assertEquals(detail.all_day, allDay);
    assertEquals(detail.start_date, created.start_date);
    assertEquals(detail.end_date, created.end_date);
  }
});

Deno.test("Reject ignore reaches store with verified actor and returns follow-up pending", async () => {
  const store = new FakeStore();
  store.statusResults = [{ outcome: "updated", pendingSubmissionId: 9 }];
  const handler = createHandler({
    authenticate: () => Promise.resolve(adminUser()),
    createStore: () => store,
    nowIso: () => "observed-now",
  });
  const response = await handler(
    new Request("http://localhost", {
      method: "POST",
      headers: { Authorization: "Bearer jwt" },
      body: JSON.stringify({
        operation: "changeStatus",
        submission_id: 7,
        status: "rejected",
        ignore_source: true,
      }),
    }),
  );
  assertEquals(response.status, 200);
  assertEquals(store.statusValues, {
    id: 7,
    status: "rejected",
    handledBy: adminUser().id,
    modifiedAt: "observed-now",
    ignoreSource: true,
  });
  assertEquals(await response.json(), {
    ok: true,
    status: "rejected",
    pending_submission_id: 9,
  });
});

Deno.test("Ignored source list and un-ignore are Admin-only, reachable without pending, and expose outcome", async () => {
  const body = { operation: "unIgnoreSource", external_event_record_id: 19 };
  const request = (payload: unknown) =>
    new Request("http://localhost", {
      method: "POST",
      headers: { Authorization: "Bearer jwt" },
      body: JSON.stringify(payload),
    });
  for (const operation of ["listIgnoredSources", "unIgnoreSource"]) {
    let constructed = false;
    const denied = createHandler({
      authenticate: () => Promise.resolve(adminUser({ app_metadata: {} })),
      createStore: () => {
        constructed = true;
        return new FakeStore();
      },
      nowIso: () => "now",
    });
    assertEquals(
      (await denied(
        request(operation === "listIgnoredSources" ? { operation } : body),
      )).status,
      403,
    );
    assertEquals(constructed, false);
  }
  const store = new FakeStore();
  store.getResult = null;
  store.ignoredSources = [{
    id: 19,
    provider: "eventimolise",
    external_id: "2",
    occurrence_key: null,
    name: "Ignored",
    ignored_at: "now",
    event_id: null,
  }];
  const handler = createHandler({
    authenticate: () => Promise.resolve(adminUser()),
    createStore: () => store,
    nowIso: () => "now",
  });
  const listed = await handler(request({ operation: "listIgnoredSources" }));
  assertEquals(await listed.json(), { sources: store.ignoredSources });
  const response = await handler(request(body));
  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    outcome: "unignored",
    pending_submission_id: 9,
  });
  assertEquals(store.calls, ["listIgnoredSources", "unIgnoreSource:19"]);
  store.unIgnoreResult = { outcome: "not_found" };
  assertEquals((await handler(request(body))).status, 404);
  store.error = new AdminSubmissionStoreError(new Error("identity missing"));
  assertEquals((await handler(request(body))).status, 500);
});

Deno.test("Stale detail and Reject acknowledgement preserve displayed hash and map source_changed409", async () => {
  const store = new FakeStore();
  const shown = "a".repeat(64);
  const newer = "b".repeat(64);
  store.getResult = {
    submission: {
      ...record,
      external_event_record_id: 19,
      external_moderation_hash: "c".repeat(64),
    },
    assets: [],
    currentSource: {
      moderation_hash: newer,
      normalized: { name: "Latest source" },
    },
  };
  const handler = createHandler({
    authenticate: () => Promise.resolve(adminUser()),
    createStore: () => store,
    nowIso: () => "now",
  });
  const req = (body: unknown) =>
    new Request("http://localhost", {
      method: "POST",
      headers: { Authorization: "Bearer jwt" },
      body: JSON.stringify(body),
    });
  const detail = await handler(req({ operation: "getById", submission_id: 7 }));
  const { submission } = await detail.json();
  assertEquals(submission.external_moderation_hash, "c".repeat(64));
  assertEquals(submission.moderation_hash, newer);
  assertEquals(submission.current_source_normalized, { name: "Latest source" });
  for (const expected of [shown, undefined]) {
    store.statusResults = ["source_changed"];
    const response = await handler(
      req({
        operation: "changeStatus",
        submission_id: 7,
        status: "rejected",
        acknowledge_current_source: true,
        ...(expected !== undefined ? { expected_source_hash: expected } : {}),
      }),
    );
    assertEquals(response.status, 409);
    assertEquals((await response.json()).code, "SOURCE_CHANGED");
    assertEquals(store.statusValues, {
      id: 7,
      status: "rejected",
      handledBy: adminUser().id,
      modifiedAt: "now",
      acknowledgeCurrentSource: true,
      ...(expected !== undefined ? { expectedSourceHash: expected } : {}),
    });
  }
  store.statusResults = [{ outcome: "updated", pendingSubmissionId: null }];
  const success = await handler(
    req({
      operation: "changeStatus",
      submission_id: 7,
      status: "rejected",
      acknowledge_current_source: true,
      expected_source_hash: shown,
    }),
  );
  assertEquals(success.status, 200);
  assertEquals(await success.json(), {
    ok: true,
    status: "rejected",
    pending_submission_id: null,
  });
});

Deno.test("Provenance added during human Reject returns stable resolution conflict", async () => {
  const test = testHandler();
  test.store.statusResults = ["external_requires_resolution"];
  const response = await test.handler(
    request({
      operation: "changeStatus",
      submission_id: 7,
      status: "rejected",
    }),
  );
  assertEquals(response.status, 409);
  assertEquals((await response.json()).code, "EXTERNAL_REQUIRES_RESOLUTION");
});

Deno.test("Linked source promotion maps409 before success parsing", async () => {
  const test = testHandler();
  test.store.promoteResults = [{ outcome: "source_already_linked" }];
  const response = await test.handler(
    request({ operation: "promote", submission_id: 7, target: "event" }),
  );
  assertEquals(response.status, 409);
  assertEquals((await response.json()).code, "PROMOTION_SOURCE_ALREADY_LINKED");
});

Deno.test("Link uses verified Admin actor and maps Event discriminator/acknowledgement failures", async () => {
  const test = testHandler();
  const hash = "a".repeat(64);
  const body = {
    operation: "link",
    submission_id: 7,
    target_event_id: 19,
    acknowledge_current_source: true,
    expected_source_hash: hash,
  };
  const response = await test.handler(request(body));
  assertEquals(response.status, 200);
  assertEquals(test.store.linkValues, {
    id: 7,
    targetEventId: 19,
    handledBy: adminUser().id,
    acknowledgeCurrentSource: true,
    expectedSourceHash: hash,
  });
  assertEquals(await response.json(), {
    resolution: {
      outcome: "linked",
      target_event_id: 19,
      pending_submission_id: null,
    },
  });
  for (
    const [outcome, status, code] of [
      ["not_event_submission", 422, "NOT_EVENT_SUBMISSION"],
      ["source_changed", 409, "SOURCE_CHANGED"],
      ["relink_conflict", 409, "RELINK_CONFLICT"],
    ] as const
  ) {
    test.store.linkResult = { outcome };
    const failed = await test.handler(request(body));
    assertEquals(failed.status, status);
    assertEquals((await failed.json()).code, code);
  }
  const spoof = await test.handler(request({ ...body, handled_by: "spoof" }));
  assertEquals(spoof.status, 400);
});

Deno.test("Event resolution response maps Apply closed-group and city failures consistently", async () => {
  for (
    const [outcome, status, code] of [
      ["city_not_found", 422, "CITY_NOT_FOUND"],
      ["invalid_groups", 422, "INVALID_GROUPS"],
      ["coordinates_required", 422, "COORDINATES_REQUIRED"],
      ["submission_changed", 409, "SUBMISSION_CHANGED"],
      ["event_changed", 409, "EVENT_CHANGED"],
      ["normalization_mismatch", 409, "NORMALIZATION_MISMATCH"],
      ["start_date_required", 422, "START_DATE_REQUIRED"],
      ["invalid_date_range", 422, "INVALID_DATE_RANGE"],
    ] as const
  ) {
    const response = eventResolutionResponse({ outcome });
    assertEquals(response.status, status);
    assertEquals((await response.json()).code, code);
  }
});

Deno.test("Link lost-response retry reaches authoritative RPC before pending-only reads", async () => {
  const test = testHandler();
  const hash = "a".repeat(64);
  const body = {
    operation: "link",
    submission_id: 7,
    target_event_id: 19,
    acknowledge_current_source: true,
    expected_source_hash: hash,
  };
  // The initial resolution commits; its response is discarded by the caller.
  await test.handler(request(body));
  test.store.calls.length = 0;
  test.store.linkResult = {
    outcome: "already_resolved",
    eventId: 19,
    pendingSubmissionId: null,
  };
  test.store.getResult = {
    submission: { ...record, status: "accepted", target_event_id: 19 },
    assets: [],
  };
  const retried = await test.handler(request(body));
  assertEquals(retried.status, 200);
  assertEquals((await retried.json()).resolution.outcome, "already_resolved");
  assertEquals(test.store.calls, ["link"]);
  assertEquals(test.store.linkValues, {
    id: 7,
    targetEventId: 19,
    handledBy: adminUser().id,
    acknowledgeCurrentSource: true,
    expectedSourceHash: hash,
  });
  test.store.linkResult = { outcome: "target_conflict" };
  assertEquals(
    (await test.handler(request({ ...body, target_event_id: 20 }))).status,
    409,
  );
});

Deno.test("Promote acknowledgement preserves displayed hash, stable failure and retry precedence", async () => {
  const test = testHandler();
  const hash = "a".repeat(64);
  const body = {
    operation: "promote",
    submission_id: 7,
    target: "event",
    acknowledge_current_source: true,
    expected_source_hash: hash,
  };
  test.store.promoteResults = [
    { outcome: "created", target: "event", entityId: 19 },
    { outcome: "source_changed" },
    { outcome: "already_promoted", target: "event", entityId: 19 },
  ];
  assertEquals((await test.handler(request(body))).status, 200);
  assertEquals(test.store.promoteValues, {
    id: 7,
    target: "event",
    handledBy: adminUser().id,
    acknowledgeCurrentSource: true,
    expectedSourceHash: hash,
  });
  const changed = await test.handler(request(body));
  assertEquals(changed.status, 409);
  assertEquals((await changed.json()).code, "SOURCE_CHANGED");
  const retried = await test.handler(
    request({ ...body, expected_source_hash: null }),
  );
  assertEquals(retried.status, 200);
  assertEquals((await retried.json()).promotion, {
    target_type: "event",
    entity_id: 19,
  });
  assertEquals(test.store.calls, ["promote", "promote", "promote"]);
  assertEquals(
    (await test.handler(request({ ...body, handled_by: "spoof" }))).status,
    400,
  );
});

Deno.test("Imported Save null-start rejection maps422 and does not accept provenance spoofing", async () => {
  const test = testHandler();
  test.store.updateResults = [{ outcome: "start_date_required" }];
  const body = {
    operation: "update",
    submission_id: 7,
    input: { ...input(), start_date: null, end_date: null, all_day: false },
  };
  const failed = await test.handler(request(body));
  assertEquals(failed.status, 422);
  assertEquals((await failed.json()).code, "START_DATE_REQUIRED");
  assertEquals(
    (await test.handler(request({ ...body, external_event_record_id: null })))
      .status,
    400,
  );
});

function mergeHandlerFixture() {
  const test = testHandler();
  const base = {
    name: "Source",
    category: "unknown" as const,
    description: null,
    description_delta: null,
    city: "Campobasso",
    latitude: "41",
    longitude: "14",
    all_day: false,
    start_date: "2026-10-02T10:00:00.123456Z",
    end_date: null,
  };
  const snapshot = { ...base, name: "Provider revision" };
  test.store.getResult = {
    submission: {
      ...record,
      ...snapshot,
      latitude: 41,
      longitude: 14,
      category: "experience",
      external_event_record_id: 1,
      external_normalized: snapshot,
      external_normalization_version: 1,
      external_moderation_hash: "a".repeat(64),
      modified_at: "2026-10-02T10:00:00.000001+00:00",
      status: "pending",
    },
    assets: [],
  };
  test.store.externalRecordResult = {
    id: 1,
    provider: "fixture",
    external_id: "1",
    occurrence_key: null,
    source_url: null,
    event_id: 19,
    ignored_at: null,
    normalized: snapshot,
    normalization_version: 1,
    moderation_hash: "b".repeat(64),
    proposed_normalized: base,
    proposed_normalization_version: 1,
    proposed_hash: "c".repeat(64),
    metadata: {},
    metadata_version: 1,
    created_at: "now",
    modified_at: "now",
  };
  test.store.eventResult = {
    id: 19,
    name: "Editorial title",
    city_id: null,
    city: null,
    description: null,
    description_delta: null,
    latitude: 41,
    longitude: 14,
    category: "history",
    all_day: false,
    start_date: base.start_date,
    end_date: null,
    created_at: "now",
    deleted_at: null,
    modified_at: "2026-10-02 10:00:00.000002+00",
  };
  return test;
}

Deno.test("Merge preview recomputes semantic groups/current values and preserves raw DB tokens", async () => {
  const test = mergeHandlerFixture();
  const response = await test.handler(
    request({
      operation: "mergePreview",
      submission_id: 7,
      target_event_id: 19,
    }),
  );
  assertEquals(response.status, 200);
  const preview = (await response.json()).preview;
  assertEquals(
    preview.submission_version_token,
    "2026-10-02T10:00:00.000001+00:00",
  );
  assertEquals(preview.event_version_token, "2026-10-02 10:00:00.000002+00");
  assertEquals(preview.groups_to_apply, ["name", "category"]);
  assertEquals(preview.groups.map((g: { overwrite: boolean }) => g.overwrite), [
    true,
    true,
    false,
    false,
    false,
  ]);
  assertEquals(preview.groups[4].current.city, null);
  assertEquals(preview.stale, true);
  assertEquals(preview.moderation_hash, "b".repeat(64));
  assertEquals(test.store.calls, ["getById", "getExternalRecord", "getEvent"]);
  test.store.eventResult!.name = "Provider revision";
  const refreshed = await test.handler(
    request({
      operation: "mergePreview",
      submission_id: 7,
      target_event_id: 19,
    }),
  );
  assertEquals((await refreshed.json()).preview.groups[0].overwrite, false);
  assertEquals(
    (await test.handler(
      request({
        operation: "mergePreview",
        submission_id: 7,
        target_event_id: 19,
        groups_to_apply: ["name"],
      }),
    )).status,
    400,
  );
});

Deno.test("Apply computes server groups while forwarding original tokens/hash/verified actor unchanged", async () => {
  const test = mergeHandlerFixture();
  const body = {
    operation: "apply",
    submission_id: 7,
    target_event_id: 19,
    submission_version_token: "2026-10-01 00:00:00.999999+00",
    event_version_token: "2026-10-01T00:00:00.999998Z",
    acknowledge_current_source: true,
    expected_source_hash: "a".repeat(64),
  };
  const response = await test.handler(request(body));
  assertEquals(response.status, 200);
  assertEquals(test.store.applyValues, {
    id: 7,
    targetEventId: 19,
    handledBy: adminUser().id,
    groupsToApply: ["name", "category"],
    submissionVersionToken: body.submission_version_token,
    eventVersionToken: body.event_version_token,
    acknowledgeCurrentSource: true,
    expectedSourceHash: body.expected_source_hash,
  });
  test.store.applyResult = { outcome: "source_changed" };
  const changed = await test.handler(request(body));
  assertEquals(changed.status, 409);
  assertEquals((await changed.json()).code, "SOURCE_CHANGED");
  assertEquals(
    (await test.handler(request({ ...body, groups_to_apply: ["location"] })))
      .status,
    400,
  );
  assertEquals(
    (await test.handler(request({ ...body, handled_by: "spoof" }))).status,
    400,
  );
});

Deno.test("Apply accepted retry precedes canonicalization/readiness and remains authoritative for conflicts", async () => {
  const test = mergeHandlerFixture();
  test.store.getResult!.submission = {
    ...test.store.getResult!.submission,
    status: "accepted",
    target_event_id: 19,
    start_date: null,
    description_delta: "invalid",
  };
  test.store.externalRecordResult = null;
  test.store.eventResult = null;
  test.store.applyResult = {
    outcome: "already_resolved",
    eventId: 19,
    pendingSubmissionId: null,
  };
  const body = {
    operation: "apply",
    submission_id: 7,
    target_event_id: 19,
    submission_version_token: "old",
    event_version_token: "old",
    acknowledge_current_source: true,
  };
  const response = await test.handler(request(body));
  assertEquals(response.status, 200);
  assertEquals((await response.json()).resolution.outcome, "already_resolved");
  assertEquals(test.store.calls, ["getById", "apply"]);
  assertEquals(
    (test.store.applyValues as { groupsToApply: string[] }).groupsToApply,
    [],
  );
  test.store.applyResult = { outcome: "target_conflict" };
  const conflict = await test.handler(
    request({ ...body, target_event_id: 20 }),
  );
  assertEquals(conflict.status, 409);
  assertEquals((await conflict.json()).code, "TARGET_CONFLICT");
});

Deno.test("Apply pending schedule readiness fails before canonicalization/merge/store writes", async () => {
  for (
    const [start, end, code] of [[null, null, "START_DATE_REQUIRED"], [
      "2026-10-03T10:00:00Z",
      "2026-10-02T10:00:00Z",
      "INVALID_DATE_RANGE",
    ]] as const
  ) {
    const test = mergeHandlerFixture();
    test.store.getResult!.submission = {
      ...test.store.getResult!.submission,
      start_date: start,
      end_date: end,
      description_delta: "invalid",
    };
    const failed = await test.handler(
      request({
        operation: "apply",
        submission_id: 7,
        target_event_id: 19,
        submission_version_token: "old",
        event_version_token: "old",
      }),
    );
    assertEquals(failed.status, 422);
    assertEquals((await failed.json()).code, code);
    assertEquals(test.store.calls, ["getById"]);
  }
});

Deno.test("Apply stale preview tokens survive newer authoritative rereads byte-for-byte", async () => {
  const test = mergeHandlerFixture();
  const body = {
    operation: "apply",
    submission_id: 7,
    target_event_id: 19,
    submission_version_token: "2026-09-30 10:00:00.000001+00",
    event_version_token: "2026-09-30T10:00:00.000002+00:00",
  };
  for (const outcome of ["submission_changed", "event_changed"] as const) {
    test.store.getResult!.submission.modified_at =
      "2026-10-03T20:00:00.999999Z";
    test.store.eventResult!.modified_at = "2026-10-04T20:00:00.999998Z";
    test.store.applyResult = { outcome };
    const failed = await test.handler(request(body));
    assertEquals(failed.status, 409);
    assertEquals(
      (test.store.applyValues as { submissionVersionToken: string })
        .submissionVersionToken,
      body.submission_version_token,
    );
    assertEquals(
      (test.store.applyValues as { eventVersionToken: string })
        .eventVersionToken,
      body.event_version_token,
    );
  }
});

Deno.test("Pending preview refuses a newer normalization profile even when all persisted versions agree", async () => {
  const test = mergeHandlerFixture();
  test.store.getResult!.submission.external_normalization_version = 2;
  test.store.externalRecordResult!.normalization_version = 2;
  test.store.externalRecordResult!.proposed_normalization_version = 2;
  const failed = await test.handler(
    request({
      operation: "mergePreview",
      submission_id: 7,
      target_event_id: 19,
    }),
  );
  assertEquals(failed.status, 409);
  assertEquals((await failed.json()).code, "NORMALIZATION_MISMATCH");
  assertEquals(test.store.calls, ["getById", "getExternalRecord"]);
});

Deno.test("list DTO exposes nullable human and authoritative imported create/update mode", async () => {
  const store = new FakeStore();
  store.listResult = [record, {
    ...record,
    id: 8,
    external_event_record_id: 12,
    currentSource: {
      event_id: null,
      moderation_hash: "x",
      normalized: { name: "Create" },
    },
  }, {
    ...record,
    id: 9,
    external_event_record_id: 13,
    currentSource: {
      event_id: 42,
      moderation_hash: "y",
      normalized: { name: "Update" },
    },
  }];
  const tested = testHandler(adminUser(), store);
  const response = await tested.handler(request({ operation: "list" }));
  const rows = (await responseJson(response)).submissions as Array<
    Record<string, unknown>
  >;
  assertEquals(rows.map((row) => [row.external_mode, row.external_event_id]), [
    [null, null],
    ["create", null],
    ["update", 42],
  ]);
  assertEquals(rows[2].current_source_normalized, { name: "Update" });
});
