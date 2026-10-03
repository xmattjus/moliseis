import {
  calendarDateInRome,
  normalizeDedupText,
} from "../_shared/external_event_candidates.ts";
import {
  romeEndOfCalendarDay,
  romeStartOfCalendarDay,
} from "../_shared/submission_dates.ts";
import type { EventMergeGroup } from "../_shared/external_event_merge.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.112.3";

import type { Database, Json } from "../_shared/database.types.ts";
import type {
  FinalSubmissionStatusWire,
  PromotionTargetWire,
  ValidatedAdminSubmissionInput,
} from "./admin_submission_validation.ts";
import type { ValidatedSubmissionAsset } from "../submit-content/submission_validation.ts";

type ContentSubmissionRow =
  Database["public"]["Tables"]["content_submissions"]["Row"];
type SubmissionAssetRow =
  Database["public"]["Tables"]["submissions_assets"]["Row"];

export type SubmissionRecord =
  & Pick<
    ContentSubmissionRow,
    | "id"
    | "city"
    | "name"
    | "description"
    | "description_delta"
    | "start_date"
    | "end_date"
    | "all_day"
    | "category"
    | "user_name"
    | "user_email"
    | "status"
    | "created_at"
    | "modified_at"
    | "latitude"
    | "longitude"
    | "promoted_place_id"
    | "promoted_event_id"
    | "external_event_record_id"
    | "external_normalized"
    | "external_normalization_version"
    | "external_moderation_hash"
    | "target_event_id"
  >
  & {
    currentSource?: {
      moderation_hash: string;
      normalized: Json;
      event_id?: number | null;
    } | null;
  };

export type SubmissionAssetRecord = Pick<
  SubmissionAssetRow,
  "id" | "url" | "width" | "height"
>;

export type AdminSubmissionCreateValues = ValidatedAdminSubmissionInput & {
  user_id: string;
  user_email: string;
  user_name: string;
};

export type ChangeStatusStoreResult =
  | "updated"
  | "not_found"
  | "not_pending"
  | "not_imported"
  | "source_changed"
  | "external_requires_resolution"
  | { outcome: "updated"; pendingSubmissionId: number | null };

export type UpdateStoreResult =
  | { outcome: "updated"; submission: SubmissionRecord }
  | { outcome: "not_found" }
  | { outcome: "not_pending" }
  | { outcome: "start_date_required" };

export type AddAssetStoreResult =
  | { outcome: "created"; asset: SubmissionAssetRecord }
  | { outcome: "not_found" }
  | { outcome: "not_pending" }
  | { outcome: "limit_reached" };

export type DeleteAssetStoreResult =
  | "deleted"
  | "not_found"
  | "not_pending"
  | "asset_not_found";

export type PromoteStoreResult =
  | { outcome: "created"; target: PromotionTargetWire; entityId: number }
  | {
    outcome: "already_promoted";
    target: PromotionTargetWire;
    entityId: number;
  }
  | { outcome: "not_found" }
  | { outcome: "not_pending" }
  | { outcome: "invalid_name" }
  | { outcome: "coordinates_required" }
  | { outcome: "invalid_coordinates" }
  | { outcome: "city_not_found" }
  | { outcome: "place_has_event_dates" }
  | { outcome: "start_date_required" }
  | { outcome: "invalid_date_range" }
  | { outcome: "invalid_asset" }
  | { outcome: "category_required" }
  | { outcome: "source_already_linked" }
  | { outcome: "source_changed" };

export type IgnoredSourceRecord =
  & Pick<
    Database["public"]["Tables"]["external_event_records"]["Row"],
    | "id"
    | "provider"
    | "external_id"
    | "occurrence_key"
    | "ignored_at"
    | "event_id"
  >
  & { name: string };
export type UnIgnoreStoreResult = {
  outcome: "unignored";
  pendingSubmissionId: number | null;
} | { outcome: "not_found" };

