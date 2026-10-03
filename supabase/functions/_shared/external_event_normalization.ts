import type { Database, Json } from "./database.types.ts";
import {
  romeEndOfCalendarDay,
  romeStartOfCalendarDay,
  validateSubmissionDates,
} from "./submission_dates.ts";
import { parseQuillDelta } from "../submit-content/submission_validation.ts";

export const EXTERNAL_EVENT_NORMALIZATION_VERSION = 1;
export const NORMALIZED_EVENT_FIELDS = [
  "name",
  "category",
  "description",
  "description_delta",
  "city",
  "latitude",
  "longitude",
  "all_day",
  "start_date",
  "end_date",
] as const;

export type NormalizedExternalEvent = {
  name: string;
  category: Database["public"]["Enums"]["content_category"];
  description: string | null;
  description_delta: Json | null;
  city: string;
  latitude: string | null;
  longitude: string | null;
  all_day: boolean;
  start_date: string;
  end_date: string | null;
};

export type CanonicalEventProjection = Omit<NormalizedExternalEvent, "city"> & {
  city: string | null;
};

export type EventNormalizationInput = {
  [K in keyof NormalizedExternalEvent]: unknown;
};

function text(
  value: unknown,
  field: string,
  limit: number,
  trim: boolean,
): string {
  if (typeof value !== "string") throw new Error(`Invalid ${field}`);
  const result = (trim ? value.trim() : value).normalize("NFC");
  if ((trim && !result) || result.length > limit) {
    throw new Error(`Invalid ${field}`);
  }
  return result;
}

/** Canonical UTC representation retains the fractional tail outside Date precision. */
export function canonicalizeEventTimestamp(value: unknown): string {
  if (typeof value !== "string") throw new Error("Invalid Event timestamp");
  const match =
    /^(\d{4}-\d{2}-\d{2})[T ](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|[+-]\d{2}(?::?\d{2})?)$/
      .exec(value);
  if (
    !match || Number(match[2]) > 23 || Number(match[3]) > 59 ||
    Number(match[4]) > 59
  ) {
    throw new Error("Invalid Event timestamp");
  }
  const zone = match[6] === "Z"
    ? "Z"
    : match[6].length === 3
    ? match[6] + ":00"
    : match[6].replace(/^([+-]\d{2})(\d{2})$/, "$1:$2");
  const wholeSecond = `${match[1]}T${match[2]}:${match[3]}:${match[4]}${zone}`;
  const valid = validateSubmissionDates(wholeSecond, null, false);
  if (!valid.ok) throw new Error("Invalid Event timestamp");
  // Date only converts a whole second to UTC; original microseconds never enter it.
  const utc = new Date(wholeSecond).toISOString();
  if (!/^\d{4}-/.test(utc) || Number(utc.slice(0, 4)) < 1) {
    throw new Error("Unsupported UTC Event year");
  }
  return utc.slice(0, 19) + "." +
    (match[5] ?? "").padEnd(6, "0") + "Z";
}

function coordinate(
  value: unknown,
  field: string,
  bound: number,
): string | null {
  if (value === null) return null;
  if (
    (typeof value !== "number" && typeof value !== "string") ||
    (typeof value === "string" &&
      !/^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?$/i.test(value))
  ) {
    throw new Error(`Invalid ${field}`);
  }
  const number = Number(value);
  if (!Number.isFinite(number) || Math.abs(number) > bound) {
    throw new Error(`Invalid ${field}`);
  }
  // v1 freezes 15 significant digits: PostgreSQL/PostgREST at the existing
  // extra_float_digits=0 boundary emits 15 digits. Normalize here, never in SQL,
  // so source string -> float8 -> Admin JSON -> canonical string is idempotent.
  const canonical = Number(number.toPrecision(15));
  return canonical === 0 ? "0" : String(canonical);
}

const categories = new Set([
  "unknown",
  "nature",
  "history",
  "folklore",
  "food",
  "allure",
  "experience",
]);
const attributesOrder = [
  "bold",
  "italic",
  "underline",
  "link",
  "list",
] as const;
const romeDateFormatter = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Europe/Rome",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});
function romeDate(value: string): string {
  const parts = Object.fromEntries(
    romeDateFormatter.formatToParts(new Date(value)).map((
      { type, value },
    ) => [type, value]),
  );
  return `${parts.year}-${parts.month}-${parts.day}`;
}

