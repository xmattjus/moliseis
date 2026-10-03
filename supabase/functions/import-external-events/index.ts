import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.112.3";

import {
  canonicalizeExternalEvent,
  EXTERNAL_EVENT_NORMALIZATION_VERSION,
  hashNormalizedExternalEvent,
} from "../_shared/external_event_normalization.ts";
import type { Database, Json } from "../_shared/database.types.ts";
import {
  type CloudinaryConfig,
  destroyCloudinaryImage,
  uploadRemoteImage,
} from "../_shared/cloudinary.ts";
import {
  discoverFutureStartDates,
  fetchEventsForDate,
  isAllowedEventImageUrl,
} from "./eventimolise.ts";
import { type PreparedExternalEvent, prepareEvent } from "./import_logic.ts";

export type ExternalEventIngestResult = {
  record_id: number;
  event_id: number | null;
  pending_submission_id: number | null;
  pending_created: boolean;
};

/** One observation, one record-scoped transaction; contributor identity stays in DB. */
export async function ingestExternalEvent(
  admin: SupabaseClient<Database>,
  event: PreparedExternalEvent,
  importerUserId: string,
): Promise<ExternalEventIngestResult> {
  const normalized = canonicalizeExternalEvent(event.normalized);
  const moderationHash = await hashNormalizedExternalEvent(normalized);
  type IngestArgs =
    Database["public"]["Functions"]["ingest_external_event"]["Args"];
  const args: Omit<IngestArgs, "p_occurrence_key"> & {
    p_occurrence_key: string | null;
  } = {
    p_provider: event.provider,
    p_external_id: event.externalId,
    p_occurrence_key: event.occurrenceKey,
    p_source_url: event.sourceUrl,
    p_normalized: normalized,
    p_normalization_version: EXTERNAL_EVENT_NORMALIZATION_VERSION,
    p_moderation_hash: moderationHash,
    p_metadata: event.metadata,
    p_metadata_version: 1,
    p_importer_user_id: importerUserId,
  };
  // Generated PostgreSQL argument metadata omits nullable parameter semantics.
  // The reviewed RPC explicitly accepts NULL occurrence keys (sent unchanged).
  const { data, error } = await admin.rpc(
    "ingest_external_event",
    args as IngestArgs,
  );
  if (error) throw new Error(`External ingest failed: ${error.message}`);
  if (data?.length !== 1 || data[0].outcome !== "ingested") {
    throw new Error(
      `External ingest failed: ${data?.[0]?.outcome ?? "invalid_response"}`,
    );
  }
  const row = data[0];
  const validId = (value: unknown) =>
    typeof value === "number" && Number.isSafeInteger(value) && value > 0;
  if (
    !validId(row.record_id) ||
    (row.event_id !== null && !validId(row.event_id)) ||
    (row.pending_submission_id !== null &&
      !validId(row.pending_submission_id)) ||
    typeof row.pending_created !== "boolean" ||
    (row.pending_created && row.pending_submission_id === null)
  ) {
    throw new Error("External ingest failed: invalid_response");
  }
  return {
    record_id: row.record_id,
    event_id: row.event_id,
    pending_submission_id: row.pending_submission_id,
    pending_created: row.pending_created,
  };
}

/** Creation budget counts new proposals, never observations of existing identity. */
export async function ingestPreparedObservations(
  admin: SupabaseClient<Database>,
  events: PreparedExternalEvent[],
  importerUserId: string,
  limit: number,
): Promise<
  {
    results: Array<
      { event: PreparedExternalEvent; observation: ExternalEventIngestResult }
    >;
    errors: ImportError[];
    created: number;
    limitReached: boolean;
  }
