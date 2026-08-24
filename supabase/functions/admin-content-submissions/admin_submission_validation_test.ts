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
  latitude: null,
  longitude: null,
  ...overrides,
});

const asset = (overrides: Record<string, unknown> = {}) => ({
  url: "https://res.cloudinary.com/demo/image/upload/v1/example.jpg",
  width: 1600,
  height: 1200,
  mime_type: "image/jpeg",
  duration_seconds: null,
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
    { operation: "addAsset", submission_id: 1, asset: asset() },
    { operation: "deleteAsset", submission_id: 1, asset_id: 2 },
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

Deno.test("validates exact add-asset and delete-asset request envelopes", () => {
  const add = parseAdminContentSubmissionsRequest({
    operation: "addAsset",
    submission_id: 1,
    asset: asset(),
  });
  assert(add.ok && add.value.operation === "addAsset");
  assertEquals(add.value.asset.mime_type, "image/jpeg");

  const deleted = parseAdminContentSubmissionsRequest({
    operation: "deleteAsset",
    submission_id: 1,
    asset_id: 2,
  });
  assert(deleted.ok && deleted.value.operation === "deleteAsset");
  assertEquals(deleted.value.asset_id, 2);

  expectInvalid(
    {
      operation: "addAsset",
      submission_id: 1,
      asset: asset({ url: "http://res.cloudinary.com/demo/image.jpg" }),
    },
    "asset url is not valid",
  );
  expectInvalid(
    { operation: "addAsset", submission_id: 1, asset: asset({ width: 0 }) },
    "asset width must be a positive safe integer",
  );
  expectInvalid(
    {
      operation: "addAsset",
      submission_id: 1,
      asset: asset({ mime_type: "not-a-mime" }),
    },
    "mime_type is not valid",
  );
  for (
    const request of [
      { operation: "addAsset", asset: asset() },
      { operation: "addAsset", submission_id: 1 },
      { operation: "addAsset", submission_id: 1, asset: asset(), extra: true },
      { operation: "deleteAsset", submission_id: 1 },
      { operation: "deleteAsset", submission_id: 1, asset_id: 2, extra: true },
    ]
  ) {
    expectInvalid(request, "Request contains unsupported or missing fields.");
  }
  for (
    const [operation, key] of [
      ["addAsset", "submission_id"],
      ["deleteAsset", "submission_id"],
      ["deleteAsset", "asset_id"],
    ] as const
  ) {
    expectInvalid(
      {
        operation,
        submission_id: key === "submission_id" ? 0 : 1,
        ...(operation === "deleteAsset"
          ? { asset_id: key === "asset_id" ? 0 : 2 }
          : {}),
        ...(operation === "addAsset" ? { asset: asset() } : {}),
      },
      `${key} must be a positive safe integer.`,
    );
  }
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

Deno.test("requires the exact nine editor input fields and rejects spoofing", () => {
  expectInvalid(
    { operation: "create", input: {} },
    "input contains unsupported or missing fields.",
  );
  for (
    const spoofedKey of [
      "user_id",
      "status",
      "assets",
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

Deno.test("validates nullable dates and enforces date pairing and ordering", () => {
  const subMillisecondStart = "2026-08-20T10:00:00.000100Z";
  const subMillisecondEnd = "2026-08-20T10:00:00.000900Z";

  for (
    const valid of [
      input(),
      input({ start_date: "2026-08-20T10:00:00.000Z" }),
      // Equal instants remain valid even when spelled with different offsets.
      input({
        start_date: "2026-08-21T10:00:00.000Z",
        end_date: "2026-08-21T12:00:00.000+02:00",
      }),
      input({
        start_date: "2026-08-20T10:00:00.000Z",
        end_date: "2026-08-21T10:00:00.000Z",
      }),
      // An end later within the same millisecond stays valid.
      input({
        start_date: subMillisecondStart,
        end_date: subMillisecondEnd,
      }),
      // Equal instants remain valid down to microsecond precision across
      // different offsets.
      input({
        start_date: "2026-08-20T10:00:00.000500Z",
        end_date: "2026-08-20T12:00:00.000500+02:00",
      }),
    ]
  ) {
    assert(
      parseAdminContentSubmissionsRequest({ operation: "create", input: valid })
        .ok,
    );
  }

  const ordered = parseAdminContentSubmissionsRequest({
    operation: "create",
    input: input({
      start_date: "2026-08-20T10:00:00.000+02:00",
      end_date: "2026-08-20T09:00:00.000Z",
    }),
  });
  assert(ordered.ok && ordered.value.operation === "create");
  assertEquals(ordered.value.input.start_date, "2026-08-20T10:00:00.000+02:00");
  assertEquals(ordered.value.input.end_date, "2026-08-20T09:00:00.000Z");

  const precise = parseAdminContentSubmissionsRequest({
    operation: "create",
    input: input({
      start_date: subMillisecondStart,
      end_date: subMillisecondEnd,
    }),
  });
  assert(precise.ok && precise.value.operation === "create");
  assertEquals(precise.value.input.start_date, subMillisecondStart);
  assertEquals(precise.value.input.end_date, subMillisecondEnd);

  for (
    const [invalid, message] of [
      [
        input({ start_date: null, end_date: "2026-08-20T10:00:00.000Z" }),
        "end_date requires start_date.",
      ],
      [
        input({
          start_date: "2026-08-21T10:00:00.000Z",
          end_date: "2026-08-20T10:00:00.000Z",
        }),
        "end_date must not be before start_date.",
      ],
      [
        // Both instants collapse to the same JavaScript millisecond but the
        // end is 998 microseconds earlier.
        input({
          start_date: "2026-08-20T10:00:00.000999Z",
          end_date: "2026-08-20T10:00:00.000001Z",
        }),
        "end_date must not be before start_date.",
      ],
    ] as const
  ) {
    for (const operation of ["create", "update"] as const) {
      expectInvalid(
        operation === "create"
          ? { operation, input: invalid }
          : { operation, submission_id: 1, input: invalid },
        message,
      );
    }
  }

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

Deno.test("accepts null and valid coordinate pairs with exact boundaries", () => {
  assert(
    parseAdminContentSubmissionsRequest({
      operation: "create",
      input: input(),
    }).ok,
  );
  assert(
    parseAdminContentSubmissionsRequest({
      operation: "update",
      submission_id: 1,
      input: input({ latitude: null, longitude: null }),
    }).ok,
  );
  const paired = parseAdminContentSubmissionsRequest({
    operation: "create",
    input: input({ latitude: 41.5575078, longitude: 14.6485406 }),
  });
  assert(paired.ok && paired.value.operation === "create");
  assertEquals(paired.value.input.latitude, 41.5575078);
  assertEquals(paired.value.input.longitude, 14.6485406);

  for (
    const [latitude, longitude] of [
      [-90, -180],
      [90, 180],
    ] as const
  ) {
    const boundary = parseAdminContentSubmissionsRequest({
      operation: "create",
      input: input({ latitude, longitude }),
    });
    assert(boundary.ok && boundary.value.operation === "create");
    assertEquals(boundary.value.input.latitude, latitude);
    assertEquals(boundary.value.input.longitude, longitude);
  }
});

Deno.test("rejects out-of-range coordinates with stable messages", () => {
  expectInvalid(
    {
      operation: "create",
      input: input({ latitude: -90.000001, longitude: 0 }),
    },
    "latitude must be between -90 and 90.",
  );
  expectInvalid(
    {
      operation: "create",
      input: input({ latitude: 90.000001, longitude: 0 }),
    },
    "latitude must be between -90 and 90.",
  );
  expectInvalid(
    {
      operation: "create",
      input: input({ latitude: 0, longitude: -180.000001 }),
    },
    "longitude must be between -180 and 180.",
  );
  expectInvalid(
    {
      operation: "create",
      input: input({ latitude: 0, longitude: 180.000001 }),
    },
    "longitude must be between -180 and 180.",
  );
});

Deno.test("rejects half-pairs, non-numbers, and non-finite numbers", () => {
  expectInvalid(
    {
      operation: "create",
      input: input({ latitude: 41.5575078 }),
    },
    "latitude and longitude must be provided together.",
  );
  expectInvalid(
    {
      operation: "update",
      submission_id: 1,
      input: input({ longitude: 14.6485406 }),
    },
    "latitude and longitude must be provided together.",
  );
  for (const badValue of ["41.55", true]) {
    expectInvalid(
      { operation: "create", input: input({ latitude: badValue }) },
      "latitude must be a finite number.",
    );
    expectInvalid(
      { operation: "create", input: input({ longitude: badValue }) },
      "longitude must be a finite number.",
    );
  }
  expectInvalid(
    { operation: "create", input: input({ latitude: Number.NaN }) },
    "latitude must be a finite number.",
  );
  expectInvalid(
    {
      operation: "create",
      input: input({ latitude: 0, longitude: Number.POSITIVE_INFINITY }),
    },
    "longitude must be a finite number.",
  );
});
