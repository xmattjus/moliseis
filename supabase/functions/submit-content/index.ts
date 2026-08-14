/**
 * Sole authenticated write path for community content submissions.
 *
 * The parser deliberately treats every request field as untrusted. It keeps
 * authored description whitespace unchanged while normalizing contact and
 * location fields used for moderation.
 */
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.112.3";
import { corsHeaders } from "npm:@supabase/supabase-js@2.112.3/cors";

import type { Database } from "../_shared/database.types.ts";
import {
  deltaAsJson,
  parseContentSubmission,
  readJsonBodyWithLimit,
  RequestBodyTooLargeError,
} from "./submission_validation.ts";

const RATE_LIMIT_WINDOW_HOURS = 24;
const RATE_LIMIT_MAX_SUBMISSIONS = 5;

function createUserClient(authHeader: string): SupabaseClient<Database> {
  return createClient<Database>(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    { global: { headers: { Authorization: authHeader } } },
  );
}

function createAdminClient(): SupabaseClient<Database> {
  return createClient<Database>(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
  );
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function errorResponse(code: string, message: string, status = 400): Response {
  return new Response(JSON.stringify({ code, message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function validationErrorResponse(message: string): Response {
  return errorResponse("VALIDATION_ERROR", message, 400);
}

export async function handleRequest(request: Request): Promise<Response> {
  try {
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

    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return errorResponse("UNAUTHORIZED", "Missing bearer token", 401);
    }

    const userClient = createUserClient(authHeader);
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();
    if (userError || !user) {
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

    const parsedSubmission = parseContentSubmission(rawBody);
    if (!parsedSubmission.ok) {
      return validationErrorResponse(parsedSubmission.message);
    }
    const body = parsedSubmission.value;
    const adminClient = createAdminClient();

    const now = new Date();
    const windowCutoff = new Date(
      now.getTime() - RATE_LIMIT_WINDOW_HOURS * 60 * 60 * 1000,
    );
    const { data: rateLimitRow, error: rateLimitReadError } = await adminClient
      .from("submission_rate_limits")
      .select("*")
      .eq("user_id", user.id)
      .maybeSingle();
    if (rateLimitReadError) {
      console.error(rateLimitReadError);
      return errorResponse(
        "RATE_LIMIT_READ_FAILED",
        "Unable to check submission quota",
        500,
      );
    }

    let nextCount = 1;
    let nextWindowStart = now;
    if (rateLimitRow) {
      const currentWindowStart = new Date(rateLimitRow.window_started_at);
      if (currentWindowStart > windowCutoff) {
        if (rateLimitRow.submission_count >= RATE_LIMIT_MAX_SUBMISSIONS) {
          return errorResponse(
            "RATE_LIMIT_EXCEEDED",
            `Maximum ${RATE_LIMIT_MAX_SUBMISSIONS} submissions per ${RATE_LIMIT_WINDOW_HOURS} hours exceeded`,
            429,
          );
        }
        nextCount = rateLimitRow.submission_count + 1;
        nextWindowStart = currentWindowStart;
      }
    }

    const { error: rateLimitUpsertError } = await adminClient
      .from("submission_rate_limits")
      .upsert({
        user_id: user.id,
        submission_count: nextCount,
        window_started_at: nextWindowStart.toISOString(),
      });
    if (rateLimitUpsertError) {
      console.error(rateLimitUpsertError);
      return errorResponse(
        "RATE_LIMIT_UPDATE_FAILED",
        "Unable to update submission quota",
        500,
      );
    }

    const { data: submission, error: submissionInsertError } = await adminClient
      .from("content_submissions")
      .insert({
        user_id: user.id,
        city: body.city,
        name: body.name,
        description: body.description,
        description_delta: deltaAsJson(body.description_delta),
        latitude: body.latitude,
        longitude: body.longitude,
        address: body.address,
        start_date: body.start_date,
        end_date: body.end_date,
        ...(body.category === null ? {} : { category: body.category }),
        user_email: body.user_email,
        user_name: body.user_name,
      })
      .select("id")
      .single();
    if (submissionInsertError) {
      console.error(submissionInsertError);
      return errorResponse(
        "SUBMISSION_INSERT_FAILED",
        "Unable to create submission",
        500,
      );
    }

    if (body.assets.length > 0) {
      const { error: assetsInsertError } = await adminClient
        .from("submissions_assets")
        .insert(body.assets.map((asset) => ({
          content_submission_id: submission.id,
          ...asset,
        })));
      if (assetsInsertError) {
        console.error(assetsInsertError);
        return errorResponse(
          "ASSET_INSERT_FAILED",
          "Unable to save submission assets",
          500,
        );
      }
    }

    return new Response(JSON.stringify({ submission_id: submission.id }), {
      status: 201,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error(error);
    return errorResponse("INTERNAL_ERROR", "Unexpected server error", 500);
  }
}

if (import.meta.main) {
  Deno.serve(handleRequest);
}
