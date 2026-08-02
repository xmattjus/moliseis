/**
 * submit-content Edge Function
 *
 * Sole write path for community content submissions.
 *
 * Responsibilities
 * - Validate the authenticated Supabase user from the Bearer JWT.
 * - Enforce a per-user submission rate limit.
 * - Validate submission payloads and attached assets.
 * - Create a content_submissions record.
 * - Create associated submissions_assets records.
 * - Return structured error responses on failure.
 *
 * Security
 * - Uses a user-scoped client only for JWT validation.
 * - Uses a service-role client for all database operations.
 * - Database tables should not expose direct INSERT, UPDATE or DELETE
 *   access to authenticated clients.
 *
 * Asset Validation
 * - Only HTTPS URLs are accepted.
 * - Asset URLs must belong to an approved host allowlist.
 * - Basic media metadata validation is performed before persistence.
 *
 * Contact Information
 * - user_name and user_email are collected exclusively for moderator
 *   communication regarding a submission.
 * - They are user-supplied values and are not considered verified.
 * - Authentication and ownership are determined exclusively through
 *   the Supabase JWT and auth.users.id.
 * 
 * Rate Limiting
 * - Fixed-window implementation.
 * - Window size and maximum submission count are currently defined as
 *   function-level constants.
 *
 * Notes
 * - Anonymous authentication is supported because anonymous users are
 *   still authenticated Supabase users with a stable user id.
 * - Asset URLs are intentionally stored in a provider-agnostic format.
 *   The database schema does not depend on Cloudinary-specific
 *   identifiers.
 *
 * TODO: Race condition in rate limiting
 * ------------------------------------
 * The current implementation performs:
 *
 *   read -> validate -> upsert
 *
 * This sequence is not atomic.
 *
 * Example:
 *
 *   Request A reads submission_count = 4
 *   Request B reads submission_count = 4
 *   Request A increments to 5
 *   Request B increments to 5
 *
 * Result:
 *
 *   Two submissions are accepted while only one quota slot remained.
 *
 * Recommended fix:
 * - Move quota management into a PostgreSQL RPC function.
 * - Use SELECT ... FOR UPDATE row locking.
 * - Alternatively use an atomic UPDATE ... RETURNING approach.
 *
 * TODO: No rollback on partial failure
 * ------------------------------------
 * Submission creation currently spans multiple independent database
 * operations.
 *
 * Example:
 *
 *   create submission
 *   create assets
 *
 * If asset insertion fails:
 *
 *   - content_submissions row remains persisted
 *   - submission quota has already been consumed
 *   - the submission becomes partially created
 *
 * Recommended fix:
 * - Perform the entire workflow inside a database transaction.
 * - Implement submission creation through a PostgreSQL RPC function.
 * - Alternatively add cleanup logic for orphaned submissions.
 */

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from 'npm:@supabase/supabase-js@^2/cors'

const RATE_LIMIT_WINDOW_HOURS = 24;
const RATE_LIMIT_MAX_SUBMISSIONS = 5;

const ALLOWED_ASSET_HOSTS = ["res.cloudinary.com"];

const ALLOWED_CONTENT_CATEGORIES = [
  "nature",
  "history",
  "folklore",
  "food",
  "allure",
  "experience",
] as const;

/**
 * Pragmatic email validation regex.
 *
 * Intentionally does not implement the full RFC 5322 specification.
 *
 * Rationale:
 * - Full RFC-compliant email validation is extremely complex.
 * - Many RFC-valid addresses are rarely used in practice.
 * - Major platforms typically use simplified validation rules.
 * - Deliverability cannot be guaranteed by regex validation alone.
 *
 * Goal:
 * - Reject obvious invalid input.
 * - Accept common real-world email addresses.
 * - Keep validation maintainable and predictable.
 *
 * Examples accepted:
 *   user@example.com
 *   user.name@example.com
 *   user+tag@example.co.uk
 *
 * Examples rejected:
 *   user@
 *   @example.com
 *   user example@example.com
 *   user@example
 */
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

