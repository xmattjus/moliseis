import type { Database, Json } from "../_shared/database.types.ts";
import { parseCloudinaryDeliveryUrl } from "../_shared/cloudinary.ts";
import { validateSubmissionDates } from "../_shared/submission_dates.ts";

export const MAX_REQUEST_BODY_BYTES = 128 * 1024;
export const MAX_SUBMISSION_ASSETS = 5;
const MAX_POSTGRES_INTEGER = 2_147_483_647;

const ALLOWED_ASSET_HOSTS = ["res.cloudinary.com"] as const;

const ALLOWED_CONTENT_CATEGORIES = [
  "nature",
  "history",
  "folklore",
  "food",
  "allure",
  "experience",
] as const satisfies readonly Database["public"]["Enums"]["content_category"][];

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const CLIENT_SUBMISSION_ID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

export type ValidatedQuillAttributes = {
  bold?: true;
  italic?: true;
  underline?: true;
  link?: string;
  list?: "ordered" | "bullet";
};

export type ValidatedQuillOperation = {
  insert: string;
  attributes?: ValidatedQuillAttributes;
};

export type ValidatedContentSubmission = {
  client_submission_id: string;
  city: string;
  name: string;
  description: string | null;
  description_delta: ValidatedQuillOperation[] | null;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
  start_date: string | null;
  end_date: string | null;
  category: Database["public"]["Enums"]["content_category"] | null;
  user_email: string;
  user_name: string;
  assets: ValidatedSubmissionAsset[];
};

export type ValidatedSubmissionAsset = {
  url: string;
  width: number;
  height: number;
  mime_type: string | null;
  duration_seconds: number | null;
};

export type ValidationResult<T> =
  | { ok: true; value: T }
  | { ok: false; message: string };

export class RequestBodyTooLargeError extends Error {
  constructor() {
    super("Request body too large");
    this.name = "RequestBodyTooLargeError";
  }
}

function valid<T>(value: T): ValidationResult<T> {
  return { ok: true, value };
}

function invalid<T = never>(message: string): ValidationResult<T> {
  return { ok: false, message };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isOptionalString(value: unknown): value is string | null | undefined {
  return value === undefined || value === null || typeof value === "string";
}

function isOptionalFiniteNumber(
  value: unknown,
): value is number | null | undefined {
  return value === undefined || value === null ||
    (typeof value === "number" && Number.isFinite(value));
}

function isAllowedCategory(
  value: unknown,
): value is Database["public"]["Enums"]["content_category"] {
  return typeof value === "string" &&
    ALLOWED_CONTENT_CATEGORIES.some((category) => category === value);
}

export function isValidLink(value: string): boolean {
  try {
    const url = new URL(value);
    return (url.protocol === "http:" || url.protocol === "https:") &&
      url.hostname.length > 0;
  } catch {
    return false;
  }
}

export function isValidAssetUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" &&
      ALLOWED_ASSET_HOSTS.some((host) => host === url.hostname);
  } catch {
    return false;
  }
}

function haveEquivalentAttributes(
  left: ValidatedQuillAttributes | undefined,
  right: ValidatedQuillAttributes | undefined,
): boolean {
  const leftEntries = Object.entries(left ?? {}).sort(([a], [b]) =>
    a.localeCompare(b)
  );
  const rightEntries = Object.entries(right ?? {}).sort(([a], [b]) =>
    a.localeCompare(b)
  );

  return leftEntries.length === rightEntries.length &&
    leftEntries.every(([key, value], index) =>
      key === rightEntries[index][0] && value === rightEntries[index][1]
    );
}

