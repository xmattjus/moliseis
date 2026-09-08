import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  MAX_REQUEST_BODY_BYTES,
  MAX_SUBMISSION_ASSETS,
  parseContentSubmission as parseContentSubmissionWithCloud,
  parseSubmissionAsset,
  readJsonBodyWithLimit,
  RequestBodyTooLargeError,
  type ValidatedQuillOperation,
} from "./submission_validation.ts";

const cloudName = "test-cloud";
const firstDigest = "a".repeat(64);
const secondDigest = "b".repeat(64);
const canonicalAssetUrl = (digest = firstDigest) =>
  `https://res.cloudinary.com/${cloudName}/image/upload/v1/content_submissions/${digest}.jpg`;
const parseContentSubmission = (value: unknown) =>
  parseContentSubmissionWithCloud(value, cloudName);

const validSubmission = () => ({
  client_submission_id: "00000000-0000-4000-8000-000000000001",
  city: " Campobasso ",
  name: " Teatro ",
  user_email: " author@example.com ",
  user_name: " Autore ",
});

const validDelta = () => [
  { insert: "Visita " },
  { insert: "guidata", attributes: { bold: true } },
  { insert: "\n" },
];

const validAsset = (overrides: Record<string, unknown> = {}) => ({
  url: canonicalAssetUrl(),
  width: 1600,
  height: 1200,
  mime_type: "image/jpeg",
  duration_seconds: null,
  ...overrides,
});

function submissionWithCoordinates(latitude: unknown, longitude: unknown) {
  const submission: Record<string, unknown> = { ...validSubmission() };
  if (latitude !== undefined) submission.latitude = latitude;
  if (longitude !== undefined) submission.longitude = longitude;
  return submission;
}

function expectInvalid(value: unknown, message: string): void {
  const result = parseContentSubmission(value);
  assert(!result.ok);
  assertEquals(result.message, message);
}

Deno.test("accepts absent and null legacy Delta projections", () => {
  for (const description_delta of [undefined, null]) {
    const result = parseContentSubmission({
      ...validSubmission(),
      description: "Legacy text",
      description_delta,
    });

    assert(result.ok);
    assertEquals(result.value.description, "Legacy text");
    assertEquals(result.value.description_delta, null);
  }
});

Deno.test("accepts an empty Quill document as null projections", () => {
  const result = parseContentSubmission({
    ...validSubmission(),
    description: null,
    description_delta: null,
  });

  assert(result.ok);
  assertEquals(result.value.description, null);
  assertEquals(result.value.description_delta, null);
});

Deno.test("normalizes omitted and null categories to null", () => {
  const omitted = parseContentSubmission(validSubmission());
  const explicitNull = parseContentSubmission({
    ...validSubmission(),
    category: null,
  });

  for (const result of [omitted, explicitNull]) {
    assert(result.ok);
    assertEquals(result.value.category, null);
  }
});

Deno.test("coordinates are a nullable finite geographic pair preserved exactly", () => {
  for (
    const [latitude, longitude] of [
      [undefined, undefined],
      [null, null],
      [undefined, null],
      [null, undefined],
      [0, 0],
      [41.561, 14.667],
      [-90, -180],
      [90, 180],
    ] as const
  ) {
    const result = parseContentSubmission(
      submissionWithCoordinates(latitude, longitude),
    );
    assert(result.ok);
    assertEquals(result.value.latitude, latitude ?? null);
    assertEquals(result.value.longitude, longitude ?? null);
  }

  for (
    const submission of [
      { ...validSubmission(), latitude: undefined, longitude: undefined },
      { ...validSubmission(), latitude: undefined, longitude: null },
      { ...validSubmission(), latitude: null, longitude: undefined },
      { ...validSubmission(), latitude: null, longitude: null },
    ]
  ) {
    const result = parseContentSubmission(submission);
    assert(result.ok);
    assertEquals(result.value.latitude, null);
    assertEquals(result.value.longitude, null);
  }

  for (
    const [latitude, longitude, message] of [
      [1, undefined, "latitude and longitude must be provided together"],
      [1, null, "latitude and longitude must be provided together"],
      [undefined, 1, "latitude and longitude must be provided together"],
      [null, 1, "latitude and longitude must be provided together"],
      [undefined, 1, "latitude and longitude must be provided together"],
      [-90.000001, 0, "latitude is not valid"],
      [90.000001, 0, "latitude is not valid"],
      [0, -180.000001, "longitude is not valid"],
      [0, 180.000001, "longitude is not valid"],
      ["1", 0, "latitude is not valid"],
      [true, 0, "latitude is not valid"],
      [{}, 0, "latitude is not valid"],
      [[], 0, "latitude is not valid"],
      [0, [], "longitude is not valid"],
      [0, false, "longitude is not valid"],
      [0, {}, "longitude is not valid"],
      [0, "1", "longitude is not valid"],
      [Number.NaN, 0, "latitude is not valid"],
      [0, Number.POSITIVE_INFINITY, "longitude is not valid"],
      [Number.NEGATIVE_INFINITY, 0, "latitude is not valid"],
      [0, Number.NEGATIVE_INFINITY, "longitude is not valid"],
    ] as const
  ) {
    expectInvalid(submissionWithCoordinates(latitude, longitude), message);
  }
});

