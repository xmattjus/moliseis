import { parseAdminContentSubmissionsRequest } from "../admin-content-submissions/admin_submission_validation.ts";
import { assertEquals, assertMatch, assertThrows } from "jsr:@std/assert@1";
import {
  canonicalizeEvent,
  canonicalizeExternalEvent,
  canonicalizeSubmission,
  hashNormalizedExternalEvent,
  NORMALIZED_EVENT_FIELDS,
  type NormalizedExternalEvent,
} from "./external_event_normalization.ts";

export const normalizedFixture: NormalizedExternalEvent = {
  name: "Concerto",
  category: "unknown",
  description: null,
  description_delta: null,
  city: "Campobasso",
  latitude: null,
  longitude: null,
  all_day: false,
  start_date: "2026-10-02T10:00:00.123456Z",
  end_date: null,
};

Deno.test("normalized v1 is complete, ordered and deterministically hashed", async () => {
  const normalized = canonicalizeExternalEvent(normalizedFixture);
  assertEquals(normalized, normalizedFixture);
  assertEquals(Object.keys(normalized), [...NORMALIZED_EVENT_FIELDS]);
  const hash = await hashNormalizedExternalEvent(normalized);
  assertMatch(hash, /^[0-9a-f]{64}$/);
  assertEquals(await hashNormalizedExternalEvent(normalized), hash);
});

Deno.test("NFC trims only title/city and preserves description whitespace and empty/null", async () => {
  const normalized = canonicalizeExternalEvent({
    ...normalizedFixture,
    name: "  Cafe\u0301  ",
    city: "  Isernia  ",
    description: "  Cafe\u0301 \n ",
  });
  assertEquals(normalized.name, "Café");
  assertEquals(normalized.city, "Isernia");
  assertEquals(normalized.description, "  Café \n ");
  const empty = canonicalizeExternalEvent({
    ...normalizedFixture,
    description: "",
  });
  assertEquals(empty.description, "");
  assertEquals(
    (await hashNormalizedExternalEvent(empty)) ===
      (await hashNormalizedExternalEvent(
        canonicalizeExternalEvent(normalizedFixture),
      )),
    false,
  );
});

Deno.test("UTC conversion retains all six microsecond digits across offsets/day/year", () => {
  for (
    const [start_date, expected] of [
      ["2026-10-02T12:00:00.123456+02:00", "2026-10-02T10:00:00.123456Z"],
      ["2026-01-01T00:15:00.000001+01:00", "2025-12-31T23:15:00.000001Z"],
      ["2026-10-02 10:00:00.1+00", "2026-10-02T10:00:00.100000Z"],
      ["2026-10-02T10:00:00Z", "2026-10-02T10:00:00.000000Z"],
    ]
  ) {
    assertEquals(
      canonicalizeExternalEvent({ ...normalizedFixture, start_date })
        .start_date,
      expected,
    );
  }
});

Deno.test("coordinate strings converge on finite double representation and negative zero", () => {
  for (const latitude of [-0, "-0.000", "0", 0]) {
    assertEquals(
      canonicalizeExternalEvent({ ...normalizedFixture, latitude }).latitude,
      "0",
    );
  }
  for (
    const value of [
      41.123456789012345,
      "41.123456789012345",
      "4.1123456789012345e1",
    ]
  ) {
    const normalized = canonicalizeExternalEvent({
      ...normalizedFixture,
      latitude: value,
    });
    assertEquals(
      normalized.latitude,
      "41.1234567890123",
    );
    assertEquals(
      canonicalizeExternalEvent({
        ...normalized,
        latitude: Number(normalized.latitude),
      }),
      normalized,
    );
  }
});