/** Sole normalization boundary for source, submission and canonical Event projections. */
function canonicalizeEventFields(
  input: EventNormalizationInput,
  nullableCity: boolean,
): CanonicalEventProjection {
  const name = text(input.name, "name", 150, true);
  const city = nullableCity && input.city === null
    ? null
    : text(input.city, "city", 100, true);
  if (typeof input.category !== "string" || !categories.has(input.category)) {
    throw new Error("Invalid category");
  }
  let description = input.description === null
    ? null
    : text(input.description, "description", 5000, false);
  let description_delta: Json | null = null;
  if (input.description_delta !== null) {
    if (!Array.isArray(input.description_delta)) {
      throw new Error("Invalid description_delta");
    }
    const normalized = input.description_delta.map((value: unknown) => {
      if (typeof value !== "object" || value === null || Array.isArray(value)) {
        throw new Error("Invalid description_delta");
      }
      const operation = value as Record<string, unknown>;
      // Reuse the authoritative parser for unsupported operation/attribute checks.
      const result: Record<string, unknown> = {
        ...operation,
        insert: typeof operation.insert === "string"
          ? operation.insert.normalize("NFC")
          : operation.insert,
      };
      if (
        typeof operation.attributes === "object" &&
        operation.attributes !== null && !Array.isArray(operation.attributes)
      ) {
        const raw = operation.attributes as Record<string, unknown>;
        const attributes: Record<string, unknown> = {};
        for (const key of attributesOrder) {
          if (Object.hasOwn(raw, key)) {
            attributes[key] = raw[key];
          }
        }
        for (const key of Object.keys(raw)) {
          if (
            !attributesOrder.includes(key as typeof attributesOrder[number])
          ) attributes[key] = raw[key];
        }
        result.attributes = attributes;
      }
      return result;
    });
    // Unicode composition can span differently formatted operations. Preserve
    // their boundaries while comparing plain text by canonical equivalence.
    const literalPlain = normalized.map((operation) =>
      typeof operation.insert === "string" ? operation.insert : ""
    ).join("").slice(0, -1);
    if (description === null || literalPlain.normalize("NFC") !== description) {
      throw new Error(
        "description does not match description_delta plain text",
      );
    }
    const delta = parseQuillDelta(normalized, literalPlain);
    if (!delta.ok) throw new Error(delta.message);
    description_delta = delta.value as Json;
    description = literalPlain;
  }
  if (typeof input.all_day !== "boolean") throw new Error("Invalid all_day");
  if (input.start_date === null) throw new Error("start_date_required");
  const start_date = canonicalizeEventTimestamp(input.start_date);
  const end_date = input.end_date === null
    ? null
    : canonicalizeEventTimestamp(input.end_date);
  const temporal = validateSubmissionDates(start_date, end_date, false);
  if (!temporal.ok) throw new Error(temporal.error);
  if (input.all_day) {
    const start = canonicalizeEventTimestamp(
      romeStartOfCalendarDay(romeDate(start_date)),
    );
    const end = end_date === null
      ? null
      : canonicalizeEventTimestamp(romeEndOfCalendarDay(romeDate(end_date)));
    if (start !== start_date || end !== end_date) {
      throw new Error("Invalid all-day Event boundaries");
    }
  }
  return {
    name,
    category: input.category as NormalizedExternalEvent["category"],
    description,
    description_delta,
    city,
    latitude: coordinate(input.latitude, "latitude", 90),
    longitude: coordinate(input.longitude, "longitude", 180),
    all_day: input.all_day,
    start_date,
    end_date,
  };
}

/** Provider snapshots always require an explicit nonempty source city. */
export function canonicalizeExternalEvent(
  input: EventNormalizationInput,
): NormalizedExternalEvent {
  return canonicalizeEventFields(input, false) as NormalizedExternalEvent;
}

/** An Event with no city relation retains null, never source/submission ownership. */
export function canonicalizeEvent(
  input: EventNormalizationInput,
): CanonicalEventProjection {
  return canonicalizeEventFields(input, true);
}

/** Persisted SQL rows use the same representation; extra transport keys are ignored. */
export function canonicalizeSubmission(
  row: EventNormalizationInput,
): NormalizedExternalEvent {
  return canonicalizeExternalEvent(row);
}

export function canonicalEncodeExternalEvent(
  normalized: NormalizedExternalEvent,
): string {
  return JSON.stringify(
    NORMALIZED_EVENT_FIELDS.map((field) => normalized[field]),
  );
}

export async function hashNormalizedExternalEvent(
  normalized: NormalizedExternalEvent,
): Promise<string> {
  const canonical = canonicalizeExternalEvent(normalized);
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(canonicalEncodeExternalEvent(canonical)),
  );
  return Array.from(
    new Uint8Array(digest),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}