Deno.test("public submission assets require the exact canonical Cloudinary delivery URL", () => {
  for (
    const url of [
      canonicalAssetUrl(),
      canonicalAssetUrl(secondDigest).replace("v1", "v2").replace(
        ".jpg",
        ".webp",
      ),
    ]
  ) {
    const result = parseContentSubmission({
      ...validSubmission(),
      assets: [validAsset({ url })],
    });
    assert(result.ok);
    assertEquals(result.value.assets[0].url, url);
  }

  for (
    const url of [
      canonicalAssetUrl().replace("https:", "http:"),
      canonicalAssetUrl().replace("res.cloudinary.com", "example.test"),
      canonicalAssetUrl().replace(cloudName, "wrong-cloud"),
      canonicalAssetUrl().replace("image/upload", "video/upload"),
      canonicalAssetUrl().replace("image/upload", "image/fetch"),
      canonicalAssetUrl().replace("content_submissions", "other"),
      canonicalAssetUrl().replace("v1/", ""),
      canonicalAssetUrl().replace(".jpg", ""),
      canonicalAssetUrl().replace(".jpg", ".JPG"),
      canonicalAssetUrl().replace("v1/", "v1/w_100/"),
      canonicalAssetUrl().replace("v1/", "v1/v2/"),
      canonicalAssetUrl().replace("upload/v1", "upload/./v1"),
      canonicalAssetUrl().replace(
        "content_submissions/",
        "content%5fsubmissions/",
      ),
      canonicalAssetUrl().replace("v1/", "v1/%2e%2e/"),
      canonicalAssetUrl().replace("v1", "v0"),
      canonicalAssetUrl().replace("v1", "v00"),
      canonicalAssetUrl().replace("v1", "v-1"),
      canonicalAssetUrl().replace("v1", "vabc"),
      canonicalAssetUrl().replace(firstDigest, firstDigest.toUpperCase()),
      canonicalAssetUrl().replace(firstDigest, "a".repeat(63)),
      canonicalAssetUrl().replace(firstDigest, `${"a".repeat(63)}g`),
      canonicalAssetUrl().replace(
        "content_submissions/",
        "content_submissions/content_submissions/",
      ),
      canonicalAssetUrl().replace(".jpg", ".j-p-g"),
      `${canonicalAssetUrl()}?x=1`,
      `${canonicalAssetUrl()}#fragment`,
      canonicalAssetUrl().replace("https://", "https://user@"),
      canonicalAssetUrl().replace(
        "res.cloudinary.com",
        "res.cloudinary.com:443",
      ),
      canonicalAssetUrl().replace(
        "res.cloudinary.com",
        "res.cloudinary.com:8443",
      ),
    ]
  ) {
    expectInvalid(
      { ...validSubmission(), assets: [validAsset({ url })] },
      "asset url is not valid",
    );
  }
});