Deno.test("Delta keeps operation order, NFC plain text coherence and fixed attribute order", async () => {
  const left = canonicalizeExternalEvent({
    ...normalizedFixture,
    description: "Cafe\u0301",
    description_delta: [
      {
        insert: "Cafe\u0301",
        attributes: { link: "https://example.test", italic: true, bold: true },
      },
      { insert: "\n" },
    ],
  });
  const right = canonicalizeExternalEvent({
    ...normalizedFixture,
    description: "Café",
    description_delta: [
      {
        attributes: { bold: true, italic: true, link: "https://example.test" },
        insert: "Café",
      },
      { insert: "\n" },
    ],
  });
  assertEquals(left, right);
  assertEquals(
    Object.keys(
      (left.description_delta as { attributes: object }[])[0].attributes,
    ),
    ["bold", "italic", "link"],
  );
  assertEquals(
    await hashNormalizedExternalEvent(left),
    await hashNormalizedExternalEvent(right),
  );
});

Deno.test("invalid Delta terminal/adjacency/attrs, dates and coordinates fail closed", () => {
  for (
    const patch of [
      { description: "text", description_delta: [{ insert: "text" }] },
      {
        description: "text",
        description_delta: [{ insert: "te" }, { insert: "xt\n" }],
      },
      {
        description: "text",
        description_delta: [{
          insert: "text\n",
          attributes: { unsupported: true },
        }],
      },
      { start_date: null },
      { start_date: "2026-02-30T10:00:00Z" },
      { start_date: "2026-10-02T24:00:00Z" },
      { start_date: "2026-10-02T10:00:00.1234567Z" },
      { end_date: "2026-10-02T10:00:00.123455Z" },
      { latitude: NaN },
      { latitude: Infinity },
      { latitude: "" },
      { latitude: 91 },
      { longitude: -181 },
    ]
  ) {
    assertThrows(() =>
      canonicalizeExternalEvent({ ...normalizedFixture, ...patch })
    );
  }
});

Deno.test("all-day canonical boundaries retain inclusive last microsecond across Rome DST", () => {
  const allDay = canonicalizeExternalEvent({
    ...normalizedFixture,
    all_day: true,
    start_date: "2026-10-24T22:00:00.000Z",
    end_date: "2026-10-25T22:59:59.999999Z",
  });
  assertEquals(allDay.start_date, "2026-10-24T22:00:00.000000Z");
  assertEquals(allDay.end_date, "2026-10-25T22:59:59.999999Z");
  assertThrows(() =>
    canonicalizeExternalEvent({
      ...allDay,
      start_date: "2026-10-25T00:00:00.000000Z",
    })
  );
});

Deno.test("every canonical field participates in full-shape hashing", async () => {
  const normalized = canonicalizeExternalEvent(normalizedFixture);
  const hash = await hashNormalizedExternalEvent(normalized);
  for (
    const patch of [
      { name: "Changed" },
      { category: "nature" },
      { description: "Changed" },
      { description: "Changed", description_delta: [{ insert: "Changed\n" }] },
      { city: "Changed" },
      { latitude: "41" },
      { longitude: "14" },
      { start_date: "2026-10-02T10:00:00.123457Z" },
      { end_date: "2026-10-02T11:00:00.000000Z" },
      { all_day: true, start_date: "2026-10-01T22:00:00.000000Z" },
    ]
  ) {
    assertEquals(
      (await hashNormalizedExternalEvent(
        canonicalizeExternalEvent({ ...normalized, ...patch }),
      )) === hash,
      false,
    );
  }
});

Deno.test("per-insert NFC remains idempotent across formatting boundaries", () => {
  const delta = [{ insert: "e", attributes: { bold: true } }, {
    insert: "\u0301\n",
  }];
  const original = canonicalizeExternalEvent({
    ...normalizedFixture,
    description: "e\u0301",
    description_delta: delta,
  });
  assertEquals(original.description, "e\u0301");
  assertEquals(original.description_delta, delta);
  assertEquals(canonicalizeExternalEvent(original), original);
  // Canonicalization equivalence alone does not prove Admin Save compatibility.
  assertEquals(
    canonicalizeExternalEvent({ ...original, description: "é" }),
    original,
  );
  assertThrows(() =>
    canonicalizeExternalEvent({ ...original, description: "wrong" })
  );
});

