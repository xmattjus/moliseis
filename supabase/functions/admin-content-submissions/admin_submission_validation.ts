import type { Database, Json } from "../_shared/database.types.ts";
import { validateSubmissionDates } from "../_shared/submission_dates.ts";
import {
  deltaAsJson,
  parseQuillDelta,
  parseSubmissionAsset,
  type ValidatedSubmissionAsset,
  type ValidationResult,
} from "../submit-content/submission_validation.ts";

export type ContentCategoryWire =
  Database["public"]["Enums"]["content_category"];
export type FinalSubmissionStatusWire = "rejected";
export type PromotionTargetWire = "place" | "event";

export type AdminSubmissionInputWire = {
  category: ContentCategoryWire;
  city: string;
  name: string;
  description: string | null;
  description_delta: unknown | null;
  all_day: boolean;
  start_calendar_date: string | null;
  end_calendar_date: string | null;
  start_date: string | null;
  end_date: string | null;
  latitude: number | null;
  longitude: number | null;
};

export type ValidatedAdminSubmissionInput =
  & Omit<
    AdminSubmissionInputWire,
    "description_delta" | "start_calendar_date" | "end_calendar_date"
  >
  & {
    description_delta: Json | null;
  };

export type ValidatedAdminContentSubmissionsRequest =
  | {
    operation: "apply";
    submission_id: number;
    target_event_id: number;
    submission_version_token: string;
    event_version_token: string;
    acknowledge_current_source?: boolean;
    expected_source_hash?: string | null;
  }
  | {
    operation: "mergePreview";
    submission_id: number;
    target_event_id: number;
  }
  | {
    operation: "eventCandidates";
    submission_id: number;
    target_event_id?: number;
    search_name?: string;
  }
  | {
    operation: "link";
    submission_id: number;
    target_event_id: number;
    acknowledge_current_source?: boolean;
    expected_source_hash?: string | null;
  }
  | { operation: "list" }
  | { operation: "listIgnoredSources" }
  | { operation: "unIgnoreSource"; external_event_record_id: number }
  | { operation: "getById"; submission_id: number }
  | { operation: "create"; input: ValidatedAdminSubmissionInput }
  | {
    operation: "update";
    submission_id: number;
    input: ValidatedAdminSubmissionInput;
  }
  | {
    operation: "changeStatus";
    submission_id: number;
    status: FinalSubmissionStatusWire;
    ignore_source?: boolean;
    acknowledge_current_source?: boolean;
    expected_source_hash?: string | null;
  }
  | {
    operation: "promote";
    submission_id: number;
    target: PromotionTargetWire;
    acknowledge_current_source?: boolean;
    expected_source_hash?: string | null;
  }
  | {
    operation: "addAsset";
    submission_id: number;
    asset: ValidatedSubmissionAsset;
  }
  | { operation: "deleteAsset"; submission_id: number; asset_id: number };

const CONTENT_CATEGORIES = [
  "unknown",
  "nature",
  "history",
  "folklore",
  "food",
  "allure",
  "experience",
] as const satisfies readonly ContentCategoryWire[];

const INPUT_KEYS = [
  "category",
  "city",
  "name",
  "description",
  "description_delta",
  "all_day",
  "start_calendar_date",
  "end_calendar_date",
  "start_date",
  "end_date",
  "latitude",
  "longitude",
] as const;

function valid<T>(value: T): ValidationResult<T> {
  return { ok: true, value };
}

function invalid<T = never>(message: string): ValidationResult<T> {
  return { ok: false, message };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactKeys(
  value: Record<string, unknown>,
  keys: readonly string[],
): boolean {
  const actualKeys = Object.keys(value);
  return actualKeys.length === keys.length &&
    keys.every((key) => Object.hasOwn(value, key));
}

function parsePositiveSafeInteger(
  value: unknown,
  fieldName:
    | "submission_id"
    | "asset_id"
    | "external_event_record_id"
    | "target_event_id",
): ValidationResult<number> {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0
    ? valid(value)
    : invalid(`${fieldName} must be a positive safe integer.`);
}

function isContentCategory(value: unknown): value is ContentCategoryWire {
  return CONTENT_CATEGORIES.some((allowed) => allowed === value);
}

function parseOptionalCoordinate(
  value: unknown,
  name: string,
  min: number,
  max: number,
): ValidationResult<number | null> {
  if (value === null) return valid(null);
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return invalid(`${name} must be a finite number.`);
  }
  if (value < min || value > max) {
    return invalid(`${name} must be between ${min} and ${max}.`);
  }
  return valid(value);
}

