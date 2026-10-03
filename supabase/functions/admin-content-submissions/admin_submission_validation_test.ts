import { assert, assertEquals } from "jsr:@std/assert@1";

import { parseAdminContentSubmissionsRequest } from "./admin_submission_validation.ts";

const input = (overrides: Record<string, unknown> = {}) => ({
  category: "unknown",
  city: " Campobasso ",
  name: " Teatro ",
  description: null,
  description_delta: null,
  all_day: false,
  start_calendar_date: null,
  end_calendar_date: null,
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
    { operation: "changeStatus", submission_id: 1, status: "rejected" },
    { operation: "promote", submission_id: 1, target: "place" },
    { operation: "promote", submission_id: 2, target: "event" },
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

  const promoted = parseAdminContentSubmissionsRequest({
    operation: "promote",
    submission_id: 1,
    target: "place",
  });
  assert(promoted.ok && promoted.value.operation === "promote");
  assertEquals(promoted.value.submission_id, 1);
  assertEquals(promoted.value.target, "place");
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
        status: "rejected",
        extra: true,
      },
      { operation: "promote", submission_id: 1 },
      { operation: "promote", target: "place" },
      { operation: "promote", submission_id: 1, target: "place", extra: true },
    ]
  ) expectInvalid(request, "Request contains unsupported or missing fields.");
  for (const id of [0, -1, 1.5, "1", Number.MAX_SAFE_INTEGER + 1]) {
    expectInvalid(
      { operation: "getById", submission_id: id },
      "submission_id must be a positive safe integer.",
    );
    expectInvalid(
      { operation: "promote", submission_id: id, target: "place" },
      "submission_id must be a positive safe integer.",
    );
  }
  // The standalone accept path cannot survive through any request shape:
  // accepted is no longer a valid changeStatus status.
  expectInvalid(
    { operation: "changeStatus", submission_id: 1, status: "accepted" },
    "status must be rejected.",
  );
  for (const status of ["pending", "accepted", "other"]) {
    expectInvalid(
      { operation: "changeStatus", submission_id: 1, status },
      "status must be rejected.",
    );
  }
  for (const target of ["Place", "places", null, 1, undefined]) {
    expectInvalid(
      { operation: "promote", submission_id: 1, target },
      "target must be place or event.",
    );
  }
});