> {
  const results: Array<
    { event: PreparedExternalEvent; observation: ExternalEventIngestResult }
  > = [];
  const errors: ImportError[] = [];
  let created = 0;
  for (let index = 0; index < events.length; index++) {
    const event = events[index];
    try {
      const observation = await ingestExternalEvent(
        admin,
        event,
        importerUserId,
      );
      results.push({ event, observation });
      if (observation.pending_created) created += 1;
      if (created >= limit) {
        return {
          results,
          errors,
          created,
          limitReached: index + 1 < events.length,
        };
      }
    } catch (error) {
      addError(errors, {
        stage: "ingest_event",
        sourceId: event.sourceId,
        sourceUrl: event.sourceUrl,
        message: error instanceof Error
          ? error.message
          : "External ingest failed",
      });
    }
  }
  return { results, errors, created, limitReached: false };
}

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 50;
const MAX_REQUEST_BODY_BYTES = 16 * 1024;
const MAX_ERRORS_IN_RESPONSE = 50;

type ImportMode = "manual" | "scheduled";

type ImportRequest = {
  source: "eventimolise";
  dryRun: boolean;
  limit: number;
  mode: ImportMode;
};

type ImportError = {
  stage: string;
  message: string;
  sourceId?: number;
  sourceUrl?: string;
  date?: string;
};

type ImportedAssetDependencies = {
  uploadRemoteImage: typeof uploadRemoteImage;
  destroyCloudinaryImage: typeof destroyCloudinaryImage;
};

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function createAdminClient(): SupabaseClient<Database> {
  return createClient<Database>(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
  );
}

function cloudinaryConfig(): CloudinaryConfig {
  return {
    cloudName: requiredEnv("CLOUDINARY_CLOUD_NAME"),
    apiKey: requiredEnv("CLOUDINARY_API_KEY"),
    apiSecret: requiredEnv("CLOUDINARY_API_SECRET"),
  };
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function safeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  if (a.length !== b.length) return false;

  let difference = 0;
  for (let index = 0; index < a.length; index += 1) {
    difference |= a[index] ^ b[index];
  }
  return difference === 0;
}

async function readJsonBody(request: Request): Promise<unknown> {
  const declared = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declared) && declared > MAX_REQUEST_BODY_BYTES) {
    throw new Error("REQUEST_TOO_LARGE");
  }

  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > MAX_REQUEST_BODY_BYTES) {
    throw new Error("REQUEST_TOO_LARGE");
  }
  if (!text.trim()) return {};

  try {
    return JSON.parse(text);
  } catch {
    throw new Error("INVALID_JSON");
  }
}

function parseRequest(value: unknown): ImportRequest | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return null;
  }
  const payload = value as Record<string, unknown>;

  const source = payload.source ?? "eventimolise";
  const dryRun = payload.dry_run ?? false;
  const limit = payload.limit ?? DEFAULT_LIMIT;
  const mode = payload.mode ?? "manual";

  if (
    source !== "eventimolise" ||
    typeof dryRun !== "boolean" ||
    typeof limit !== "number" ||
    !Number.isInteger(limit) ||
    limit < 1 ||
    limit > MAX_LIMIT ||
    (mode !== "manual" && mode !== "scheduled")
  ) {
    return null;
  }

  return {
    source,
    dryRun,
    limit,
    mode,
  };
}

function hourInRome(now: Date): number {
  const hour = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Rome",
    hour: "2-digit",
    hourCycle: "h23",
  }).format(now);
  return Number(hour);
}

function addError(errors: ImportError[], error: ImportError): void {
  if (errors.length < MAX_ERRORS_IN_RESPONSE) errors.push(error);
}

async function appendAssetFailureNote(
  admin: SupabaseClient<Database>,
  submissionId: number,
  originalNotes: string,
): Promise<void> {
  const { error } = await admin
    .from("content_submissions")
    .update({
      internal_notes:
        `${originalNotes}\nWarning: image import failed; reviewer may need to add it manually`,
    })
    .eq("id", submissionId);

  if (error) {
    console.error("Could not append image failure note", {
      submissionId,
      error: error.message,
    });
  }
}

const defaultImportedAssetDependencies: ImportedAssetDependencies = {
  uploadRemoteImage,
  destroyCloudinaryImage,
};

