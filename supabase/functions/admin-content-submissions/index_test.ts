import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import type { User } from "npm:@supabase/supabase-js@2.112.3";

import {
  type AddAssetStoreResult,
  type AdminSubmissionStore,
  AdminSubmissionStoreError,
  type ChangeStatusStoreResult,
  type DeleteAssetStoreResult,
  type SubmissionRecord,
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
});

class FakeStore implements AdminSubmissionStore {
  calls: string[] = [];
  createValues: unknown;
  updateValues: unknown;
  statusValues: unknown;
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
  updateResult: SubmissionRecord | null = { ...record, status: "accepted" };
  statusResults: ChangeStatusStoreResult[] = ["updated"];
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
  ): Promise<SubmissionRecord | null> {
    this.calls.push("update");
    this.updateValues = args;
    if (this.error) throw this.error;
    return this.updateResult;
  }

  async changeStatus(
    params: Parameters<AdminSubmissionStore["changeStatus"]>[0],
  ): Promise<ChangeStatusStoreResult> {
    this.calls.push("changeStatus");
    this.statusValues = params;
    if (this.error) throw this.error;
    return this.statusResults.shift() ?? "not_pending";
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
      "modified_at",
      "name",
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

Deno.test("updates all statuses and maps status transitions atomically", async () => {
  const update = testHandler();
  const updateResponse = await update.handler(
    request({ operation: "update", submission_id: 7, input: input() }),
  );
  assertEquals(updateResponse.status, 200);
  assertEquals(update.created(), 1);
  assertEquals(update.store.updateValues, [
    7,
    input(),
    "2026-08-21T11:00:00.000Z",
  ]);

  const status = testHandler();
  status.store.statusResults = ["updated", "not_found"];
  const accepted = await status.handler(
    request({
      operation: "changeStatus",
      submission_id: 7,
      status: "accepted",
    }),
  );
  assertEquals(await responseJson(accepted), { ok: true, status: "accepted" });
  assertEquals(status.store.statusValues, {
    id: 7,
    status: "accepted",
    handledBy: "00000000-0000-4000-8000-000000000001",
    modifiedAt: "2026-08-21T11:00:00.000Z",
  });
  const concurrent = testHandler();
  concurrent.store.statusResults = ["updated", "not_pending"];
  const [first, late] = await Promise.all([
    concurrent.handler(
      request({
        operation: "changeStatus",
        submission_id: 7,
        status: "accepted",
      }),
    ),
    concurrent.handler(
      request({
        operation: "changeStatus",
        submission_id: 7,
        status: "accepted",
      }),
    ),
  ]);
  assertEquals(first.status, 200);
  assertEquals(late.status, 409);
  const absent = await status.handler(
    request({
      operation: "changeStatus",
      submission_id: 8,
      status: "rejected",
    }),
  );
  assertEquals(absent.status, 404);

  const rejected = testHandler();
  const rejectedResponse = await rejected.handler(
    request({
      operation: "changeStatus",
      submission_id: 7,
      status: "rejected",
    }),
  );
  assertEquals(await responseJson(rejectedResponse), {
    ok: true,
    status: "rejected",
  });
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
