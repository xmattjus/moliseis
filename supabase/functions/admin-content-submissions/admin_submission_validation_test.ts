import { assert, assertEquals } from "jsr:@std/assert@1";

import { parseAdminContentSubmissionsRequest } from "./admin_submission_validation.ts";

const input = (overrides: Record<string, unknown> = {}) => ({
  category: "unknown",
  city: " Campobasso ",
  name: " Teatro ",
  description: null,
  description_delta: null,
  start_date: null,
  end_date: null,
  ...overrides,
});

function expectInvalid(value: unknown, message: string): void {
  const result = parseAdminContentSubmissionsRequest(value);
  assert(!result.ok);
  assertEquals(result.message, message);
}

Deno.test("accepts all operation envelopes and normalizes editor input", () => {
  const requests = [
    { operation: "list" },
    { operation: "getById", submission_id: 1 },
    { operation: "create", input: input() },
    { operation: "update", submission_id: 1, input: input() },
    { operation: "changeStatus", submission_id: 1, status: "accepted" },
  ];
  for (const request of requests) {
    assert(parseAdminContentSubmissionsRequest(request).ok);
  }

  const created = parseAdminContentSubmissionsRequest({
    operation: "create",
    input: input(),
  });
  assert(created.ok && created.value.operation === "create");
  assertEquals(created.value.input.city, "Campobasso");
  assertEquals(created.value.input.name, "Teatro");
});

Deno.test("rejects invalid request envelopes, IDs, and status", () => {
  expectInvalid([], "Request body must be a JSON object.");
  expectInvalid({}, "operation is required.");
  expectInvalid({ operation: "delete" }, "operation is not supported.");
  for (
    const request of [
      { operation: "list", extra: true },
      { operation: "getById" },
      { operation: "getById", submission_id: 1, extra: true },
      { operation: "create" },
      { operation: "create", input: input(), extra: true },
      { operation: "update" },
      { operation: "update", submission_id: 1, input: input(), extra: true },
      { operation: "changeStatus", submission_id: 1 },
      {
        operation: "changeStatus",
        submission_id: 1,
        status: "accepted",
        extra: true,
      },
    ]
  ) expectInvalid(request, "Request contains unsupported or missing fields.");
  for (const id of [0, -1, 1.5, "1", Number.MAX_SAFE_INTEGER + 1]) {
    expectInvalid(
      { operation: "getById", submission_id: id },
      "submission_id must be a positive safe integer.",
    );
  }
  for (const status of ["pending", "other"]) {
    expectInvalid(
      { operation: "changeStatus", submission_id: 1, status },
      "status must be accepted or rejected.",
    );
  }
});

Deno.test("requires the exact seven editor input fields and rejects spoofing", () => {
  expectInvalid(
    { operation: "create", input: {} },
    "input contains unsupported or missing fields.",
  );
  for (
    const spoofedKey of [
      "user_id",
      "status",
      "assets",
      "latitude",
      "address",
      "handled_at",
      "status_email_key",
    ]
  ) {
    expectInvalid(
      { operation: "create", input: input({ [spoofedKey]: true }) },
      "input contains unsupported or missing fields.",
    );
  }
  expectInvalid(
    { operation: "create", input: [] },
    "input must be a JSON object.",
  );
});

Deno.test("validates categories, city, and name boundaries", () => {
  for (
    const category of [
      "unknown",
      "nature",
      "history",
      "folklore",
      "food",
      "allure",
      "experience",
    ]
  ) {
    assert(
      parseAdminContentSubmissionsRequest({
        operation: "create",
        input: input({ category }),
      }).ok,
    );
  }
  expectInvalid(
    { operation: "create", input: input({ category: "other" }) },
    "category is not supported.",
  );
  expectInvalid(
    { operation: "create", input: input({ city: "  " }) },
    "city must be a non-empty string.",
  );
  expectInvalid(
    { operation: "create", input: input({ name: "  " }) },
    "name must be a non-empty string.",
  );
  assert(
    parseAdminContentSubmissionsRequest({
      operation: "create",
      input: input({ city: "a".repeat(100), name: "a".repeat(150) }),
    }).ok,
  );
  expectInvalid({
    operation: "create",
    input: input({ city: "a".repeat(101) }),
  }, "city exceeds maximum length of 100 characters.");
  expectInvalid({
    operation: "create",
    input: input({ name: "a".repeat(151) }),
  }, "name exceeds maximum length of 150 characters.");
});

Deno.test("preserves descriptions and applies the shared canonical Delta rules", () => {
  const delta = [{ insert: "  Text\n" }];
  const result = parseAdminContentSubmissionsRequest({
    operation: "create",
    input: input({ description: "  Text", description_delta: delta }),
  });
  assert(result.ok && result.value.operation === "create");
  assertEquals(result.value.input.description, "  Text");
  assertEquals(result.value.input.description_delta, delta);
  assert(
    parseAdminContentSubmissionsRequest({
      operation: "create",
      input: input({ description: "legacy", description_delta: null }),
    }).ok,
  );
  expectInvalid(
    { operation: "create", input: input({ description: 1 }) },
    "description must be a string or null.",
  );
  assert(
    parseAdminContentSubmissionsRequest({
      operation: "create",
      input: input({ description: "a".repeat(5000), description_delta: null }),
    }).ok,
  );
  expectInvalid({
    operation: "create",
    input: input({ description: "a".repeat(5001) }),
  }, "description exceeds maximum length of 5000 characters.");
  expectInvalid({
    operation: "create",
    input: input({ description: "x", description_delta: [{ insert: "x" }] }),
  }, "description_delta must end with a terminal newline");
  expectInvalid({
    operation: "create",
    input: input({ description: null, description_delta: [{ insert: "x\n" }] }),
  }, "description_delta requires a non-null description");
});

Deno.test("validates nullable dates without enforcing date ordering", () => {
  assert(
    parseAdminContentSubmissionsRequest({
      operation: "create",
      input: input({
        start_date: "2026-08-21T10:00:00.000Z",
        end_date: "2026-08-20T10:00:00.000Z",
      }),
    }).ok,
  );
  for (
    const [key, value, message] of [
      [
        "start_date",
        "",
        "start_date must be a parseable date-time string or null.",
      ],
      [
        "start_date",
        1,
        "start_date must be a parseable date-time string or null.",
      ],
      [
        "end_date",
        "not-a-date",
        "end_date must be a parseable date-time string or null.",
      ],
    ] as const
  ) {
    expectInvalid(
      { operation: "create", input: input({ [key]: value }) },
      message,
    );
  }
});
