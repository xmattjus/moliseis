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
  submissionId?: number;
  publicId?: string;
  phase?: "claim" | "upload" | "association";
  outcome?: "failed" | "rejected" | "unknown";
  cleanup?: "confirmed" | "unconfirmed";
  note?: "confirmed" | "unconfirmed";
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

export class ImportedAssetError extends Error {
  readonly publicId?: string;
  readonly cleanup?: "confirmed" | "unconfirmed";

  constructor(
    readonly phase: "claim" | "upload" | "association",
    readonly outcome: "failed" | "rejected" | "unknown",
    message: string,
    options: {
      cause?: unknown;
      publicId?: string;
      cleanup?: "confirmed" | "unconfirmed";
    } = {},
  ) {
    super(message, { cause: options.cause });
    this.name = "ImportedAssetError";
    this.publicId = options.publicId;
    this.cleanup = options.cleanup;
  }
}

async function appendAssetFailureNote(
  admin: SupabaseClient<Database>,
  submissionId: number,
): Promise<"confirmed" | "unconfirmed"> {
  try {
    const { data, error } = await admin.from("content_submissions")
      .select("internal_notes").eq("id", submissionId).single().retry(false);
    if (
      error || !data ||
      (data.internal_notes !== null && typeof data.internal_notes !== "string")
    ) {
      return "unconfirmed";
    }
    const previous = data.internal_notes;
    const warning =
      "Warning: image import failed; inspect current assets before adding an image manually";
    let update = admin.from("content_submissions").update({
      internal_notes: previous ? `${previous}\n${warning}` : warning,
    }).eq("id", submissionId);
    update = previous === null
      ? update.is("internal_notes", null)
      : update.eq("internal_notes", previous);
    const result = await update.select("id");
    return !result.error && result.data?.length === 1 &&
        result.data[0].id === submissionId
      ? "confirmed"
      : "unconfirmed";
  } catch {
    return "unconfirmed";
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
  try {
    const { data, error } = await admin.rpc(
      "claim_external_event_source_asset",
      {
        p_submission_id: observation.pending_submission_id,
      },
    );
    if (error) throw error;
    const outcome = data?.length === 1 ? data[0]?.outcome : null;
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
    if (outcome !== "claimed") throw new Error("Invalid claim outcome");
  } catch (cause) {
    throw new ImportedAssetError(
      "claim",
      "failed",
      "Source asset claim failed",
      {
        cause,
      },
    );
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
  let uploaded;
  try {
    uploaded = await dependencies.uploadRemoteImage({
      sourceUrl: params.sourceUrl,
      config: params.cloudinary,
    });
  } catch (cause) {
    throw new ImportedAssetError(
      "upload",
      "failed",
      "Cloudinary upload failed",
      {
        cause,
      },
    );
  }

  const unknownAssociation = (cause?: unknown) =>
    new ImportedAssetError(
      "association",
      "unknown",
      "Asset association outcome unknown; inspect current submission assets before manual addition",
      { publicId: uploaded.publicId, cause },
    );
  let response: unknown;
  try {
    response = await admin.rpc("add_submission_assets", {
      p_submission_id: params.submissionId,
      p_assets: [{
        url: uploaded.url,
        width: uploaded.width,
        height: uploaded.height,
        mime_type: uploaded.mimeType,
        duration_seconds: null,
      }] as Json,
    });
  } catch (cause) {
    throw unknownAssociation(cause);
  }
  if (!response || typeof response !== "object" || Array.isArray(response)) {
    throw unknownAssociation();
  }
  const { data, error } = response as { data?: unknown; error?: unknown };
  const row = Array.isArray(data) && data.length === 1 ? data[0] : null;
  if (error !== null || !row || typeof row !== "object" || Array.isArray(row)) {
    throw unknownAssociation(error);
  }
  if (
    row.outcome === "created" && Number.isSafeInteger(row.id) && row.id > 0 &&
    row.url === uploaded.url && row.width === uploaded.width &&
    row.height === uploaded.height
  ) return;
  if (
    !["not_found", "not_pending", "limit_reached"].includes(row.outcome) ||
    row.id !== null || row.url !== null || row.width !== null ||
    row.height !== null
  ) throw unknownAssociation();

  let cleanup: "confirmed" | "unconfirmed" = "confirmed";
  let cleanupCause: unknown;
  try {
    await dependencies.destroyCloudinaryImage({
      publicId: uploaded.publicId,
      config: params.cloudinary,
    });
  } catch (cause) {
    cleanup = "unconfirmed";
    cleanupCause = cause;
  }
  throw new ImportedAssetError(
    "association",
    "rejected",
    `Asset association rejected: ${row.outcome}`,
    { publicId: uploaded.publicId, cleanup, cause: cleanupCause },
  );
}

/** Processes the observed batch; diagnostic persistence never owns its outcome. */
export async function importObservedAssets(
  admin: SupabaseClient<Database>,
  observations: Array<
    { event: PreparedExternalEvent; observation: ExternalEventIngestResult }
  >,
  cloudinary: CloudinaryConfig,
  dependencies: ImportedAssetDependencies = defaultImportedAssetDependencies,
) {
  const report = {
    assets_uploaded: 0,
    assets_failed: 0,
    assets_unknown: 0,
    without_asset: 0,
    errors: [] as ImportError[],
  };
  for (const { event, observation } of observations) {
    try {
      const asset = await importSourceAssetIfEligible(admin, {
        event,
        observation,
        cloudinary,
      }, dependencies);
      if (asset === "skipped") report.without_asset++;
      else report.assets_uploaded++;
    } catch (error) {
      const failure = error instanceof ImportedAssetError
        ? error
        : new ImportedAssetError(
          "claim",
          "failed",
          "Source asset processing failed",
        );
      if (failure.outcome === "unknown") report.assets_unknown++;
      else report.assets_failed++;
      const note = failure.outcome !== "unknown" &&
          observation.pending_submission_id !== null
        ? await appendAssetFailureNote(admin, observation.pending_submission_id)
        : undefined;
      addError(report.errors, {
        stage: "import_asset",
        sourceId: event.sourceId,
        sourceUrl: event.sourceUrl,
        submissionId: observation.pending_submission_id ?? undefined,
        publicId: failure.publicId,
        phase: failure.phase,
        outcome: failure.outcome,
        cleanup: failure.cleanup,
        note,
        message: failure.message,
      });
    }
  }
  return report;
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
  const assets = await importObservedAssets(
    admin,
    batch.results,
    cloudinaryConfig(),
  );
  for (const error of assets.errors) addError(errors, error);

  return jsonResponse({
    ...baseReport,
    inserted: batch.created,
    observations_processed: batch.results.length + batch.errors.length,
    limit_reached: batch.limitReached,
    ...assets,
    errors,
  });
}

if (import.meta.main) {
  Deno.serve(handleRequest);
}