Deno.test("public submission assets reject duplicate public IDs after the maximum size gate", () => {
  const first = validAsset();
  const second = validAsset({ url: canonicalAssetUrl(secondDigest) });
  for (const assets of [[first], [first, second]]) {
    const result = parseContentSubmission({ ...validSubmission(), assets });
    assert(result.ok);
    assertEquals(result.value.assets, assets);
  }
  expectInvalid(
    { ...validSubmission(), assets: [first, first] },
    "assets must not contain duplicates",
  );
  expectInvalid(
    { ...validSubmission(), assets: Array.from({ length: 6 }, () => first) },
    "assets length is not valid",
  );
});

Deno.test("preserves a canonical client submission identity", () => {
  const result = parseContentSubmission({
    ...validSubmission(),
    client_submission_id: "00000000-0000-4000-8000-000000000001",
  });

  assert(result.ok);
  assertEquals(
    result.value.client_submission_id,
    "00000000-0000-4000-8000-000000000001",
  );
});

Deno.test("rejects missing and non-canonical client submission identities", () => {
  const invalidIdentities: Array<[unknown, string]> = [
    [undefined, "client_submission_id is required"],
    [null, "client_submission_id must be a canonical UUID v4"],
    [
      "00000000-0000-4000-8000-00000000000A",
      "client_submission_id must be a canonical UUID v4",
    ],
    [
      "00000000-0000-5000-8000-000000000001",
      "client_submission_id must be a canonical UUID v4",
    ],
    [
      "00000000-0000-4000-7000-000000000001",
      "client_submission_id must be a canonical UUID v4",
    ],
    ["not-a-uuid", "client_submission_id must be a canonical UUID v4"],
    [
      "key:00000000-0000-4000-8000-000000000001",
      "client_submission_id must be a canonical UUID v4",
    ],
  ];

  for (const [client_submission_id, message] of invalidIdentities) {
    const submission = validSubmission();
    if (client_submission_id === undefined) {
      delete (submission as { client_submission_id?: unknown })
        .client_submission_id;
    } else {
      (submission as { client_submission_id: unknown }).client_submission_id =
        client_submission_id;
    }
    expectInvalid(submission, message);
  }
});

Deno.test("rejects the non-null representation of an empty Quill document", () => {
  expectInvalid(
    {
      ...validSubmission(),
      description: "",
      description_delta: [{ insert: "\n" }],
    },
    "empty Quill documents require null description and description_delta",
  );
});

Deno.test("preserves canonical rich projections and supported formats", () => {
  const delta: ValidatedQuillOperation[] = [
    { insert: "  Visita", attributes: { bold: true, italic: true } },
    { insert: " il sito", attributes: { underline: true } },
    { insert: " ufficiale", attributes: { link: "https://example.com/info" } },
    { insert: "\n" },
    { insert: "\n", attributes: { list: "ordered" } },
    { insert: "Seconda voce" },
    { insert: "\n", attributes: { list: "bullet" } },
    { insert: "\n" },
  ];
  const result = parseContentSubmission({
    ...validSubmission(),
    description: "  Visita il sito ufficiale\n\nSeconda voce\n",
    description_delta: delta,
  });

  assert(result.ok);
  assertEquals(
    result.value.description,
    "  Visita il sito ufficiale\n\nSeconda voce\n",
  );
  assertEquals(result.value.description_delta, delta);
  assertEquals(result.value.city, "Campobasso");
});

Deno.test("accepts exactly 5,000 authored characters and rejects longer text", () => {
  const withinLimit = "a".repeat(5000);
  const accepted = parseContentSubmission({
    ...validSubmission(),
    description: withinLimit,
    description_delta: [{ insert: `${withinLimit}\n` }],
  });
  assert(accepted.ok);

  const tooLong = "a".repeat(5001);
  expectInvalid(
    {
      ...validSubmission(),
      description: tooLong,
      description_delta: [{ insert: `${tooLong}\n` }],
    },
    "description exceeds maximum length of 5000",
  );
});

Deno.test("counts legacy description whitespace toward the maximum length", () => {
  const whitespacePaddedDescription = `${" ".repeat(2501)}text${
    " ".repeat(2500)
  }`;

  expectInvalid(
    {
      ...validSubmission(),
      description: whitespacePaddedDescription,
      description_delta: null,
    },
    "description exceeds maximum length of 5000",
  );
});

