import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
  type User,
} from "npm:@supabase/supabase-js@2.112.3";
import { corsHeaders } from "npm:@supabase/supabase-js@2.112.3/cors";

import type { Database, Json } from "../_shared/database.types.ts";
import {
  readJsonBodyWithLimit,
  RequestBodyTooLargeError,
} from "../submit-content/submission_validation.ts";
import {
  type AdminSubmissionStore,
  AdminSubmissionStoreError,
  createAdminSubmissionStore,
  type SubmissionAssetRecord,
  type SubmissionRecord,
} from "./admin_submission_store.ts";
import {
  type ContentCategoryWire,
  type FinalSubmissionStatusWire,
  parseAdminContentSubmissionsRequest,
} from "./admin_submission_validation.ts";

type AdminSubmissionAssetWire = {
  id: number;
  url: string;
  width: number;
  height: number;
};

type AdminSubmissionWire = {
  id: number;
  city: string;
  name: string;
  description: string | null;
  description_delta: Json | null;
  start_date: string | null;
  end_date: string | null;
  category: ContentCategoryWire;
  user_name: string;
  user_email: string;
  status: "pending" | "accepted" | "rejected";
  created_at: string;
  modified_at: string;
  assets: AdminSubmissionAssetWire[];
};

export type HandlerDependencies = {
  authenticate: (authorizationHeader: string) => Promise<User | null>;
  createStore: () => AdminSubmissionStore;
  nowIso: () => string;
};

type NamedOrLegacyKeyInput = {
  namedKeysJson: string | null | undefined;
  legacyKey: string | null | undefined;
  keyName: "default";
};

