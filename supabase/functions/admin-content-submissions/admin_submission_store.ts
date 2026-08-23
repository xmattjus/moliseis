import type { SupabaseClient } from "npm:@supabase/supabase-js@2.112.3";

import type { Database, Json } from "../_shared/database.types.ts";
import type {
  FinalSubmissionStatusWire,
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
  ): Promise<SubmissionRecord | null>;
  changeStatus(params: {
    id: number;
    status: FinalSubmissionStatusWire;
    handledBy: string;
    modifiedAt: string;
  }): Promise<ChangeStatusStoreResult>;
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
  "id,city,name,description,description_delta,start_date,end_date,category,user_name,user_email,status,created_at,modified_at,latitude,longitude";
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

    async update(id, input, modifiedAt): Promise<SubmissionRecord | null> {
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
        .select(SUBMISSION_SELECT)
        .maybeSingle();
      throwOnError(error);
      return data;
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
