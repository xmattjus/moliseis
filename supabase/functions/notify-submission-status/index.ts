import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.112.3";

import type { Database } from "../_shared/database.types.ts";

type SubmissionStatus = "pending" | "accepted" | "rejected";
type FinalSubmissionStatus = Exclude<SubmissionStatus, "pending">;
type EmailState = "sending" | "sent" | "failed";

type ContentSubmission = {
  id: number;
  user_id: string;
  city: string;
  name: string;
  user_email: string;
  user_name: string;
  handled_at: string | null;
  status: SubmissionStatus;
  rejection_reason: string | null;
  status_email_state: EmailState | null;
  status_email_key: string | null;
  status_email_attempted_at: string | null;
};

type FinalizedSubmission = ContentSubmission & {
  handled_at: string;
  status: FinalSubmissionStatus;
};

type WebhookRequest = {
  kind: "webhook";
  submissionId: number;
  expectedStatus: FinalSubmissionStatus;
};

type ManualRetryRequest = {
  kind: "manual-retry";
  submissionId: number;
};

type ParsedRequest = WebhookRequest | ManualRetryRequest;

type EmailContent = {
  subject: string;
  text: string;
  html: string;
};

type BrevoRecipient = {
  email: string;
  name?: string;
};

type BrevoSendPayload = {
  sender: BrevoRecipient;
  to: BrevoRecipient[];
  bcc?: BrevoRecipient[];
  replyTo?: BrevoRecipient;
  subject: string;
  textContent: string;
  htmlContent: string;
  tags: string[];
  headers: Record<string, string>;
};

type BrevoSendResult = {
  messageId: string | null;
  duplicate: boolean;
};

type ClaimResult = {
  claimed: boolean;
  reclaimedStaleClaim: boolean;
  manualReviewRequired: boolean;
};

class ExternalServiceError extends Error {
  constructor(
    message: string,
    readonly status: number | null,
    readonly details: unknown,
  ) {
    super(message);
    this.name = "ExternalServiceError";
  }
}

class RequestBodyTooLargeError extends Error {
  constructor() {
    super("Request body too large");
    this.name = "RequestBodyTooLargeError";
  }
}

const MAX_REQUEST_BODY_BYTES = 128 * 1024;
const BREVO_TIMEOUT_MS = 10_000;
const DATABASE_TIMEOUT_MS = 8_000;

// A hard-killed worker can leave a row in `sending`. Retrying after two minutes
// is safe while Brevo's idempotency key is still inside its documented TTL.
const STALE_CLAIM_MIN_AGE_MS = 60 * 1000;
// Brevo documentation has historically cited both 15- and 30-minute TTLs.
// Ten minutes stays safely inside either documented window.
const STALE_CLAIM_MAX_SAFE_AGE_MS = 10 * 60 * 1000;

function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();

  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }

  return value;
}

function optionalEnv(name: string): string | null {
  return Deno.env.get(name)?.trim() || null;
}

function getSupabaseAdminKey(): string {
  const secretKeysJson = Deno.env.get("SUPABASE_SECRET_KEYS")?.trim();

  if (secretKeysJson) {
    let secretKeys: unknown;

    try {
      secretKeys = JSON.parse(secretKeysJson);
    } catch {
      throw new Error("SUPABASE_SECRET_KEYS is not valid JSON");
    }

    if (typeof secretKeys !== "object" || secretKeys === null) {
      throw new Error("SUPABASE_SECRET_KEYS must contain a JSON object");
    }

    const defaultKey = (secretKeys as Record<string, unknown>).default;

    if (typeof defaultKey !== "string" || !defaultKey.trim()) {
      throw new Error(
        "SUPABASE_SECRET_KEYS does not contain a non-empty 'default' key",
      );
    }

    return defaultKey.trim();
  }

  // Legacy projects still expose this environment variable automatically.
  return requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
}

let supabaseAdmin: SupabaseClient<Database> | null = null;

