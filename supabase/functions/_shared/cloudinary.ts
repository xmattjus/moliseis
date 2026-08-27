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

export type CloudinaryClientUploadIntent = {
  contentSha256: string;
  maxWidth: number | null;
  maxHeight: number | null;
  tags: readonly string[];
  context: ReadonlyMap<string, string>;
};

export type CloudinaryDuplicateAsset = {
  secureUrl: string;
  width: number;
  height: number;
  mimeType: string | null;
  durationSeconds: null;
};

export class CloudinaryLookupError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CloudinaryLookupError";
  }
}

/** A Cloudinary Admin API authentication failure must never authorize fallback. */
export class CloudinaryLookupAuthenticationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "CloudinaryLookupAuthenticationError";
  }
}

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

function queryComponentEncode(value: string): string {
  const bytes = new TextEncoder().encode(value);
  let encoded = "";

  for (const byte of bytes) {
    const isAlphaNumeric = (byte >= 0x30 && byte <= 0x39) ||
      (byte >= 0x41 && byte <= 0x5a) ||
      (byte >= 0x61 && byte <= 0x7a);
    const isUnreserved = isAlphaNumeric ||
      byte === 0x2d || byte === 0x2e || byte === 0x5f || byte === 0x7e;
    if (isUnreserved) {
      encoded += String.fromCharCode(byte);
    } else if (byte === 0x20) {
      encoded += "+";
    } else {
      encoded += `%${byte.toString(16).toUpperCase().padStart(2, "0")}`;
    }
  }

  return encoded;
}

function signedFields(params: {
  signableFields: Record<string, string>;
  config: CloudinaryConfig;
}): Promise<Record<string, string>> {
  return cloudinarySignature(params.signableFields, params.config.apiSecret)
    .then(
      (signature) => ({
        api_key: params.config.apiKey,
        ...params.signableFields,
        signature,
      }),
    );
}

export async function prepareCloudinaryUploadFields(params: {
  intent: CloudinaryClientUploadIntent;
  config: CloudinaryConfig;
  uploadPreset: string;
  nowUnixSeconds: number;
}): Promise<Record<string, string>> {
  const publicId = `content_submissions/${params.intent.contentSha256}`;
  const signableFields: Record<string, string> = {
    public_id: publicId,
    timestamp: String(params.nowUnixSeconds),
    overwrite: "false",
    upload_preset: params.uploadPreset,
  };
  const transformationParts: string[] = [];
  if (params.intent.maxWidth !== null) {
    transformationParts.push(`w_${params.intent.maxWidth}`);
  }
  if (params.intent.maxHeight !== null) {
    transformationParts.push(`h_${params.intent.maxHeight}`);
  }
  if (transformationParts.length > 0) {
    transformationParts.push("c_limit");
    signableFields.transformation = transformationParts.join(",");
  }
  if (params.intent.tags.length > 0) {
    signableFields.tags = params.intent.tags.join(",");
  }
  if (params.intent.context.size > 0) {
    signableFields.context = [...params.intent.context.entries()]
      .map(([key, value]) =>
        `${queryComponentEncode(key)}=${queryComponentEncode(value)}`
      )
      .join("|");
  }

  return await signedFields({ signableFields, config: params.config });
}

function mimeTypeForFormat(format: unknown): string | null {
  if (typeof format !== "string") return null;

  switch (format.trim().toLowerCase()) {
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "png":
      return "image/png";
    case "gif":
      return "image/gif";
    case "webp":
      return "image/webp";
    case "avif":
      return "image/avif";
    case "bmp":
      return "image/bmp";
    case "tif":
    case "tiff":
      return "image/tiff";
    case "svg":
      return "image/svg+xml";
    default:
      return null;
  }
}

async function withCloudinaryTimeout<T>(
  operation: (signal: AbortSignal) => Promise<T>,
  timeoutMs = CLOUDINARY_TIMEOUT_MS,
): Promise<T> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await operation(controller.signal);
  } finally {
    clearTimeout(timeout);
  }
}

function isValidDeliveryUrl(url: string, cloudName: string): boolean {
  try {
    const parsed = new URL(url);
    return parsed.protocol === "https:" &&
      parsed.hostname === "res.cloudinary.com" &&
      parsed.pathname.split("/")[1] === cloudName;
  } catch {
    return false;
  }
}