Deno.test("requires the exact twelve editor input fields and rejects spoofing", () => {
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
    const startDate of [
      "2026-08-20",
      "2026-08-20T10:00:00",
      "2026-08-20T10:00:00Z",
      "2026-08-20T10:00:00+02:00",
      "2026-08-20T10:00:00-02:00",
      subMillisecondStart,
    ]
  ) {
    const result = parseAdminContentSubmissionsRequest({
      operation: "create",
      input: input({ start_date: startDate }),
    });
    assert(result.ok && result.value.operation === "create");
    assertEquals(result.value.input.start_date, startDate);
  }

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

  for (
    const invalidDate of [
      "2024-04-31",
      "2024-04-31T10:00:00Z",
      "2024-04-31T10:00:00+02:00",
      "2024-04-31T10:00:00.000100Z",
    ]
  ) {
    for (const operation of ["create", "update"] as const) {
      expectInvalid(
        operation === "create"
          ? { operation, input: input({ start_date: invalidDate }) }
          : {
            operation,
            submission_id: 1,
            input: input({ start_date: invalidDate }),
          },
        "start_date must be a parseable date-time string or null.",
      );
      expectInvalid(
        operation === "create"
          ? {
            operation,
            input: input({
              start_date: "2026-08-20",
              end_date: invalidDate,
            }),
          }
          : {
            operation,
            submission_id: 1,
            input: input({
              start_date: "2026-08-20",
              end_date: invalidDate,
            }),
          },
        "end_date must be a parseable date-time string or null.",
      );
    }
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

Deno.test("Admin complete input shares civil normalization and mode transitions", () => {
  for (const operation of ["create", "update"]) {
    for (
      const fields of [
        {
          all_day: true,
          start_calendar_date: "2026-03-29",
          end_calendar_date: "2026-03-29",
        },
        {
          all_day: false,
          start_date: "2026-03-29T10:00:00.000Z",
          end_date: null,
        },
        {},
      ]
    ) {
      const result = parseAdminContentSubmissionsRequest({
        operation,
        ...(operation === "update" ? { submission_id: 1 } : {}),
        input: input(fields),
      });
      assert(
        result.ok &&
          (result.value.operation === "create" ||
            result.value.operation === "update"),
      );
      assertEquals(result.value.input.all_day, fields.all_day ?? false);
      if (fields.all_day) {
        assertEquals(result.value.input.start_date, "2026-03-28T23:00:00.000Z");
        assertEquals(
          result.value.input.end_date,
          "2026-03-29T21:59:59.999999Z",
        );
      }
      assert(!Object.hasOwn(result.value.input, "start_calendar_date"));
      assert(!Object.hasOwn(result.value.input, "end_calendar_date"));
    }
  }
});

Deno.test("Admin requires every temporal key and rejects invalid temporal representations", () => {
  for (const key of ["all_day", "start_calendar_date", "end_calendar_date"]) {
    const missing: Record<string, unknown> = input();
    delete missing[key];
    expectInvalid(
      { operation: "create", input: missing },
      "input contains unsupported or missing fields.",
    );
  }
  for (
    const [fields, message] of [
      [{ all_day: null }, "all_day must be a boolean."],
      [
        { all_day: true },
        "start_calendar_date must be a Gregorian YYYY-MM-DD date.",
      ],
      [
        { all_day: true, start_calendar_date: "1900-02-29" },
        "start_calendar_date must be a Gregorian YYYY-MM-DD date.",
      ],
      [{
        all_day: true,
        start_calendar_date: "2026-01-02",
        end_calendar_date: "2026-01-01",
      }, "end_date must not be before start_date."],
      [{
        all_day: true,
        start_calendar_date: "2026-01-02",
        end_calendar_date: "2026-02-30",
      }, "end_calendar_date must be a Gregorian YYYY-MM-DD date or null."],
      [{
        all_day: true,
        start_calendar_date: "2026-01-01",
        start_date: "2026-01-01",
      }, "timestamp and civil-date formats must not be mixed."],
      [
        { start_calendar_date: "2026-01-01" },
        "timestamp and civil-date formats must not be mixed.",
      ],
    ] as const
  ) {
    expectInvalid({ operation: "create", input: input(fields) }, message);
  }
});

Deno.test("Reject ignore option is explicit boolean; actor and importer identity cannot be supplied", () => {
  const body = {
    operation: "changeStatus",
    submission_id: 7,
    status: "rejected",
    ignore_source: true,
  } as const;
  assertEquals(parseAdminContentSubmissionsRequest(body), {
    ok: true,
    value: body,
  });
  for (
    const extra of [{ handled_by: "spoof" }, { importer_user_id: "spoof" }, {
      ignore_source: "true",
    }, { status: "accepted" }]
  ) {
    assertEquals(
      parseAdminContentSubmissionsRequest({ ...body, ...extra }).ok,
      false,
    );
  }
});

Deno.test("Ignored source Admin operations have closed envelopes and positive ID", () => {
  assertEquals(
    parseAdminContentSubmissionsRequest({ operation: "listIgnoredSources" }).ok,
    true,
  );
  assertEquals(
    parseAdminContentSubmissionsRequest({
      operation: "unIgnoreSource",
      external_event_record_id: 19,
    }).ok,
    true,
  );
  for (
    const body of [
      { operation: "listIgnoredSources", handled_by: "spoof" },
      {
        operation: "unIgnoreSource",
        external_event_record_id: 19,
        handled_by: "spoof",
      },
      { operation: "unIgnoreSource", external_event_record_id: 0 },
      {
        operation: "unIgnoreSource",
        external_event_record_id: 19,
        importer_user_id: "spoof",
      },
    ]
  ) assertEquals(parseAdminContentSubmissionsRequest(body).ok, false);
});

Deno.test("Reject acknowledgement preserves exact shown hash; missing semantic hash reaches resolution", () => {
  const shown = "a".repeat(64);
  const base = {
    operation: "changeStatus",
    submission_id: 7,
    status: "rejected",
    acknowledge_current_source: true,
  } as const;
  assertEquals(parseAdminContentSubmissionsRequest(base), {
    ok: true,
    value: base,
  });
  assertEquals(
    parseAdminContentSubmissionsRequest({
      ...base,
      expected_source_hash: shown,
    }),
    { ok: true, value: { ...base, expected_source_hash: shown } },
  );
  for (
    const patch of [
      { acknowledge_current_source: 1 },
      { expected_source_hash: 3 },
      { expected_source_hash: ` ${shown}` },
      { handled_by: "spoof" },
    ]
  ) {
    assertEquals(
      parseAdminContentSubmissionsRequest({ ...base, ...patch }).ok,
      false,
    );
  }
});

Deno.test("Link closes Event target/actor envelope and preserves acknowledgement hash", () => {
  const body = {
    operation: "link",
    submission_id: 7,
    target_event_id: 19,
    acknowledge_current_source: true,
    expected_source_hash: "a".repeat(64),
  } as const;
  assertEquals(parseAdminContentSubmissionsRequest(body), {
    ok: true,
    value: body,
  });
  for (
    const extra of [{ handled_by: "spoof" }, { groups_to_apply: ["name"] }, {
      target_event_id: 0,
    }, { acknowledge_current_source: "true" }]
  ) {
    assertEquals(
      parseAdminContentSubmissionsRequest({ ...body, ...extra }).ok,
      false,
    );
  }
});

Deno.test("Event candidate requests close actor fields and support manual name or Event ID", () => {
  for (
    const extra of [{}, { target_event_id: 19 }, { search_name: " Concert " }]
  ) {
    assertEquals(
      parseAdminContentSubmissionsRequest({
        operation: "eventCandidates",
        submission_id: 7,
        ...extra,
      }).ok,
      true,
    );
  }
  for (
    const extra of [{ target_event_id: 0 }, { search_name: " " }, {
      target_event_id: 19,
      search_name: "Concert",
    }, { handled_by: "spoof" }]
  ) {
    assertEquals(
      parseAdminContentSubmissionsRequest({
        operation: "eventCandidates",
        submission_id: 7,
        ...extra,
      }).ok,
      false,
    );
  }
});

Deno.test("Apply accepts opaque tokens and rejects caller actor/group authority", () => {
  const body = {
    operation: "apply",
    submission_id: 7,
    target_event_id: 19,
    submission_version_token: "  original raw token  ",
    event_version_token: "old",
  };
  const parsed = parseAdminContentSubmissionsRequest(body);
  assertEquals(parsed.ok, true);
  if (parsed.ok && parsed.value.operation === "apply") {
    assertEquals(
      parsed.value.submission_version_token,
      body.submission_version_token,
    );
  }
  for (
    const extra of [{ handled_by: "spoof" }, { handledBy: "spoof" }, {
      importer_user_id: "spoof",
    }, { groups_to_apply: ["name"] }]
  ) {
    assertEquals(
      parseAdminContentSubmissionsRequest({ ...body, ...extra }).ok,
      false,
    );
  }
  assertEquals(
    parseAdminContentSubmissionsRequest({
      ...body,
      acknowledge_current_source: true,
    }).ok,
    true,
  );
  assertEquals(
    parseAdminContentSubmissionsRequest({
      ...body,
      submission_version_token: null,
    }).ok,
    false,
  );
});
