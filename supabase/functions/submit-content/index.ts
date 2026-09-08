/**
 * Sole authenticated write path for community content submissions.
 *
 * Request parsing is complete before the privileged store is constructed. The
 * store's single RPC call owns quota, idempotency, content, and asset writes.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
  type User,
} from "npm:@supabase/supabase-js@2.112.3";
import { corsHeaders } from "npm:@supabase/supabase-js@2.112.3/cors";

import type { Database } from "../_shared/database.types.ts";
import {
  parseContentSubmission,
  readJsonBodyWithLimit,
  RequestBodyTooLargeError,
} from "./submission_validation.ts";
import {
  createSubmissionStore,
  type SubmissionStore,
  type SubmissionStoreResult,
} from "./submission_store.ts";

const JSON_HEADERS = { ...corsHeaders, "Content-Type": "application/json" };

type FailureLog = (
  operation: "submit_content",
  outcome: "persistence_failed" | "invalid_outcome",
) => void;

export type HandlerDependencies = {
  authenticate: (authorizationHeader: string) => Promise<User | null>;
  cloudName: string;
  createStore: () => SubmissionStore;
  logFailure: FailureLog;
};

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });
}

function errorResponse(code: string, message: string, status = 400): Response {
  return jsonResponse({ code, message }, status);
}

export function validationErrorResponse(message: string): Response {
  return errorResponse("VALIDATION_ERROR", message, 400);
}

function persistenceFailure(
  dependencies: HandlerDependencies,
  outcome: "persistence_failed" | "invalid_outcome",
): Response {
  try {
    dependencies.logFailure("submit_content", outcome);
  } catch {
    // Logging must not change the stable failure response.
  }
  return errorResponse(
    "INTERNAL_ERROR",
    "Unable to save submission",
    500,
  );
}

function responseForResult(
  result: SubmissionStoreResult,
  dependencies: HandlerDependencies,
): Response {
  switch (result.outcome) {
    case "created":
      return jsonResponse(
        { submission_id: result.submissionId, replayed: false },
        201,
      );
    case "replayed":
      return jsonResponse(
        { submission_id: result.submissionId, replayed: true },
        200,
      );
    case "rate_limited":
      return errorResponse(
        "RATE_LIMIT_EXCEEDED",
        "Maximum 5 submissions per 24 hours exceeded",
        429,
      );
    default:
      return persistenceFailure(dependencies, "invalid_outcome");
  }
}

export function createHandler(
  dependencies: HandlerDependencies,
): (request: Request) => Promise<Response> {
  return async (request) => {
    if (request.method === "OPTIONS") {
      return Response.json({ ok: true }, { headers: corsHeaders });
    }
    if (request.method !== "POST") {
      return errorResponse(
        "METHOD_NOT_ALLOWED",
        `${request.method} is not allowed`,
        405,
      );
    }

    const bearerMatch = /^Bearer ([^\s,]+)$/.exec(
      request.headers.get("Authorization") ?? "",
    );
    if (!bearerMatch) {
      return errorResponse("UNAUTHORIZED", "Missing bearer token", 401);
    }

    let user: User | null;
    try {
      user = await dependencies.authenticate(bearerMatch[0]);
    } catch {
      return errorResponse("UNAUTHORIZED", "Invalid user token", 401);
    }
    if (!user) {
      return errorResponse("UNAUTHORIZED", "Invalid user token", 401);
    }

    let rawBody: unknown;
    try {
      rawBody = await readJsonBodyWithLimit(request);
    } catch (error) {
      if (error instanceof RequestBodyTooLargeError) {
        return validationErrorResponse("Request body too large");
      }
      return validationErrorResponse("Request body must be valid JSON");
    }
    const parsedSubmission = parseContentSubmission(
      rawBody,
      dependencies.cloudName,
    );
    if (!parsedSubmission.ok) {
      return validationErrorResponse(parsedSubmission.message);
    }

    try {
      const result = await dependencies.createStore().submit({
        userId: user.id,
        submission: parsedSubmission.value,
      });
      return responseForResult(result, dependencies);
    } catch {
      return persistenceFailure(dependencies, "persistence_failed");
    }
  };
}

export function createProductionDependencies(): HandlerDependencies {
  const supabaseUrl = requiredEnv("SUPABASE_URL");
  const anonKey = requiredEnv("SUPABASE_ANON_KEY");
  const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const cloudName = requiredEnv("CLOUDINARY_CLOUD_NAME");
  return {
    cloudName,
    authenticate: async (authorizationHeader) => {
      const userClient: SupabaseClient<Database> = createClient<Database>(
        supabaseUrl,
        anonKey,
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
        serviceRoleKey,
        {
          auth: {
            persistSession: false,
            autoRefreshToken: false,
            detectSessionInUrl: false,
          },
        },
      );
      return createSubmissionStore(privilegedClient);
    },
    logFailure: (operation, outcome) => console.error(operation, outcome),
  };
}

if (import.meta.main) {
  Deno.serve(createHandler(createProductionDependencies()));
}
