import { assert, assertEquals } from "jsr:@std/assert@1";

import { validateSubmissionDates } from "./submission_dates.ts";

Deno.test("accepts supported nullable ISO-like date forms unchanged", () => {
  const supportedStarts = [
    "2026-08-20",
    "2026-08-20T10:00:00",
    "2026-08-20T10:00:00Z",
    "2026-08-20T10:00:00+02:00",
    "2026-08-20T10:00:00-02:00",
    "2026-08-20T10:00:00.000100Z",
  ];

  for (const startDate of supportedStarts) {
    const result = validateSubmissionDates(startDate, null);
    assert(result.ok);
    assertEquals(result.value, { start_date: startDate, end_date: null });
  }

  assertEquals(validateSubmissionDates(null, null), {
    ok: true,
    value: { start_date: null, end_date: null },
  });
});

Deno.test("enforces Gregorian validity for every supported date form", () => {
  for (const date of ["2000-02-29", "2024-02-29", "2024-04-30"]) {
    assertEquals(validateSubmissionDates(date, null), {
      ok: true,
      value: { start_date: date, end_date: null },
    });
  }

  const impossibleDates = [
    "1900-02-29",
    "2023-02-29",
    "2024-04-31",
    "2024-04-31T10:00:00",
    "2024-04-31T10:00:00Z",
    "2024-04-31T10:00:00+02:00",
    "2024-04-31T10:00:00.000100Z",
  ];
  for (const date of impossibleDates) {
    assertEquals(validateSubmissionDates(date, null), {
      ok: false,
      error: "invalid_start_date",
    });
    assertEquals(validateSubmissionDates("2026-08-20", date), {
      ok: false,
      error: "invalid_end_date",
    });
  }
});

Deno.test("rejects invalid dates and end dates without a start", () => {
  for (
    const [startDate, endDate, error] of [
      ["", null, "invalid_start_date"],
      [1, null, "invalid_start_date"],
      ["not-a-date", null, "invalid_start_date"],
      ["2026/08/20", null, "invalid_start_date"],
      ["2026-08-20 10:00:00Z", null, "invalid_start_date"],
      [null, "", "invalid_end_date"],
      [null, false, "invalid_end_date"],
      [null, "not-a-date", "invalid_end_date"],
      ["2026-08-20", "August 20, 2026", "invalid_end_date"],
      [null, "2026-08-20T10:00:00Z", "end_date_requires_start_date"],
    ] as const
  ) {
    assertEquals(validateSubmissionDates(startDate, endDate), {
      ok: false,
      error,
    });
  }
});

Deno.test("accepts equal and chronological instants including microseconds", () => {
  for (
    const [startDate, endDate] of [
      ["2026-08-20T10:00:00.000Z", "2026-08-20T10:00:00.000Z"],
      ["2026-08-21T10:00:00.000Z", "2026-08-21T12:00:00.000+02:00"],
      ["2026-08-20T10:00:00.000100Z", "2026-08-20T10:00:00.000900Z"],
      [
        "2026-08-20T10:00:00.000500Z",
        "2026-08-20T12:00:00.000500+02:00",
      ],
    ]
  ) {
    const result = validateSubmissionDates(startDate, endDate);
    assert(result.ok);
    assertEquals(result.value, { start_date: startDate, end_date: endDate });
  }
});

Deno.test("rejects inverted ranges including within one millisecond", () => {
  for (
    const [startDate, endDate] of [
      ["2026-08-21T10:00:00.000Z", "2026-08-20T10:00:00.000Z"],
      ["2026-08-20T10:00:00.000999Z", "2026-08-20T10:00:00.000001Z"],
    ]
  ) {
    assertEquals(validateSubmissionDates(startDate, endDate), {
      ok: false,
      error: "end_date_before_start_date",
    });
  }
});