Deno.test("UTC offset crossing the supported four-digit year range is rejected", () => {
  for (
    const start_date of [
      "9999-12-31T23:59:59-01:00",
      "0000-01-01T00:00:00Z",
      "0001-01-01T00:00:00+01:00",
    ]
  ) {
    assertThrows(() =>
      canonicalizeExternalEvent({ ...normalizedFixture, start_date })
    );
  }
});

Deno.test("canonical source Delta survives exact loaded Admin no-op Save", () => {
  const raw = {
    ...normalizedFixture,
    description: "e\u0301",
    description_delta: [
      { insert: "e", attributes: { bold: true } },
      { insert: "\u0301\n" },
    ],
  };
  const request = (input: typeof raw | NormalizedExternalEvent) => ({
    operation: "update",
    submission_id: 1,
    input: { ...input, start_calendar_date: null, end_calendar_date: null },
  });
  assertEquals(
    parseAdminContentSubmissionsRequest(request(raw)).ok,
    true,
    "Original baseline Delta is valid",
  );
  const persistedCanonical = canonicalizeExternalEvent(raw);
  const noOpSave = parseAdminContentSubmissionsRequest(
    request(persistedCanonical),
  );
  assertEquals(
    noOpSave.ok,
    true,
    "Canonical enqueue row loaded unchanged must remain valid through ordinary Admin Save",
  );
});

Deno.test("Quill NFC preserves attribute values and equal canonical hashes without boundary differences", async () => {
  const attrs = { link: "https://example.test/Cafe\u0301", bold: true };
  const a = canonicalizeExternalEvent({
    ...normalizedFixture,
    description: "Cafe\u0301",
    description_delta: [{ insert: "Cafe\u0301", attributes: attrs }, {
      insert: "\n",
    }],
  });
  const b = canonicalizeExternalEvent({
    ...normalizedFixture,
    description: "Café",
    description_delta: [{
      insert: "Café",
      attributes: { bold: true, link: attrs.link },
    }, { insert: "\n" }],
  });
  assertEquals(a, b);
  assertEquals(
    (a.description_delta as { attributes: { link: string } }[])[0].attributes
      .link,
    attrs.link,
  );
  assertEquals(
    await hashNormalizedExternalEvent(a),
    await hashNormalizedExternalEvent(b),
  );
  assertEquals(canonicalizeExternalEvent(a), a);
});

Deno.test("coordinate v1 precision is 15 significant digits before SQL and remains idempotent", () => {
  for (
    const [input, expected] of [
      ["41.123456789012344", "41.1234567890123"],
      ["41.1234567890123", "41.1234567890123"],
      ["0.0000000012345678901234567", "1.23456789012346e-9"],
      ["-0", "0"],
    ]
  ) {
    const canonical = canonicalizeExternalEvent({
      ...normalizedFixture,
      latitude: input,
    });
    assertEquals(canonical.latitude, expected);
    assertEquals(canonicalizeExternalEvent(canonical), canonical);
  }
  assertThrows(() =>
    canonicalizeExternalEvent({
      ...normalizedFixture,
      latitude: "90.00000000000001",
    })
  );
});

Deno.test("Persisted submission and canonical Event share every field rule with explicit nullable Event city", () => {
  const wire = {
    ...normalizedFixture,
    name: "  Cafe\u0301  ",
    city: " Campobasso ",
    latitude: 41.123456789012345,
    longitude: -0,
    start_date: "2026-10-02 12:00:00.123456+02",
  };
  const source = canonicalizeExternalEvent(wire);
  assertEquals(canonicalizeSubmission(wire), source);
  assertEquals(canonicalizeEvent(wire), source);
  const noCity = canonicalizeEvent({ ...wire, city: null });
  assertEquals(noCity, { ...source, city: null });
  assertEquals(canonicalizeEvent(noCity), noCity);
  assertThrows(() => canonicalizeExternalEvent({ ...wire, city: null }));
  assertThrows(() => canonicalizeSubmission({ ...wire, city: null }));
  assertThrows(() => canonicalizeEvent({ ...wire, city: " " }));
});
