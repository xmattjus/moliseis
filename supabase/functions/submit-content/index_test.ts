import { assertEquals } from "jsr:@std/assert@1";
import type { User } from "npm:@supabase/supabase-js@2.112.3";

import type { ValidatedContentSubmission } from "./submission_validation.ts";
import { createHandler, type HandlerDependencies } from "./index.ts";
import type {
  SubmissionStore,
  SubmissionStoreResult,
} from "./submission_store.ts";

const userId = "00000000-0000-4000-8000-000000000002";
const cloudName = "test-cloud";
const canonicalAssetUrl =
  `https://res.cloudinary.com/${cloudName}/image/upload/v1/content_submissions/${
    "a".repeat(64)
  }.jpg`;

const validSubmission = () => ({
  client_submission_id: "00000000-0000-4000-8000-000000000001",
  city: "Campobasso",
  name: "Teatro",
  user_email: "author@example.test",
  user_name: "Author",
});

function user(): User {
  return { id: userId, aud: "authenticated", role: "authenticated" } as User;
}

function request(
  body: unknown,
  options: { method?: string; authorization?: string; contentLength?: string } =
    {},
): Request {
  const method = options.method ?? "POST";
  return new Request("https://example.test/submit-content", {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(options.authorization === undefined
        ? { Authorization: "Bearer valid-token" }
        : options.authorization
        ? { Authorization: options.authorization }
        : {}),
      ...(options.contentLength
        ? { "Content-Length": options.contentLength }
        : {}),
    },
    body: method === "POST" ? JSON.stringify(body) : undefined,
  });
}

class FakeStore implements SubmissionStore {
  calls: Array<{ userId: string; submission: ValidatedContentSubmission }> = [];
  result: SubmissionStoreResult = { outcome: "created", submissionId: 7 };
  error: Error | null = null;

  async submit(params: {
    userId: string;
    submission: ValidatedContentSubmission;
  }): Promise<SubmissionStoreResult> {
    this.calls.push(params);
    if (this.error) throw this.error;
    return this.result;
  }
}

function createHarness(overrides: Partial<HandlerDependencies> = {}) {
  const store = new FakeStore();
  const calls = { authenticate: 0, stores: 0, logs: [] as string[] };
  const dependencies: HandlerDependencies = {
    cloudName,
    authenticate: async () => {
      calls.authenticate += 1;
      return user();
    },
    createStore: () => {
      calls.stores += 1;
      return store;
    },
    logFailure: (operation, outcome) =>
      calls.logs.push(`${operation}:${outcome}`),
    ...overrides,
  };
  return { calls, handler: createHandler(dependencies), store };
}

async function responseJson(response: Response): Promise<unknown> {
  assertEquals(response.headers.get("access-control-allow-origin"), "*");
  assertEquals(response.headers.get("content-type"), "application/json");
  return await response.json();
}

Deno.test("OPTIONS and unsupported methods return before authentication or store construction", async () => {
  const { calls, handler } = createHarness();
  const options = await handler(request({}, { method: "OPTIONS" }));
  const method = await handler(request({}, { method: "GET" }));

  assertEquals(options.status, 200);
  assertEquals(await responseJson(options), { ok: true });
  assertEquals(method.status, 405);
  assertEquals(await responseJson(method), {
    code: "METHOD_NOT_ALLOWED",
    message: "GET is not allowed",
  });
  assertEquals(calls, { authenticate: 0, stores: 0, logs: [] });
});

Deno.test("authentication gates invalid requests before body parsing or store construction", async () => {
  for (
    const authorization of ["", "Bearer ", "Bearer token extra", "Basic x"]
  ) {
    const { calls, handler } = createHarness();
    const response = await handler(
      request(validSubmission(), { authorization }),
    );
    assertEquals(response.status, 401);
    assertEquals(await responseJson(response), {
      code: "UNAUTHORIZED",
      message: "Missing bearer token",
    });
    assertEquals(calls, { authenticate: 0, stores: 0, logs: [] });
  }

  for (
    const authenticate of [
      async () => null,
      async () => {
        throw new Error("transport failed");
      },
    ]
  ) {
    const { calls, handler } = createHarness({ authenticate });
    const response = await handler(request(validSubmission()));
    assertEquals(response.status, 401);
    assertEquals(
      (await responseJson(response) as { code: string }).code,
      "UNAUTHORIZED",
    );
    assertEquals(calls.stores, 0);
  }
});

