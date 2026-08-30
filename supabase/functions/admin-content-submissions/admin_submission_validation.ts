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
  start_date: string | null;
  end_date: string | null;
  latitude: number | null;
  longitude: number | null;
};

export type ValidatedAdminSubmissionInput =
  & Omit<AdminSubmissionInputWire, "description_delta">
  & {
    description_delta: Json | null;
  };

export type ValidatedAdminContentSubmissionsRequest =
  | { operation: "list" }
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
  }
  | {
    operation: "promote";
    submission_id: number;
    target: PromotionTargetWire;
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
  fieldName: "submission_id" | "asset_id",
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

  const parsedDates = validateSubmissionDates(start_date, end_date);
  if (!parsedDates.ok) {
    switch (parsedDates.error) {
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
      "list",
      "getById",
      "create",
      "update",
      "changeStatus",
      "promote",
      "addAsset",
      "deleteAsset",
    ].includes(value.operation)
  ) {
    return invalid("operation is not supported.");
  }

  switch (value.operation) {
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
      if (!hasExactKeys(value, ["operation", "submission_id", "status"])) {
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
      return valid({
        operation: "changeStatus",
        submission_id: submissionId.value,
        status: value.status,
      });
    }
    case "promote": {
      if (!hasExactKeys(value, ["operation", "submission_id", "target"])) {
        return invalid("Request contains unsupported or missing fields.");
      }
      const submissionId = parsePositiveSafeInteger(
        value.submission_id,
        "submission_id",
      );
      if (!submissionId.ok) return submissionId;
      if (value.target !== "place" && value.target !== "event") {
        return invalid("target must be place or event.");
      }
      return valid({
        operation: "promote",
        submission_id: submissionId.value,
        target: value.target,
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