Deno.test("rejects malformed Delta shapes, operations, and attributes", () => {
  expectInvalid(
    { ...validSubmission(), description: "x", description_delta: {} },
    "description_delta must be a non-empty array when present",
  );
  expectInvalid(
    { ...validSubmission(), description: "x", description_delta: [{}] },
    "description_delta operations may contain only insert and attributes",
  );
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      description_delta: [{ insert: "" }],
    },
    "description_delta insert must be a non-empty string",
  );
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      description_delta: [{ insert: "x\n", attributes: { bold: false } }],
    },
    "description_delta bold must be true",
  );
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      description_delta: [{ insert: "x\n", attributes: null }],
    },
    "description_delta attributes must be a non-empty object",
  );
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      description_delta: [{ insert: "x\n", attributes: { italic: "true" } }],
    },
    "description_delta italic must be true",
  );
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      description_delta: [{ insert: "x\n", attributes: { link: null } }],
    },
    "description_delta link must be an absolute HTTP/HTTPS URL",
  );
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      description_delta: [{ insert: "x\n", attributes: { color: "red" } }],
    },
    "description_delta attribute color is not supported",
  );
});

Deno.test("rejects unsupported operations, unsafe links, and invalid list placement", () => {
  for (
    const unsupportedOperation of [{ retain: 1 }, { delete: 1 }, {
      insert: { image: "https://example.test/image.png" },
    }]
  ) {
    expectInvalid(
      {
        ...validSubmission(),
        description: "x",
        description_delta: [unsupportedOperation, { insert: "x\n" }],
      },
      "insert" in unsupportedOperation
        ? "description_delta insert must be a non-empty string"
        : "description_delta operations may contain only insert and attributes",
    );
  }
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      description_delta: [{
        insert: "x\n",
        attributes: { link: "javascript:alert(1)" },
      }],
    },
    "description_delta link must be an absolute HTTP/HTTPS URL",
  );
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      description_delta: [{
        insert: "x\n",
        attributes: { link: "https://" },
      }],
    },
    "description_delta link must be an absolute HTTP/HTTPS URL",
  );
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      description_delta: [{ insert: "x", attributes: { list: "ordered" } }],
    },
    "description_delta list must be ordered or bullet on an exact newline insert",
  );
});

Deno.test("rejects non-canonical and mismatched Delta projections", () => {
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      description_delta: [{ insert: "x" }, { insert: "\n" }],
    },
    "description_delta contains adjacent operations Quill would normalize",
  );
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      description_delta: [{ insert: "x" }],
    },
    "description_delta must end with a terminal newline",
  );
  expectInvalid(
    {
      ...validSubmission(),
      description: "different",
      description_delta: validDelta(),
    },
    "description does not match description_delta plain text",
  );
});

Deno.test("rejects non-string submission and asset fields before normalization", () => {
  expectInvalid({ ...validSubmission(), city: 1 }, "city is required");
  expectInvalid(
    { ...validSubmission(), description: "x", latitude: "1" },
    "latitude is not valid",
  );
  expectInvalid(
    {
      ...validSubmission(),
      description: "x",
      assets: [{
        url: "https://res.cloudinary.com/demo/image",
        width: "1",
        height: 1,
      }],
    },
    "asset is not valid",
  );
});