function parseInput(
  value: unknown,
): ValidationResult<ValidatedAdminSubmissionInput> {
  if (!isRecord(value)) return invalid("input must be a JSON object.");
  if (!hasExactKeys(value, INPUT_KEYS)) {
    return invalid("input contains unsupported or missing fields.");
  }

  const {
    category,
    city,
    name,
    description,
    description_delta,
    start_date,
    end_date,
    all_day,
    start_calendar_date,
    end_calendar_date,
    latitude,
    longitude,
  } = value;
  if (typeof city !== "string" || !city.trim()) {
    return invalid("city must be a non-empty string.");
  }
  const normalizedCity = city.trim();
  if (normalizedCity.length > 100) {
    return invalid("city exceeds maximum length of 100 characters.");
  }

  if (typeof name !== "string" || !name.trim()) {
    return invalid("name must be a non-empty string.");
  }
  const normalizedName = name.trim();
  if (normalizedName.length > 150) {
    return invalid("name exceeds maximum length of 150 characters.");
  }

  if (!isContentCategory(category)) {
    return invalid("category is not supported.");
  }
  if (description !== null && typeof description !== "string") {
    return invalid("description must be a string or null.");
  }
  if (typeof description === "string" && description.length > 5000) {
    return invalid("description exceeds maximum length of 5000 characters.");
  }

  if (typeof all_day !== "boolean") {
    return invalid("all_day must be a boolean.");
  }
  const parsedDates = validateSubmissionDates(
    start_date,
    end_date,
    all_day,
    start_calendar_date,
    end_calendar_date,
  );
  if (!parsedDates.ok) {
    switch (parsedDates.error) {
      case "invalid_all_day":
        return invalid("all_day must be a boolean.");
      case "mixed_temporal_formats":
        return invalid("timestamp and civil-date formats must not be mixed.");
      case "invalid_start_calendar_date":
        return invalid(
          "start_calendar_date must be a Gregorian YYYY-MM-DD date.",
        );
      case "invalid_end_calendar_date":
        return invalid(
          "end_calendar_date must be a Gregorian YYYY-MM-DD date or null.",
        );
      case "invalid_start_date":
        return invalid(
          "start_date must be a parseable date-time string or null.",
        );
      case "invalid_end_date":
        return invalid(
          "end_date must be a parseable date-time string or null.",
        );
      case "end_date_requires_start_date":
        return invalid("end_date requires start_date.");
      case "end_date_before_start_date":
        return invalid("end_date must not be before start_date.");
    }
  }
  const parsedDelta = parseQuillDelta(description_delta, description);
  if (!parsedDelta.ok) return parsedDelta;

  const parsedLatitude = parseOptionalCoordinate(latitude, "latitude", -90, 90);
  if (!parsedLatitude.ok) return parsedLatitude;
  const parsedLongitude = parseOptionalCoordinate(
    longitude,
    "longitude",
    -180,
    180,
  );
  if (!parsedLongitude.ok) return parsedLongitude;
  if ((parsedLatitude.value === null) !== (parsedLongitude.value === null)) {
    return invalid("latitude and longitude must be provided together.");
  }

  return valid({
    category,
    city: normalizedCity,
    name: normalizedName,
    description,
    description_delta: deltaAsJson(parsedDelta.value),
    all_day: parsedDates.value.all_day,
    start_date: parsedDates.value.start_date,
    end_date: parsedDates.value.end_date,
    latitude: parsedLatitude.value,
    longitude: parsedLongitude.value,
  });
}