function getSupabaseAdmin(): SupabaseClient<Database> {
  if (!supabaseAdmin) {
    supabaseAdmin = createClient<Database>(
      requiredEnv("SUPABASE_URL"),
      getSupabaseAdminKey(),
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );
  }

  return supabaseAdmin;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

function safeEqual(left: string, right: string): boolean {
  const encoder = new TextEncoder();
  const leftBytes = encoder.encode(left);
  const rightBytes = encoder.encode(right);
  const length = Math.max(leftBytes.length, rightBytes.length);

  let difference = leftBytes.length ^ rightBytes.length;

  for (let index = 0; index < length; index += 1) {
    difference |= (leftBytes[index] ?? 0) ^ (rightBytes[index] ?? 0);
  }

  return difference === 0;
}

export function shouldSkipStatusNotification(
  submission: { user_id: string },
  importerUserId: string | null,
): boolean {
  if (!importerUserId) {
    return false;
  }

  return safeEqual(submission.user_id.trim(), importerUserId.trim());
}

function isFinalStatus(value: unknown): value is FinalSubmissionStatus {
  return value === "accepted" || value === "rejected";
}

function isFinalizedSubmission(
  submission: ContentSubmission,
): submission is FinalizedSubmission {
  return isFinalStatus(submission.status) &&
    submission.handled_at !== null &&
    isValidIsoDate(submission.handled_at);
}

function isEmailState(value: unknown): value is EmailState {
  return value === "sending" || value === "sent" || value === "failed";
}

export function isValidSubmissionId(value: unknown): value is number {
  return typeof value === "number" && Number.isSafeInteger(value) && value > 0;
}

function isValidIsoDate(value: unknown): value is string {
  return typeof value === "string" && Number.isFinite(Date.parse(value));
}

function isValidEmail(value: string): boolean {
  return value.length <= 320 && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function sanitizeSingleLine(value: string): string {
  return value.replace(/[\r\n]+/g, " ").trim();
}

function truncate(value: string, maxLength: number): string {
  return value.length <= maxLength
    ? value
    : `${value.slice(0, maxLength - 1)}…`;
}

function escapeHtml(value: string): string {
  return value.replace(
    /[&<>"']/g,
    (character) =>
      ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        '"': "&quot;",
        "'": "&#039;",
      })[character]!,
  );
}

function htmlWithLineBreaks(value: string): string {
  return escapeHtml(value).replace(/\r?\n/g, "<br>");
}

function canonicalEmailForComparison(value: string): string {
  // Used only to avoid sending the same mailbox both as To and BCC.
  // The original casing is preserved in the actual API payload.
  return value.trim().toLocaleLowerCase("en-US");
}

function buildEmail(submission: ContentSubmission): EmailContent {
  const userName = submission.user_name.trim() || "utente";
  const submissionName = submission.name.trim() || "contenuto inviato";
  const city = submission.city.trim();

  if (submission.status === "accepted") {
    const subject = sanitizeSingleLine(
      `La tua proposta “${submissionName}” è stata approvata`,
    );

    return {
      subject,
      text: [
        `Ciao ${userName},`,
        "",
        `la tua proposta “${submissionName}”, relativa al comune di ${city}, è stata approvata.`,
        "",
        "Il contenuto verrà reso disponibile nell’app Molise Is secondo i normali tempi di pubblicazione.",
        "",
        "Grazie per il tuo contributo!",
        "",
        "Il team di Molise Is",
      ].join("\n"),
      html: `<!doctype html>
<html lang="it">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${escapeHtml(subject)}</title>
  </head>
  <body style="margin:0;padding:24px;background:#f5f5f5;font-family:Arial,Helvetica,sans-serif;color:#202124;line-height:1.55">
    <div style="max-width:600px;margin:0 auto;padding:32px;background:#ffffff;border-radius:12px">
      <h1 style="margin:0 0 24px;font-size:24px;line-height:1.25">Proposta approvata</h1>
      <p>Ciao ${escapeHtml(userName)},</p>
      <p>
        la tua proposta <strong>${escapeHtml(submissionName)}</strong>,
        relativa al comune di <strong>${
        escapeHtml(city)
      }</strong>, è stata approvata.
      </p>
      <p>
        Il contenuto verrà reso disponibile nell’app Molise Is secondo i normali tempi di pubblicazione.
      </p>
      <p style="margin-top:32px">Grazie per il tuo contributo!</p>
      <p>Il team di Molise Is</p>
    </div>
  </body>
</html>`,
    };
  }

  const subject = sanitizeSingleLine(
    `Aggiornamento sulla proposta “${submissionName}”`,
  );
  const rejectionReason = submission.rejection_reason?.trim() || null;
  const reasonText = rejectionReason
    ? ["", "Motivazione:", rejectionReason].join("\n")
    : "";
  const reasonHtml = rejectionReason
    ? `<div style="margin:24px 0;padding:16px;background:#f5f5f5;border-radius:8px">
         <strong>Motivazione</strong>
         <p style="margin:8px 0 0">${htmlWithLineBreaks(rejectionReason)}</p>
       </div>`
    : "";

  return {
    subject,
    text: [
      `Ciao ${userName},`,
      "",
      `abbiamo completato la revisione della tua proposta “${submissionName}”, relativa al comune di ${city}.`,
      "",
      "Al momento non è stato possibile approvarla.",
      reasonText,
      "",
      "Puoi verificare la motivazione e, quando opportuno, inviare nuovamente il contenuto con le modifiche necessarie.",
      "",
      "Grazie per il tuo contributo.",
      "",
      "Il team di Molise Is",
    ].join("\n"),
    html: `<!doctype html>
<html lang="it">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${escapeHtml(subject)}</title>
  </head>
  <body style="margin:0;padding:24px;background:#f5f5f5;font-family:Arial,Helvetica,sans-serif;color:#202124;line-height:1.55">
    <div style="max-width:600px;margin:0 auto;padding:32px;background:#ffffff;border-radius:12px">
      <h1 style="margin:0 0 24px;font-size:24px;line-height:1.25">Proposta non approvata</h1>
      <p>Ciao ${escapeHtml(userName)},</p>
      <p>
        abbiamo completato la revisione della tua proposta
        <strong>${escapeHtml(submissionName)}</strong>, relativa al comune di
        <strong>${escapeHtml(city)}</strong>.
      </p>
      <p>Al momento non è stato possibile approvarla.</p>
      ${reasonHtml}
      <p>
        Puoi verificare la motivazione e, quando opportuno, inviare nuovamente
        il contenuto con le modifiche necessarie.
      </p>
      <p style="margin-top:32px">Grazie per il tuo contributo.</p>
      <p>Il team di Molise Is</p>
    </div>
  </body>
</html>`,
  };
}

function buildBrevoPayload(params: {
  submission: ContentSubmission;
  email: EmailContent;
  transitionKey: string;
  idempotencyKey: string;
}): BrevoSendPayload {
  const senderEmail = requiredEnv("BREVO_SENDER_EMAIL");
  const senderName = optionalEnv("BREVO_SENDER_NAME") || "Molise Is";
  const replyToEmail = optionalEnv("BREVO_REPLY_TO_EMAIL") || senderEmail;
  const monitorEmail = optionalEnv("BREVO_MONITOR_EMAIL");
  const recipientEmail = params.submission.user_email.trim();

  if (!isValidEmail(senderEmail)) {
    throw new Error("BREVO_SENDER_EMAIL is not a valid email address");
  }

  if (!isValidEmail(replyToEmail)) {
    throw new Error("BREVO_REPLY_TO_EMAIL is not a valid email address");
  }

  if (monitorEmail && !isValidEmail(monitorEmail)) {
    throw new Error("BREVO_MONITOR_EMAIL is not a valid email address");
  }

  const payload: BrevoSendPayload = {
    sender: {
      email: senderEmail,
      name: sanitizeSingleLine(senderName),
    },
    to: [
      {
        email: recipientEmail,
        name: sanitizeSingleLine(params.submission.user_name),
      },
    ],
    replyTo: {
      email: replyToEmail,
      name: sanitizeSingleLine(senderName),
    },
    subject: params.email.subject,
    textContent: params.email.text,
    htmlContent: params.email.html,
    tags: [
      "content-submission",
      `status-${params.submission.status}`,
    ],
    headers: {
      // Brevo uses this custom message header to suppress duplicate requests.
      "Idempotency-Key": params.idempotencyKey,
      // Also makes future Brevo delivery webhooks easy to correlate.
      "X-Mailin-custom": `submission:${
        String(params.submission.id)
      }|status:${params.submission.status}|key:${params.transitionKey}`,
    },
  };

  // The monitoring copy is hidden from the user and can be disabled simply by
  // removing BREVO_MONITOR_EMAIL from the Edge Function secrets.
  if (
    monitorEmail &&
    canonicalEmailForComparison(monitorEmail) !==
      canonicalEmailForComparison(recipientEmail)
  ) {
    payload.bcc = [
      {
        email: monitorEmail,
        name: "Molise Is Monitor",
      },
    ];
  }

  return payload;
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );

  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function sha256HexToUuid(hex: string): string {
  if (!/^[0-9a-f]{64}$/.test(hex)) {
    throw new Error("Transition key is not a SHA-256 hexadecimal digest");
  }

  const characters = hex.slice(0, 32).split("");

  // Encode this deterministic identifier as an RFC 4122-compatible v5 UUID.
  characters[12] = "5";
  characters[16] = (
    (Number.parseInt(characters[16], 16) & 0x3) |
    0x8
  ).toString(16);

  const compact = characters.join("");

  return [
    compact.slice(0, 8),
    compact.slice(8, 12),
    compact.slice(12, 16),
    compact.slice(16, 20),
    compact.slice(20, 32),
  ].join("-");
}

function safeJsonStringify(value: unknown): string {
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

async function readResponseBody(response: Response): Promise<unknown> {
  const text = await response.text();

  if (!text) {
    return null;
  }

  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function isBrevoIdempotencyDuplicate(value: unknown): boolean {
  if (typeof value !== "object" || value === null) {
    return false;
  }

  const record = value as Record<string, unknown>;
  const code = typeof record.code === "string" ? record.code : "";
  const serialized = safeJsonStringify(value).toLowerCase();

  return (
    (code === "duplicate_parameter" || code === "duplicate_request") &&
    serialized.includes("idempot")
  );
}

function isRetryableExternalError(error: ExternalServiceError): boolean {
  return (
    error.status === null ||
    error.status === 408 ||
    error.status === 425 ||
    error.status === 429 ||
    error.status >= 500
  );
}

async function sendBrevoEmail(
  payload: BrevoSendPayload,
): Promise<BrevoSendResult> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), BREVO_TIMEOUT_MS);

  try {
    const response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "api-key": requiredEnv("BREVO_API_KEY"),
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    const result = await readResponseBody(response);

    if (!response.ok && isBrevoIdempotencyDuplicate(result)) {
      return {
        messageId: null,
        duplicate: true,
      };
    }

    if (
      !response.ok ||
      typeof result !== "object" ||
      result === null ||
      !("messageId" in result) ||
      typeof result.messageId !== "string" ||
      !result.messageId.trim()
    ) {
      throw new ExternalServiceError(
        "Brevo rejected the transactional email",
        response.status,
        result,
      );
    }

    return {
      messageId: result.messageId,
      duplicate: false,
    };
  } catch (error) {
    if (error instanceof ExternalServiceError) {
      throw error;
    }

    if (error instanceof DOMException && error.name === "AbortError") {
      throw new ExternalServiceError(
        "Brevo request timed out",
        null,
        null,
      );
    }

    throw new ExternalServiceError(
      "Could not reach Brevo",
      null,
      error instanceof Error ? error.message : String(error),
    );
  } finally {
    clearTimeout(timeout);
  }
}