function parseQuillAttributes(
  value: unknown,
  insert: string,
): ValidationResult<ValidatedQuillAttributes> {
  if (!isRecord(value) || Object.keys(value).length === 0) {
    return invalid("description_delta attributes must be a non-empty object");
  }

  const attributes: ValidatedQuillAttributes = {};
  for (const [key, attributeValue] of Object.entries(value)) {
    switch (key) {
      case "bold":
      case "italic":
      case "underline":
        if (attributeValue !== true) {
          return invalid(`description_delta ${key} must be true`);
        }
        attributes[key] = true;
        break;
      case "link":
        if (
          typeof attributeValue !== "string" || !isValidLink(attributeValue)
        ) {
          return invalid(
            "description_delta link must be an absolute HTTP/HTTPS URL",
          );
        }
        attributes.link = attributeValue;
        break;
      case "list":
        if (
          insert !== "\n" ||
          (attributeValue !== "ordered" && attributeValue !== "bullet")
        ) {
          return invalid(
            "description_delta list must be ordered or bullet on an exact newline insert",
          );
        }
        attributes.list = attributeValue;
        break;
      default:
        return invalid(`description_delta attribute ${key} is not supported`);
    }
  }

  return valid(attributes);
}

export function parseQuillDelta(
  value: unknown,
  description: string | null,
): ValidationResult<ValidatedQuillOperation[] | null> {
  if (value === undefined || value === null) {
    return valid(null);
  }

  if (!Array.isArray(value) || value.length === 0) {
    return invalid("description_delta must be a non-empty array when present");
  }

  if (description === null) {
    return invalid("description_delta requires a non-null description");
  }

  const operations: ValidatedQuillOperation[] = [];
  let plainText = "";
  for (const rawOperation of value) {
    if (!isRecord(rawOperation)) {
      return invalid("description_delta operations must be objects");
    }

    const keys = Object.keys(rawOperation);
    if (
      !Object.hasOwn(rawOperation, "insert") ||
      keys.some((key) => key !== "insert" && key !== "attributes")
    ) {
      return invalid(
        "description_delta operations may contain only insert and attributes",
      );
    }

    const insert = rawOperation.insert;
    if (typeof insert !== "string" || insert.length === 0) {
      return invalid("description_delta insert must be a non-empty string");
    }

    let attributes: ValidatedQuillAttributes | undefined;
    if (Object.hasOwn(rawOperation, "attributes")) {
      const parsedAttributes = parseQuillAttributes(
        rawOperation.attributes,
        insert,
      );
      if (!parsedAttributes.ok) return parsedAttributes;
      attributes = parsedAttributes.value;
    }

    const previous = operations.at(-1);
    if (previous && haveEquivalentAttributes(previous.attributes, attributes)) {
      return invalid(
        "description_delta contains adjacent operations Quill would normalize",
      );
    }

    operations.push(attributes ? { insert, attributes } : { insert });
    plainText += insert;
  }

  if (!plainText.endsWith("\n")) {
    return invalid("description_delta must end with a terminal newline");
  }

  const derivedDescription = plainText.slice(0, -1);
  if (derivedDescription !== description) {
    return invalid("description does not match description_delta plain text");
  }

  if (derivedDescription.length === 0) {
    return invalid(
      "empty Quill documents require null description and description_delta",
    );
  }

  if (derivedDescription.length > 5000) {
    return invalid("description exceeds maximum length of 5000");
  }

  return valid(operations);
}