/** Current image eligibility belongs to Edge; DB claims only persisted budget/state. */
export async function importSourceAssetIfEligible(
  admin: SupabaseClient<Database>,
  params: {
    event: Pick<PreparedExternalEvent, "imageUrl">;
    observation: ExternalEventIngestResult;
    cloudinary: CloudinaryConfig;
  },
  dependencies: ImportedAssetDependencies = defaultImportedAssetDependencies,
): Promise<"uploaded" | "skipped"> {
  const { event, observation, cloudinary } = params;
  if (
    !event.imageUrl || !isAllowedEventImageUrl(event.imageUrl) ||
    observation.event_id !== null || observation.pending_submission_id === null
  ) return "skipped";
  const { data, error } = await admin.rpc("claim_external_event_source_asset", {
    p_submission_id: observation.pending_submission_id,
  });
  if (error) throw new Error(`Source asset claim failed: ${error.message}`);
  const outcome = data?.length === 1 ? data[0].outcome : null;
  if (
    [
      "not_found",
      "not_imported",
      "not_pending",
      "source_already_linked",
      "already_claimed",
      "assets_present",
    ].includes(outcome ?? "")
  ) return "skipped";
  if (outcome !== "claimed") {
    throw new Error("Source asset claim returned an invalid outcome");
  }
  await uploadAndPersistImportedAsset(admin, {
    submissionId: observation.pending_submission_id,
    sourceUrl: event.imageUrl,
    cloudinary,
  }, dependencies);
  return "uploaded";
}

export async function uploadAndPersistImportedAsset(
  admin: SupabaseClient<Database>,
  params: {
    submissionId: number;
    sourceUrl: string;
    cloudinary: CloudinaryConfig;
  },
  dependencies: ImportedAssetDependencies = defaultImportedAssetDependencies,
): Promise<void> {
  const uploaded = await dependencies.uploadRemoteImage({
    sourceUrl: params.sourceUrl,
    config: params.cloudinary,
  });

  try {
    const { data: assetInsertResults, error: assetError } = await admin
      .rpc("add_submission_assets", {
        p_submission_id: params.submissionId,
        p_assets: [{
          url: uploaded.url,
          width: uploaded.width,
          height: uploaded.height,
          mime_type: uploaded.mimeType,
          duration_seconds: null,
        }] as Json,
      });
    const assetInsertResult = assetInsertResults?.[0];
    if (
      assetError ||
      assetInsertResults?.length !== 1 ||
      assetInsertResult?.outcome !== "created"
    ) {
      throw new Error(
        `Asset insert failed: ${
          assetError?.message ??
            `Asset insertion returned ${
              assetInsertResult?.outcome ?? "no outcome"
            }`
        }`,
      );
    }
  } catch (error) {
    try {
      await dependencies.destroyCloudinaryImage({
        publicId: uploaded.publicId,
        config: params.cloudinary,
      });
    } catch (cleanupError) {
      console.error("Could not clean up orphaned Cloudinary image", {
        publicId: uploaded.publicId,
        error: cleanupError instanceof Error
          ? cleanupError.message
          : String(cleanupError),
      });
    }
    throw error;
  }
}