const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const JSON_HEADERS = {
  ...corsHeaders,
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
  "Content-Type": "application/json; charset=utf-8",
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

function toAssetWire(asset: SubmissionAssetRecord): AdminSubmissionAssetWire {
  return {
    id: asset.id,
    url: asset.url,
    width: asset.width,
    height: asset.height,
  };
}

function toSubmissionWire(
  submission: SubmissionRecord,
  assets: SubmissionAssetRecord[] = [],
): AdminSubmissionWire {
  return {
    id: submission.id,
    city: submission.city,
    name: submission.name,
    description: submission.description,
    description_delta: submission.description_delta,
    start_date: submission.start_date,
    end_date: submission.end_date,
    category: submission.category,
    user_name: submission.user_name,
    user_email: submission.user_email,
    status: submission.status,
    created_at: submission.created_at,
    modified_at: submission.modified_at,
    assets: assets.map(toAssetWire),
  };
}

export function requireTrimmedValue(
  value: string | null | undefined,
  name: string,
): string {
  const trimmedValue = value?.trim();
  if (!trimmedValue) {
    throw new Error(`Missing required configuration value: ${name}`);
  }
  return trimmedValue;
}

export function resolveNamedOrLegacyKey({
  namedKeysJson,
  legacyKey,
  keyName,
}: NamedOrLegacyKeyInput): string {
  const trimmedNamedKeys = namedKeysJson?.trim();
  if (!trimmedNamedKeys) return requireTrimmedValue(legacyKey, "legacy key");

  let parsed: unknown;
  try {
    parsed = JSON.parse(trimmedNamedKeys);
  } catch {
    throw new Error("Named key map must be valid JSON");
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new Error("Named key map must be a JSON object");
  }
  const value = (parsed as Record<string, unknown>)[keyName];
  if (typeof value !== "string" || !value.trim()) {
    throw new Error(`Named key map requires a non-empty ${keyName} key`);
  }
  return value.trim();
}

function getCreateProfile(
  user: User,
): { userEmail: string; userName: string } | null {
  const userEmail = user.email?.trim();
  const metadataName = user.user_metadata?.name;
  if (
    !userEmail || userEmail.length > 320 || !EMAIL_REGEX.test(userEmail) ||
    typeof metadataName !== "string"
  ) return null;
  const userName = metadataName.trim();
  if (!userName || userName.length > 100) return null;
  return { userEmail, userName };
}

export function createHandler(
  dependencies: HandlerDependencies,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return jsonResponse({ ok: true });
    if (request.method !== "POST") {
      return errorResponse(
        "METHOD_NOT_ALLOWED",
        "Only POST requests are allowed.",
        405,
        { Allow: "POST, OPTIONS" },
      );
    }

    try {
      const bearerMatch = /^Bearer ([^\s,]+)$/.exec(
        request.headers.get("Authorization") ?? "",
      );
      if (!bearerMatch) {
        return errorResponse(
          "UNAUTHORIZED",
          "Authentication is required.",
          401,
        );
      }
      const authorizationHeader = bearerMatch[0];
      const user = await dependencies.authenticate(authorizationHeader);
      if (!user) {
        return errorResponse(
          "UNAUTHORIZED",
          "Authentication is required.",
          401,
        );
      }
      if (user.is_anonymous === true) {
        return errorResponse(
          "ADMIN_REQUIRED",
          "Administrator access is required.",
          403,
        );
      }
      if (user.app_metadata?.admin !== true) {
        return errorResponse(
          "ADMIN_REQUIRED",
          "Administrator access is required.",
          403,
        );
      }

      let rawBody: unknown;
      try {
        rawBody = await readJsonBodyWithLimit(request);
      } catch (error) {
        if (error instanceof RequestBodyTooLargeError) {
          return errorResponse(
            "REQUEST_TOO_LARGE",
            "Request body exceeds 131072 bytes.",
            413,
          );
        }
        return errorResponse(
          "INVALID_JSON",
          "Request body must be valid JSON.",
          400,
        );
      }
      const parsed = parseAdminContentSubmissionsRequest(rawBody);
      if (!parsed.ok) {
        return errorResponse("VALIDATION_ERROR", parsed.message, 400);
      }

      const createProfile = parsed.value.operation === "create"
        ? getCreateProfile(user)
        : null;
      if (parsed.value.operation === "create" && !createProfile) {
        return errorResponse(
          "ADMIN_PROFILE_INCOMPLETE",
          "Administrator profile requires a valid name and email.",
          422,
        );
      }

      const store = dependencies.createStore();
      switch (parsed.value.operation) {
        case "list": {
          const submissions = await store.list();
          return jsonResponse({
            submissions: submissions.map((submission) =>
              toSubmissionWire(submission)
            ),
          });
        }
        case "getById": {
          const result = await store.getById(parsed.value.submission_id);
          if (!result) {
            return errorResponse("NOT_FOUND", "Submission not found.", 404);
          }
          return jsonResponse({
            submission: toSubmissionWire(result.submission, result.assets),
          });
        }
        case "create": {
          if (!createProfile) {
            return errorResponse(
              "ADMIN_PROFILE_INCOMPLETE",
              "Administrator profile requires a valid name and email.",
              422,
            );
          }
          const submission = await store.create({
            ...parsed.value.input,
            user_id: user.id,
            user_email: createProfile.userEmail,
            user_name: createProfile.userName,
          });
          return jsonResponse({ submission: toSubmissionWire(submission) });
        }
        case "update": {
          const submission = await store.update(
            parsed.value.submission_id,
            parsed.value.input,
            dependencies.nowIso(),
          );
          if (!submission) {
            return errorResponse("NOT_FOUND", "Submission not found.", 404);
          }
          return jsonResponse({ submission: toSubmissionWire(submission) });
        }
        case "changeStatus": {
          const result = await store.changeStatus({
            id: parsed.value.submission_id,
            status: parsed.value.status,
            handledBy: user.id,
            modifiedAt: dependencies.nowIso(),
          });
          if (result === "not_found") {
            return errorResponse("NOT_FOUND", "Submission not found.", 404);
          }
          if (result === "not_pending") {
            return errorResponse(
              "INVALID_STATUS_TRANSITION",
              "Only pending submissions can be moderated.",
              409,
            );
          }
          return jsonResponse({ ok: true, status: parsed.value.status });
        }
      }
    } catch (error) {
      console.error("admin-content-submissions request failed", error);
      if (error instanceof AdminSubmissionStoreError) {
        return errorResponse(
          "DATABASE_ERROR",
          "The submission database operation failed.",
          500,
        );
      }
      return errorResponse("INTERNAL_ERROR", "Unexpected server error.", 500);
    }
  };
}

export function createProductionDependencies(): HandlerDependencies {
  const supabaseUrl = requireTrimmedValue(
    Deno.env.get("SUPABASE_URL"),
    "SUPABASE_URL",
  );
  const publishableKey = resolveNamedOrLegacyKey({
    namedKeysJson: Deno.env.get("SUPABASE_PUBLISHABLE_KEYS"),
    legacyKey: Deno.env.get("SUPABASE_ANON_KEY"),
    keyName: "default",
  });
  const privilegedKey = resolveNamedOrLegacyKey({
    namedKeysJson: Deno.env.get("SUPABASE_SECRET_KEYS"),
    legacyKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
    keyName: "default",
  });

  return {
    authenticate: async (authorizationHeader) => {
      const userClient: SupabaseClient<Database> = createClient<Database>(
        supabaseUrl,
        publishableKey,
        {
          global: { headers: { Authorization: authorizationHeader } },
          auth: { autoRefreshToken: false, persistSession: false },
        },
      );
      const { data, error } = await userClient.auth.getUser();
      return error ? null : data.user;
    },
    createStore: () => {
      const privilegedClient = createClient<Database>(
        supabaseUrl,
        privilegedKey,
        {
          auth: {
            persistSession: false,
            autoRefreshToken: false,
            detectSessionInUrl: false,
          },
        },
      );
      return createAdminSubmissionStore(privilegedClient);
    },
    nowIso: () => new Date().toISOString(),
  };
}

if (import.meta.main) {
  Deno.serve(createHandler(createProductionDependencies()));
}
