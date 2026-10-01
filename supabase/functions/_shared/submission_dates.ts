export type SubmissionDateError =
  | "invalid_all_day"
  | "mixed_temporal_formats"
  | "invalid_start_calendar_date"
  | "invalid_end_calendar_date"
  | "invalid_start_date"
  | "invalid_end_date"
  | "end_date_requires_start_date"
  | "end_date_before_start_date";

export type ValidatedSubmissionDates = {
  all_day: boolean;
  start_date: string | null;
  end_date: string | null;
};

export type SubmissionDatesResult =
  | { ok: true; value: ValidatedSubmissionDates }
  | { ok: false; error: SubmissionDateError };

// JavaScript Dates carry only millisecond precision while validated wire
// strings may preserve microseconds, so ordering compares an epoch-millisecond
// key plus the retained fractional tail instead of raw Date.parse results.
type InstantKey = [epochMilliseconds: number, subMilliseconds: string];

const isoLikeDatePattern =
  /^(\d{4})-(\d{2})-(\d{2})(?:T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})?)?$/;

function isGregorianDate(year: number, month: number, day: number): boolean {
  if (month < 1 || month > 12 || day < 1) return false;
  const isLeapYear = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const daysInMonth = [
    31,
    isLeapYear ? 29 : 28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];
  return day <= daysInMonth[month - 1];
}

function isSupportedIsoLikeDate(value: string): boolean {
  const match = isoLikeDatePattern.exec(value);
  if (match === null) return false;
  return isGregorianDate(
    Number.parseInt(match[1], 10),
    Number.parseInt(match[2], 10),
    Number.parseInt(match[3], 10),
  );
}

function parseDate(
  value: unknown,
  error: "invalid_start_date" | "invalid_end_date",
): SubmissionDatesResult {
  if (value === null) {
    return {
      ok: true,
      value: { all_day: false, start_date: null, end_date: null },
    };
  }
  if (
    typeof value !== "string" ||
    !isSupportedIsoLikeDate(value) ||
    !Number.isFinite(Date.parse(value))
  ) {
    return { ok: false, error };
  }
  return {
    ok: true,
    value: error === "invalid_start_date"
      ? { all_day: false, start_date: value, end_date: null }
      : { all_day: false, start_date: null, end_date: value },
  };
}

function instantKey(value: string): InstantKey {
  const match = /\.(\d+)/.exec(value);
  if (!match) return [Date.parse(value), ""];
  const digits = match[1];
  const epochMilliseconds = digits.length <= 3
    ? Date.parse(value)
    : Date.parse(value.replace(`.${digits}`, `.${digits.slice(0, 3)}`));
  return [epochMilliseconds, digits.length <= 3 ? "" : digits.slice(3)];
}

function isBeforeInstant(a: string, b: string): boolean {
  const [aMilliseconds, aSubMilliseconds] = instantKey(a);
  const [bMilliseconds, bSubMilliseconds] = instantKey(b);
  if (aMilliseconds !== bMilliseconds) return aMilliseconds < bMilliseconds;
  const width = Math.max(aSubMilliseconds.length, bSubMilliseconds.length);
  return aSubMilliseconds.padEnd(width, "0") <
    bSubMilliseconds.padEnd(width, "0");
}

const civilDatePattern = /^(\d{4})-(\d{2})-(\d{2})$/;
const romeOffsetFormatter = new Intl.DateTimeFormat("en-US", {
  timeZone: "Europe/Rome",
  timeZoneName: "shortOffset",
});

function isCivilDate(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const match = civilDatePattern.exec(value);
  return match !== null &&
    isGregorianDate(Number(match[1]), Number(match[2]), Number(match[3]));
}

function romeOffsetMilliseconds(instant: number): number {
  const name = romeOffsetFormatter.formatToParts(new Date(instant))
    .find((part) => part.type === "timeZoneName")?.value;
  const match = name?.match(
    /^GMT(?:(\+|-)(\d{1,2})(?::(\d{2}))?(?::(\d{2}))?)?$/,
  );
  if (!match) throw new Error("Could not determine Europe/Rome UTC offset");
  if (!match[1]) return 0;
  return (match[1] === "+" ? 1 : -1) *
    (Number(match[2]) * 3600 + Number(match[3] ?? 0) * 60 +
      Number(match[4] ?? 0)) *
    1000;
}

function civilDayUtcGuess(date: string, nextDay = false): number {
  const [year, month, day] = date.split("-").map(Number);
  const instant = new Date(0);
  instant.setUTCFullYear(year, month - 1, day + (nextDay ? 1 : 0));
  return instant.getTime();
}

function romeMidnight(utcGuess: number): number {
  const first = utcGuess - romeOffsetMilliseconds(utcGuess);
  return utcGuess - romeOffsetMilliseconds(first);
}

/** Rome start of an already validated Gregorian civil day. */
export function romeStartOfCalendarDay(date: string): string {
  if (!isCivilDate(date)) throw new Error("Invalid civil date");
  return new Date(romeMidnight(civilDayUtcGuess(date))).toISOString();
}

/** Inclusive final microsecond, derived from the following civil midnight. */
export function romeEndOfCalendarDay(date: string): string {
  if (!isCivilDate(date)) throw new Error("Invalid civil date");
  return new Date(romeMidnight(civilDayUtcGuess(date, true)) - 1)
    .toISOString().replace(/\.999Z$/, ".999999Z");
}

export function validateSubmissionDates(
  startDate: unknown,
  endDate: unknown,
  allDay: unknown = undefined,
  startCalendarDate: unknown = undefined,
  endCalendarDate: unknown = undefined,
): SubmissionDatesResult {
  if (allDay !== undefined && typeof allDay !== "boolean") {
    return { ok: false, error: "invalid_all_day" };
  }
  const absent = (value: unknown) => value === null || value === undefined;
  if (allDay === true) {
    if (!absent(startDate) || !absent(endDate)) {
      return { ok: false, error: "mixed_temporal_formats" };
    }
    if (!isCivilDate(startCalendarDate)) {
      return { ok: false, error: "invalid_start_calendar_date" };
    }
    if (!absent(endCalendarDate) && !isCivilDate(endCalendarDate)) {
      return { ok: false, error: "invalid_end_calendar_date" };
    }
    if (
      typeof endCalendarDate === "string" && endCalendarDate < startCalendarDate
    ) {
      return { ok: false, error: "end_date_before_start_date" };
    }
    return {
      ok: true,
      value: {
        all_day: true,
        start_date: romeStartOfCalendarDay(startCalendarDate),
        end_date: typeof endCalendarDate === "string"
          ? romeEndOfCalendarDay(endCalendarDate)
          : null,
      },
    };
  }
  if (!absent(startCalendarDate) || !absent(endCalendarDate)) {
    return { ok: false, error: "mixed_temporal_formats" };
  }
  const parsedStartDate = parseDate(startDate, "invalid_start_date");
  if (!parsedStartDate.ok) return parsedStartDate;
  const parsedEndDate = parseDate(endDate, "invalid_end_date");
  if (!parsedEndDate.ok) return parsedEndDate;

  const start_date = parsedStartDate.value.start_date;
  const end_date = parsedEndDate.value.end_date;
  if (end_date !== null && start_date === null) {
    return { ok: false, error: "end_date_requires_start_date" };
  }
  if (
    start_date !== null && end_date !== null &&
    isBeforeInstant(end_date, start_date)
  ) {
    return { ok: false, error: "end_date_before_start_date" };
  }
  return { ok: true, value: { all_day: false, start_date, end_date } };
}