export async function handleRequest(request: Request): Promise<Response> {
  if (request.method !== "POST") {
    return jsonResponse({ code: "METHOD_NOT_ALLOWED" }, 405);
  }

  const expectedSecret = requiredEnv("IMPORT_EXTERNAL_EVENTS_CRON_SECRET");
  const receivedSecret = request.headers.get("x-import-secret") ?? "";
  if (!safeEqual(receivedSecret, expectedSecret)) {
    return jsonResponse({ code: "UNAUTHORIZED" }, 401);
  }

  let body: unknown;
  try {
    body = await readJsonBody(request);
  } catch (error) {
    if (error instanceof Error && error.message === "REQUEST_TOO_LARGE") {
      return jsonResponse({ code: "REQUEST_TOO_LARGE" }, 413);
    }
    return jsonResponse({ code: "INVALID_JSON" }, 400);
  }

  const parsed = parseRequest(body);
  if (!parsed) {
    return jsonResponse({ code: "VALIDATION_ERROR" }, 400);
  }

  const now = new Date();
  if (parsed.mode === "scheduled" && hourInRome(now) !== 0) {
    return jsonResponse({
      source: parsed.source,
      skipped: true,
      reason: "Scheduled invocation is outside midnight in Europe/Rome",
    });
  }

  const errors: ImportError[] = [];
  const admin = createAdminClient();

  let importerUserId: string;
  try {
    importerUserId = requiredEnv("EXTERNAL_EVENTS_IMPORTER_USER_ID");
  } catch (error) {
    console.error(error);
    return jsonResponse({ code: "IMPORTER_USER_INVALID" }, 500);
  }

  let discovery;
  try {
    discovery = await discoverFutureStartDates({ now });
  } catch (error) {
    console.error("EventiMolise discovery failed", error);
    return jsonResponse({ code: "SOURCE_DISCOVERY_FAILED" }, 502);
  }

  const sourceEvents = [];
  let skippedInvalid = 0;

  for (const date of discovery.dates) {
    try {
      const result = await fetchEventsForDate(date);
      sourceEvents.push(...result.events);
      skippedInvalid += result.invalidCount;
    } catch (error) {
      addError(errors, {
        stage: "fetch_date",
        date,
        message: error instanceof Error
          ? error.message
          : "Unknown source error",
      });
    }
  }

  const prepared: PreparedExternalEvent[] = [];
  for (const event of sourceEvents) {
    try {
      prepared.push(prepareEvent(event));
    } catch (error) {
      skippedInvalid += 1;
      addError(errors, {
        stage: "prepare_event",
        sourceId: event.id,
        sourceUrl: event.url,
        message: error instanceof Error
          ? error.message
          : "Could not prepare event",
      });
    }
  }

  prepared.sort((left, right) =>
    left.startDate.localeCompare(right.startDate) ||
    left.sourceId - right.sourceId
  );

  // Every source observation reaches strong-identity ingest. Semantic matches
  // and repeated listing appearances cannot suppress provenance persistence.
  const baseReport = {
    source: parsed.source,
    dry_run: parsed.dryRun,
    listing_pages: discovery.pagesFetched,
    discovered_dates: discovery.dates.length,
    discovered_events: sourceEvents.length,
    eligible: prepared.length,
    skipped_invalid: skippedInvalid,
    limit: parsed.limit,
  };

  if (parsed.dryRun) {
    return jsonResponse({
      ...baseReport,
      observations_available: prepared.length,
      would_insert_upper_bound: Math.min(prepared.length, parsed.limit),
      errors,
    });
  }

  const batch = await ingestPreparedObservations(
    admin,
    prepared,
    importerUserId,
    parsed.limit,
  );
  for (const error of batch.errors) addError(errors, error);
  const cloudinary = cloudinaryConfig();
  const inserted = batch.created;
  let assetsUploaded = 0;
  let assetsFailed = 0;
  let withoutAsset = 0;

  for (const { event, observation } of batch.results) {
    try {
      const asset = await importSourceAssetIfEligible(admin, {
        event,
        observation,
        cloudinary,
      });
      if (asset === "skipped") {
        withoutAsset += 1;
        continue;
      }
      assetsUploaded += 1;
    } catch (error) {
      assetsFailed += 1;
      if (observation.pending_submission_id !== null) {
        await appendAssetFailureNote(
          admin,
          observation.pending_submission_id,
          event.internalNotes,
        );
      }
      addError(errors, {
        stage: "import_asset",
        sourceId: event.sourceId,
        sourceUrl: event.sourceUrl,
        message: error instanceof Error ? error.message : "Asset import failed",
      });
    }
  }

  return jsonResponse({
    ...baseReport,
    inserted,
    observations_processed: batch.results.length + batch.errors.length,
    limit_reached: batch.limitReached,
    assets_uploaded: assetsUploaded,
    assets_failed: assetsFailed,
    without_asset: withoutAsset,
    errors,
  });
}

if (import.meta.main) {
  Deno.serve(handleRequest);
}
