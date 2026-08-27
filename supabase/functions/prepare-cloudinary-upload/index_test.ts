import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import type { User } from "npm:@supabase/supabase-js@2.112.3";

import type {
  CloudinaryClientUploadIntent,
  CloudinaryConfig,
  CloudinaryDuplicateAsset,
} from "../_shared/cloudinary.ts";
import {
  CloudinaryLookupError,
  lookupCloudinaryImage,
  prepareCloudinaryUploadFields,
} from "../_shared/cloudinary.ts";
import {
  createHandler,
  type HandlerDependencies,
  resolvePublishableKey,
} from "./index.ts";

const digest = "a".repeat(64);
const publicId = `content_submissions/${digest}`;
const config: CloudinaryConfig & { uploadPreset: string } = {
  cloudName: "test-cloud",
  apiKey: "test-key",
  apiSecret: "test-secret",
  uploadPreset: "content_submission_signed",
};

function user(isAnonymous = false): User {
  return {
    id: "user-id",
    aud: "authenticated",
    role: "authenticated",
    is_anonymous: isAnonymous,
  } as User;
}

function request(
  body: unknown,
  options: { method?: string; authorization?: string; contentLength?: string } =
    {},
): Request {
  return new Request(
    "https://project.functions.supabase.co/prepare-cloudinary-upload",
    {
      method: options.method ?? "POST",
      headers: {
        "Content-Type": "application/json",
        ...(options.authorization
          ? { Authorization: options.authorization }
          : {}),
        ...(options.contentLength
          ? { "Content-Length": options.contentLength }
          : {}),
      },
      body: (options.method ?? "POST") === "POST"
        ? JSON.stringify(body)
        : undefined,
    },
  );
}

function validFields(): Record<string, string> {
  return {
    api_key: "test-key",
    public_id: publicId,
    timestamp: "1715060510",
    overwrite: "false",
    upload_preset: "content_submission_signed",
    signature: "signature",
  };
}

function createHarness(overrides: Partial<HandlerDependencies> = {}) {
  const calls = {
    authenticate: 0,
    lookup: 0,
    prepare: 0,
    warnings: [] as string[],
  };
  const dependencies: HandlerDependencies = {
    authenticate: async () => {
      calls.authenticate += 1;
      return user();
    },
    loadCloudinaryConfig: () => config,
    lookup: async () => {
      calls.lookup += 1;
      return null;
    },
    prepareFields: async () => {
      calls.prepare += 1;
      return validFields();
    },
    nowUnixSeconds: () => 1_715_060_510,
    warn: (message) => calls.warnings.push(message),
    ...overrides,
  };
  return { calls, handler: createHandler(dependencies) };
}

async function responseJson(response: Response): Promise<unknown> {
  return await response.json();
}

function assertContractHeaders(
  response: Response,
  extraHeaders: Record<string, string> = {},
): void {
  assertEquals(Object.fromEntries(response.headers.entries()), {
    "access-control-allow-headers":
      "authorization, x-client-info, apikey, content-type, x-retry-count, traceparent, tracestate, baggage",
    "access-control-allow-methods": "POST, OPTIONS",
    "access-control-allow-origin": "*",
    "cache-control": "no-store",
    "content-type": "application/json; charset=utf-8",
    ...extraHeaders,
  });
}

Deno.test("OPTIONS and unsupported methods avoid authentication and Cloudinary work", async () => {
  const { calls, handler } = createHarness();
  const optionsResponse = await handler(request({}, { method: "OPTIONS" }));
  const methodResponse = await handler(request({}, { method: "GET" }));

  assertEquals(optionsResponse.status, 200);
  assertContractHeaders(optionsResponse);
  assertEquals(methodResponse.status, 405);
  assertContractHeaders(methodResponse, { allow: "POST, OPTIONS" });
  assertEquals(await responseJson(methodResponse), {
    code: "METHOD_NOT_ALLOWED",
    message: "Only POST requests are allowed.",
  });
  assertEquals(calls, { authenticate: 0, lookup: 0, prepare: 0, warnings: [] });
});

Deno.test("rejects missing authentication before parsing or privileged work", async () => {
  const { calls, handler } = createHarness();
  const response = await handler(request({ content_sha256: digest }));

  assertEquals(response.status, 401);
  assertContractHeaders(response);
  assertEquals(await responseJson(response), {
    code: "UNAUTHORIZED",
    message: "Authentication is required.",
  });
  assertEquals(calls, { authenticate: 0, lookup: 0, prepare: 0, warnings: [] });
});

