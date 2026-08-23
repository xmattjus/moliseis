import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.112.3";

import type { Database, Json } from "../_shared/database.types.ts";
import {
  type CloudinaryConfig,
  destroyCloudinaryImage,
  uploadRemoteImage,
} from "../_shared/cloudinary.ts";
import {
  discoverFutureStartDates,
  fetchEventsForDate,
} from "./eventimolise.ts";
import {
  addDaysToCalendarDate,
  buildDedupKey,
  calendarDateInRome,
  type PreparedExternalEvent,
  prepareEvent,
  zonedDateTimeToIso,
} from "./import_logic.ts";

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

type ExistingSubmission = {
  city: string;
  name: string;
  start_date: string | null;
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

async function loadImporterIdentity(
  admin: SupabaseClient<Database>,
): Promise<{ id: string; email: string; name: string }> {
  const importerId = requiredEnv("EXTERNAL_EVENTS_IMPORTER_USER_ID");
  const { data, error } = await admin.auth.admin.getUserById(importerId);

  if (error || !data.user) {
    throw new Error(
      "Could not load the configured external-events importer user",
    );
  }

  const email = data.user.email?.trim();
  const displayName = typeof data.user.user_metadata?.display_name === "string"
    ? data.user.user_metadata.display_name.trim()
    : "";

  if (!email || !displayName) {
    throw new Error(
      "External-events importer user requires email and display_name",
    );
  }

  return { id: data.user.id, email, name: displayName };
}

async function loadExistingKeys(
  admin: SupabaseClient<Database>,
  events: PreparedExternalEvent[],
): Promise<Set<string>> {
  const keys = new Set<string>();
  if (events.length === 0) return keys;

  const sourceDates = events
    .map((event) => calendarDateInRome(event.startDate))
    .sort();
  const minDate = sourceDates[0];
  const maxDate = sourceDates.at(-1)!;
  const lowerBound = zonedDateTimeToIso(minDate, "00:00");
  const upperBound = zonedDateTimeToIso(
    addDaysToCalendarDate(maxDate, 1),
    "00:00",
  );

  const { data, error } = await admin
    .from("content_submissions")
    .select("city,name,start_date")
    .gte("start_date", lowerBound)
    .lt("start_date", upperBound);

  if (error) {
    throw new Error(`Could not load existing submissions: ${error.message}`);
  }

  for (const row of (data ?? []) as ExistingSubmission[]) {
    if (!row.start_date) continue;
    try {
      keys.add(buildDedupKey(row.city, row.name, row.start_date));
    } catch {
      // Ignore an unexpected historic timestamp instead of blocking all imports.
    }
  }

  return keys;
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

  let importer: { id: string; email: string; name: string };
  try {
    importer = await loadImporterIdentity(admin);
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

  const sourceSeen = new Set<string>();
  const sourceUnique: PreparedExternalEvent[] = [];
  let sourceDuplicates = 0;

  for (const event of prepared) {
    if (sourceSeen.has(event.dedupKey)) {
      sourceDuplicates += 1;
      continue;
    }
    sourceSeen.add(event.dedupKey);
    sourceUnique.push(event);
  }

  let existingKeys: Set<string>;
  try {
    existingKeys = await loadExistingKeys(admin, sourceUnique);
  } catch (error) {
    console.error(error);
    return jsonResponse({ code: "DEDUP_READ_FAILED" }, 500);
  }

  const newEvents = sourceUnique.filter((event) =>
    !existingKeys.has(event.dedupKey)
  );
  const existingDuplicates = sourceUnique.length - newEvents.length;
  const selectedEvents = newEvents.slice(0, parsed.limit);
  const limitReached = newEvents.length > selectedEvents.length;

  const baseReport = {
    source: parsed.source,
    dry_run: parsed.dryRun,
    listing_pages: discovery.pagesFetched,
    discovered_dates: discovery.dates.length,
    discovered_events: sourceEvents.length,
    source_duplicates: sourceDuplicates,
    existing_duplicates: existingDuplicates,
    eligible: newEvents.length,
    skipped_invalid: skippedInvalid,
    limit: parsed.limit,
    limit_reached: limitReached,
  };

  if (parsed.dryRun) {
    return jsonResponse({
      ...baseReport,
      would_insert: selectedEvents.length,
      errors,
    });
  }

  const cloudinary = cloudinaryConfig();
  let inserted = 0;
  let assetsUploaded = 0;
  let assetsFailed = 0;
  let withoutAsset = 0;

  for (const event of selectedEvents) {
    // Re-check the in-memory key immediately before insert so successful rows in
    // this same run also protect subsequent events.
    if (existingKeys.has(event.dedupKey)) continue;

    const { data: submission, error: insertError } = await admin
      .from("content_submissions")
      .insert({
        user_id: importer.id,
        user_email: importer.email,
        user_name: importer.name,
        city: event.city,
        name: event.name,
        description: null,
        description_delta: null,
        latitude: null,
        longitude: null,
        address: null,
        start_date: event.startDate,
        end_date: event.endDate,
        category: "unknown",
        status: "pending",
        internal_notes: event.internalNotes,
      })
      .select("id")
      .single();

    if (insertError || !submission) {
      addError(errors, {
        stage: "insert_submission",
        sourceId: event.sourceId,
        sourceUrl: event.sourceUrl,
        message: insertError?.message ?? "Submission insert returned no row",
      });
      continue;
    }

    inserted += 1;
    existingKeys.add(event.dedupKey);

    if (!event.imageUrl) {
      withoutAsset += 1;
      continue;
    }

    try {
      await uploadAndPersistImportedAsset(admin, {
        submissionId: submission.id,
        sourceUrl: event.imageUrl,
        cloudinary,
      });

      assetsUploaded += 1;
    } catch (error) {
      assetsFailed += 1;
      await appendAssetFailureNote(admin, submission.id, event.internalNotes);
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
    assets_uploaded: assetsUploaded,
    assets_failed: assetsFailed,
    without_asset: withoutAsset,
    errors,
  });
}

if (import.meta.main) {
  Deno.serve(handleRequest);
}
