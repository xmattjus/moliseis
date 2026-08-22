export type CloudinaryConfig = {
  cloudName: string;
  apiKey: string;
  apiSecret: string;
};

export type CloudinaryUploadResult = {
  url: string;
  width: number;
  height: number;
  mimeType: string | null;
  publicId: string;
};

export type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

const CLOUDINARY_TIMEOUT_MS = 20_000;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function sha1Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-1",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function cloudinarySignature(
  params: Record<string, string | number>,
  apiSecret: string,
): Promise<string> {
  const canonical = Object.entries(params)
    .filter(([, value]) => value !== "")
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${key}=${value}`)
    .join("&");

  return await sha1Hex(`${canonical}${apiSecret}`);
}

function mimeTypeForFormat(format: unknown): string | null {
  if (typeof format !== "string" || !format) return null;
  const normalized = format.toLowerCase();
  if (normalized === "jpg" || normalized === "jpeg") return "image/jpeg";
  if (normalized === "svg") return "image/svg+xml";
  if (["png", "gif", "webp", "avif", "bmp", "tiff"].includes(normalized)) {
    return `image/${normalized}`;
  }
  return null;
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  fetchImpl: FetchLike,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), CLOUDINARY_TIMEOUT_MS);

  try {
    return await fetchImpl(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

export async function uploadRemoteImage(params: {
  sourceUrl: string;
  config: CloudinaryConfig;
  fetchImpl?: FetchLike;
}): Promise<CloudinaryUploadResult> {
  const fetchImpl = params.fetchImpl ?? fetch;
  const timestamp = Math.floor(Date.now() / 1000);
  const signedParams = { timestamp };
  const signature = await cloudinarySignature(
    signedParams,
    params.config.apiSecret,
  );

  const form = new FormData();
  form.set("file", params.sourceUrl);
  form.set("api_key", params.config.apiKey);
  form.set("timestamp", String(timestamp));
  form.set("signature", signature);

  const response = await fetchWithTimeout(
    `https://api.cloudinary.com/v1_1/${encodeURIComponent(params.config.cloudName)}/image/upload`,
    { method: "POST", body: form },
    fetchImpl,
  );

  let body: unknown = null;
  try {
    body = await response.json();
  } catch {
    // Handled by the shape validation below.
  }

  if (!response.ok || !isRecord(body)) {
    throw new Error(`Cloudinary upload failed with HTTP ${response.status}`);
  }

  const url = body.secure_url;
  const width = body.width;
  const height = body.height;
  const publicId = body.public_id;

  if (
    typeof url !== "string" ||
    !url.startsWith("https://res.cloudinary.com/") ||
    typeof width !== "number" ||
    !Number.isInteger(width) ||
    width <= 0 ||
    typeof height !== "number" ||
    !Number.isInteger(height) ||
    height <= 0 ||
    typeof publicId !== "string" ||
    !publicId
  ) {
    throw new Error("Cloudinary upload response has an unexpected shape");
  }

  return {
    url,
    width,
    height,
    mimeType: mimeTypeForFormat(body.format),
    publicId,
  };
}

export async function destroyCloudinaryImage(params: {
  publicId: string;
  config: CloudinaryConfig;
  fetchImpl?: FetchLike;
}): Promise<void> {
  const fetchImpl = params.fetchImpl ?? fetch;
  const timestamp = Math.floor(Date.now() / 1000);
  const signedParams = {
    public_id: params.publicId,
    timestamp,
  };
  const signature = await cloudinarySignature(
    signedParams,
    params.config.apiSecret,
  );

  const form = new FormData();
  form.set("public_id", params.publicId);
  form.set("api_key", params.config.apiKey);
  form.set("timestamp", String(timestamp));
  form.set("signature", signature);

  const response = await fetchWithTimeout(
    `https://api.cloudinary.com/v1_1/${encodeURIComponent(params.config.cloudName)}/image/destroy`,
    { method: "POST", body: form },
    fetchImpl,
  );

  if (!response.ok) {
    throw new Error(`Cloudinary destroy failed with HTTP ${response.status}`);
  }
}
