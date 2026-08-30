export type SubmissionDateError =
  | "invalid_start_date"
  | "invalid_end_date"
  | "end_date_requires_start_date"
  | "end_date_before_start_date";

export type ValidatedSubmissionDates = {
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
    return { ok: true, value: { start_date: null, end_date: null } };
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
      ? { start_date: value, end_date: null }
      : { start_date: null, end_date: value },
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

export function validateSubmissionDates(
  startDate: unknown,
  endDate: unknown,
): SubmissionDatesResult {
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
  return { ok: true, value: { start_date, end_date } };
}