function errorForLog(error: unknown): string {
  if (error instanceof ExternalServiceError) {
    return truncate(
      safeJsonStringify({
        message: error.message,
        status: error.status,
        details: error.details,
      }),
      2000,
    );
  }

  return truncate(
    error instanceof Error ? error.message : String(error),
    2000,
  );
}

export function parseContentSubmission(
  value: unknown,
): ContentSubmission | null {
  if (typeof value !== "object" || value === null) {
    return null;
  }

  const row = value as Record<string, unknown>;

  if (
    !isValidSubmissionId(row.id) ||
    typeof row.user_id !== "string" ||
    !row.user_id.trim() ||
    typeof row.city !== "string" ||
    typeof row.name !== "string" ||
    typeof row.user_email !== "string" ||
    typeof row.user_name !== "string" ||
    !(row.handled_at === null || isValidIsoDate(row.handled_at)) ||
    !(row.status === "pending" || isFinalStatus(row.status)) ||
    !(row.rejection_reason === null ||
      typeof row.rejection_reason === "string") ||
    !(row.status_email_state === null ||
      isEmailState(row.status_email_state)) ||
    !(row.status_email_key === null ||
      typeof row.status_email_key === "string") ||
    !(row.status_email_attempted_at === null ||
      isValidIsoDate(row.status_email_attempted_at))
  ) {
    return null;
  }

  return {
    id: row.id,
    user_id: row.user_id,
    city: row.city,
    name: row.name,
    user_email: row.user_email,
    user_name: row.user_name,
    handled_at: row.handled_at,
    status: row.status,
    rejection_reason: row.rejection_reason,
    status_email_state: row.status_email_state,
    status_email_key: row.status_email_key,
    status_email_attempted_at: row.status_email_attempted_at,
  };
}

