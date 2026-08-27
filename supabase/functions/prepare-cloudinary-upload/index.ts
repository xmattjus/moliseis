import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
  type User,
} from "npm:@supabase/supabase-js@2.112.3";
import { corsHeaders } from "npm:@supabase/supabase-js@2.112.3/cors";

import type { Database } from "../_shared/database.types.ts";
import {
  type CloudinaryClientUploadIntent,
  type CloudinaryConfig,
  type CloudinaryDuplicateAsset,
  CloudinaryLookupError,
  lookupCloudinaryImage,
  prepareCloudinaryUploadFields,
} from "../_shared/cloudinary.ts";
import {
  readJsonBodyWithLimit,
  RequestBodyTooLargeError,
} from "../submit-content/submission_validation.ts";

const MAX_REQUEST_BODY_BYTES = 16 * 1024;
const DEFAULT_DIMENSION = 2048;
const MAX_DIMENSION = 8192;
const MAX_TAGS = 20;
const MAX_TAG_BYTES = 128;
const MAX_CONTEXT_ENTRIES = 20;
const MAX_CONTEXT_KEY_BYTES = 64;
const MAX_CONTEXT_VALUE_BYTES = 1024;
const MAX_CONTEXT_ENCODED_BYTES = 8192;
const CONTENT_SHA256 = /^[0-9a-f]{64}$/;
const CONTROL_CHARACTERS = /[\u0000-\u001F\u007F]/;
const encoder = new TextEncoder();

const JSON_HEADERS = {
  ...corsHeaders,
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
  "Content-Type": "application/json; charset=utf-8",
};

type ValidatedRequest = CloudinaryClientUploadIntent;

export type HandlerDependencies = {
  authenticate: (authorizationHeader: string) => Promise<User | null>;
  loadCloudinaryConfig: () => CloudinaryConfig & { uploadPreset: string };
  lookup: (params: {
    publicId: string;
    config: CloudinaryConfig;
  }) => Promise<CloudinaryDuplicateAsset | null>;
  prepareFields: (params: {
    intent: CloudinaryClientUploadIntent;
    config: CloudinaryConfig;
    uploadPreset: string;
    nowUnixSeconds: number;
  }) => Promise<Record<string, string>>;
  nowUnixSeconds: () => number;
  warn: (message: string, metadata: { publicId: string }) => void;
};

function jsonResponse(
  body: unknown,
  status = 200,
  extraHeaders: HeadersInit = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...JSON_HEADERS, ...extraHeaders },
  });
}

function errorResponse(
  code: string,
  message: string,
  status: number,
  extraHeaders: HeadersInit = {},
): Response {
  return jsonResponse({ code, message }, status, extraHeaders);
}

