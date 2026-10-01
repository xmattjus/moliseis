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
    assertEquals(result.value, {
      all_day: false,
      start_date: startDate,
      end_date: null,
    });
  }

  assertEquals(validateSubmissionDates(null, null), {
    ok: true,
    value: { all_day: false, start_date: null, end_date: null },
  });
});

Deno.test("enforces Gregorian validity for every supported date form", () => {
  for (const date of ["2000-02-29", "2024-02-29", "2024-04-30"]) {
    assertEquals(validateSubmissionDates(date, null), {
      ok: true,
      value: { all_day: false, start_date: date, end_date: null },
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
    assertEquals(result.value, {
      all_day: false,
      start_date: startDate,
      end_date: endDate,
    });
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

Deno.test("all-day dates normalize Rome bounds with exact final microseconds", () => {
  for (
    const [start, end, expectedStart, expectedEnd] of [
      ["2026-10-12", null, "2026-10-11T22:00:00.000Z", null],
      [
        "2026-10-12",
        "2026-10-12",
        "2026-10-11T22:00:00.000Z",
        "2026-10-12T21:59:59.999999Z",
      ],
      [
        "2026-10-12",
        "2026-10-14",
        "2026-10-11T22:00:00.000Z",
        "2026-10-14T21:59:59.999999Z",
      ],
      [
        "2026-12-31",
        "2027-01-01",
        "2026-12-30T23:00:00.000Z",
        "2027-01-01T22:59:59.999999Z",
      ],
      [
        "2026-03-29",
        "2026-03-29",
        "2026-03-28T23:00:00.000Z",
        "2026-03-29T21:59:59.999999Z",
      ],
      [
        "2026-10-25",
        "2026-10-25",
        "2026-10-24T22:00:00.000Z",
        "2026-10-25T22:59:59.999999Z",
      ],
    ]
  ) {
    assertEquals(validateSubmissionDates(null, undefined, true, start, end), {
      ok: true,
      value: {
        all_day: true,
        start_date: expectedStart,
        end_date: expectedEnd,
      },
    });
  }
});

Deno.test("mode and civil grammar reject invalid or mixed temporal formats", () => {
  for (const flag of [null, 0, "true", {}]) {
    assertEquals(validateSubmissionDates(null, null, flag), {
      ok: false,
      error: "invalid_all_day",
    });
  }
  for (
    const start of [
      undefined,
      null,
      1,
      "2026-2-01",
      "2026-02-30",
      "1900-02-29",
      "2026-01-01T00:00:00Z",
    ]
  ) {
    assertEquals(validateSubmissionDates(null, null, true, start), {
      ok: false,
      error: "invalid_start_calendar_date",
    });
  }
  for (
    const end of [
      1,
      "2026-2-01",
      "2026-02-30",
      "1900-02-29",
      "2026-01-01T00:00:00Z",
    ]
  ) {
    assertEquals(validateSubmissionDates(null, null, true, "2026-01-01", end), {
      ok: false,
      error: "invalid_end_calendar_date",
    });
  }
  assertEquals(
    validateSubmissionDates(null, null, true, "2026-02-02", "2026-02-01"),
    { ok: false, error: "end_date_before_start_date" },
  );
  for (const flag of [false, undefined]) {
    assertEquals(validateSubmissionDates(null, null, flag, "2026-01-01"), {
      ok: false,
      error: "mixed_temporal_formats",
    });
    assertEquals(validateSubmissionDates(null, null, flag, null, null), {
      ok: true,
      value: { all_day: false, start_date: null, end_date: null },
    });
  }
  for (const [start, end] of [["2026-01-01", null], [null, "2026-01-01"]]) {
    assertEquals(validateSubmissionDates(start, end, true, "2026-01-01"), {
      ok: false,
      error: "mixed_temporal_formats",
    });
  }
  assert(validateSubmissionDates(null, null, true, "2000-02-29").ok);
  assert(validateSubmissionDates(null, null, true, "2024-04-30").ok);
});