export type EventResolutionStoreResult =
  | {
    outcome: "linked" | "applied" | "already_resolved";
    eventId: number;
    pendingSubmissionId: number | null;
  }
  | {
    outcome:
      | "not_found"
      | "not_pending"
      | "not_event_submission"
      | "source_changed"
      | "target_conflict"
      | "relink_conflict"
      | "event_not_found"
      | "event_inactive"
      | "not_imported"
      | "source_not_linked"
      | "base_required"
      | "normalization_mismatch"
      | "invalid_groups"
      | "submission_changed"
      | "event_changed"
      | "start_date_required"
      | "invalid_date_range"
      | "coordinates_required"
      | "invalid_coordinates"
      | "city_not_found";
  };
export type LinkStoreParams = {
  id: number;
  targetEventId: number;
  handledBy: string;
  acknowledgeCurrentSource?: boolean;
  expectedSourceHash?: string | null;
};
export type { EventMergeGroup } from "../_shared/external_event_merge.ts";
export type ApplyStoreParams = LinkStoreParams & {
  groupsToApply: EventMergeGroup[];
  submissionVersionToken: string;
  eventVersionToken: string;
};
export type EventRecord = Database["public"]["Tables"]["events"]["Row"] & {
  city: string | null;
};
export type EventCandidates = {
  events: Array<EventRecord & { name_match: boolean }>;
  pending_warnings: Array<
    Pick<SubmissionRecord, "id" | "name" | "city" | "start_date">
  >;
};
export type EventCandidateSearch = { eventId?: number; name?: string };
export interface AdminSubmissionStore {
  getExternalRecord(
    id: number,
  ): Promise<
    Database["public"]["Tables"]["external_event_records"]["Row"] | null
  >;
  getEvent(id: number): Promise<EventRecord | null>;
  findEventCandidates(
    submission: SubmissionRecord,
    search?: EventCandidateSearch,
  ): Promise<EventCandidates>;
  apply(params: ApplyStoreParams): Promise<EventResolutionStoreResult>;
  link(params: LinkStoreParams): Promise<EventResolutionStoreResult>;
  listIgnoredSources(): Promise<IgnoredSourceRecord[]>;
  unIgnoreSource(id: number): Promise<UnIgnoreStoreResult>;
  list(): Promise<SubmissionRecord[]>;
  getById(id: number): Promise<
    {
      submission: SubmissionRecord;
      assets: SubmissionAssetRecord[];
      currentSource?: {
        moderation_hash: string;
        normalized: Json;
        event_id?: number | null;
      } | null;
    } | null
  >;
  create(values: AdminSubmissionCreateValues): Promise<SubmissionRecord>;
  update(
    id: number,
    input: ValidatedAdminSubmissionInput,
    modifiedAt: string,
  ): Promise<UpdateStoreResult>;
  changeStatus(params: {
    id: number;
    status: FinalSubmissionStatusWire;
    handledBy: string;
    modifiedAt: string;
    ignoreSource?: boolean;
    acknowledgeCurrentSource?: boolean;
    expectedSourceHash?: string | null;
  }): Promise<ChangeStatusStoreResult>;
  promote(params: {
    id: number;
    target: PromotionTargetWire;
    handledBy: string;
    acknowledgeCurrentSource?: boolean;
    expectedSourceHash?: string | null;
  }): Promise<PromoteStoreResult>;
  addAsset(
    submissionId: number,
    asset: ValidatedSubmissionAsset,
  ): Promise<AddAssetStoreResult>;
  deleteAsset(
    submissionId: number,
    assetId: number,
  ): Promise<DeleteAssetStoreResult>;
}

export class AdminSubmissionStoreError extends Error {
  constructor(override readonly cause: unknown) {
    super("Admin submission store operation failed");
    this.name = "AdminSubmissionStoreError";
  }
}

export const SUBMISSION_SELECT =
  "id,city,name,description,description_delta,start_date,end_date,all_day,category,user_name,user_email,status,created_at,modified_at,latitude,longitude,promoted_place_id,promoted_event_id,external_event_record_id,external_normalized,external_normalization_version,external_moderation_hash,target_event_id";
export const ASSET_SELECT = "id,url,width,height";

function throwOnError(error: unknown): void {
  if (error) throw new AdminSubmissionStoreError(error);
}

