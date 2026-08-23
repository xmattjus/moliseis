import type { Database, Json } from "../_shared/database.types.ts";

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

function parseAssets(
  value: unknown,
): ValidationResult<ValidatedSubmissionAsset[]> {
  if (value === undefined || value === null) return valid([]);
  if (!Array.isArray(value) || value.length > MAX_SUBMISSION_ASSETS) {
    return invalid("assets length is not valid");
  }

  const assets: ValidatedSubmissionAsset[] = [];
  for (const rawAsset of value) {
    const parsedAsset = parseSubmissionAsset(rawAsset);
    if (!parsedAsset.ok) return parsedAsset;
    assets.push(parsedAsset.value);
  }

  return valid(assets);
}

export function parseContentSubmission(
  value: unknown,
): ValidationResult<ValidatedContentSubmission> {
  if (!isRecord(value)) return invalid("Request body must be a JSON object");

  const {
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

  if (typeof city !== "string" || !city.trim()) {
    return invalid("city is required");
  }
  if (typeof name !== "string" || !name.trim()) {
    return invalid("name is required");
  }
  if (!isOptionalString(description)) {
    return invalid("description must be a string or null");
  }
  if (!isOptionalFiniteNumber(latitude)) {
    return invalid("latitude is not valid");
  }
  if (!isOptionalFiniteNumber(longitude)) {
    return invalid("longitude is not valid");
  }
  if (!isOptionalString(address)) {
    return invalid("address must be a string or null");
  }
  if (
    !isOptionalString(start_date) ||
    (start_date != null && Number.isNaN(Date.parse(start_date)))
  ) {
    return invalid("start_date is not valid");
  }
  if (
    !isOptionalString(end_date) ||
    (end_date != null && Number.isNaN(Date.parse(end_date)))
  ) {
    return invalid("end_date is not valid");
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
  const parsedAssets = parseAssets(assets);
  if (!parsedAssets.ok) return parsedAssets;

  return valid({
    city: city.trim(),
    name: name.trim(),
    description: description ?? null,
    description_delta: delta.value,
    latitude: latitude ?? null,
    longitude: longitude ?? null,
    address: address?.trim() ?? null,
    start_date: start_date ?? null,
    end_date: end_date ?? null,
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