async function fetchSubmission(
  submissionId: number,
): Promise<ContentSubmission | null> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DATABASE_TIMEOUT_MS);

  try {
    const { data, error } = await getSupabaseAdmin()
      .from("content_submissions")
      .select(`
        id,
        user_id,
        city,
        name,
        user_email,
        user_name,
        handled_at,
        status,
        rejection_reason,
        status_email_state,
        status_email_key,
        status_email_attempted_at
      `)
      .eq("id", submissionId)
      .abortSignal(controller.signal)
      .maybeSingle();

    if (error) {
      throw new Error(`Could not fetch content submission: ${error.message}`);
    }

    if (data === null) {
      return null;
    }

    const parsed = parseContentSubmission(data);

    if (!parsed) {
      throw new Error("The content submission row has an unexpected shape");
    }

    return parsed;
  } finally {
    clearTimeout(timeout);
  }
}

async function updateAndReturnId(params: {
  submission: FinalizedSubmission;
  transitionKey: string;
  staleAttemptedAt?: string;
}): Promise<boolean> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DATABASE_TIMEOUT_MS);

  try {
    let query = getSupabaseAdmin()
      .from("content_submissions")
      .update({
        status_email_state: "sending",
        status_email_key: params.transitionKey,
        status_email_attempted_at: new Date().toISOString(),
        status_email_sent_at: null,
        status_email_message_id: null,
        status_email_last_error: null,
      })
      .eq("id", params.submission.id)
      .eq("status", params.submission.status)
      .eq("handled_at", params.submission.handled_at);

    if (params.staleAttemptedAt) {
      query = query
        .eq("status_email_key", params.transitionKey)
        .eq("status_email_state", "sending")
        .eq("status_email_attempted_at", params.staleAttemptedAt);
    } else {
      // transitionKey is a SHA-256 hex digest. Never interpolate untrusted input
      // into a PostgREST `.or()` filter string.
      query = query.or(
        `status_email_key.is.null,status_email_key.neq.${params.transitionKey},status_email_state.is.null,status_email_state.eq.failed`,
      );
    }

    const { data, error } = await query
      .select("id")
      .abortSignal(controller.signal)
      .maybeSingle();

    if (error) {
      throw new Error(`Could not claim status email: ${error.message}`);
    }

    return data !== null;
  } finally {
    clearTimeout(timeout);
  }
}