function parseEventResolutionResult(
  data: unknown,
  success: "linked" | "applied",
  requestedEvent: number,
): EventResolutionStoreResult {
  if (
    !Array.isArray(data) || data.length !== 1 || data[0] === null ||
    typeof data[0] !== "object" || Array.isArray(data[0])
  ) {
    throw new AdminSubmissionStoreError(
      new Error("Resolution returned invalid outcome row"),
    );
  }
  const row = data[0] as Record<string, unknown>;
  if (row.outcome === success || row.outcome === "already_resolved") {
    if (
      row.event_id !== requestedEvent ||
      (row.pending_submission_id !== null &&
        (typeof row.pending_submission_id !== "number" ||
          !Number.isSafeInteger(row.pending_submission_id) ||
          row.pending_submission_id <= 0))
    ) {
      throw new AdminSubmissionStoreError(
        new Error("Resolution returned invalid success payload"),
      );
    }
    return {
      outcome: row.outcome === "already_resolved"
        ? "already_resolved"
        : success,
      eventId: requestedEvent,
      pendingSubmissionId: row.pending_submission_id as number | null,
    };
  }
  switch (row.outcome) {
    case "not_found":
    case "not_pending":
    case "not_event_submission":
    case "source_changed":
    case "target_conflict":
    case "relink_conflict":
    case "event_not_found":
    case "event_inactive":
    case "not_imported":
    case "source_not_linked":
    case "base_required":
    case "normalization_mismatch":
    case "invalid_groups":
    case "submission_changed":
    case "event_changed":
    case "start_date_required":
    case "invalid_date_range":
    case "coordinates_required":
    case "invalid_coordinates":
    case "city_not_found":
      if (row.event_id !== null || row.pending_submission_id !== null) {
        throw new AdminSubmissionStoreError(
          new Error("Resolution failure carried a payload"),
        );
      }
      return { outcome: row.outcome };
    default:
      throw new AdminSubmissionStoreError(
        new Error("Resolution returned unknown outcome"),
      );
  }
}

