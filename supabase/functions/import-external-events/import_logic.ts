import type { EventiMoliseEvent } from "./eventimolise.ts";

const TIME_ZONE = "Europe/Rome";
const FALLBACK_VALUE = "EventiMolise";
const MAX_NAME_LENGTH = 150;
const MAX_CITY_LENGTH = 100;

export type PreparedExternalEvent = {
  sourceId: number;
  sourceUrl: string;
  name: string;
  city: string;
  startDate: string;
  endDate: string | null;
  imageUrl: string | null;
  internalNotes: string;
  dedupKey: string;
};

export function normalizeDedupText(value: string): string {
  return value
    .normalize("NFKC")
    .trim()
    .replace(/\s+/gu, " ")
    .toLocaleLowerCase("it-IT");
}

function timeZoneOffsetMinutes(instantMs: number, timeZone: string): number {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    timeZoneName: "shortOffset",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date(instantMs));

  const zoneName = parts.find((part) => part.type === "timeZoneName")?.value;
  const match = zoneName?.match(/^GMT(?:(\+|-)(\d{1,2})(?::(\d{2}))?)?$/);
  if (!match) throw new Error(`Could not determine ${timeZone} UTC offset`);
  if (!match[1]) return 0;

  const sign = match[1] === "+" ? 1 : -1;
  const hours = Number(match[2]);
  const minutes = Number(match[3] ?? "0");
  return sign * (hours * 60 + minutes);
}

export function zonedDateTimeToIso(
  date: string,
  time: string,
  timeZone = TIME_ZONE,
): string {
  const dateMatch = date.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  const timeMatch = time.match(/^(\d{2}):(\d{2})$/);
  if (!dateMatch || !timeMatch) throw new Error("Invalid local date/time");

  const year = Number(dateMatch[1]);
  const month = Number(dateMatch[2]);
  const day = Number(dateMatch[3]);
  const hour = Number(timeMatch[1]);
  const minute = Number(timeMatch[2]);

  const utcGuess = Date.UTC(year, month - 1, day, hour, minute, 0, 0);
  let offset = timeZoneOffsetMinutes(utcGuess, timeZone);
  let instant = utcGuess - offset * 60_000;

  const correctedOffset = timeZoneOffsetMinutes(instant, timeZone);
  if (correctedOffset !== offset) {
    offset = correctedOffset;
    instant = utcGuess - offset * 60_000;
  }

  return new Date(instant).toISOString();
}

export function calendarDateInRome(isoTimestamp: string): string {
  const instant = new Date(isoTimestamp);
  if (Number.isNaN(instant.getTime())) throw new Error("Invalid ISO timestamp");

  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(instant);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return `${values.year}-${values.month}-${values.day}`;
}

export function buildDedupKey(
  city: string,
  name: string,
  startDateIso: string,
): string {
  return [
    normalizeDedupText(city),
    normalizeDedupText(name),
    calendarDateInRome(startDateIso),
  ].join("\u001f");
}

export function addDaysToCalendarDate(date: string, days: number): string {
  const [year, month, day] = date.split("-").map(Number);
  const result = new Date(Date.UTC(year, month - 1, day + days));
  return [
    String(result.getUTCFullYear()).padStart(4, "0"),
    String(result.getUTCMonth() + 1).padStart(2, "0"),
    String(result.getUTCDate()).padStart(2, "0"),
  ].join("-");
}

function uniqueLocations(locations: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];

  for (const location of locations.map((value) => value.trim()).filter(Boolean)) {
    const key = normalizeDedupText(location);
    if (!seen.has(key)) {
      seen.add(key);
      result.push(location);
    }
  }

  return result;
}

function truncate(value: string, maxLength: number): string {
  return value.length <= maxLength ? value : value.slice(0, maxLength).trimEnd();
}

export function prepareEvent(
  event: EventiMoliseEvent,
): PreparedExternalEvent {
  const warnings: string[] = [];

  let name = event.title.trim();
  if (!name) {
    name = FALLBACK_VALUE;
    warnings.push("missing source title; name fallback applied");
  } else if (name.length > MAX_NAME_LENGTH) {
    warnings.push(`source title exceeded ${MAX_NAME_LENGTH} characters and was truncated`);
    name = truncate(name, MAX_NAME_LENGTH);
  }

  const locations = uniqueLocations(event.locations);
  let city: string;
  if (locations.length === 1 && locations[0].length <= MAX_CITY_LENGTH) {
    city = locations[0];
  } else {
    city = FALLBACK_VALUE;
    if (locations.length === 0) {
      warnings.push("missing source location; city fallback applied");
    } else if (locations.length > 1) {
      warnings.push(`multiple source locations; city fallback applied: ${locations.join(", ")}`);
    } else {
      warnings.push(`source location exceeded ${MAX_CITY_LENGTH} characters; city fallback applied`);
    }
  }

  const startDate = zonedDateTimeToIso(event.date, event.time);
  let endDate: string | null = null;

  if (event.endDate && event.endTime) {
    try {
      const candidate = zonedDateTimeToIso(event.endDate, event.endTime);
      if (Date.parse(candidate) > Date.parse(startDate)) {
        endDate = candidate;
      } else {
        warnings.push("source end date/time was not after start; end_date omitted");
      }
    } catch {
      warnings.push("source end date/time could not be parsed; end_date omitted");
    }
  }

  const notes = [
    "Imported from EventiMolise",
    `Source event ID: ${event.id}`,
    `Source URL: ${event.url}`,
  ];

  if (event.categories.length > 0) {
    notes.push(`Source categories: ${event.categories.join(", ")}`);
  }
  if (event.organizers.length > 0) {
    notes.push(`Source organizers: ${event.organizers.join(", ")}`);
  }
  for (const warning of warnings) notes.push(`Warning: ${warning}`);

  return {
    sourceId: event.id,
    sourceUrl: event.url,
    name,
    city,
    startDate,
    endDate,
    imageUrl: event.image,
    internalNotes: notes.join("\n"),
    dedupKey: buildDedupKey(city, name, startDate),
  };
}
