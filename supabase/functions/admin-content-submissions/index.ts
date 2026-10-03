import {
  canonicalizeEvent,
  canonicalizeExternalEvent,
  canonicalizeSubmission,
  type EventNormalizationInput,
  EXTERNAL_EVENT_NORMALIZATION_VERSION,
} from "../_shared/external_event_normalization.ts";
import { calculateExternalEventMerge } from "../_shared/external_event_merge.ts";
import { validateSubmissionDates } from "../_shared/submission_dates.ts";
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
  type EventResolutionStoreResult,
  type PromoteStoreResult,
  type SubmissionAssetRecord,
  type SubmissionRecord,
} from "./admin_submission_store.ts";
import {
  type ContentCategoryWire,
  type FinalSubmissionStatusWire,
  parseAdminContentSubmissionsRequest,
  type PromotionTargetWire,
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
  all_day: boolean;
  start_date: string | null;
  end_date: string | null;
  category: ContentCategoryWire;
  user_name: string;
  user_email: string;
  status: "pending" | "accepted" | "rejected";
  created_at: string;
  modified_at: string;
  latitude: number | null;
  longitude: number | null;
  promoted_place_id: number | null;
  promoted_event_id: number | null;
  external_event_record_id: number | null;
  external_normalized: Json | null;
  external_normalization_version: number | null;
  external_moderation_hash: string | null;
  target_event_id: number | null;
  moderation_hash: string | null;
  current_source_normalized: Json | null;
  external_mode: "create" | "update" | null;
  external_event_id: number | null;
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

function promotionResponse(
  result: PromoteStoreResult,
  requestedTarget: PromotionTargetWire,
): Response {
  switch (result.outcome) {
    case "created":
      // Store-level fail-closed validation guarantees a created target equals
      // the requested one.
      return jsonResponse({
        promotion: {
          target_type: result.target,
          entity_id: result.entityId,
        },
      });
    case "already_promoted":
      // Same-target retry is idempotent success; a different target means the
      // submission was published as the other kind and is a conflict.
      if (result.target !== requestedTarget) {
        return errorResponse(
          "PROMOTION_TARGET_CONFLICT",
          "The submission was already promoted with another target.",
          409,
        );
      }
      return jsonResponse({
        promotion: {
          target_type: result.target,
          entity_id: result.entityId,
        },
      });
    case "source_changed":
      return errorResponse(
        "SOURCE_CHANGED",
        "The displayed source revision changed; reload before resolving.",
        409,
      );
    case "source_already_linked":
      return errorResponse(
        "PROMOTION_SOURCE_ALREADY_LINKED",
        "The source already links to an Event; use Link or Apply.",
        409,
      );
    case "not_found":
      return errorResponse("NOT_FOUND", "Submission not found.", 404);
    case "not_pending":
      return errorResponse(
        "INVALID_STATUS_TRANSITION",
        "Only pending submissions can be promoted.",
        409,
      );
    case "invalid_name":
      return errorResponse(
        "PROMOTION_INVALID_NAME",
        "The submission name is not publishable.",
        422,
      );
    case "coordinates_required":
      return errorResponse(
        "PROMOTION_COORDINATES_REQUIRED",
        "The submission requires coordinates to be published.",
        422,
      );
    case "invalid_coordinates":
      return errorResponse(
        "PROMOTION_INVALID_COORDINATES",
        "The submission coordinates are out of range.",
        422,
      );
    case "city_not_found":
      return errorResponse(
        "PROMOTION_CITY_NOT_FOUND",
        "The submission city does not match an available locality.",
        422,
      );
    case "place_has_event_dates":
      return errorResponse(
        "PROMOTION_PLACE_HAS_EVENT_DATES",
        "A submission with event dates cannot be published as a place.",
        422,
      );
    case "start_date_required":
      return errorResponse(
        "PROMOTION_START_DATE_REQUIRED",
        "An event publication requires a start date.",
        422,
      );
    case "invalid_date_range":
      return errorResponse(
        "PROMOTION_INVALID_DATE_RANGE",
        "The event end date must not precede its start date.",
        422,
      );
    case "invalid_asset":
      return errorResponse(
        "PROMOTION_INVALID_ASSET",
        "A submission asset violates publication requirements.",
        422,
      );
    case "category_required":
      return errorResponse(
        "PROMOTION_CATEGORY_REQUIRED",
        "The submission requires a category before publication.",
        422,
      );
  }
}

export function eventResolutionResponse(
  result: EventResolutionStoreResult,
): Response {
  switch (result.outcome) {
    case "linked":
    case "applied":
    case "already_resolved":
      return jsonResponse({
        resolution: {
          outcome: result.outcome,
          target_event_id: result.eventId,
          pending_submission_id: result.pendingSubmissionId,
        },
      });
    case "not_found":
      return errorResponse("NOT_FOUND", "Submission not found.", 404);
    case "event_not_found":
      return errorResponse("EVENT_NOT_FOUND", "Event not found.", 404);
    case "not_event_submission":
      return errorResponse(
        "NOT_EVENT_SUBMISSION",
        "Only Event submissions can link to an Event.",
        422,
      );
    case "source_changed":
      return errorResponse(
        "SOURCE_CHANGED",
        "Review the current source version before acknowledging it.",
        409,
      );
    case "not_pending":
      return errorResponse(
        "INVALID_STATUS_TRANSITION",
        "Only pending submissions can be resolved.",
        409,
      );
    case "target_conflict":
      return errorResponse(
        "TARGET_CONFLICT",
        "Submission already resolved against another Event.",
        409,
      );
    case "relink_conflict":
      return errorResponse(
        "RELINK_CONFLICT",
        "The source already links to another Event.",
        409,
      );
    case "not_imported":
    case "source_not_linked":
    case "base_required":
      return errorResponse(
        "LINK_REQUIRED",
        "A linked imported source with a known base is required for Apply.",
        409,
      );
    case "normalization_mismatch":
      return errorResponse(
        "NORMALIZATION_MISMATCH",
        "Source normalization versions require migration.",
        409,
      );
    case "invalid_groups":
      return errorResponse(
        "INVALID_GROUPS",
        "Apply requires known unique semantic groups.",
        422,
      );
    case "submission_changed":
      return errorResponse(
        "SUBMISSION_CHANGED",
        "Submission changed; reload its preview.",
        409,
      );
    case "event_changed":
      return errorResponse(
        "EVENT_CHANGED",
        "Event changed; reload its preview.",
        409,
      );
    case "start_date_required":
      return errorResponse(
        "START_DATE_REQUIRED",
        "Event start date is required.",
        422,
      );
    case "invalid_date_range":
      return errorResponse(
        "INVALID_DATE_RANGE",
        "Event end must not precede start.",
        422,
      );
    case "coordinates_required":
      return errorResponse(
        "COORDINATES_REQUIRED",
        "Location requires coordinates.",
        422,
      );
    case "invalid_coordinates":
      return errorResponse(
        "INVALID_COORDINATES",
        "Location coordinates are invalid.",
        422,
      );
    case "city_not_found":
      return errorResponse(
        "CITY_NOT_FOUND",
        "Location city is not available.",
        422,
      );
    case "event_inactive":
      return errorResponse(
        "EVENT_INACTIVE",
        "The target Event is unavailable.",
        409,
      );
  }
}

function toSubmissionWire(
  submission: SubmissionRecord,
  assets: SubmissionAssetRecord[] = [],
  currentSource: {
    moderation_hash: string;
    normalized: Json;
    event_id?: number | null;
  } | null = null,
): AdminSubmissionWire {
  currentSource ??= submission.currentSource ?? null;
  return {
    id: submission.id,
    city: submission.city,
    name: submission.name,
    description: submission.description,
    description_delta: submission.description_delta,
    all_day: submission.all_day,
    start_date: submission.start_date,
    end_date: submission.end_date,
    category: submission.category,
    user_name: submission.user_name,
    user_email: submission.user_email,
    status: submission.status,
    created_at: submission.created_at,
    modified_at: submission.modified_at,
    latitude: submission.latitude,
    longitude: submission.longitude,
    promoted_place_id: submission.promoted_place_id,
    promoted_event_id: submission.promoted_event_id,
    external_event_record_id: submission.external_event_record_id,
    external_normalized: submission.external_normalized,
    external_normalization_version: submission.external_normalization_version,
    external_moderation_hash: submission.external_moderation_hash,
    target_event_id: submission.target_event_id,
    moderation_hash: currentSource?.moderation_hash ?? null,
    current_source_normalized: currentSource?.normalized ?? null,
    external_mode: currentSource
      ? (currentSource.event_id ? "update" : "create")
      : null,
    external_event_id: currentSource?.event_id ?? null,
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

function eventReadinessResponse(submission: SubmissionRecord): Response | null {
  if (submission.start_date === null) {
    return eventResolutionResponse({ outcome: "start_date_required" });
  }
  const temporal = validateSubmissionDates(
    submission.start_date,
    submission.end_date,
    false,
  );
  if (!temporal.ok) {
    return eventResolutionResponse({ outcome: "invalid_date_range" });
  }
  return null;
}

async function prepareMergePreview(
  store: AdminSubmissionStore,
  submission: SubmissionRecord,
  targetEventId: number,
) {
  if (submission.status !== "pending") {
    return eventResolutionResponse({ outcome: "not_pending" });
  }
  const readiness = eventReadinessResponse(submission);
  if (readiness) return readiness;
  if (submission.external_event_record_id === null) {
    return eventResolutionResponse({ outcome: "not_imported" });
  }
  const source = await store.getExternalRecord(
    submission.external_event_record_id,
  );
  if (!source || source.event_id === null) {
    return eventResolutionResponse({ outcome: "source_not_linked" });
  }
  if (source.event_id !== targetEventId) {
    return eventResolutionResponse({ outcome: "relink_conflict" });
  }
  if (source.proposed_normalized === null) {
    return eventResolutionResponse({ outcome: "base_required" });
  }
  if (
    submission.external_normalization_version !==
      EXTERNAL_EVENT_NORMALIZATION_VERSION ||
    source.normalization_version !==
      submission.external_normalization_version ||
    source.proposed_normalization_version !==
      submission.external_normalization_version
  ) return eventResolutionResponse({ outcome: "normalization_mismatch" });
  const event = await store.getEvent(targetEventId);
  if (!event) return eventResolutionResponse({ outcome: "event_inactive" });
  const base = canonicalizeExternalEvent(
    source.proposed_normalized as EventNormalizationInput,
  );
  const snapshot = canonicalizeExternalEvent(
    submission.external_normalized as EventNormalizationInput,
  );
  const moderated = canonicalizeSubmission(submission);
  const current = canonicalizeEvent(event);
  return {
    ...calculateExternalEventMerge(base, snapshot, moderated, current),
    submission_version_token: submission.modified_at,
    event_version_token: event.modified_at,
    target_event_id: targetEventId,
    stale: submission.external_moderation_hash !== source.moderation_hash,
    external_moderation_hash: submission.external_moderation_hash,
    moderation_hash: source.moderation_hash,
    current_source_normalized: source.normalized,
  };
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
        case "listIgnoredSources":
          return jsonResponse({ sources: await store.listIgnoredSources() });
        case "unIgnoreSource": {
          const result = await store.unIgnoreSource(
            parsed.value.external_event_record_id,
          );
          if (result.outcome === "not_found") {
            return errorResponse("NOT_FOUND", "Source record not found.", 404);
          }
          return jsonResponse({
            outcome: result.outcome,
            pending_submission_id: result.pendingSubmissionId,
          });
        }
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
            submission: toSubmissionWire(
              result.submission,
              result.assets,
              result.currentSource ?? null,
            ),
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
          const result = await store.update(
            parsed.value.submission_id,
            parsed.value.input,
            dependencies.nowIso(),
          );
          if (result.outcome === "not_found") {
            return errorResponse("NOT_FOUND", "Submission not found.", 404);
          }
          if (result.outcome === "not_pending") {
            return errorResponse(
              "INVALID_STATUS_TRANSITION",
              "Only pending submissions can be changed.",
              409,
            );
          }
          if (result.outcome === "start_date_required") {
            return errorResponse(
              "START_DATE_REQUIRED",
              "Imported submissions require an Event start date.",
              422,
            );
          }
          return jsonResponse({
            submission: toSubmissionWire(result.submission),
          });
        }
        case "changeStatus": {
          const result = await store.changeStatus({
            id: parsed.value.submission_id,
            status: parsed.value.status,
            handledBy: user.id,
            modifiedAt: dependencies.nowIso(),
            ...(parsed.value.ignore_source !== undefined
              ? { ignoreSource: parsed.value.ignore_source }
              : {}),
            ...(parsed.value.acknowledge_current_source !== undefined
              ? {
                acknowledgeCurrentSource:
                  parsed.value.acknowledge_current_source,
              }
              : {}),
            ...(parsed.value.expected_source_hash !== undefined
              ? { expectedSourceHash: parsed.value.expected_source_hash }
              : {}),
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
          if (result === "source_changed") {
            return errorResponse(
              "SOURCE_CHANGED",
              "Review the current source version before acknowledging it.",
              409,
            );
          }
          if (result === "external_requires_resolution") {
            return errorResponse(
              "EXTERNAL_REQUIRES_RESOLUTION",
              "Submission provenance changed; reload before resolving it.",
              409,
            );
          }
          if (result === "not_imported") {
            return errorResponse(
              "EXTERNAL_REQUIRES_RESOLUTION",
              "Source options require an imported submission.",
              409,
            );
          }
          return jsonResponse({
            ok: true,
            status: parsed.value.status,
            ...(typeof result === "object"
              ? { pending_submission_id: result.pendingSubmissionId }
              : {}),
          });
        }
        case "apply": {
          const detail = await store.getById(parsed.value.submission_id);
          if (!detail) return eventResolutionResponse({ outcome: "not_found" });
          const params = {
            id: parsed.value.submission_id,
            targetEventId: parsed.value.target_event_id,
            handledBy: user.id,
            submissionVersionToken: parsed.value.submission_version_token,
            eventVersionToken: parsed.value.event_version_token,
            ...(parsed.value.acknowledge_current_source !== undefined
              ? {
                acknowledgeCurrentSource:
                  parsed.value.acknowledge_current_source,
              }
              : {}),
            ...(parsed.value.expected_source_hash !== undefined
              ? { expectedSourceHash: parsed.value.expected_source_hash }
              : {}),
          };
          // The RPC owns accepted retry/conflict discovery before old tokens,
          // readiness, snapshots or pending-only canonicalization can intervene.
          if (detail.submission.status !== "pending") {
            return eventResolutionResponse(
              await store.apply({ ...params, groupsToApply: [] }),
            );
          }
          const preview = await prepareMergePreview(
            store,
            detail.submission,
            parsed.value.target_event_id,
          );
          if (preview instanceof Response) return preview;
          return eventResolutionResponse(
            await store.apply({
              ...params,
              groupsToApply: preview.groups_to_apply,
            }),
          );
        }
        case "mergePreview": {
          const detail = await store.getById(parsed.value.submission_id);
          if (!detail) return eventResolutionResponse({ outcome: "not_found" });
          const preview = await prepareMergePreview(
            store,
            detail.submission,
            parsed.value.target_event_id,
          );
          if (preview instanceof Response) return preview;
          return jsonResponse({ preview });
        }
        case "eventCandidates": {
          const detail = await store.getById(parsed.value.submission_id);
          if (!detail) {
            return errorResponse("NOT_FOUND", "Submission not found.", 404);
          }
          if (detail.submission.status !== "pending") {
            return errorResponse(
              "INVALID_STATUS_TRANSITION",
              "Candidate discovery requires a pending submission.",
              409,
            );
          }
          if (detail.submission.start_date === null) {
            return errorResponse(
              "NOT_EVENT_SUBMISSION",
              "Event candidates require an Event submission.",
              422,
            );
          }
          const candidates = await store.findEventCandidates(
            detail.submission,
            parsed.value.target_event_id !== undefined
              ? { eventId: parsed.value.target_event_id }
              : parsed.value.search_name !== undefined
              ? { name: parsed.value.search_name }
              : undefined,
          );
          return jsonResponse({ candidates });
        }
        case "link":
          return eventResolutionResponse(
            await store.link({
              id: parsed.value.submission_id,
              targetEventId: parsed.value.target_event_id,
              handledBy: user.id,
              ...(parsed.value.acknowledge_current_source !== undefined
                ? {
                  acknowledgeCurrentSource:
                    parsed.value.acknowledge_current_source,
                }
                : {}),
              ...(parsed.value.expected_source_hash !== undefined
                ? { expectedSourceHash: parsed.value.expected_source_hash }
                : {}),
            }),
          );
        case "promote": {
          const result = await store.promote({
            id: parsed.value.submission_id,
            target: parsed.value.target,
            // The authenticated administrator is always the handler; a
            // client-supplied handled_by is never trusted.
            handledBy: user.id,
            ...(parsed.value.acknowledge_current_source !== undefined
              ? {
                acknowledgeCurrentSource:
                  parsed.value.acknowledge_current_source,
              }
              : {}),
            ...(parsed.value.expected_source_hash !== undefined
              ? { expectedSourceHash: parsed.value.expected_source_hash }
              : {}),
          });
          return promotionResponse(result, parsed.value.target);
        }
        case "addAsset": {
          const result = await store.addAsset(
            parsed.value.submission_id,
            parsed.value.asset,
          );
          if (result.outcome === "not_found") {
            return errorResponse("NOT_FOUND", "Submission not found.", 404);
          }
          if (result.outcome === "not_pending") {
            return errorResponse(
              "INVALID_STATUS_TRANSITION",
              "Only pending submissions can be changed.",
              409,
            );
          }
          if (result.outcome === "limit_reached") {
            return errorResponse(
              "ASSET_LIMIT_REACHED",
              "A submission can have at most five assets.",
              409,
            );
          }
          return jsonResponse({ asset: toAssetWire(result.asset) });
        }
        case "deleteAsset": {
          const result = await store.deleteAsset(
            parsed.value.submission_id,
            parsed.value.asset_id,
          );
          if (result === "not_found") {
            return errorResponse("NOT_FOUND", "Submission not found.", 404);
          }
          if (result === "asset_not_found") {
            return errorResponse("ASSET_NOT_FOUND", "Asset not found.", 404);
          }
          if (result === "not_pending") {
            return errorResponse(
              "INVALID_STATUS_TRANSITION",
              "Only pending submissions can be changed.",
              409,
            );
          }
          return jsonResponse({ ok: true });
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
