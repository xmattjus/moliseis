import type { SupabaseClient } from "npm:@supabase/supabase-js@2.112.3";

import type { Database, Json } from "../_shared/database.types.ts";
import {
  deltaAsJson,
  type ValidatedContentSubmission,
} from "./submission_validation.ts";

export type SubmissionStoreResult =
  | { outcome: "created"; submissionId: number }
  | { outcome: "replayed"; submissionId: number }
  | { outcome: "rate_limited" };

export interface SubmissionStore {
  submit(params: {
    userId: string;
    submission: ValidatedContentSubmission;
  }): Promise<SubmissionStoreResult>;
}

export class SubmissionStoreError extends Error {
  constructor(override readonly cause: unknown) {
    super("Content submission store operation failed");
    this.name = "SubmissionStoreError";
  }
}

type SubmitContentArgs =
  Database["public"]["Functions"]["submit_content"]["Args"];

function parseResult(data: unknown): SubmissionStoreResult {
  if (!Array.isArray(data) || data.length !== 1) {
    throw new SubmissionStoreError(
      new Error("Submit content returned an invalid outcome row count"),
    );
  }

  const row = data[0];
  if (row === null || typeof row !== "object" || Array.isArray(row)) {
    throw new SubmissionStoreError(
      new Error("Submit content returned a non-object outcome row"),
    );
  }

  const { outcome, submission_id } = row as Record<string, unknown>;
  switch (outcome) {
    case "created":
    case "replayed":
      if (
        typeof submission_id !== "number" ||
        !Number.isSafeInteger(submission_id) ||
        submission_id <= 0
      ) {
        throw new SubmissionStoreError(
          new Error("Submit content returned an invalid submission ID"),
        );
      }
      return { outcome, submissionId: submission_id };
    case "rate_limited":
      if (submission_id !== null) {
        throw new SubmissionStoreError(
          new Error("Rate-limited submit content returned a submission ID"),
        );
      }
      return { outcome };
    default:
      throw new SubmissionStoreError(
        new Error("Submit content returned an unknown outcome"),
      );
  }
}

export function createSubmissionStore(
  client: SupabaseClient<Database>,
): SubmissionStore {
  return {
    async submit({ userId, submission }): Promise<SubmissionStoreResult> {
      // `supabase gen types` currently renders nullable SQL function inputs as
      // non-null. The values remain deliberately null at runtime so the RPC,
      // rather than this transport boundary, owns its null-category mapping.
      const args = {
        p_user_id: userId,
        p_client_submission_id: submission.client_submission_id,
        p_city: submission.city,
        p_name: submission.name,
        p_description: submission.description,
        p_description_delta: deltaAsJson(submission.description_delta),
        p_latitude: submission.latitude,
        p_longitude: submission.longitude,
        p_address: submission.address,
        p_start_date: submission.start_date,
        p_end_date: submission.end_date,
        p_category: submission.category,
        p_user_email: submission.user_email,
        p_user_name: submission.user_name,
        p_assets: submission.assets as Json,
      } as unknown as SubmitContentArgs;
      const { data, error } = await client.rpc("submit_content", args);
      if (error) throw new SubmissionStoreError(error);
      return parseResult(data);
    },
  };
}