export function parseAdminContentSubmissionsRequest(
  value: unknown,
): ValidationResult<ValidatedAdminContentSubmissionsRequest> {
  if (!isRecord(value)) return invalid("Request body must be a JSON object.");
  if (!Object.hasOwn(value, "operation")) {
    return invalid("operation is required.");
  }
  if (
    typeof value.operation !== "string" || ![
      "apply",
      "mergePreview",
      "eventCandidates",
      "list",
      "listIgnoredSources",
      "unIgnoreSource",
      "getById",
      "create",
      "update",
      "changeStatus",
      "promote",
      "link",
      "addAsset",
      "deleteAsset",
    ].includes(value.operation)
  ) {
    return invalid("operation is not supported.");
  }

  switch (value.operation) {
    case "listIgnoredSources":
      return hasExactKeys(value, ["operation"])
        ? valid({ operation: "listIgnoredSources" })
        : invalid("Request contains unsupported or missing fields.");
    case "unIgnoreSource": {
      if (!hasExactKeys(value, ["operation", "external_event_record_id"])) {
        return invalid("Request contains unsupported or missing fields.");
      }
      const id = parsePositiveSafeInteger(
        value.external_event_record_id,
        "external_event_record_id",
      );
      return id.ok
        ? valid({
          operation: "unIgnoreSource",
          external_event_record_id: id.value,
        })
        : id;
    }
    case "list":
      return hasExactKeys(value, ["operation"])
        ? valid({ operation: "list" })
        : invalid("Request contains unsupported or missing fields.");
    case "getById": {
      if (!hasExactKeys(value, ["operation", "submission_id"])) {
        return invalid("Request contains unsupported or missing fields.");
      }
      const submissionId = parsePositiveSafeInteger(
        value.submission_id,
        "submission_id",
      );
      return submissionId.ok
        ? valid({ operation: "getById", submission_id: submissionId.value })
        : submissionId;
    }
    case "create": {
      if (!hasExactKeys(value, ["operation", "input"])) {
        return invalid("Request contains unsupported or missing fields.");
      }
      const input = parseInput(value.input);
      return input.ok
        ? valid({ operation: "create", input: input.value })
        : input;
    }
    case "update": {
      if (!hasExactKeys(value, ["operation", "submission_id", "input"])) {
        return invalid("Request contains unsupported or missing fields.");
      }
      const submissionId = parsePositiveSafeInteger(
        value.submission_id,
        "submission_id",
      );
      if (!submissionId.ok) return submissionId;
      const input = parseInput(value.input);
      return input.ok
        ? valid({
          operation: "update",
          submission_id: submissionId.value,
          input: input.value,
        })
        : input;
    }
    case "changeStatus": {
      if (
        !hasExactKeys(value, [
          "operation",
          "submission_id",
          "status",
          ...(Object.hasOwn(value, "ignore_source") ? ["ignore_source"] : []),
          ...(Object.hasOwn(value, "acknowledge_current_source")
            ? ["acknowledge_current_source"]
            : []),
          ...(Object.hasOwn(value, "expected_source_hash")
            ? ["expected_source_hash"]
            : []),
        ])
      ) {
        return invalid("Request contains unsupported or missing fields.");
      }
      const submissionId = parsePositiveSafeInteger(
        value.submission_id,
        "submission_id",
      );
      if (!submissionId.ok) return submissionId;
      // Acceptance is reachable only through the promotion RPC, so the
      // standalone status transition is reject-only by construction.
      if (value.status !== "rejected") {
        return invalid("status must be rejected.");
      }
      if (
        Object.hasOwn(value, "ignore_source") &&
        typeof value.ignore_source !== "boolean"
      ) {
        return invalid("ignore_source must be a boolean.");
      }
      if (
        Object.hasOwn(value, "acknowledge_current_source") &&
        typeof value.acknowledge_current_source !== "boolean"
      ) return invalid("acknowledge_current_source must be a boolean.");
      if (
        Object.hasOwn(value, "expected_source_hash") &&
        value.expected_source_hash !== null &&
        (typeof value.expected_source_hash !== "string" ||
          !/^[0-9a-f]{64}$/.test(value.expected_source_hash))
      ) return invalid("expected_source_hash must be a SHA-256 hash or null.");
      return valid({
        operation: "changeStatus",
        submission_id: submissionId.value,
        status: value.status,
        ...(Object.hasOwn(value, "acknowledge_current_source")
          ? {
            acknowledge_current_source: value
              .acknowledge_current_source as boolean,
          }
          : {}),
        ...(Object.hasOwn(value, "expected_source_hash")
          ? {
            expected_source_hash: value.expected_source_hash as string | null,
          }
          : {}),
        ...(Object.hasOwn(value, "ignore_source")
          ? { ignore_source: value.ignore_source as boolean }
          : {}),
      });
    }
    case "apply": {
      if (
        !hasExactKeys(value, [
          "operation",
          "submission_id",
          "target_event_id",
          "submission_version_token",
          "event_version_token",
          ...(Object.hasOwn(value, "acknowledge_current_source")
            ? ["acknowledge_current_source"]
            : []),
          ...(Object.hasOwn(value, "expected_source_hash")
            ? ["expected_source_hash"]
            : []),
        ])
      ) return invalid("Request contains unsupported or missing fields.");
      const id = parsePositiveSafeInteger(value.submission_id, "submission_id"),
        target = parsePositiveSafeInteger(
          value.target_event_id,
          "target_event_id",
        );
      if (!id.ok) return id;
      if (!target.ok) return target;
      for (const key of ["submission_version_token", "event_version_token"]) {
        if (
          typeof value[key] !== "string" || !value[key] ||
          value[key].length > 100
        ) return invalid(`${key} must be an opaque version string.`);
      }
      if (
        Object.hasOwn(value, "acknowledge_current_source") &&
        typeof value.acknowledge_current_source !== "boolean"
      ) return invalid("acknowledge_current_source must be a boolean.");
      if (
        Object.hasOwn(value, "expected_source_hash") &&
        value.expected_source_hash !== null &&
        (typeof value.expected_source_hash !== "string" ||
          !/^[0-9a-f]{64}$/.test(value.expected_source_hash))
      ) return invalid("expected_source_hash must be a SHA-256 hash or null.");
      return valid({
        operation: "apply",
        submission_id: id.value,
        target_event_id: target.value,
        submission_version_token: value.submission_version_token as string,
        event_version_token: value.event_version_token as string,
        ...(Object.hasOwn(value, "acknowledge_current_source")
          ? {
            acknowledge_current_source: value
              .acknowledge_current_source as boolean,
          }
          : {}),
        ...(Object.hasOwn(value, "expected_source_hash")
          ? {
            expected_source_hash: value.expected_source_hash as string | null,
          }
          : {}),
      });
    }
    case "mergePreview": {
      if (
        !hasExactKeys(value, ["operation", "submission_id", "target_event_id"])
      ) return invalid("Request contains unsupported or missing fields.");
      const id = parsePositiveSafeInteger(value.submission_id, "submission_id"),
        target = parsePositiveSafeInteger(
          value.target_event_id,
          "target_event_id",
        );
      if (!id.ok) return id;
      if (!target.ok) return target;
      return valid({
        operation: "mergePreview",
        submission_id: id.value,
        target_event_id: target.value,
      });
    }
    case "eventCandidates": {
      if (
        !hasExactKeys(value, [
          "operation",
          "submission_id",
          ...(Object.hasOwn(value, "target_event_id")
            ? ["target_event_id"]
            : []),
          ...(Object.hasOwn(value, "search_name") ? ["search_name"] : []),
        ])
      ) return invalid("Request contains unsupported or missing fields.");
      const id = parsePositiveSafeInteger(value.submission_id, "submission_id");
      if (!id.ok) return id;
      if (
        Object.hasOwn(value, "target_event_id") &&
        Object.hasOwn(value, "search_name")
      ) return invalid("Specify Event ID or name, not both.");
      const target = Object.hasOwn(value, "target_event_id")
        ? parsePositiveSafeInteger(value.target_event_id, "target_event_id")
        : null;
      if (target && !target.ok) return target;
      if (
        Object.hasOwn(value, "search_name") &&
        (typeof value.search_name !== "string" || !value.search_name.trim() ||
          value.search_name.length > 150)
      ) {
        return invalid(
          "search_name must be a nonempty name up to 150 characters.",
        );
      }
      return valid({
        operation: "eventCandidates",
        submission_id: id.value,
        ...(target?.ok ? { target_event_id: target.value } : {}),
        ...(typeof value.search_name === "string"
          ? { search_name: value.search_name.trim() }
          : {}),
      });
    }
    case "link": {
      if (
        !hasExactKeys(value, [
          "operation",
          "submission_id",
          "target_event_id",
          ...(Object.hasOwn(value, "acknowledge_current_source")
            ? ["acknowledge_current_source"]
            : []),
          ...(Object.hasOwn(value, "expected_source_hash")
            ? ["expected_source_hash"]
            : []),
        ])
      ) return invalid("Request contains unsupported or missing fields.");
      const id = parsePositiveSafeInteger(value.submission_id, "submission_id");
      if (!id.ok) return id;
      const target = parsePositiveSafeInteger(
        value.target_event_id,
        "target_event_id",
      );
      if (!target.ok) return target;
      if (
        Object.hasOwn(value, "acknowledge_current_source") &&
        typeof value.acknowledge_current_source !== "boolean"
      ) return invalid("acknowledge_current_source must be a boolean.");
      if (
        Object.hasOwn(value, "expected_source_hash") &&
        value.expected_source_hash !== null &&
        (typeof value.expected_source_hash !== "string" ||
          !/^[0-9a-f]{64}$/.test(value.expected_source_hash))
      ) return invalid("expected_source_hash must be a SHA-256 hash or null.");
      return valid({
        operation: "link",
        submission_id: id.value,
        target_event_id: target.value,
        ...(Object.hasOwn(value, "acknowledge_current_source")
          ? {
            acknowledge_current_source: value
              .acknowledge_current_source as boolean,
          }
          : {}),
        ...(Object.hasOwn(value, "expected_source_hash")
          ? {
            expected_source_hash: value.expected_source_hash as string | null,
          }
          : {}),
      });
    }
    case "promote": {
      if (
        !hasExactKeys(value, [
          "operation",
          "submission_id",
          "target",
          ...(Object.hasOwn(value, "acknowledge_current_source")
            ? ["acknowledge_current_source"]
            : []),
          ...(Object.hasOwn(value, "expected_source_hash")
            ? ["expected_source_hash"]
            : []),
        ])
      ) return invalid("Request contains unsupported or missing fields.");
      const submissionId = parsePositiveSafeInteger(
        value.submission_id,
        "submission_id",
      );
      if (!submissionId.ok) return submissionId;
      if (value.target !== "place" && value.target !== "event") {
        return invalid("target must be place or event.");
      }
      if (
        Object.hasOwn(value, "acknowledge_current_source") &&
        typeof value.acknowledge_current_source !== "boolean"
      ) return invalid("acknowledge_current_source must be a boolean.");
      if (
        Object.hasOwn(value, "expected_source_hash") &&
        value.expected_source_hash !== null &&
        (typeof value.expected_source_hash !== "string" ||
          !/^[0-9a-f]{64}$/.test(value.expected_source_hash))
      ) return invalid("expected_source_hash must be a SHA-256 hash or null.");
      return valid({
        operation: "promote",
        submission_id: submissionId.value,
        target: value.target,
        ...(Object.hasOwn(value, "acknowledge_current_source")
          ? {
            acknowledge_current_source: value
              .acknowledge_current_source as boolean,
          }
          : {}),
        ...(Object.hasOwn(value, "expected_source_hash")
          ? {
            expected_source_hash: value.expected_source_hash as string | null,
          }
          : {}),
      });
    }
    case "addAsset": {
      if (!hasExactKeys(value, ["operation", "submission_id", "asset"])) {
        return invalid("Request contains unsupported or missing fields.");
      }
      const submissionId = parsePositiveSafeInteger(
        value.submission_id,
        "submission_id",
      );
      if (!submissionId.ok) return submissionId;
      const asset = parseSubmissionAsset(value.asset);
      return asset.ok
        ? valid({
          operation: "addAsset",
          submission_id: submissionId.value,
          asset: asset.value,
        })
        : asset;
    }
    case "deleteAsset": {
      if (!hasExactKeys(value, ["operation", "submission_id", "asset_id"])) {
        return invalid("Request contains unsupported or missing fields.");
      }
      const submissionId = parsePositiveSafeInteger(
        value.submission_id,
        "submission_id",
      );
      if (!submissionId.ok) return submissionId;
      const assetId = parsePositiveSafeInteger(value.asset_id, "asset_id");
      return assetId.ok
        ? valid({
          operation: "deleteAsset",
          submission_id: submissionId.value,
          asset_id: assetId.value,
        })
        : assetId;
    }
  }

  return invalid("operation is not supported.");
}