interface SubmissionAsset {
  url: string;

  width: number;
  height: number;

  mime_type?: string | null;

  duration_seconds?: number | null;
}

interface ContentSubmission {
  city: string;

  name: string;
  description?: string | null;

  latitude?: number | null;
  longitude?: number | null;
  address?: string | null;

  start_date?: string | null; // ISO-8601 for timestamptz
  end_date?: string | null; // ISO-8601 for timestamptz

  category?: string | null;

  /**
   * User-provided contact information.
   *
   * These fields are used exclusively by moderators to contact the
   * submitter regarding their submission (e.g. clarification requests,
   * missing information, moderation feedback).
   *
   * They are NOT used for authentication, authorization, user identity,
   * account ownership, or rate limiting.
   *
   * The authenticated user is identified exclusively through the
   * Supabase JWT and auth.users.id.
   */
  user_email: string;

  /**
   * User-provided contact information.
   *
   * This name is used exclusively for communication purposes and may
   * represent a real name, nickname, association, organization or
   * business name.
   *
   * It is NOT considered a verified identity and must not be used for
   * authorization or ownership checks.
   */
  user_name: string;

  assets?: SubmissionAsset[];
}

function createUserClient(authHeader: string) {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    },
  );
}

function createAdminClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

function errorResponse(code: string, message: string, status = 400): Response {
  return new Response(
    JSON.stringify({
      code,
      message,
    }),
    {
      status,
      headers: {
        ...corsHeaders, 'Content-Type': 'application/json'
      },
    },
  );
}

function validationErrorResponse(message: string): Response {
  return errorResponse("VALIDATION_ERROR", message, 400);
}

function isValidAssetUrl(urlString: string): boolean {
  try {
    const url = new URL(urlString);

    return (
      url.protocol === "https:" && ALLOWED_ASSET_HOSTS.includes(url.hostname)
    );
  } catch {
    return false;
  }
}

function validateMaxLength(
  value: string | null | undefined,
  maxLength: number,
  fieldName: string,
): Response | null {
  if (value != null && value.trim().length > maxLength) {
    return validationErrorResponse(
      `${fieldName} exceeds maximum length of ${maxLength}`,
    );
  }

  return null;
}

/**
 * Validates a user-provided contact email.
 *
 * Validation steps:
 * - Requires a non-empty value after trimming whitespace.
 * - Enforces a practical maximum length.
 * - Applies a pragmatic email format check.
 *
 * This email address is collected solely for moderation and contact
 * purposes. It is not used for authentication, account recovery,
 * authorization, identity verification, or ownership checks.
 *
 * The authenticated user is identified exclusively through the
 * Supabase JWT and auth.users.id.
 *
 * This validation intentionally prioritizes usability over strict RFC
 * compliance. The objective is to reject malformed addresses while
 * accepting the formats commonly used by real users.
 *
 * Note:
 * Passing validation only confirms that the email address appears
 * syntactically valid. It does not guarantee that the address exists
 * or can receive email.
 */
function validateEmail(email: string | null | undefined): Response | null {
  if (!email?.trim()) {
    return validationErrorResponse("user_email is required");
  }

  const normalizedEmail = email.trim();

  if (!EMAIL_REGEX.test(normalizedEmail)) {
    return validationErrorResponse("user_email is not valid");
  }

  return null;
}