export async function lookupCloudinaryImage(params: {
  publicId: string;
  config: CloudinaryConfig;
  fetchImpl?: FetchLike;
  timeoutMs?: number;
}): Promise<CloudinaryDuplicateAsset | null> {
  const fetchImpl = params.fetchImpl ?? fetch;
  const encodedPublicId = params.publicId.split("/").map(encodeURIComponent)
    .join("/");
  const authorization = `Basic ${
    btoa(`${params.config.apiKey}:${params.config.apiSecret}`)
  }`;
  try {
    return await withCloudinaryTimeout(async (signal) => {
      const response = await fetchImpl(
        `https://api.cloudinary.com/v1_1/${
          encodeURIComponent(params.config.cloudName)
        }/resources/image/upload/${encodedPublicId}`,
        { headers: { Authorization: authorization }, signal },
      );
      if (response.status === 404) {
        await response.body?.cancel();
        return null;
      }
      if (response.status === 401 || response.status === 403) {
        await response.body?.cancel();
        throw new CloudinaryLookupAuthenticationError(
          "Cloudinary duplicate lookup authentication failed",
        );
      }

      let body: unknown = null;
      try {
        body = await response.json();
      } catch {
        // Shape validation below returns a typed operational failure.
      }
      if (!response.ok || !isRecord(body)) {
        throw new CloudinaryLookupError("Cloudinary duplicate lookup failed");
      }

      const secureUrl = body.secure_url;
      const width = body.width;
      const height = body.height;
      if (
        body.public_id !== params.publicId ||
        typeof secureUrl !== "string" ||
        !isValidDeliveryUrl(secureUrl, params.config.cloudName) ||
        typeof width !== "number" || !Number.isSafeInteger(width) ||
        width <= 0 ||
        typeof height !== "number" || !Number.isSafeInteger(height) ||
        height <= 0
      ) {
        throw new CloudinaryLookupError("Cloudinary duplicate lookup failed");
      }

      return {
        secureUrl,
        width,
        height,
        mimeType: mimeTypeForFormat(body.format),
        durationSeconds: null,
      };
    }, params.timeoutMs);
  } catch (error) {
    if (error instanceof CloudinaryLookupAuthenticationError) throw error;
    throw new CloudinaryLookupError("Cloudinary duplicate lookup failed");
  }
}

export async function uploadRemoteImage(params: {
  sourceUrl: string;
  config: CloudinaryConfig;
  fetchImpl?: FetchLike;
  timeoutMs?: number;
}): Promise<CloudinaryUploadResult> {
  const fetchImpl = params.fetchImpl ?? fetch;
  const timestamp = Math.floor(Date.now() / 1000);
  const fields = await signedFields({
    signableFields: { timestamp: String(timestamp) },
    config: params.config,
  });

  const form = new FormData();
  form.set("file", params.sourceUrl);
  for (const [key, value] of Object.entries(fields)) {
    form.set(key, value);
  }

  return await withCloudinaryTimeout(async (signal) => {
    const response = await fetchImpl(
      `https://api.cloudinary.com/v1_1/${
        encodeURIComponent(params.config.cloudName)
      }/image/upload`,
      { method: "POST", body: form, signal },
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
  }, params.timeoutMs);
}

export async function destroyCloudinaryImage(params: {
  publicId: string;
  config: CloudinaryConfig;
  fetchImpl?: FetchLike;
}): Promise<void> {
  const fetchImpl = params.fetchImpl ?? fetch;
  const timestamp = Math.floor(Date.now() / 1000);
  const fields = await signedFields({
    signableFields: {
      public_id: params.publicId,
      timestamp: String(timestamp),
    },
    config: params.config,
  });

  const form = new FormData();
  for (const [key, value] of Object.entries(fields)) {
    form.set(key, value);
  }

  await withCloudinaryTimeout(async (signal) => {
    const response = await fetchImpl(
      `https://api.cloudinary.com/v1_1/${
        encodeURIComponent(params.config.cloudName)
      }/image/destroy`,
      { method: "POST", body: form, signal },
    );
    if (!response.ok) {
      throw new Error(`Cloudinary destroy failed with HTTP ${response.status}`);
    }
    await response.body?.cancel();
  });
}
