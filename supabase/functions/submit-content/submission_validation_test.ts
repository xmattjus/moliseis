import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  MAX_REQUEST_BODY_BYTES,
  MAX_SUBMISSION_ASSETS,
  parseContentSubmission,
  parseSubmissionAsset,
  readJsonBodyWithLimit,
  RequestBodyTooLargeError,
  type ValidatedQuillOperation,
} from "./submission_validation.ts";

const validSubmission = () => ({
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
  url: "https://res.cloudinary.com/demo/image/upload/v1/example.jpg",
  width: 1600,
  height: 1200,
  mime_type: "image/jpeg",
  duration_seconds: null,
  ...overrides,
});

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
  expectInvalid({ city: 1 }, "city is required");
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
          url:
            `https://res.cloudinary.com/demo/image/upload/v1/example-${index}.jpg`,
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
            url:
              `https://res.cloudinary.com/demo/image/upload/v1/example-${index}.jpg`,
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