export function parseSubmissionAsset(
  value: unknown,
): ValidationResult<ValidatedSubmissionAsset> {
  if (
    !isRecord(value) ||
    typeof value.url !== "string" ||
    typeof value.width !== "number" ||
    typeof value.height !== "number" ||
    !isOptionalString(value.mime_type) ||
    !isOptionalFiniteNumber(value.duration_seconds)
  ) {
    return invalid("asset is not valid");
  }

  if (!isValidAssetUrl(value.url)) {
    return invalid("asset url is not valid");
  }
  if (
    !Number.isSafeInteger(value.width) ||
    value.width <= 0 ||
    value.width > MAX_POSTGRES_INTEGER
  ) {
    return invalid("asset width must be a positive safe integer");
  }
  if (
    !Number.isSafeInteger(value.height) ||
    value.height <= 0 ||
    value.height > MAX_POSTGRES_INTEGER
  ) {
    return invalid("asset height must be a positive safe integer");
  }
  if (
    value.duration_seconds != null &&
    (!Number.isSafeInteger(value.duration_seconds) ||
      value.duration_seconds < 0 ||
      value.duration_seconds > MAX_POSTGRES_INTEGER)
  ) {
    return invalid(
      "asset duration_seconds must be a non-negative safe integer",
    );
  }
  if (value.mime_type && !value.mime_type.includes("/")) {
    return invalid("mime_type is not valid");
  }

  return valid({
    url: value.url,
    width: value.width,
    height: value.height,
    mime_type: value.mime_type ?? null,
    duration_seconds: value.duration_seconds ?? null,
  });
}

function parseCoordinates(
  latitude: unknown,
  longitude: unknown,
): ValidationResult<{ latitude: number | null; longitude: number | null }> {
  const isAbsent = (value: unknown) => value === undefined || value === null;
  if (
    !isAbsent(latitude) &&
    (typeof latitude !== "number" || !Number.isFinite(latitude))
  ) {
    return invalid("latitude is not valid");
  }
  if (
    !isAbsent(longitude) &&
    (typeof longitude !== "number" || !Number.isFinite(longitude))
  ) {
    return invalid("longitude is not valid");
  }
  if (isAbsent(latitude) && isAbsent(longitude)) {
    return valid({ latitude: null, longitude: null });
  }
  if (isAbsent(latitude) || isAbsent(longitude)) {
    return invalid("latitude and longitude must be provided together");
  }
  if (latitude < -90 || latitude > 90) {
    return invalid("latitude is not valid");
  }
  if (longitude < -180 || longitude > 180) {
    return invalid("longitude is not valid");
  }
  return valid({ latitude, longitude });
}