async function claimNotification(params: {
  submission: FinalizedSubmission;
  transitionKey: string;
}): Promise<ClaimResult> {
  const claimedNormally = await updateAndReturnId(params);

  if (claimedNormally) {
    return {
      claimed: true,
      reclaimedStaleClaim: false,
      manualReviewRequired: false,
    };
  }

  const attemptedAt = params.submission.status_email_attempted_at;

  if (
    params.submission.status_email_state !== "sending" ||
    params.submission.status_email_key !== params.transitionKey ||
    !attemptedAt
  ) {
    return {
      claimed: false,
      reclaimedStaleClaim: false,
      manualReviewRequired: false,
    };
  }

  const attemptAge = Date.now() - Date.parse(attemptedAt);

  if (
    attemptAge < STALE_CLAIM_MIN_AGE_MS ||
    attemptAge > STALE_CLAIM_MAX_SAFE_AGE_MS
  ) {
    return {
      claimed: false,
      reclaimedStaleClaim: false,
      manualReviewRequired: attemptAge > STALE_CLAIM_MAX_SAFE_AGE_MS,
    };
  }

  const reclaimed = await updateAndReturnId({
    ...params,
    staleAttemptedAt: attemptedAt,
  });

  return {
    claimed: reclaimed,
    reclaimedStaleClaim: reclaimed,
    manualReviewRequired: false,
  };
}