Deno.test("rejects an invalid bearer token before parsing or privileged work", async () => {
  let authenticationCalls = 0;
  const { calls, handler } = createHarness({
    authenticate: async () => {
      authenticationCalls += 1;
      return null;
    },
  });
  const response = await handler(request({ content_sha256: digest }, {
    authorization: "Bearer invalid-token",
  }));

  assertEquals(response.status, 401);
  assertContractHeaders(response);
  assertEquals(authenticationCalls, 1);
  assertEquals(calls.lookup, 0);
  assertEquals(calls.prepare, 0);
});

Deno.test("contains authentication transport failures", async () => {
  const { calls, handler } = createHarness({
    authenticate: async () => {
      throw new Error("auth unavailable");
    },
  });
  const response = await handler(request({ content_sha256: digest }, {
    authorization: "Bearer token",
  }));

  assertEquals(response.status, 401);
  assertContractHeaders(response);
  assertEquals(calls.lookup, 0);
  assertEquals(calls.prepare, 0);
});

Deno.test("allows anonymous and permanent users to receive exact authorized fields", async () => {
  for (const isAnonymous of [false, true]) {
    const captured: CloudinaryClientUploadIntent[] = [];
    const { handler } = createHarness({
      authenticate: async () => user(isAnonymous),
      prepareFields: async ({ intent }) => {
        captured.push(intent);
        return validFields();
      },
    });
    const response = await handler(request({
      content_sha256: digest,
      max_width: null,
      tags: ["content"],
      context: { caption: "hello world" },
      overwrite: false,
    }, { authorization: "Bearer token" }));

    assertEquals(response.status, 200);
    assertContractHeaders(response);
    assertEquals(await responseJson(response), {
      outcome: "authorized",
      fields: validFields(),
    });
    assertEquals(captured[0], {
      contentSha256: digest,
      maxWidth: null,
      maxHeight: 2048,
      tags: ["content"],
      context: new Map([["caption", "hello world"]]),
    });
  }
});

Deno.test("returns duplicate asset without preparing signed fields", async () => {
  const duplicate: CloudinaryDuplicateAsset = {
    secureUrl: "https://res.cloudinary.com/test-cloud/image/upload/v1/test.png",
    width: 100,
    height: 200,
    mimeType: "image/png",
    durationSeconds: null,
  };
  const { calls, handler } = createHarness({ lookup: async () => duplicate });
  const response = await handler(request({ content_sha256: digest }, {
    authorization: "Bearer token",
  }));

  assertEquals(response.status, 200);
  assertContractHeaders(response);
  assertEquals(await responseJson(response), {
    outcome: "duplicate",
    asset: {
      secure_url: duplicate.secureUrl,
      width: 100,
      height: 200,
      mime_type: "image/png",
      duration_seconds: null,
    },
  });
  assertEquals(calls.prepare, 0);
});

Deno.test("falls back only for an operational duplicate lookup failure", async () => {
  const { calls, handler } = createHarness({
    lookup: async () => {
      throw new CloudinaryLookupError("lookup failed");
    },
  });
  const response = await handler(request({ content_sha256: digest }, {
    authorization: "Bearer token",
  }));

  assertEquals(response.status, 200);
  assertContractHeaders(response);
  assertEquals(calls.prepare, 1);
  assertEquals(calls.warnings, ["cloudinary_duplicate_lookup_failed"]);
});

Deno.test("rejects invalid, oversized, and privileged request inputs before Cloudinary work", async () => {
  const invalidBodies = [
    { content_sha256: digest.toUpperCase() },
    { content_sha256: digest, overwrite: true },
    { content_sha256: digest, public_id: publicId },
    { content_sha256: digest, sourceUrl: "https://example.test/image" },
    { content_sha256: digest, file: "not-a-file" },
    { content_sha256: digest, signature: "attacker" },
    { content_sha256: digest, upload_preset: "attacker" },
    { content_sha256: digest, transformation: "w_1" },
    { content_sha256: digest, max_width: 8193 },
    { content_sha256: digest, tags: ["contains,comma"] },
    { content_sha256: digest, context: { key: "bad\nvalue" } },
  ];
  for (const body of invalidBodies) {
    const { calls, handler } = createHarness();
    const response = await handler(
      request(body, { authorization: "Bearer token" }),
    );
    assertEquals(response.status, 400);
    assertContractHeaders(response);
    assertEquals(await responseJson(response), {
      code: "VALIDATION_ERROR",
      message: "Request body is invalid.",
    });
    assertEquals(calls.lookup, 0);
    assertEquals(calls.prepare, 0);
  }

  const { calls, handler } = createHarness();
  const response = await handler(request({ content_sha256: digest }, {
    authorization: "Bearer token",
    contentLength: "16385",
  }));
  assertEquals(response.status, 413);
  assertContractHeaders(response);
  assertEquals(calls.lookup, 0);
  assertEquals(calls.prepare, 0);
});