function parsePublicSubmissionAsset(
  value: unknown,
  cloudName: string,
): ValidationResult<{ asset: ValidatedSubmissionAsset; publicId: string }> {
  const parsedAsset = parseSubmissionAsset(value);
  if (!parsedAsset.ok) return parsedAsset;
  if (!parseCloudinaryDeliveryUrl(parsedAsset.value.url, cloudName)) {
    return invalid("asset url is not valid");
  }
  const urlPattern = new RegExp(
    `^https://res\\.cloudinary\\.com/${
      escapeRegExp(cloudName)
    }/image/upload/v[1-9][0-9]*/content_submissions/([0-9a-f]{64})\\.[a-z0-9]+$`,
  );
  const match = urlPattern.exec(parsedAsset.value.url);
  if (!match) return invalid("asset url is not valid");
  return valid({
    asset: parsedAsset.value,
    publicId: `content_submissions/${match[1]}`,
  });
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function parseAssets(
  value: unknown,
  cloudName: string,
): ValidationResult<ValidatedSubmissionAsset[]> {
  if (value === undefined || value === null) return valid([]);
  if (!Array.isArray(value) || value.length > MAX_SUBMISSION_ASSETS) {
    return invalid("assets length is not valid");
  }

  const assets: ValidatedSubmissionAsset[] = [];
  const publicIds = new Set<string>();
  for (const rawAsset of value) {
    const parsedAsset = parsePublicSubmissionAsset(rawAsset, cloudName);
    if (!parsedAsset.ok) return parsedAsset;
    if (publicIds.has(parsedAsset.value.publicId)) {
      return invalid("assets must not contain duplicates");
    }
    publicIds.add(parsedAsset.value.publicId);
    assets.push(parsedAsset.value.asset);
  }

  return valid(assets);
}

export function parseContentSubmission(
  value: unknown,
  cloudName: string,
): ValidationResult<ValidatedContentSubmission> {
  if (!isRecord(value)) return invalid("Request body must be a JSON object");

  const {
    client_submission_id,
    city,
    name,
    description,
    description_delta,
    latitude,
    longitude,
    address,
    start_date,
    end_date,
    category,
    user_email,
    user_name,
    assets,
  } = value;

  if (client_submission_id === undefined) {
    return invalid("client_submission_id is required");
  }
  if (
    typeof client_submission_id !== "string" ||
    !CLIENT_SUBMISSION_ID_REGEX.test(client_submission_id)
  ) {
    return invalid("client_submission_id must be a canonical UUID v4");
  }
  if (typeof city !== "string" || !city.trim()) {
    return invalid("city is required");
  }
  if (typeof name !== "string" || !name.trim()) {
    return invalid("name is required");
  }
  if (!isOptionalString(description)) {
    return invalid("description must be a string or null");
  }
  const coordinates = parseCoordinates(
    latitude,
    longitude,
  );
  if (!coordinates.ok) return coordinates;
  if (!isOptionalString(address)) {
    return invalid("address must be a string or null");
  }
  const parsedDates = validateSubmissionDates(
    start_date ?? null,
    end_date ?? null,
  );
  if (!parsedDates.ok) {
    switch (parsedDates.error) {
      case "invalid_start_date":
        return invalid("start_date is not valid");
      case "invalid_end_date":
        return invalid("end_date is not valid");
      case "end_date_requires_start_date":
        return invalid("end_date requires start_date");
      case "end_date_before_start_date":
        return invalid("end_date must not be before start_date");
    }
  }
  if (
    category !== undefined && category !== null && !isAllowedCategory(category)
  ) {
    return invalid("category is not valid");
  }
  if (typeof user_email !== "string" || !user_email.trim()) {
    return invalid("user_email is required");
  }
  if (!EMAIL_REGEX.test(user_email.trim())) {
    return invalid("user_email is not valid");
  }
  if (typeof user_name !== "string" || !user_name.trim()) {
    return invalid("user_name is required");
  }

  if (
    description !== null && description !== undefined &&
    description.length > 5000
  ) {
    return invalid("description exceeds maximum length of 5000");
  }

  if (
    address !== null && address !== undefined && address.trim().length > 250
  ) {
    return invalid("address exceeds maximum length of 250");
  }

  const normalizedLengthChecks: Array<[string, number, string]> = [
    [name, 150, "name"],
    [city, 100, "city"],
    [user_name, 100, "user_name"],
    [user_email, 320, "user_email"],
  ];
  for (const [fieldValue, maxLength, fieldName] of normalizedLengthChecks) {
    if (fieldValue.trim().length > maxLength) {
      return invalid(`${fieldName} exceeds maximum length of ${maxLength}`);
    }
  }

  const delta = parseQuillDelta(description_delta, description ?? null);
  if (!delta.ok) return delta;
  const parsedAssets = parseAssets(assets, cloudName);
  if (!parsedAssets.ok) return parsedAssets;

  return valid({
    client_submission_id,
    city: city.trim(),
    name: name.trim(),
    description: description ?? null,
    description_delta: delta.value,
    latitude: coordinates.value.latitude,
    longitude: coordinates.value.longitude,
    address: address?.trim() ?? null,
    start_date: parsedDates.value.start_date,
    end_date: parsedDates.value.end_date,
    category: category ?? null,
    user_email: user_email.trim(),
    user_name: user_name.trim(),
    assets: parsedAssets.value,
  });
}

export async function readJsonBodyWithLimit(
  request: Request,
  maxBytes = MAX_REQUEST_BODY_BYTES,
): Promise<unknown> {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
    throw new RequestBodyTooLargeError();
  }
  if (!request.body) throw new SyntaxError("Missing request body");

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    totalBytes += value.byteLength;
    if (totalBytes > maxBytes) {
      await reader.cancel();
      throw new RequestBodyTooLargeError();
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
}

export function deltaAsJson(
  value: ValidatedQuillOperation[] | null,
): Json | null {
  return value;
}
