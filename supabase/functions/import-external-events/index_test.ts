import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.112.3";

import type {
  CloudinaryConfig,
  CloudinaryUploadResult,
} from "../_shared/cloudinary.ts";
import type { Database } from "../_shared/database.types.ts";
import {
  insertImportedSubmission,
  uploadAndPersistImportedAsset,
} from "./index.ts";
import {
  romeEndOfCalendarDay,
  validateSubmissionDates,
} from "../_shared/submission_dates.ts";
import {
  type PreparedExternalEvent,
  zonedDateTimeToIso,
} from "./import_logic.ts";

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

// Fixture adapters interpret source precision; PreparedExternalEvent keeps the
// repository's existing normalized UTC shape rather than adding transport fields.
type SourceFixture = {
  startDay: string;
  startClock?: string;
  finalDay?: string;
};

function prepareFixtureSource(source: SourceFixture): PreparedExternalEvent {
  const allDay = source.startClock === undefined;
  const civil = validateSubmissionDates(
    null,
    null,
    true,
    source.startDay,
    source.finalDay,
  );
  if (!civil.ok || civil.value.start_date === null) {
    throw new Error("Invalid fixture source civil input");
  }
  const temporal = allDay ? civil : validateSubmissionDates(
    zonedDateTimeToIso(source.startDay, source.startClock!),
    source.finalDay === undefined
      ? null
      : romeEndOfCalendarDay(source.finalDay),
    false,
  );
  if (!temporal.ok || temporal.value.start_date === null) {
    throw new Error("Invalid fixture source temporal input");
  }
  return {
    sourceId: 1,
    sourceUrl: "https://fixture.invalid/event",
    city: "Campobasso",
    name: "Fixture event",
    allDay,
    startDate: temporal.value.start_date,
    endDate: temporal.value.end_date,
    imageUrl: null,
    internalNotes: "Source-owned fixture interpretation",
    dedupKey: "fixture",
  };
}

class FakeImporterSubmissionClient {
  readonly inserts: unknown[] = [];
  from(table: string) {
    assertEquals(table, "content_submissions");
    return {
      insert: (payload: unknown) => {
        this.inserts.push(payload);
        return {
          select: (columns: string) => {
            assertEquals(columns, "id");
            return {
              single: () => Promise.resolve({ data: { id: 17 }, error: null }),
            };
          },
        };
      },
    };
  }
}

for (
  const fixture of [
    {
      name: "date-only single-day at spring DST",
      source: { startDay: "2026-03-29" },
      allDay: true,
      start: "2026-03-28T23:00:00.000Z",
      end: null,
    },
    {
      name: "date with meaningful time",
      source: { startDay: "2026-08-20", startClock: "18:30" },
      allDay: false,
      start: "2026-08-20T16:30:00.000Z",
      end: null,
    },
    {
      name: "date-only multi-day spanning autumn DST",
      source: { startDay: "2026-10-24", finalDay: "2026-10-25" },
      allDay: true,
      start: "2026-10-23T22:00:00.000Z",
      end: "2026-10-25T22:59:59.999999Z",
    },
    {
      name: "timed initial clock with final civil day only",
      source: {
        startDay: "2026-10-24",
        startClock: "18:30",
        finalDay: "2026-10-25",
      },
      allDay: false,
      start: "2026-10-24T16:30:00.000Z",
      end: "2026-10-25T22:59:59.999999Z",
    },
    {
      name: "real midnight remains timed",
      source: { startDay: "2026-10-25", startClock: "00:00" },
      allDay: false,
      start: "2026-10-24T22:00:00.000Z",
      end: null,
    },
  ]
) {
  Deno.test(`source adapter to actual importer payload: ${fixture.name}`, async () => {
    const prepared = prepareFixtureSource(fixture.source);
    assertEquals(prepared.allDay, fixture.allDay);
    const admin = new FakeImporterSubmissionClient();
    await insertImportedSubmission(
      admin as unknown as SupabaseClient<Database>,
      prepared,
      { id: "fixture-user", email: "fixture@example.test", name: "Fixture" },
    );
    assertEquals(admin.inserts.length, 1);
    const payload = admin.inserts[0] as Record<string, unknown>;
    assertEquals(payload.all_day, fixture.allDay);
    assertEquals(payload.start_date, fixture.start);
    assertEquals(payload.end_date, fixture.end);
    assertEquals(payload.category, "unknown");
    assertEquals(payload.status, "pending");
    assertEquals("start_calendar_date" in payload, false);
    assertEquals("end_calendar_date" in payload, false);
  });
}

Deno.test("invalid source civil date rejects before importer write", async () => {
  const admin = new FakeImporterSubmissionClient();
  await assertRejects(
    async () => {
      const prepared = prepareFixtureSource({ startDay: "2026-02-30" });
      await insertImportedSubmission(
        admin as unknown as SupabaseClient<Database>,
        prepared,
        { id: "fixture-user", email: "fixture@example.test", name: "Fixture" },
      );
    },
    Error,
    "Invalid fixture source civil input",
  );
  assertEquals(admin.inserts, []);
});