Deno.test("configuration and non-lookup preparation failures are fail-closed", async () => {
  const configurationHarness = createHarness({
    loadCloudinaryConfig: () => {
      throw new Error("missing secret");
    },
  });
  const configurationResponse = await configurationHarness.handler(request({
    content_sha256: digest,
  }, { authorization: "Bearer token" }));
  assertEquals(configurationResponse.status, 500);
  assertContractHeaders(configurationResponse);
  assertEquals(await responseJson(configurationResponse), {
    code: "CLOUDINARY_CONFIGURATION_ERROR",
    message: "Upload configuration is unavailable.",
  });
  assertEquals(configurationHarness.calls.lookup, 0);

  const preparationHarness = createHarness({
    lookup: async () => {
      throw new Error("configuration failure");
    },
  });
  const preparationResponse = await preparationHarness.handler(request({
    content_sha256: digest,
  }, { authorization: "Bearer token" }));
  assertEquals(preparationResponse.status, 502);
  assertContractHeaders(preparationResponse);
  assertEquals(preparationHarness.calls.prepare, 0);

  const malformedFieldsHarness = createHarness({
    prepareFields: async () => ({
      ...validFields(),
      api_secret: "must-not-leak",
    }),
  });
  const malformedFieldsResponse = await malformedFieldsHarness.handler(request({
    content_sha256: digest,
  }, { authorization: "Bearer token" }));
  assertEquals(malformedFieldsResponse.status, 502);
  assertContractHeaders(malformedFieldsResponse);
  assertEquals(await responseJson(malformedFieldsResponse), {
    code: "CLOUDINARY_PREPARATION_ERROR",
    message: "Upload preparation failed.",
  });
});

Deno.test("rejects malformed prepared field sets including configuration mismatches", async () => {
  const malformedFields = [
    { ...validFields(), api_key: "different-key" },
    { ...validFields(), upload_preset: "different-preset" },
    { ...validFields(), timestamp: "" },
    { ...validFields(), timestamp: "01" },
    { ...validFields(), signature: "" },
    { ...validFields(), unexpected: "value" },
  ];
  for (const fields of malformedFields) {
    const { handler } = createHarness({ prepareFields: async () => fields });
    const response = await handler(request({ content_sha256: digest }, {
      authorization: "Bearer token",
    }));
    assertEquals(response.status, 502);
    assertContractHeaders(response);
    assertEquals(await responseJson(response), {
      code: "CLOUDINARY_PREPARATION_ERROR",
      message: "Upload preparation failed.",
    });
  }
});

Deno.test("fixed-clock real field builder signs preset and overwrite protection", async () => {
  const { handler } = createHarness({
    prepareFields: prepareCloudinaryUploadFields,
  });
  const response = await handler(request({ content_sha256: digest }, {
    authorization: "Bearer token",
  }));

  assertEquals(response.status, 200);
  assertContractHeaders(response);
  assertEquals(await responseJson(response), {
    outcome: "authorized",
    fields: await prepareCloudinaryUploadFields({
      intent: {
        contentSha256: digest,
        maxWidth: 2048,
        maxHeight: 2048,
        tags: [],
        context: new Map(),
      },
      config,
      uploadPreset: config.uploadPreset,
      nowUnixSeconds: 1_715_060_510,
    }),
  });
});

