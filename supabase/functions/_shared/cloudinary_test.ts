import { assertEquals } from "jsr:@std/assert@1";
import { cloudinarySignature } from "./cloudinary.ts";

Deno.test("Cloudinary signature sorts signed parameters before hashing", async () => {
  assertEquals(
    await cloudinarySignature(
      { timestamp: 1315060510 },
      "abcd",
    ),
    "a21ad0f63beb4de2e5575204b79ab90bffb02c10",
  );
});
