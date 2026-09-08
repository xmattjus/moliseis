import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.112.3";

import type { Database } from "../_shared/database.types.ts";
import type { ValidatedContentSubmission } from "./submission_validation.ts";
import {
  createSubmissionStore,
  SubmissionStoreError,
} from "./submission_store.ts";

type RpcResponse = { data: unknown; error: unknown };

class FakeSubmissionClient {
  readonly calls: Array<{ functionName: string; args: unknown }> = [];
  #responses: RpcResponse[] = [];

  queue(response: RpcResponse): void {
    this.#responses.push(response);
  }

  rpc(functionName: string, args: unknown): Promise<RpcResponse> {
    this.calls.push({ functionName, args });
    return Promise.resolve(
      this.#responses.shift() ?? { data: null, error: null },
    );
  }
}

function submission(): ValidatedContentSubmission {
  return {
    client_submission_id: "00000000-0000-4000-8000-000000000001",
    city: "Campobasso",
    name: "Teatro",
    description: null,
    description_delta: null,
    latitude: 41.56,
    longitude: 14.66,
    address: null,
    start_date: "2026-08-21T10:00:00.000Z",
    end_date: null,
    category: null,
    user_email: "contributor@example.test",
    user_name: "Contributor",
    assets: [
      {
        url:
          `https://res.cloudinary.com/test-cloud/image/upload/v1/content_submissions/${
            "a".repeat(64)
          }.jpg`,
        width: 1600,
        height: 1200,
        mime_type: "image/jpeg",
        duration_seconds: null,
      },
      {
        url:
          `https://res.cloudinary.com/test-cloud/image/upload/v2/content_submissions/${
            "b".repeat(64)
          }.webp`,
        width: 800,
        height: 600,
        mime_type: null,
        duration_seconds: 12,
      },
    ],
  };
}

function row(outcome: unknown, submissionId: unknown): Record<string, unknown> {
  return { outcome, submission_id: submissionId };
}

Deno.test("submission store forwards the exact submit_content argument allowlist", async () => {
  const client = new FakeSubmissionClient();
  client.queue({ data: [row("created", 7)], error: null });
  const store = createSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );

  assertEquals(
    await store.submit({
      userId: "00000000-0000-4000-8000-000000000002",
      submission: submission(),
    }),
    { outcome: "created", submissionId: 7 },
  );
  assertEquals(client.calls, [{
    functionName: "submit_content",
    args: {
      p_user_id: "00000000-0000-4000-8000-000000000002",
      p_client_submission_id: "00000000-0000-4000-8000-000000000001",
      p_city: "Campobasso",
      p_name: "Teatro",
      p_description: null,
      p_description_delta: null,
      p_latitude: 41.56,
      p_longitude: 14.66,
      p_address: null,
      p_start_date: "2026-08-21T10:00:00.000Z",
      p_end_date: null,
      p_category: null,
      p_user_email: "contributor@example.test",
      p_user_name: "Contributor",
      p_assets: submission().assets,
    },
  }]);
});

Deno.test("submission store preserves Delta and asset order", async () => {
  const client = new FakeSubmissionClient();
  client.queue({ data: [row("replayed", 8)], error: null });
  const store = createSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  const input = submission();
  input.description = "A description";
  input.description_delta = [{ insert: "A description\n" }];

  assertEquals(
    await store.submit({
      userId: "00000000-0000-4000-8000-000000000002",
      submission: input,
    }),
    { outcome: "replayed", submissionId: 8 },
  );
  assertEquals(
    (client.calls[0].args as Record<string, unknown>)[
      "p_description_delta"
    ],
    [{ insert: "A description\n" }],
  );
  assertEquals(
    (client.calls[0].args as Record<string, unknown>)["p_assets"],
    input.assets,
  );
});

Deno.test("submission store preserves an allowed category and complete date range", async () => {
  const client = new FakeSubmissionClient();
  client.queue({ data: [row("created", 9)], error: null });
  const store = createSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );
  const input = submission();
  input.category = "history";
  input.start_date = "2026-08-21T10:00:00.000+02:00";
  input.end_date = "2026-08-21T12:00:00.000+02:00";

  await store.submit({ userId: "user", submission: input });

  const args = client.calls[0].args as Record<string, unknown>;
  assertEquals(args["p_category"], "history");
  assertEquals(args["p_start_date"], "2026-08-21T10:00:00.000+02:00");
  assertEquals(args["p_end_date"], "2026-08-21T12:00:00.000+02:00");
});

Deno.test("submission store wraps RPC errors", async () => {
  const client = new FakeSubmissionClient();
  client.queue({ data: null, error: { message: "database unavailable" } });
  const store = createSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );

  await assertRejects(
    () => store.submit({ userId: "user", submission: submission() }),
    SubmissionStoreError,
  );
});

Deno.test("submission store rejects malformed RPC result shapes", async () => {
  const invalidResults: unknown[] = [
    null,
    [],
    [row("created", 1), row("created", 2)],
    [null],
    [row("unknown", null)],
    [row("created", null)],
    [row("replayed", 0)],
    [row("created", -1)],
    [row("created", 1.5)],
    [row("rate_limited", 1)],
  ];

  for (const data of invalidResults) {
    const client = new FakeSubmissionClient();
    client.queue({ data, error: null });
    const store = createSubmissionStore(
      client as unknown as SupabaseClient<Database>,
    );
    await assertRejects(
      () => store.submit({ userId: "user", submission: submission() }),
      SubmissionStoreError,
    );
  }
});

Deno.test("submission store accepts a null-ID rate-limit result", async () => {
  const client = new FakeSubmissionClient();
  client.queue({ data: [row("rate_limited", null)], error: null });
  const store = createSubmissionStore(
    client as unknown as SupabaseClient<Database>,
  );

  assertEquals(
    await store.submit({ userId: "user", submission: submission() }),
    { outcome: "rate_limited" },
  );
});