Deno.test("enforces digest, option, body, and response-header bounds", async () => {
  const validBodies = [
    { content_sha256: digest },
    {
      content_sha256: digest,
      max_width: null,
      max_height: 1,
      tags: Array.from({ length: 20 }, (_, index) => `tag-${index}`),
      context: Object.fromEntries(
        Array.from({ length: 20 }, (_, index) => [`key-${index}`, "value"]),
      ),
      overwrite: false,
    },
    {
      content_sha256: digest,
      max_width: 8192,
      max_height: null,
      tags: ["a".repeat(128)],
      context: { ["k".repeat(64)]: "v".repeat(1024) },
    },
  ];
  for (const body of validBodies) {
    const { handler } = createHarness();
    const response = await handler(
      request(body, { authorization: "Bearer token" }),
    );
    assertEquals(response.status, 200);
    assertContractHeaders(response);
  }

  const invalidBodies = [
    { content_sha256: "" },
    { content_sha256: "a".repeat(63) },
    { content_sha256: "a".repeat(65) },
    { content_sha256: digest.toUpperCase() },
    { content_sha256: digest, max_width: 0 },
    { content_sha256: digest, max_height: 8193 },
    { content_sha256: digest, max_width: 1.5 },
    { content_sha256: digest, max_height: "1" },
    { content_sha256: digest, tags: Array.from({ length: 21 }, () => "tag") },
    { content_sha256: digest, tags: ["a".repeat(129)] },
    {
      content_sha256: digest,
      context: Object.fromEntries(
        Array.from({ length: 21 }, (_, index) => [`key-${index}`, "value"]),
      ),
    },
    { content_sha256: digest, context: { ["k".repeat(65)]: "value" } },
    { content_sha256: digest, context: { key: "v".repeat(1025) } },
  ];
  for (const body of invalidBodies) {
    const { calls, handler } = createHarness();
    const response = await handler(
      request(body, { authorization: "Bearer token" }),
    );
    assertEquals(response.status, 400);
    assertContractHeaders(response);
    assertEquals(await responseJson(response), {
      code: "VALIDATION_ERROR",
      message: "Request body is invalid.",
    });
    assertEquals(calls.lookup, 0);
    assertEquals(calls.prepare, 0);
  }

  for (const rawBody of ["", "{"]) {
    const { calls, handler } = createHarness();
    const response = await handler(
      new Request(
        "https://project.functions.supabase.co/prepare-cloudinary-upload",
        {
          method: "POST",
          headers: {
            Authorization: "Bearer token",
            "Content-Type": "application/json",
          },
          body: rawBody,
        },
      ),
    );
    assertEquals(response.status, 400);
    assertContractHeaders(response);
    assertEquals(calls.lookup, 0);
    assertEquals(calls.prepare, 0);
  }

  const { calls, handler } = createHarness();
  const oversizedResponse = await handler(
    new Request(
      "https://project.functions.supabase.co/prepare-cloudinary-upload",
      {
        method: "POST",
        headers: {
          Authorization: "Bearer token",
          "Content-Type": "application/json",
        },
        body: new ReadableStream({
          start(controller) {
            controller.enqueue(new Uint8Array(16 * 1024 + 1));
            controller.close();
          },
        }),
      },
    ),
  );
  assertEquals(oversizedResponse.status, 413);
  assertContractHeaders(oversizedResponse);
  assertEquals(await responseJson(oversizedResponse), {
    code: "REQUEST_TOO_LARGE",
    message: "Request body is too large.",
  });
  assertEquals(calls.lookup, 0);
  assertEquals(calls.prepare, 0);
});

Deno.test("actual Cloudinary lookup authentication failures fail closed", async () => {
  for (const status of [401, 403]) {
    const { calls, handler } = createHarness({
      lookup: (params) =>
        lookupCloudinaryImage({
          ...params,
          fetchImpl: () => Promise.resolve(new Response(null, { status })),
        }),
    });
    const response = await handler(request({ content_sha256: digest }, {
      authorization: "Bearer token",
    }));

    assertEquals(response.status, 502);
    assertContractHeaders(response);
    assertEquals(await responseJson(response), {
      code: "CLOUDINARY_PREPARATION_ERROR",
      message: "Upload preparation failed.",
    });
    assertEquals(calls.prepare, 0);
    assertEquals(calls.warnings, []);
  }
});

Deno.test("resolves named and legacy publishable-key configuration safely", () => {
  const named = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  const legacy = Deno.env.get("SUPABASE_ANON_KEY");
  try {
    Deno.env.set("SUPABASE_PUBLISHABLE_KEYS", '{"default":" named-key "}');
    Deno.env.set("SUPABASE_ANON_KEY", "legacy-key");
    assertEquals(resolvePublishableKey(), "named-key");

    Deno.env.delete("SUPABASE_PUBLISHABLE_KEYS");
    assertEquals(resolvePublishableKey(), "legacy-key");

    Deno.env.set("SUPABASE_PUBLISHABLE_KEYS", '{"default":""}');
    assertThrows(resolvePublishableKey);
    Deno.env.set("SUPABASE_PUBLISHABLE_KEYS", "not-json");
    assertThrows(resolvePublishableKey);
  } finally {
    if (named == null) {
      Deno.env.delete("SUPABASE_PUBLISHABLE_KEYS");
    } else {
      Deno.env.set("SUPABASE_PUBLISHABLE_KEYS", named);
    }
    if (legacy == null) {
      Deno.env.delete("SUPABASE_ANON_KEY");
    } else {
      Deno.env.set("SUPABASE_ANON_KEY", legacy);
    }
  }
});
