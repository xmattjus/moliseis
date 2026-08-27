import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  CloudinaryLookupAuthenticationError,
  CloudinaryLookupError,
  cloudinarySignature,
  lookupCloudinaryImage,
  prepareCloudinaryUploadFields,
  uploadRemoteImage,
} from "./cloudinary.ts";

const config = {
  cloudName: "test-cloud",
  apiKey: "test-key",
  apiSecret: "test-secret",
};

Deno.test("Cloudinary signature sorts signed parameters before hashing", async () => {
  assertEquals(
    await cloudinarySignature(
      { timestamp: 1315060510 },
      "abcd",
    ),
    "a21ad0f63beb4de2e5575204b79ab90bffb02c10",
  );
});

async function uploadMimeType(format: unknown): Promise<string | null> {
  const result = await uploadRemoteImage({
    sourceUrl: "https://example.test/source-image",
    config,
    fetchImpl: () =>
      Promise.resolve(
        new Response(JSON.stringify({
          secure_url:
            "https://res.cloudinary.com/test-cloud/image/upload/image",
          width: 10,
          height: 20,
          public_id: "test-image",
          format,
        })),
      ),
  });
  return result.mimeType;
}

Deno.test("Cloudinary upload maps only known image formats to explicit MIME types", async () => {
  assertEquals(await uploadMimeType("jpg"), "image/jpeg");
  assertEquals(await uploadMimeType(" JPEG "), "image/jpeg");
  assertEquals(await uploadMimeType("png"), "image/png");
  assertEquals(await uploadMimeType("svg"), "image/svg+xml");
  assertEquals(await uploadMimeType("tif"), "image/tiff");
});

Deno.test("Cloudinary upload leaves missing and unknown MIME types null", async () => {
  assertEquals(await uploadMimeType(null), null);
  assertEquals(await uploadMimeType("unrecognized-image-format"), null);
});

Deno.test("trusted importer upload forwards exactly the signed multipart fields", async () => {
  await uploadRemoteImage({
    sourceUrl: "https://example.test/source-image?size=small",
    config,
    fetchImpl: async (_input, init) => {
      const form = init?.body as FormData;
      const fields = Object.fromEntries(form.entries());
      assertEquals(fields.file, "https://example.test/source-image?size=small");
      assertEquals(fields.api_key, config.apiKey);
      assertEquals(typeof fields.timestamp, "string");
      assertEquals(
        fields.signature,
        await cloudinarySignature(
          { timestamp: fields.timestamp as string },
          config.apiSecret,
        ),
      );
      return Promise.resolve(
        new Response(JSON.stringify({
          secure_url:
            "https://res.cloudinary.com/test-cloud/image/upload/image",
          width: 10,
          height: 20,
          public_id: "test-image",
        })),
      );
    },
  });
});

Deno.test("prepares bounded client upload fields with explicit overwrite protection", async () => {
  const fields = await prepareCloudinaryUploadFields({
    intent: {
      contentSha256: "a".repeat(64),
      maxWidth: 1200,
      maxHeight: 800,
      tags: ["content-submission", "photo"],
      context: new Map([
        ["space key", "a b"],
        ["special", "&=|%~"],
        ["unicode", "è"],
        ["empty", ""],
      ]),
    },
    config,
    uploadPreset: "content_submission_signed",
    nowUnixSeconds: 1_715_060_510,
  });

  assertEquals(fields, {
    api_key: "test-key",
    public_id: `content_submissions/${"a".repeat(64)}`,
    timestamp: "1715060510",
    overwrite: "false",
    upload_preset: "content_submission_signed",
    transformation: "w_1200,h_800,c_limit",
    tags: "content-submission,photo",
    context: "space+key=a+b|special=%26%3D%7C%25~|unicode=%C3%A8|empty=",
    signature: await cloudinarySignature({
      public_id: `content_submissions/${"a".repeat(64)}`,
      timestamp: "1715060510",
      overwrite: "false",
      upload_preset: "content_submission_signed",
      transformation: "w_1200,h_800,c_limit",
      tags: "content-submission,photo",
      context: "space+key=a+b|special=%26%3D%7C%25~|unicode=%C3%A8|empty=",
    }, "test-secret"),
  });
});

Deno.test("omits transformation only when both client dimensions are absent", async () => {
  const fields = await prepareCloudinaryUploadFields({
    intent: {
      contentSha256: "b".repeat(64),
      maxWidth: null,
      maxHeight: null,
      tags: [],
      context: new Map(),
    },
    config,
    uploadPreset: "content_submission_signed",
    nowUnixSeconds: 1,
  });

  assertEquals("transformation" in fields, false);
  assertEquals(fields.overwrite, "false");
});