async function markNotificationSent(params: {
  submissionId: number;
  transitionKey: string;
  messageId: string | null;
  duplicate: boolean;
}): Promise<void> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DATABASE_TIMEOUT_MS);

  try {
    const { data, error } = await getSupabaseAdmin()
      .from("content_submissions")
      .update({
        status_email_state: "sent",
        status_email_sent_at: new Date().toISOString(),
        status_email_message_id: params.messageId,
        status_email_last_error: params.duplicate
          ? "Brevo rejected a repeated request because the idempotency key had already been processed"
          : null,
      })
      .eq("id", params.submissionId)
      .eq("status_email_key", params.transitionKey)
      .eq("status_email_state", "sending")
      .select("id")
      .abortSignal(controller.signal)
      .maybeSingle();

    if (error || !data) {
      throw new Error(
        error?.message ?? "The successful Brevo send could not be persisted",
      );
    }
  } finally {
    clearTimeout(timeout);
  }
}

async function recordAmbiguousNotificationError(params: {
  submissionId: number;
  transitionKey: string;
  errorMessage: string;
}): Promise<void> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DATABASE_TIMEOUT_MS);

  try {
    const { error } = await getSupabaseAdmin()
      .from("content_submissions")
      .update({
        // Keep `sending`: the request may have reached Brevo even though the
        // function did not receive a definitive response. A retry is allowed
        // only inside the safe idempotency window handled by claimNotification.
        status_email_last_error: truncate(params.errorMessage, 2000),
      })
      .eq("id", params.submissionId)
      .eq("status_email_key", params.transitionKey)
      .eq("status_email_state", "sending")
      .abortSignal(controller.signal);

    if (error) {
      console.error("Could not persist the ambiguous email error", {
        submissionId: params.submissionId,
        error: error.message,
      });
    }
  } finally {
    clearTimeout(timeout);
  }
}

async function markNotificationFailed(params: {
  submissionId: number;
  transitionKey: string;
  errorMessage: string;
}): Promise<void> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), DATABASE_TIMEOUT_MS);

  try {
    const { error } = await getSupabaseAdmin()
      .from("content_submissions")
      .update({
        status_email_state: "failed",
        status_email_last_error: truncate(params.errorMessage, 2000),
      })
      .eq("id", params.submissionId)
      .eq("status_email_key", params.transitionKey)
      .eq("status_email_state", "sending")
      .abortSignal(controller.signal);

    if (error) {
      console.error("Could not persist the email failure", {
        submissionId: params.submissionId,
        error: error.message,
      });
    }
  } finally {
    clearTimeout(timeout);
  }
}

export function parseRequest(value: unknown): ParsedRequest | null {
  if (typeof value !== "object" || value === null) {
    return null;
  }

  const payload = value as Record<string, unknown>;

  if (
    payload.action === "retry" &&
    isValidSubmissionId(payload.submission_id)
  ) {
    return {
      kind: "manual-retry",
      submissionId: payload.submission_id,
    };
  }

  const record = payload.record;
  const oldRecord = payload.old_record;

  if (
    payload.type !== "UPDATE" ||
    payload.schema !== "public" ||
    payload.table !== "content_submissions" ||
    typeof record !== "object" ||
    record === null ||
    typeof oldRecord !== "object" ||
    oldRecord === null
  ) {
    return null;
  }

  const current = record as Record<string, unknown>;
  const previous = oldRecord as Record<string, unknown>;

  if (
    !isValidSubmissionId(current.id) ||
    !isFinalStatus(current.status) ||
    previous.status !== "pending"
  ) {
    return null;
  }

  return {
    kind: "webhook",
    submissionId: current.id,
    expectedStatus: current.status,
  };
}

async function readJsonBodyWithLimit(
  request: Request,
  maxBytes: number,
): Promise<unknown> {
  const declaredLength = Number(request.headers.get("content-length") ?? "0");

  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
    throw new RequestBodyTooLargeError();
  }

  if (!request.body) {
    throw new SyntaxError("Missing request body");
  }

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let totalBytes = 0;

  while (true) {
    const { done, value } = await reader.read();

    if (done) {
      break;
    }

    totalBytes += value.byteLength;

    if (totalBytes > maxBytes) {
      await reader.cancel();
      throw new RequestBodyTooLargeError();
    }

    chunks.push(value);
  }

  const bytes = new Uint8Array(totalBytes);
  let offset = 0;

  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }

  const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  return JSON.parse(text);
}

