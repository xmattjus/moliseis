export function normalizeDedupText(value: string): string {
  return value
    .normalize("NFKC")
    .trim()
    .replace(/\s+/gu, " ")
    .toLocaleLowerCase("it-IT");
}

export function calendarDateInRome(isoTimestamp: string): string {
  const instant = new Date(isoTimestamp);
  if (Number.isNaN(instant.getTime())) throw new Error("Invalid ISO timestamp");

  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Rome",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(instant);
  const values = Object.fromEntries(
    parts.map((part) => [part.type, part.value]),
  );
  return `${values.year}-${values.month}-${values.day}`;
}

export function sameEventCandidateDay(left: string, right: string): boolean {
  return calendarDateInRome(left) === calendarDateInRome(right);
}
