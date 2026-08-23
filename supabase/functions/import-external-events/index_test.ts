import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.112.3";

import type {
  CloudinaryConfig,
  CloudinaryUploadResult,
} from "../_shared/cloudinary.ts";
import type { Database } from "../_shared/database.types.ts";
import { uploadAndPersistImportedAsset } from "./index.ts";

const cloudinaryConfig: CloudinaryConfig = {
  cloudName: "test-cloud",
  apiKey: "test-key",
  apiSecret: "test-secret",
};

const uploadedAsset: CloudinaryUploadResult = {
  url: "https://res.cloudinary.com/test-cloud/image/upload/v1/imported.png",
  width: 1200,
  height: 800,
  mimeType: "image/png",
  publicId: "import-external-events/imported",
};

type RpcResponse = {
  data: Array<{ outcome: string }> | null;
  error: { message: string } | null;
};

class FakeImporterAdminClient {
  constructor(readonly rpcResponse: RpcResponse) {}

  readonly rpcCalls: Array<{ functionName: string; args: unknown }> = [];

  rpc(functionName: string, args: unknown): Promise<RpcResponse> {
    this.rpcCalls.push({ functionName, args });
    return Promise.resolve(this.rpcResponse);
  }
}

function testDependencies(
  destroyedPublicIds: string[],
): NonNullable<Parameters<typeof uploadAndPersistImportedAsset>[2]> {
  return {
    uploadRemoteImage: ({ sourceUrl, config }) => {
      assertEquals(sourceUrl, "https://eventimolise.it/import-test.png");
      assertEquals(config, cloudinaryConfig);
      return Promise.resolve(uploadedAsset);
    },
    destroyCloudinaryImage: ({ publicId, config }) => {
      assertEquals(config, cloudinaryConfig);
      destroyedPublicIds.push(publicId);
      return Promise.resolve();
    },
  };
}

function persistImportedAsset(
  rpcResponse: RpcResponse,
): {
  admin: FakeImporterAdminClient;
  destroyedPublicIds: string[];
  persist: () => Promise<void>;
} {
  const admin = new FakeImporterAdminClient(rpcResponse);
  const destroyedPublicIds: string[] = [];

  return {
    admin,
    destroyedPublicIds,
    persist: () =>
      uploadAndPersistImportedAsset(
        admin as unknown as SupabaseClient<Database>,
        {
          submissionId: 17,
          sourceUrl: "https://eventimolise.it/import-test.png",
          cloudinary: cloudinaryConfig,
        },
        testDependencies(destroyedPublicIds),
      ),
  };
}

Deno.test("persists imported assets through add_submission_assets", async () => {
  const { admin, destroyedPublicIds, persist } = persistImportedAsset({
    data: [{ outcome: "created" }],
    error: null,
  });

  await persist();

  assertEquals(admin.rpcCalls, [{
    functionName: "add_submission_assets",
    args: {
      p_submission_id: 17,
      p_assets: [{
        url: uploadedAsset.url,
        width: uploadedAsset.width,
        height: uploadedAsset.height,
        mime_type: uploadedAsset.mimeType,
        duration_seconds: null,
      }],
    },
  }]);
  assertEquals(destroyedPublicIds, []);
});

Deno.test("cleans up a Cloudinary upload when add_submission_assets rejects it", async () => {
  const { destroyedPublicIds, persist } = persistImportedAsset({
    data: [{ outcome: "limit_reached" }],
    error: null,
  });

  await assertRejects(persist, Error, "limit_reached");

  assertEquals(destroyedPublicIds, [uploadedAsset.publicId]);
});

Deno.test("cleans up a Cloudinary upload when add_submission_assets returns an RPC error", async () => {
  const { destroyedPublicIds, persist } = persistImportedAsset({
    data: null,
    error: { message: "database unavailable" },
  });

  await assertRejects(persist, Error, "database unavailable");

  assertEquals(destroyedPublicIds, [uploadedAsset.publicId]);
});
