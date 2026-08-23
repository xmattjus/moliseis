import { assertEquals } from "jsr:@std/assert@1";
import { cloudinarySignature, uploadRemoteImage } from "./cloudinary.ts";

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
    config: {
      cloudName: "test-cloud",
      apiKey: "test-key",
      apiSecret: "test-secret",
    },
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
