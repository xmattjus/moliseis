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

export type SubmissionRecord = Pick<
  ContentSubmissionRow,
  | "id"
  | "city"
  | "name"
  | "description"
  | "description_delta"
  | "start_date"
  | "end_date"
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
>;

export type SubmissionAssetRecord = Pick<
  SubmissionAssetRow,
  "id" | "url" | "width" | "height"
>;

export type AdminSubmissionCreateValues = ValidatedAdminSubmissionInput & {
  user_id: string;
  user_email: string;
  user_name: string;
};

export type ChangeStatusStoreResult = "updated" | "not_found" | "not_pending";

export type UpdateStoreResult =
  | { outcome: "updated"; submission: SubmissionRecord }
  | { outcome: "not_found" }
  | { outcome: "not_pending" };

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
  | { outcome: "category_required" };

export interface AdminSubmissionStore {
  list(): Promise<SubmissionRecord[]>;
  getById(id: number): Promise<
    {
      submission: SubmissionRecord;
      assets: SubmissionAssetRecord[];
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
  }): Promise<ChangeStatusStoreResult>;
  promote(params: {
    id: number;
    target: PromotionTargetWire;
    handledBy: string;
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
  "id,city,name,description,description_delta,start_date,end_date,category,user_name,user_email,status,created_at,modified_at,latitude,longitude,promoted_place_id,promoted_event_id";
export const ASSET_SELECT = "id,url,width,height";

function throwOnError(error: unknown): void {
  if (error) throw new AdminSubmissionStoreError(error);
}

export function createAdminSubmissionStore(
  client: SupabaseClient<Database>,
): AdminSubmissionStore {
  return {
    async list(): Promise<SubmissionRecord[]> {
      const { data, error } = await client
        .from("content_submissions")
        .select(SUBMISSION_SELECT)
        .order("created_at", { ascending: false })
        .order("id", { ascending: false });
      throwOnError(error);
      return data ?? [];
    },

    async getById(id): Promise<
      {
        submission: SubmissionRecord;
        assets: SubmissionAssetRecord[];
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
      return { submission, assets: assets ?? [] };
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
      modifiedAt,
    ): Promise<UpdateStoreResult> {
      // Pending-only predicate: the guarded UPDATE itself is the race
      // protection against a concurrent promotion. Under READ COMMITTED it
      // blocks on the promoted row's lock, re-evaluates the status predicate
      // after the promote transaction commits, and matches zero rows, so an
      // accepted source can never diverge from its published entity.
      const { data, error } = await client
        .from("content_submissions")
        .update({
          category: input.category,
          city: input.city,
          name: input.name,
          description: input.description,
          description_delta: input.description_delta,
          start_date: input.start_date,
          end_date: input.end_date,
          latitude: input.latitude,
          longitude: input.longitude,
          modified_at: modifiedAt,
        })
        .eq("id", id)
        .eq("status", "pending")
        .select(SUBMISSION_SELECT)
        .maybeSingle();
      throwOnError(error);
      if (data) return { outcome: "updated", submission: data };

      // Classification only: distinguishes an absent row from one that is no
      // longer pending so the handler can answer 404 vs 409.
      const { data: existing, error: existingError } = await client
        .from("content_submissions")
        .select("id,status")
        .eq("id", id)
        .maybeSingle();
      throwOnError(existingError);
      return existing ? { outcome: "not_pending" } : { outcome: "not_found" };
    },

    async changeStatus(
      { id, status, handledBy, modifiedAt },
    ): Promise<ChangeStatusStoreResult> {
      const { data, error } = await client
        .from("content_submissions")
        .update({ status, handled_by: handledBy, modified_at: modifiedAt })
        .eq("id", id)
        .eq("status", "pending")
        .select("id")
        .maybeSingle();
      throwOnError(error);
      if (data) return "updated";

      const { data: existing, error: existingError } = await client
        .from("content_submissions")
        .select("id,status")
        .eq("id", id)
        .maybeSingle();
      throwOnError(existingError);
      return existing ? "not_pending" : "not_found";
    },

    async promote(
      { id, target, handledBy },
    ): Promise<PromoteStoreResult> {
      const { data, error } = await client.rpc("promote_content_submission", {
        p_submission_id: id,
        p_target: target,
        p_handled_by: handledBy,
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