export async function handleRequest(
  request: Request,
  expectedWebhookSecret: string | null = requiredEnv("DATABASE_WEBHOOK_SECRET"),
): Promise<Response> {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const receivedSecret = request.headers.get("x-webhook-secret") ?? "";

  if (!expectedWebhookSecret) {
    throw new Error(
      "Missing required environment variable: DATABASE_WEBHOOK_SECRET",
    );
  }

  if (!safeEqual(receivedSecret, expectedWebhookSecret)) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  let rawPayload: unknown;

  try {
    rawPayload = await readJsonBodyWithLimit(
      request,
      MAX_REQUEST_BODY_BYTES,
    );
  } catch (error) {
    if (error instanceof RequestBodyTooLargeError) {
      return jsonResponse({ error: "Request body too large" }, 413);
    }

    return jsonResponse({ error: "Invalid JSON payload" }, 400);
  }

  const parsedRequest = parseRequest(rawPayload);

  if (!parsedRequest) {
    return jsonResponse({
      ignored: true,
      reason: "No pending-to-accepted/rejected transition or retry request",
    });
  }

  let submission: ContentSubmission | null;

  try {
    submission = await fetchSubmission(parsedRequest.submissionId);
  } catch (error) {
    console.error("Could not load the authoritative submission row", {
      submissionId: parsedRequest.submissionId,
      error: errorForLog(error),
    });

    return jsonResponse({ error: "Could not load the submission" }, 500);
  }

  if (!submission) {
    return jsonResponse({
      ignored: true,
      reason: "Submission not found",
    });
  }

  if (
    parsedRequest.kind === "webhook" &&
    submission.status !== parsedRequest.expectedStatus
  ) {
    return jsonResponse({
      ignored: true,
      reason: "The current database row no longer matches the webhook event",
      currentStatus: submission.status,
      expectedStatus: parsedRequest.expectedStatus,
    });
  }

  if (!isFinalStatus(submission.status)) {
    return jsonResponse({
      ignored: true,
      reason: "The current submission is not in a final moderation state",
      currentStatus: submission.status,
    });
  }

  if (
    shouldSkipStatusNotification(
      submission,
      optionalEnv("EXTERNAL_EVENTS_IMPORTER_USER_ID"),
    )
  ) {
    console.log("Skipping status email for automated importer submission", {
      submissionId: submission.id,
      submissionStatus: submission.status,
    });

    return jsonResponse({
      ignored: true,
      reason: "Submission belongs to the external-events importer",
      submissionId: submission.id,
    });
  }

  if (!isFinalizedSubmission(submission)) {
    return jsonResponse({
      ignored: true,
      reason: "The final submission has no valid handled_at timestamp",
      submissionId: submission.id,
      currentStatus: submission.status,
      handledAt: submission.handled_at,
    });
  }

  const transitionKey = await sha256Hex([
    String(submission.id),
    submission.status,
    submission.handled_at,
  ].join("|"));
  const idempotencyKey = sha256HexToUuid(transitionKey);
  const recipient = submission.user_email.trim();

  if (!isValidEmail(recipient)) {
    try {
      const claim = await claimNotification({ submission, transitionKey });

      if (claim.claimed) {
        await markNotificationFailed({
          submissionId: submission.id,
          transitionKey,
          errorMessage: "Invalid recipient email stored in content_submissions",
        });
      }
    } catch (error) {
      console.error("Could not persist the invalid recipient failure", {
        submissionId: submission.id,
        error: errorForLog(error),
      });

      return jsonResponse(
        { error: "Could not persist the invalid recipient failure" },
        500,
      );
    }

    console.error("Submission contains an invalid recipient email", {
      submissionId: submission.id,
    });

    return jsonResponse({
      processed: true,
      sent: false,
      permanentFailure: true,
      reason: "Invalid recipient email",
      retryHint:
        'Correct user_email, then invoke the function from the Dashboard tester with {"action":"retry","submission_id":<id>}.',
    });
  }

  let email: EmailContent;
  let brevoPayload: BrevoSendPayload;

  try {
    email = buildEmail(submission);
    brevoPayload = buildBrevoPayload({
      submission,
      email,
      transitionKey,
      idempotencyKey,
    });
  } catch (error) {
    console.error("Could not build the Brevo request", {
      submissionId: submission.id,
      error: errorForLog(error),
    });

    return jsonResponse({ error: "Email configuration is invalid" }, 500);
  }

  let claim: ClaimResult;

  try {
    claim = await claimNotification({ submission, transitionKey });
  } catch (error) {
    console.error("Could not claim the status email", {
      submissionId: submission.id,
      error: errorForLog(error),
    });

    return jsonResponse({ error: "Could not claim the status email" }, 500);
  }

  if (!claim.claimed) {
    return jsonResponse({
      ignored: true,
      reason: claim.manualReviewRequired
        ? "A previous sending claim is older than the safe Brevo idempotency retry window; check Brevo logs before resetting it"
        : "Notification already sending or sent",
      submissionId: submission.id,
      manualReviewRequired: claim.manualReviewRequired,
    });
  }

  let brevoResult: BrevoSendResult;

  try {
    brevoResult = await sendBrevoEmail(brevoPayload);
  } catch (error) {
    const errorMessage = errorForLog(error);
    const retryable = error instanceof ExternalServiceError &&
      isRetryableExternalError(error);

    console.error("Brevo could not send the status email", {
      submissionId: submission.id,
      submissionStatus: submission.status,
      retryable,
      error: errorMessage,
    });

    if (!retryable) {
      await markNotificationFailed({
        submissionId: submission.id,
        transitionKey,
        errorMessage,
      });

      return jsonResponse({
        processed: true,
        sent: false,
        retryable: false,
        error: "Brevo rejected the status email permanently",
      });
    }

    await recordAmbiguousNotificationError({
      submissionId: submission.id,
      transitionKey,
      errorMessage,
    });

    // Stock Supabase Database Webhooks record this status but do not provide a
    // built-in automatic retry queue. The 503 still correctly signals that the
    // failure is transient and supports any retry mechanism added later.
    return jsonResponse(
      {
        error: "Brevo could not send the status email",
        retryable: true,
        retryHint:
          'Wait at least one minute, then use the Dashboard tester with {"action":"retry","submission_id":<id>}.',
      },
      503,
    );
  }

  try {
    await markNotificationSent({
      submissionId: submission.id,
      transitionKey,
      messageId: brevoResult.messageId,
      duplicate: brevoResult.duplicate,
    });
  } catch (error) {
    console.error("Email accepted by Brevo but audit persistence failed", {
      submissionId: submission.id,
      brevoMessageId: brevoResult.messageId,
      duplicate: brevoResult.duplicate,
      error: errorForLog(error),
    });

    // The primary side effect already happened. Returning 2xx avoids causing a
    // generic caller to blindly repeat an email that Brevo may have accepted.
    return jsonResponse({
      sent: true,
      persisted: false,
      submissionId: submission.id,
      brevoMessageId: brevoResult.messageId,
      idempotentDuplicate: brevoResult.duplicate,
      manualReviewRequired: true,
    });
  }

  console.log("Submission status email accepted by Brevo", {
    submissionId: submission.id,
    submissionStatus: submission.status,
    brevoMessageId: brevoResult.messageId,
    idempotentDuplicate: brevoResult.duplicate,
    reclaimedStaleClaim: claim.reclaimedStaleClaim,
    monitoringCopyEnabled: Boolean(brevoPayload.bcc?.length),
    requestKind: parsedRequest.kind,
  });

  return jsonResponse({
    sent: true,
    submissionId: submission.id,
    submissionStatus: submission.status,
    brevoMessageId: brevoResult.messageId,
    idempotentDuplicate: brevoResult.duplicate,
    reclaimedStaleClaim: claim.reclaimedStaleClaim,
    monitoringCopyEnabled: Boolean(brevoPayload.bcc?.length),
  });
}

export async function serveRequest(
  request: Request,
  expectedWebhookSecret: string | null = requiredEnv("DATABASE_WEBHOOK_SECRET"),
): Promise<Response> {
  try {
    return await handleRequest(request, expectedWebhookSecret);
  } catch (error) {
    console.error("Unhandled notify-submission-status error", {
      error: errorForLog(error),
    });

    return jsonResponse({ error: "Internal server error" }, 500);
  }
}

if (import.meta.main) {
  Deno.serve((request) => serveRequest(request));
}