Deno.test("looks up a valid duplicate with server-only Basic authentication", async () => {
  let authorization: string | null = null;
  const result = await lookupCloudinaryImage({
    publicId: "content_submissions/abc",
    config,
    fetchImpl: (input, init) => {
      assertEquals(
        String(input),
        "https://api.cloudinary.com/v1_1/test-cloud/resources/image/upload/content_submissions/abc",
      );
      authorization = new Headers(init?.headers).get("Authorization");
      return Promise.resolve(
        new Response(JSON.stringify({
          public_id: "content_submissions/abc",
          secure_url:
            "https://res.cloudinary.com/test-cloud/image/upload/v1/abc.png",
          width: 1200,
          height: 800,
          format: "png",
        })),
      );
    },
  });

  assertEquals(result, {
    secureUrl: "https://res.cloudinary.com/test-cloud/image/upload/v1/abc.png",
    width: 1200,
    height: 800,
    mimeType: "image/png",
    durationSeconds: null,
  });
  assertEquals(authorization, "Basic dGVzdC1rZXk6dGVzdC1zZWNyZXQ=");
});

Deno.test("maps a missing Cloudinary duplicate to null", async () => {
  const result = await lookupCloudinaryImage({
    publicId: "content_submissions/abc",
    config,
    fetchImpl: () => Promise.resolve(new Response(null, { status: 404 })),
  });

  assertEquals(result, null);
});

Deno.test("classifies Cloudinary lookup authentication failures as non-fallbackable", async () => {
  for (const status of [401, 403]) {
    await assertRejects(
      () =>
        lookupCloudinaryImage({
          publicId: "content_submissions/abc",
          config,
          fetchImpl: () => Promise.resolve(new Response(null, { status })),
        }),
      CloudinaryLookupAuthenticationError,
    );
  }
});

Deno.test("rejects malformed and operational duplicate lookup responses", async () => {
  const malformedLookup = (body: unknown) =>
    lookupCloudinaryImage({
      publicId: "content_submissions/abc",
      config,
      fetchImpl: () =>
        Promise.resolve(
          new Response(JSON.stringify(body)),
        ),
    });
  const failedLookup = () =>
    lookupCloudinaryImage({
      publicId: "content_submissions/abc",
      config,
      fetchImpl: () =>
        Promise.resolve(
          new Response("upstream failure", {
            status: 500,
          }),
        ),
    });

  await assertRejects(
    () =>
      malformedLookup({
        public_id: "different",
        secure_url: "https://res.cloudinary.com/test-cloud/image/upload/v1/a",
        width: 1,
        height: 1,
      }),
    CloudinaryLookupError,
  );
  await assertRejects(
    () =>
      malformedLookup({
        public_id: "content_submissions/abc",
        secure_url: "https://example.test/not-cloudinary.png",
        width: 1,
        height: 1,
      }),
    CloudinaryLookupError,
  );
  await assertRejects(
    () =>
      malformedLookup({
        public_id: "content_submissions/abc",
        secure_url: "https://res.cloudinary.com/wrong-cloud/image/upload/v1/a",
        width: 1,
        height: 1,
      }),
    CloudinaryLookupError,
  );
  await assertRejects(
    () =>
      malformedLookup({
        public_id: "content_submissions/abc",
        secure_url: "https://res.cloudinary.com/test-cloud/image/upload/v1/a",
        width: Number.MAX_SAFE_INTEGER + 1,
        height: 1,
      }),
    CloudinaryLookupError,
  );
  await assertRejects(failedLookup, CloudinaryLookupError);
  await assertRejects(
    () =>
      lookupCloudinaryImage({
        publicId: "content_submissions/abc",
        config,
        fetchImpl: () => Promise.reject(new Error("network unavailable")),
      }),
    CloudinaryLookupError,
  );
});

Deno.test("lookup timeout during response body consumption is fallbackable", async () => {
  await assertRejects(
    () =>
      lookupCloudinaryImage({
        publicId: "content_submissions/abc",
        config,
        timeoutMs: 1,
        fetchImpl: (_input, init) => {
          const signal = init?.signal;
          return Promise.resolve(
            new Response(
              new ReadableStream({
                start(controller) {
                  signal?.addEventListener(
                    "abort",
                    () => controller.error(signal.reason),
                    { once: true },
                  );
                },
              }),
            ),
          );
        },
      }),
    CloudinaryLookupError,
  );
});

Deno.test("remote upload timeout includes response body consumption", async () => {
  await assertRejects(() =>
    uploadRemoteImage({
      sourceUrl: "https://example.test/source-image",
      config,
      timeoutMs: 1,
      fetchImpl: (_input, init) => {
        const signal = init?.signal;
        return Promise.resolve(
          new Response(
            new ReadableStream({
              start(controller) {
                signal?.addEventListener(
                  "abort",
                  () => controller.error(signal.reason),
                  { once: true },
                );
              },
            }),
          ),
        );
      },
    })
  );
});