function validateSubmission(body: ContentSubmission): Response | null {
  if (!body.name) {
    return validationErrorResponse("name is required");
  }

  if (!body.city) {
    return validationErrorResponse("city is required");
  }

  if (body.start_date && Number.isNaN(Date.parse(body.start_date))) {
    return validationErrorResponse("start_date is not valid");
  }

  if (body.end_date && Number.isNaN(Date.parse(body.end_date))) {
    return validationErrorResponse("end_date is not valid");
  }

  if (
    body.category !== undefined &&
    body.category !== null &&
    !ALLOWED_CONTENT_CATEGORIES.includes(body.category as any)
  ) {
    return validationErrorResponse("category is not valid");
  }

  const emailValidation = validateEmail(body.user_email);

  if (emailValidation) {
    return emailValidation;
  }

  if (!body.user_name) {
    return validationErrorResponse("user_name is required");
  }

  const lengthChecks = [
    validateMaxLength(body.name, 150, "name"),
    validateMaxLength(body.city, 100, "city"),
    validateMaxLength(body.description, 5000, "description"),
    validateMaxLength(body.address, 250, "address"),
    validateMaxLength(body.user_name, 100, "user_name"),
    validateMaxLength(body.user_email, 320, "user_email"),
  ];

  for (const result of lengthChecks) {
    if (result) {
      return result;
    }
  }

  const assets = body.assets ?? [];

  if (assets.length > 4) {
    return validationErrorResponse("assets length is not valid");
  }

  for (const asset of assets) {
    if (!isValidAssetUrl(asset.url)) {
      return validationErrorResponse("asset url is not valid");
    }

    if (asset.width <= 0) {
      return validationErrorResponse("asset width must be > 0");
    }

    if (asset.height <= 0) {
      return validationErrorResponse("asset height must be > 0");
    }

    if (asset.mime_type && !asset.mime_type.includes("/")) {
      return validationErrorResponse("mime_type is not valid");
    }
  }

  return null;
}

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return Response.json({ ok: true }, { headers: corsHeaders })
    }

    if (req.method !== "POST") {
      return errorResponse(
        "METHOD_NOT_ALLOWED",
        `${req.method} is not allowed`,
        405,
      );
    }
    
    const authHeader = req.headers.get("Authorization");

    if (!authHeader?.startsWith("Bearer ")) {
      return errorResponse("UNAUTHORIZED", "Missing bearer token", 401);
    }

    const userClient = createUserClient(authHeader);
    const adminClient = createAdminClient();

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return errorResponse("UNAUTHORIZED", "Invalid user token", 401);
    }

    let body: ContentSubmission;

    try {
      body = await req.json();
    } catch {
      return validationErrorResponse("Request body must be valid JSON");
    }

    const validationError = validateSubmission(body);

    if (validationError) {
      return validationError;
    }

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

      const isCurrentWindowActive = currentWindowStart > windowCutoff;

      if (isCurrentWindowActive) {
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

        city: body.city.trim(),

        name: body.name.trim(),
        description: body.description?.trim(),

        latitude: body.latitude,
        longitude: body.longitude,
        address: body.address?.trim(),

        start_date: body.start_date,
        end_date: body.end_date,

        ...(body.category != null ? { category: body.category } : {}),

        user_email: body.user_email.trim(),
        user_name: body.user_name.trim(),
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

    const assets = body.assets ?? [];

    if (assets.length > 0) {
      const assetRows = assets.map((asset) => ({
        content_submission_id: submission.id,

        url: asset.url,

        width: asset.width,
        height: asset.height,

        mime_type: asset.mime_type,

        duration_seconds: asset.duration_seconds,
      }));

      const { error: assetsInsertError } = await adminClient
        .from("submissions_assets")
        .insert(assetRows);

      if (assetsInsertError) {
        console.error(assetsInsertError);

        return errorResponse(
          "ASSET_INSERT_FAILED",
          "Unable to save submission assets",
          500,
        );
      }
    }

    return new Response(
      JSON.stringify({
        submission_id: submission.id,
      }),
      {
        status: 201,
        headers: {
          ...corsHeaders, 'Content-Type': 'application/json',
        },
      },
    );
  } catch (error) {
    console.error(error);

    return errorResponse("INTERNAL_ERROR", "Unexpected server error", 500);
  }
});
