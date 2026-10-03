import { assertEquals } from "jsr:@std/assert@1";

import {
  parseContentSubmission,
  parseRequest,
  serveRequest,
  shouldSkipStatusNotification,
} from "./index.ts";

const webhookHeaders = (secret = "test-secret") => ({
  "content-type": "application/json",
  "x-webhook-secret": secret,
});

function webhookPayload(status: "accepted" | "rejected") {
  return {
    type: "UPDATE",
    schema: "public",
    table: "content_submissions",
    record: { id: 42, status },
    old_record: { id: 42, status: "pending" },
  };
}

Deno.test("rejects missing and incorrect webhook secrets", async () => {
  const missing = await serveRequest(
    new Request("https://example.test", { method: "POST", body: "{}" }),
    null,
  );
  assertEquals(missing.status, 500);

  const wrong = await serveRequest(
    new Request("https://example.test", {
      method: "POST",
      headers: webhookHeaders("wrong"),
      body: "{}",
    }),
    "test-secret",
  );
  assertEquals(wrong.status, 401);
});

Deno.test("accepts a correct secret before rejecting malformed and oversized bodies", async () => {
  const malformed = await serveRequest(
    new Request("https://example.test", {
      method: "POST",
      headers: webhookHeaders(),
      body: "not-json",
    }),
    "test-secret",
  );
  assertEquals(malformed.status, 400);

  const tooLarge = await serveRequest(
    new Request("https://example.test", {
      method: "POST",
      headers: {
        ...webhookHeaders(),
        "content-length": String(128 * 1024 + 1),
      },
      body: "{}",
    }),
    "test-secret",
  );
  assertEquals(tooLarge.status, 413);
});

Deno.test("ignores non-transition webhook events without accessing the network", async () => {
  const response = await serveRequest(
    new Request("https://example.test", {
      method: "POST",
      headers: webhookHeaders(),
      body: JSON.stringify({ type: "INSERT" }),
    }),
    "test-secret",
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), {
    ignored: true,
    reason: "No pending-to-accepted/rejected transition or retry request",
  });
});

Deno.test("parses accepted and rejected pending transitions", () => {
  assertEquals(parseRequest(webhookPayload("accepted")), {
    kind: "webhook",
    submissionId: 42,
    expectedStatus: "accepted",
  });
  assertEquals(parseRequest(webhookPayload("rejected")), {
    kind: "webhook",
    submissionId: 42,
    expectedStatus: "rejected",
  });
});

Deno.test("parses valid manual retries and rejects invalid retry identifiers", () => {
  assertEquals(parseRequest({ action: "retry", submission_id: 42 }), {
    kind: "manual-retry",
    submissionId: 42,
  });
  assertEquals(parseRequest({ action: "retry", submission_id: "42" }), null);
  assertEquals(parseRequest({ action: "retry", submission_id: 0 }), null);
});

Deno.test("skips status notifications for the configured external-events importer", () => {
  const importerUserId = "6f8a6e05-8c9d-4fb3-90dc-b3adb7bb45cb";

  assertEquals(
    shouldSkipStatusNotification(
      { user_id: importerUserId },
      importerUserId,
    ),
    true,
  );

  assertEquals(
    shouldSkipStatusNotification(
      { user_id: "11111111-1111-4111-8111-111111111111" },
      importerUserId,
    ),
    false,
  );

  assertEquals(
    shouldSkipStatusNotification(
      { user_id: importerUserId },
      null,
    ),
    false,
  );
});

Deno.test("Structural external suppression is authoritative independent of legacy UUID", () => {
  assertEquals(
    shouldSkipStatusNotification({
      user_id: "different",
      external_event_record_id: 19,
    }, null),
    true,
  );
  assertEquals(
    shouldSkipStatusNotification({
      user_id: "different",
      external_event_record_id: 19,
    }, "legacy"),
    true,
  );
  assertEquals(
    shouldSkipStatusNotification({
      user_id: "human",
      external_event_record_id: null,
    }, "legacy"),
    false,
  );
});
Deno.test("Authoritative notification row requires nullable positive provenance ID", () => {
  const row = {
    id: 7,
    external_event_record_id: null,
    user_id: "human",
    city: "City",
    name: "Event",
    user_email: "human@example.test",
    user_name: "Human",
    handled_at: "2026-10-02T10:00:00Z",
    status: "accepted",
    rejection_reason: null,
    status_email_state: null,
    status_email_key: null,
    status_email_attempted_at: null,
  };
  assertEquals(parseContentSubmission(row)?.external_event_record_id, null);
  assertEquals(
    parseContentSubmission({ ...row, external_event_record_id: 19 })
      ?.external_event_record_id,
    19,
  );
  for (const invalid of [undefined, 0, -1, "19"]) {
    assertEquals(
      parseContentSubmission({ ...row, external_event_record_id: invalid }),
      null,
    );
  }
});