export function createAdminSubmissionStore(
  client: SupabaseClient<Database>,
): AdminSubmissionStore {
  return {
    async getExternalRecord(id) {
      const { data, error } = await client.from("external_event_records")
        .select("*").eq("id", id).maybeSingle();
      throwOnError(error);
      return data;
    },
    async getEvent(id) {
      const { data, error } = await client.from("events").select(
        "*,city:cities(name)",
      ).eq("id", id).is("deleted_at", null).maybeSingle();
      throwOnError(error);
      return data ? { ...data, city: data.city?.name ?? null } : null;
    },
    async findEventCandidates(submission, search) {
      if (!submission.start_date) return { events: [], pending_warnings: [] };
      const day = calendarDateInRome(submission.start_date);
      const start = romeStartOfCalendarDay(day),
        end = romeEndOfCalendarDay(day);
      const { data: city, error: cityError } = await client.from("cities")
        .select("id").eq("name", submission.city).is("deleted_at", null)
        .maybeSingle();
      throwOnError(cityError);
      let eventsQuery = client.from("events").select("*,city:cities(name)").is(
        "deleted_at",
        null,
      );
      if (search?.eventId !== undefined) {
        eventsQuery = eventsQuery.eq("id", search.eventId);
      } else if (search?.name !== undefined) {
        eventsQuery = eventsQuery.ilike(
          "name",
          `%${search.name.replace(/[\\%_]/g, "\\$&")}%`,
        );
      } else if (city) {
        eventsQuery = eventsQuery.eq("city_id", city.id).gte(
          "start_date",
          start,
        ).lte("start_date", end);
      }
      const eventsResult = city || search
        ? await eventsQuery.order("start_date", { ascending: true }).limit(50)
        : { data: [], error: null };
      throwOnError(eventsResult.error);
      const { data: pending, error: pendingError } = await client.from(
        "content_submissions",
      ).select("id,name,city,start_date").eq("status", "pending").eq(
        "city",
        submission.city,
      ).gte("start_date", start).lte("start_date", end).neq("id", submission.id)
        .order("id", { ascending: true });
      throwOnError(pendingError);
      const name = normalizeDedupText(submission.name);
      return {
        events: (eventsResult.data ?? []).map((event) => ({
          ...event,
          city: event.city?.name ?? null,
          name_match: normalizeDedupText(event.name) === name,
        })),
        pending_warnings: (pending ?? []).filter((row) =>
          normalizeDedupText(row.name) === name
        ),
      };
    },
    async apply(
      {
        id,
        targetEventId,
        handledBy,
        groupsToApply,
        submissionVersionToken,
        eventVersionToken,
        acknowledgeCurrentSource,
        expectedSourceHash,
      },
    ) {
      const { data, error } = await client.rpc(
        "apply_external_event_submission",
        {
          p_submission_id: id,
          p_target_event_id: targetEventId,
          p_handled_by: handledBy,
          p_groups_to_apply: groupsToApply,
          p_submission_version_token: submissionVersionToken,
          p_event_version_token: eventVersionToken,
          ...(acknowledgeCurrentSource !== undefined
            ? { p_acknowledge_current_source: acknowledgeCurrentSource }
            : {}),
          ...(expectedSourceHash !== undefined
            ? { p_expected_source_hash: expectedSourceHash ?? undefined }
            : {}),
        },
      );
      throwOnError(error);
      return parseEventResolutionResult(data, "applied", targetEventId);
    },
    async link(
      {
        id,
        targetEventId,
        handledBy,
        acknowledgeCurrentSource,
        expectedSourceHash,
      },
    ) {
      const { data, error } = await client.rpc(
        "link_content_submission_to_event",
        {
          p_submission_id: id,
          p_target_event_id: targetEventId,
          p_handled_by: handledBy,
          ...(acknowledgeCurrentSource !== undefined
            ? { p_acknowledge_current_source: acknowledgeCurrentSource }
            : {}),
          ...(expectedSourceHash !== undefined
            ? { p_expected_source_hash: expectedSourceHash ?? undefined }
            : {}),
        },
      );
      throwOnError(error);
      return parseEventResolutionResult(data, "linked", targetEventId);
    },
    async listIgnoredSources() {
      const { data, error } = await client.from("external_event_records")
        .select(
          "id,provider,external_id,occurrence_key,normalized,ignored_at,event_id",
        )
        .not("ignored_at", "is", null).order("ignored_at", { ascending: false })
        .order("id", { ascending: false });
      throwOnError(error);
      return (data ?? []).map(({ normalized, ...row }) => {
        if (
          normalized === null || typeof normalized !== "object" ||
          Array.isArray(normalized) || typeof normalized.name !== "string"
        ) {
          throw new AdminSubmissionStoreError(
            new Error("Ignored source lacks normalized name"),
          );
        }
        return { ...row, name: normalized.name };
      });
    },
    async unIgnoreSource(id) {
      const { data, error } = await client.rpc("set_source_ignored", {
        p_external_event_record_id: id,
        p_ignored: false,
      });
      throwOnError(error);
      if (!Array.isArray(data) || data.length !== 1) {
        throw new AdminSubmissionStoreError(
          new Error("Un-ignore returned invalid outcome rows"),
        );
      }
      const row = data[0];
      if (row.outcome === "not_found" && row.pending_submission_id === null) {
        return { outcome: "not_found" };
      }
      if (
        row.outcome !== "unignored" ||
        (row.pending_submission_id !== null &&
          (!Number.isSafeInteger(row.pending_submission_id) ||
            row.pending_submission_id <= 0))
      ) {
        throw new AdminSubmissionStoreError(
          new Error("Un-ignore returned invalid outcome"),
        );
      }
      return {
        outcome: "unignored",
        pendingSubmissionId: row.pending_submission_id,
      };
    },
    async list(): Promise<SubmissionRecord[]> {
      const { data, error } = await client
        .from("content_submissions")
        .select(SUBMISSION_SELECT)
        .order("created_at", { ascending: false })
        .order("id", { ascending: false });
      throwOnError(error);
      const submissions = data ?? [];
      const recordIds = [
        ...new Set(
          submissions.flatMap((submission) =>
            submission.external_event_record_id === null
              ? []
              : [submission.external_event_record_id]
          ),
        ),
      ];
      if (recordIds.length === 0) return submissions;
      const { data: sources, error: sourceError } = await client.from(
        "external_event_records",
      )
        .select("id,moderation_hash,normalized,event_id").in("id", recordIds);
      throwOnError(sourceError);
      const sourcesById = new Map(
        (sources ?? []).map((source) => [source.id, source]),
      );
      return submissions.map((submission) => ({
        ...submission,
        currentSource: submission.external_event_record_id === null
          ? null
          : sourcesById.get(submission.external_event_record_id) ?? null,
      }));
    },

    async getById(id): Promise<
      {
        submission: SubmissionRecord;
        assets: SubmissionAssetRecord[];
        currentSource?: {
          moderation_hash: string;
          normalized: Json;
          event_id?: number | null;
        } | null;
      } | null
    > {
      const { data: submission, error: submissionError } = await client
        .from("content_submissions")
        .select(SUBMISSION_SELECT)
        .eq("id", id)
        .maybeSingle();
      throwOnError(submissionError);
      if (!submission) return null;

      const { data: assets, error: assetsError } = await client
        .from("submissions_assets")
        .select(ASSET_SELECT)
        .eq("content_submission_id", id)
        .order("id", { ascending: true });
      throwOnError(assetsError);
      let currentSource: {
        moderation_hash: string;
        normalized: Json;
        event_id?: number | null;
      } | null = null;
      if (submission.external_event_record_id !== null) {
        const { data: source, error: sourceError } = await client.from(
          "external_event_records",
        )
          .select("moderation_hash,normalized,event_id").eq(
            "id",
            submission.external_event_record_id,
          ).single();
        throwOnError(sourceError);
        if (!source) {
          throw new AdminSubmissionStoreError(
            new Error("Imported source record is missing"),
          );
        }
        currentSource = source;
      }
      return { submission, assets: assets ?? [], currentSource };
    },

    async create(values): Promise<SubmissionRecord> {
      const { data, error } = await client
        .from("content_submissions")
        .insert({
          category: values.category,
          city: values.city,
          name: values.name,
          description: values.description,
          description_delta: values.description_delta,
          start_date: values.start_date,
          end_date: values.end_date,
          all_day: values.all_day,
          user_id: values.user_id,
          user_email: values.user_email,
          user_name: values.user_name,
          latitude: values.latitude,
          longitude: values.longitude,
        })
        .select(SUBMISSION_SELECT)
        .single();
      throwOnError(error);
      if (!data) {
        throw new AdminSubmissionStoreError(
          new Error("Insert returned no row"),
        );
      }
      return data;
    },

    async update(
      id,
      input,
      _modifiedAt,
    ): Promise<UpdateStoreResult> {
      // Pending-only predicate: the guarded UPDATE itself is the race
      // protection against a concurrent promotion. Under READ COMMITTED it
      // blocks on the promoted row's lock, re-evaluates the status predicate
      // after the promote transaction commits, and matches zero rows, so an
      // accepted source can never diverge from its published entity.
      let update = client
        .from("content_submissions")
        .update({
          category: input.category,
          city: input.city,
          name: input.name,
          description: input.description,
          description_delta: input.description_delta,
          start_date: input.start_date,
          end_date: input.end_date,
          all_day: input.all_day,
          latitude: input.latitude,
          longitude: input.longitude,
        })
        .eq("id", id)
        .eq("status", "pending");
      // Predicate is rechecked under the row lock, including concurrent
      // migration from human to verified imported provenance.
      if (input.start_date === null) {
        update = update.is("external_event_record_id", null);
      }
      const { data, error } = await update
        .select(SUBMISSION_SELECT)
        .maybeSingle();
      throwOnError(error);
      if (data) return { outcome: "updated", submission: data };

      // Classification only: distinguish missing/finalized rows from imported
      // pending rows whose Event discriminator blocked this write.
      const { data: existing, error: existingError } = await client
        .from("content_submissions")
        .select("id,status,external_event_record_id")
        .eq("id", id)
        .maybeSingle();
      throwOnError(existingError);
      if (!existing) return { outcome: "not_found" };
      if (
        existing.status === "pending" &&
        existing.external_event_record_id !== null && input.start_date === null
      ) return { outcome: "start_date_required" };
      return { outcome: "not_pending" };
    },

    async changeStatus(
      {
        id,
        status,
        handledBy,
        modifiedAt,
        ignoreSource,
        acknowledgeCurrentSource,
        expectedSourceHash,
      },
    ): Promise<ChangeStatusStoreResult> {
      // Populated provenance is immutable; the RPC revalidates under locks.
      const { data: source, error: sourceError } = await client
        .from("content_submissions").select("id,external_event_record_id")
        .eq("id", id).maybeSingle();
      throwOnError(sourceError);
      if (!source) return "not_found";
      if (source.external_event_record_id !== null) {
        const { data, error } = await client.rpc(
          "reject_external_event_submission",
          {
            p_submission_id: id,
            p_handled_by: handledBy,
            ...(ignoreSource !== undefined
              ? { p_ignore_source: ignoreSource }
              : {}),
            ...(acknowledgeCurrentSource !== undefined
              ? { p_acknowledge_current_source: acknowledgeCurrentSource }
              : {}),
            ...(expectedSourceHash !== undefined
              ? { p_expected_source_hash: expectedSourceHash ?? undefined }
              : {}),
          },
        );
        throwOnError(error);
        if (!Array.isArray(data) || data.length !== 1) {
          throw new AdminSubmissionStoreError(
            new Error("Reject returned invalid outcome rows"),
          );
        }
        switch (data[0].outcome) {
          case "rejected": {
            const pendingId = data[0].pending_submission_id as number | null;
            if (
              pendingId !== null &&
              (!Number.isSafeInteger(pendingId) || pendingId <= 0)
            ) {
              throw new AdminSubmissionStoreError(
                new Error("Reject returned invalid pending ID"),
              );
            }
            return { outcome: "updated", pendingSubmissionId: pendingId };
          }
          case "not_found":
            return "not_found";
          case "not_pending":
            return "not_pending";
          case "source_changed":
            return "source_changed";
          default:
            throw new AdminSubmissionStoreError(
              new Error("Reject returned an unexpected outcome"),
            );
        }
      }
      if (acknowledgeCurrentSource === true) return "source_changed";
      if (ignoreSource === true) return "not_imported";
      const { data, error } = await client
        .from("content_submissions")
        .update({ status, handled_by: handledBy, modified_at: modifiedAt })
        .eq("id", id)
        .eq("status", "pending")
        .is("external_event_record_id", null)
        .select("id")
        .maybeSingle();
      throwOnError(error);
      if (data) return "updated";

      const { data: existing, error: existingError } = await client
        .from("content_submissions")
        .select("id,status,external_event_record_id")
        .eq("id", id)
        .maybeSingle();
      throwOnError(existingError);
      if (!existing) return "not_found";
      if (
        existing.status === "pending" &&
        existing.external_event_record_id !== null
      ) return "external_requires_resolution";
      return "not_pending";
    },

    async promote(
      { id, target, handledBy, acknowledgeCurrentSource, expectedSourceHash },
    ): Promise<PromoteStoreResult> {
      const { data, error } = await client.rpc("promote_content_submission", {
        p_submission_id: id,
        p_target: target,
        p_handled_by: handledBy,
        ...(acknowledgeCurrentSource !== undefined
          ? { p_acknowledge_current_source: acknowledgeCurrentSource }
          : {}),
        ...(expectedSourceHash !== undefined
          ? { p_expected_source_hash: expectedSourceHash ?? undefined }
          : {}),
      });
      throwOnError(error);

      // Generated database types declare entity_id/target_type non-null even
      // though domain-failure rows contain SQL NULLs. Runtime validation never
      // trusts that declaration. The RPC is a set-returning function whose
      // every code path returns exactly one row, so anything else is a
      // contract violation and fails closed instead of being interpreted.
      if (!Array.isArray(data) || data.length !== 1) {
        throw new AdminSubmissionStoreError(
          new Error(
            `Promotion returned ${
              data === null ? "null" : String(data.length)
            } outcome rows`,
          ),
        );
      }
      const row = data[0] as unknown;
      if (row === null || typeof row !== "object" || Array.isArray(row)) {
        throw new AdminSubmissionStoreError(
          new Error("Promotion returned a non-object outcome row"),
        );
      }
      const rowObject = row as Record<string, unknown>;
      const outcome = typeof rowObject.outcome === "string"
        ? rowObject.outcome
        : null;
      const targetType = rowObject.target_type;
      const entityId = rowObject.entity_id;

      switch (outcome) {
        case "created":
        case "already_promoted": {
          if (targetType !== "place" && targetType !== "event") {
            throw new AdminSubmissionStoreError(
              new Error(`Promotion returned an invalid target type`),
            );
          }
          if (
            typeof entityId !== "number" ||
            !Number.isSafeInteger(entityId) ||
            entityId <= 0
          ) {
            throw new AdminSubmissionStoreError(
              new Error("Promotion returned an invalid entity ID"),
            );
          }
          // A created result must match the requested target; any mismatch is
          // impossible legitimate data and fails closed. An already_promoted
          // result keeps the ACTUAL returned target so the handler can
          // distinguish same-target retries from conflicts.
          if (outcome === "created" && targetType !== target) {
            throw new AdminSubmissionStoreError(
              new Error(
                "Promotion created a target that differs from the request",
              ),
            );
          }
          return { outcome, target: targetType, entityId };
        }
        case "not_found":
        case "not_pending":
        case "invalid_name":
        case "coordinates_required":
        case "invalid_coordinates":
        case "city_not_found":
        case "place_has_event_dates":
        case "start_date_required":
        case "invalid_date_range":
        case "invalid_asset":
        case "category_required":
        case "source_already_linked":
        case "source_changed":
          // Domain failures carry no payload; populated payload fields on a
          // failure row are malformed data and fail closed.
          if (targetType !== null || entityId !== null) {
            throw new AdminSubmissionStoreError(
              new Error(
                `Promotion outcome ${outcome} unexpectedly carried a payload`,
              ),
            );
          }
          return { outcome };
        default:
          throw new AdminSubmissionStoreError(
            new Error("Promotion returned an unknown outcome"),
          );
      }
    },

    async addAsset(submissionId, asset): Promise<AddAssetStoreResult> {
      const { data, error } = await client.rpc("add_submission_assets", {
        p_submission_id: submissionId,
        p_assets: [asset] as Json,
      });
      throwOnError(error);
      const result = data?.[0];
      if (!result) {
        throw new AdminSubmissionStoreError(
          new Error("Asset insertion returned no outcome"),
        );
      }

      switch (result.outcome) {
        case "not_found":
          return { outcome: "not_found" };
        case "not_pending":
          return { outcome: "not_pending" };
        case "limit_reached":
          return { outcome: "limit_reached" };
        case "created":
          if (
            result.id === null ||
            result.url === null ||
            result.width === null ||
            result.height === null
          ) {
            throw new AdminSubmissionStoreError(
              new Error("Asset insertion returned incomplete row"),
            );
          }
          return {
            outcome: "created",
            asset: {
              id: result.id,
              url: result.url,
              width: result.width,
              height: result.height,
            },
          };
        default:
          throw new AdminSubmissionStoreError(
            new Error("Asset insertion returned an unknown outcome"),
          );
      }
    },

    async deleteAsset(submissionId, assetId): Promise<DeleteAssetStoreResult> {
      const { data, error } = await client.rpc("delete_submission_asset", {
        p_submission_id: submissionId,
        p_asset_id: assetId,
      });
      throwOnError(error);
      switch (data) {
        case "deleted":
        case "not_found":
        case "not_pending":
        case "asset_not_found":
          return data;
        default:
          throw new AdminSubmissionStoreError(
            new Error("Asset deletion returned an unknown outcome"),
          );
      }
    },
  };
}