function byteLength(value: string): number {
  return encoder.encode(value).byteLength;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isValidString(
  value: unknown,
  maxBytes: number,
  allowEmpty = false,
): value is string {
  return typeof value === "string" && (allowEmpty || value.length > 0) &&
    byteLength(value) <= maxBytes && !CONTROL_CHARACTERS.test(value);
}

function encodeQueryComponent(value: string): string {
  let encoded = "";
  for (const byte of encoder.encode(value)) {
    const isAlphaNumeric = (byte >= 0x30 && byte <= 0x39) ||
      (byte >= 0x41 && byte <= 0x5a) ||
      (byte >= 0x61 && byte <= 0x7a);
    if (
      isAlphaNumeric || byte === 0x2d || byte === 0x2e || byte === 0x5f ||
      byte === 0x7e
    ) {
      encoded += String.fromCharCode(byte);
    } else if (byte === 0x20) {
      encoded += "+";
    } else {
      encoded += `%${byte.toString(16).toUpperCase().padStart(2, "0")}`;
    }
  }
  return encoded;
}

function parseDimension(value: unknown): number | null | undefined {
  if (value === undefined) return DEFAULT_DIMENSION;
  if (value === null) return null;
  return typeof value === "number" && Number.isSafeInteger(value) &&
      value >= 1 && value <= MAX_DIMENSION
    ? value
    : undefined;
}

function parseRequest(value: unknown): ValidatedRequest | null {
  if (!isRecord(value)) return null;
  const allowedKeys = new Set([
    "content_sha256",
    "max_width",
    "max_height",
    "tags",
    "context",
    "overwrite",
  ]);
  if (Object.keys(value).some((key) => !allowedKeys.has(key))) return null;
  if (
    typeof value.content_sha256 !== "string" ||
    !CONTENT_SHA256.test(value.content_sha256)
  ) {
    return null;
  }
  if (value.overwrite !== undefined && value.overwrite !== false) return null;

  const maxWidth = parseDimension(value.max_width);
  const maxHeight = parseDimension(value.max_height);
  if (maxWidth === undefined || maxHeight === undefined) return null;

  const rawTags = value.tags ?? [];
  if (
    !Array.isArray(rawTags) || rawTags.length > MAX_TAGS ||
    rawTags.some((tag) =>
      !isValidString(tag, MAX_TAG_BYTES) || tag.includes(",")
    )
  ) return null;

  const rawContext = value.context ?? {};
  if (
    !isRecord(rawContext) ||
    Object.keys(rawContext).length > MAX_CONTEXT_ENTRIES
  ) return null;
  const context = new Map<string, string>();
  for (const [key, rawValue] of Object.entries(rawContext)) {
    if (
      !isValidString(key, MAX_CONTEXT_KEY_BYTES) ||
      !isValidString(rawValue, MAX_CONTEXT_VALUE_BYTES, true)
    ) return null;
    context.set(key, rawValue);
  }
  const encodedContext = [...context.entries()].map(([key, entryValue]) =>
    `${encodeQueryComponent(key)}=${encodeQueryComponent(entryValue)}`
  ).join("|");
  if (byteLength(encodedContext) > MAX_CONTEXT_ENCODED_BYTES) return null;

  return {
    contentSha256: value.content_sha256,
    maxWidth,
    maxHeight,
    tags: rawTags,
    context,
  };
}

function isLookupError(error: unknown): boolean {
  return error instanceof CloudinaryLookupError;
}

function isAuthorizedFieldSet(
  fields: Record<string, string>,
  publicId: string,
  configuration: CloudinaryConfig & { uploadPreset: string },
): boolean {
  const requiredKeys = new Set([
    "api_key",
    "public_id",
    "timestamp",
    "overwrite",
    "upload_preset",
    "signature",
  ]);
  const optionalKeys = new Set(["transformation", "tags", "context"]);
  const timestamp = fields.timestamp;
  return Object.entries(fields).every(([key, value]) =>
    (requiredKeys.has(key) || optionalKeys.has(key)) &&
    typeof value === "string" && value.length > 0
  ) && [...requiredKeys].every((key) => typeof fields[key] === "string") &&
    fields.api_key === configuration.apiKey &&
    fields.public_id === publicId &&
    fields.overwrite === "false" &&
    fields.upload_preset === configuration.uploadPreset &&
    /^(?:0|[1-9][0-9]*)$/.test(timestamp) &&
    Number.isSafeInteger(Number(timestamp));
}

export function createHandler(
  dependencies: HandlerDependencies,
): (request: Request) => Promise<Response> {
  return async (request) => {
    if (request.method === "OPTIONS") return jsonResponse({ ok: true });
    if (request.method !== "POST") {
      return errorResponse(
        "METHOD_NOT_ALLOWED",
        "Only POST requests are allowed.",
        405,
        {
          Allow: "POST, OPTIONS",
        },
      );
    }

    const bearerMatch = /^Bearer ([^\s,]+)$/.exec(
      request.headers.get("Authorization") ?? "",
    );
    if (!bearerMatch) {
      return errorResponse("UNAUTHORIZED", "Authentication is required.", 401);
    }
    let user: User | null;
    try {
      user = await dependencies.authenticate(bearerMatch[0]);
    } catch {
      return errorResponse("UNAUTHORIZED", "Authentication is required.", 401);
    }
    if (!user) {
      return errorResponse("UNAUTHORIZED", "Authentication is required.", 401);
    }

    let rawBody: unknown;
    try {
      rawBody = await readJsonBodyWithLimit(request, MAX_REQUEST_BODY_BYTES);
    } catch (error) {
      if (error instanceof RequestBodyTooLargeError) {
        return errorResponse(
          "REQUEST_TOO_LARGE",
          "Request body is too large.",
          413,
        );
      }
      return errorResponse("VALIDATION_ERROR", "Request body is invalid.", 400);
    }
    const intent = parseRequest(rawBody);
    if (!intent) {
      return errorResponse("VALIDATION_ERROR", "Request body is invalid.", 400);
    }

    let configuration: CloudinaryConfig & { uploadPreset: string };
    try {
      configuration = dependencies.loadCloudinaryConfig();
    } catch {
      return errorResponse(
        "CLOUDINARY_CONFIGURATION_ERROR",
        "Upload configuration is unavailable.",
        500,
      );
    }
    const publicId = `content_submissions/${intent.contentSha256}`;
    try {
      const duplicate = await dependencies.lookup({
        publicId,
        config: configuration,
      });
      if (duplicate) {
        return jsonResponse({
          outcome: "duplicate",
          asset: {
            secure_url: duplicate.secureUrl,
            width: duplicate.width,
            height: duplicate.height,
            mime_type: duplicate.mimeType,
            duration_seconds: null,
          },
        });
      }
    } catch (error) {
      if (!isLookupError(error)) {
        return errorResponse(
          "CLOUDINARY_PREPARATION_ERROR",
          "Upload preparation failed.",
          502,
        );
      }
      dependencies.warn("cloudinary_duplicate_lookup_failed", { publicId });
    }

    try {
      const fields = await dependencies.prepareFields({
        intent,
        config: configuration,
        uploadPreset: configuration.uploadPreset,
        nowUnixSeconds: dependencies.nowUnixSeconds(),
      });
      if (!isAuthorizedFieldSet(fields, publicId, configuration)) {
        throw new Error("Invalid prepared Cloudinary fields");
      }
      return jsonResponse({ outcome: "authorized", fields });
    } catch {
      return errorResponse(
        "CLOUDINARY_PREPARATION_ERROR",
        "Upload preparation failed.",
        502,
      );
    }
  };
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required configuration: ${name}`);
  return value;
}

export function resolvePublishableKey(): string {
  const namedKeys = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS")?.trim();
  if (!namedKeys) return requiredEnv("SUPABASE_ANON_KEY");
  const parsed: unknown = JSON.parse(namedKeys);
  if (
    !isRecord(parsed) || typeof parsed.default !== "string" ||
    !parsed.default.trim()
  ) {
    throw new Error("Missing default publishable key");
  }
  return parsed.default.trim();
}

export function createProductionDependencies(): HandlerDependencies {
  const supabaseUrl = requiredEnv("SUPABASE_URL");
  const publishableKey = resolvePublishableKey();
  return {
    authenticate: async (authorizationHeader) => {
      const client: SupabaseClient<Database> = createClient<Database>(
        supabaseUrl,
        publishableKey,
        {
          global: { headers: { Authorization: authorizationHeader } },
          auth: { autoRefreshToken: false, persistSession: false },
        },
      );
      const { data, error } = await client.auth.getUser();
      return error ? null : data.user;
    },
    loadCloudinaryConfig: () => ({
      cloudName: requiredEnv("CLOUDINARY_CLOUD_NAME"),
      apiKey: requiredEnv("CLOUDINARY_API_KEY"),
      apiSecret: requiredEnv("CLOUDINARY_API_SECRET"),
      uploadPreset: requiredEnv("CLOUDINARY_CONTENT_UPLOAD_PRESET"),
    }),
    lookup: lookupCloudinaryImage,
    prepareFields: prepareCloudinaryUploadFields,
    nowUnixSeconds: () => Math.floor(Date.now() / 1000),
    warn: (message, metadata) => console.warn(message, metadata),
  };
}

if (import.meta.main) {
  Deno.serve(createHandler(createProductionDependencies()));
}