Deno.test("malformed, oversized, and invalid bodies return before store construction", async () => {
  const malformed = createHarness();
  const malformedResponse = await malformed.handler(
    new Request("https://example.test/submit-content", {
      method: "POST",
      headers: { Authorization: "Bearer valid-token" },
      body: "not-json",
    }),
  );
  assertEquals(malformedResponse.status, 400);
  assertEquals(await responseJson(malformedResponse), {
    code: "VALIDATION_ERROR",
    message: "Request body must be valid JSON",
  });
  assertEquals(malformed.calls.stores, 0);

  const oversized = createHarness();
  const oversizedResponse = await oversized.handler(
    request(validSubmission(), { contentLength: "131073" }),
  );
  assertEquals(oversizedResponse.status, 400);
  assertEquals(
    (await responseJson(oversizedResponse) as { code: string }).code,
    "VALIDATION_ERROR",
  );
  assertEquals(oversized.calls.stores, 0);

  const invalid = createHarness();
  const invalidResponse = await invalid.handler(request({
    ...validSubmission(),
    city: "",
  }));
  assertEquals(invalidResponse.status, 400);
  assertEquals(await responseJson(invalidResponse), {
    code: "VALIDATION_ERROR",
    message: "city is required",
  });
  assertEquals(invalid.calls.stores, 0);
});

Deno.test("boundary validation rejects invalid coordinates and public assets before store construction", async () => {
  const invalidRequests: Array<[Record<string, unknown>, string]> = [
    [
      { ...validSubmission(), latitude: 41.5 },
      "latitude and longitude must be provided together",
    ],
    [
      { ...validSubmission(), latitude: 91, longitude: 0 },
      "latitude is not valid",
    ],
    [{
      ...validSubmission(),
      assets: [{
        url:
          `https://res.cloudinary.com/wrong-cloud/image/upload/v1/content_submissions/${
            "a".repeat(64)
          }.jpg`,
        width: 1,
        height: 1,
        mime_type: null,
        duration_seconds: null,
      }],
    }, "asset url is not valid"],
    [{
      ...validSubmission(),
      assets: Array.from(
        { length: 2 },
        () => ({
          url: canonicalAssetUrl,
          width: 1,
          height: 1,
          mime_type: null,
          duration_seconds: null,
        }),
      ),
    }, "assets must not contain duplicates"],
  ];
  for (const [body, message] of invalidRequests) {
    const harness = createHarness();
    const response = await harness.handler(request(body));
    assertEquals(response.status, 400);
    assertEquals(await responseJson(response), {
      code: "VALIDATION_ERROR",
      message,
    });
    assertEquals(harness.calls.stores, 0);
    assertEquals(harness.store.calls, []);
  }

  const replay = createHarness();
  replay.store.result = { outcome: "replayed", submissionId: 7 };
  const replayResponse = await replay.handler(request({
    ...validSubmission(),
    latitude: 41.5,
  }));
  assertEquals(replayResponse.status, 400);
  assertEquals(await responseJson(replayResponse), {
    code: "VALIDATION_ERROR",
    message: "latitude and longitude must be provided together",
  });
  assertEquals(replay.calls.stores, 0);
  assertEquals(replay.store.calls, []);
});

Deno.test("created and replayed acknowledgements make exactly one store call", async () => {
  for (
    const [result, status, body] of [
      [
        { outcome: "created", submissionId: 7 },
        201,
        { submission_id: 7, replayed: false },
      ],
      [
        { outcome: "replayed", submissionId: 7 },
        200,
        { submission_id: 7, replayed: true },
      ],
    ] as const
  ) {
    const harness = createHarness();
    harness.store.result = result;
    const response = await harness.handler(request({
      ...validSubmission(),
      category: null,
      assets: [],
    }));

    assertEquals(response.status, status);
    assertEquals(await responseJson(response), body);
    assertEquals(harness.calls.stores, 1);
    assertEquals(harness.store.calls, [{
      userId,
      submission: {
        ...validSubmission(),
        description: null,
        description_delta: null,
        latitude: null,
        longitude: null,
        address: null,
        start_date: null,
        end_date: null,
        category: null,
        assets: [],
      },
    }]);
  }
});

Deno.test("rate limit retains the public quota response", async () => {
  const harness = createHarness();
  harness.store.result = { outcome: "rate_limited" };
  const response = await harness.handler(request(validSubmission()));

  assertEquals(response.status, 429);
  assertEquals(await responseJson(response), {
    code: "RATE_LIMIT_EXCEEDED",
    message: "Maximum 5 submissions per 24 hours exceeded",
  });
  assertEquals(harness.store.calls.length, 1);
});

Deno.test("store failures and malformed outcomes are stable, safe server errors", async () => {
  const failure = createHarness();
  failure.store.error = new Error("database details");
  const failureResponse = await failure.handler(request(validSubmission()));
  assertEquals(failureResponse.status, 500);
  assertEquals(await responseJson(failureResponse), {
    code: "INTERNAL_ERROR",
    message: "Unable to save submission",
  });
  assertEquals(failure.calls.logs, ["submit_content:persistence_failed"]);

  const malformed = createHarness();
  malformed.store.result = {
    outcome: "unexpected",
  } as unknown as SubmissionStoreResult;
  const malformedResponse = await malformed.handler(request(validSubmission()));
  assertEquals(malformedResponse.status, 500);
  assertEquals(await responseJson(malformedResponse), {
    code: "INTERNAL_ERROR",
    message: "Unable to save submission",
  });
  assertEquals(malformed.calls.logs, ["submit_content:invalid_outcome"]);
});