Deno.test("preserves compatible dates and rejects invalid public ranges", () => {
  for (
    const start_date of [
      "2026-08-20",
      "2026-08-20T10:00:00",
      "2026-08-20T10:00:00Z",
      "2026-08-20T10:00:00+02:00",
      "2026-08-20T10:00:00-02:00",
      "2026-08-20T10:00:00.000100Z",
    ]
  ) {
    const result = parseContentSubmission({ ...validSubmission(), start_date });
    assert(result.ok);
    assertEquals(result.value.start_date, start_date);
    assertEquals(result.value.end_date, null);
  }

  const offsetEquivalent = parseContentSubmission({
    ...validSubmission(),
    start_date: "2026-08-21T10:00:00.000Z",
    end_date: "2026-08-21T12:00:00.000+02:00",
  });
  assert(offsetEquivalent.ok);
  assertEquals(
    offsetEquivalent.value.start_date,
    "2026-08-21T10:00:00.000Z",
  );
  assertEquals(
    offsetEquivalent.value.end_date,
    "2026-08-21T12:00:00.000+02:00",
  );

  for (
    const submission of [
      validSubmission(),
      { ...validSubmission(), start_date: null, end_date: null },
    ]
  ) {
    const result = parseContentSubmission(submission);
    assert(result.ok);
    assertEquals(result.value.start_date, null);
    assertEquals(result.value.end_date, null);
  }

  expectInvalid(
    { ...validSubmission(), start_date: "not-a-date" },
    "start_date is not valid",
  );
  expectInvalid(
    { ...validSubmission(), end_date: "not-a-date" },
    "end_date is not valid",
  );
  for (
    const invalidDate of [
      "2024-04-31",
      "2024-04-31T10:00:00Z",
      "2024-04-31T10:00:00+02:00",
      "2024-04-31T10:00:00.000100Z",
    ]
  ) {
    expectInvalid(
      { ...validSubmission(), start_date: invalidDate },
      "start_date is not valid",
    );
    expectInvalid(
      {
        ...validSubmission(),
        start_date: "2026-08-20",
        end_date: invalidDate,
      },
      "end_date is not valid",
    );
  }
  expectInvalid(
    { ...validSubmission(), end_date: "2026-08-20T10:00:00Z" },
    "end_date requires start_date",
  );
  expectInvalid(
    {
      ...validSubmission(),
      start_date: "2026-08-21T10:00:00.000999Z",
      end_date: "2026-08-21T10:00:00.000001Z",
    },
    "end_date must not be before start_date",
  );
});

Deno.test("accepts five assets and rejects a sixth", () => {
  const accepted = parseContentSubmission({
    ...validSubmission(),
    assets: Array.from(
      { length: MAX_SUBMISSION_ASSETS },
      (_, index) =>
        validAsset({
          url: canonicalAssetUrl(`${index}`.padStart(64, "0")),
        }),
    ),
  });

  assert(accepted.ok);
  assertEquals(accepted.value.assets.length, MAX_SUBMISSION_ASSETS);
  expectInvalid(
    {
      ...validSubmission(),
      assets: Array.from(
        { length: MAX_SUBMISSION_ASSETS + 1 },
        (_, index) =>
          validAsset({
            url: canonicalAssetUrl(`${index}`.padStart(64, "0")),
          }),
      ),
    },
    "assets length is not valid",
  );
});

Deno.test("single-asset parsing rejects values incompatible with integer columns", () => {
  for (
    const [asset, message] of [
      [
        validAsset({ width: 1.5 }),
        "asset width must be a positive safe integer",
      ],
      [
        validAsset({ height: Number.MAX_SAFE_INTEGER + 1 }),
        "asset height must be a positive safe integer",
      ],
      [
        validAsset({ width: 2_147_483_648 }),
        "asset width must be a positive safe integer",
      ],
      [
        validAsset({ duration_seconds: -1 }),
        "asset duration_seconds must be a non-negative safe integer",
      ],
      [
        validAsset({ duration_seconds: 1.5 }),
        "asset duration_seconds must be a non-negative safe integer",
      ],
    ] as const
  ) {
    const result = parseSubmissionAsset(asset);
    assert(!result.ok);
    assertEquals(result.message, message);
  }
});

Deno.test("enforces the streaming request-body limit", async () => {
  const oversizedBody = "x".repeat(MAX_REQUEST_BODY_BYTES + 1);
  const request = new Request("https://example.test", {
    method: "POST",
    body: oversizedBody,
  });

  await assertRejects(
    () => readJsonBodyWithLimit(request),
    RequestBodyTooLargeError,
  );
});

async function assertRejects(
  action: () => Promise<unknown>,
  expected: new (...args: never[]) => Error,
): Promise<void> {
  try {
    await action();
  } catch (error) {
    assert(error instanceof expected);
    return;
  }
  throw new Error("Expected promise to reject");
}
