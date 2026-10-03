import { canonicalizeExternalEvent } from "../_shared/external_event_normalization.ts";
import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2.112.3";

import type {
  CloudinaryConfig,
  CloudinaryUploadResult,
} from "../_shared/cloudinary.ts";
import type { Database } from "../_shared/database.types.ts";
import {
  importSourceAssetIfEligible,
  ingestExternalEvent,
  ingestPreparedObservations,
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
    provider: "eventimolise",
    externalId: "1",
    occurrenceKey: null,
    normalized: canonicalizeExternalEvent({
      name: "Fixture event",
      city: "Campobasso",
      category: "unknown",
      description: null,
      description_delta: null,
      latitude: null,
      longitude: null,
      ...temporal.value,
    }),
    metadata: {},
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
  readonly rpcCalls: Array<{ name: string; args: Record<string, unknown> }> =
    [];
  rpc(name: string, args: Record<string, unknown>) {
    this.rpcCalls.push({ name, args });
    return Promise.resolve({
      data: [{
        outcome: "ingested",
        record_id: 5,
        event_id: null,
        pending_submission_id: 17,
        pending_created: true,
      }],
      error: null,
    });
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
    await ingestExternalEvent(
      admin as unknown as SupabaseClient<Database>,
      prepared,
      "fixture-user",
    );
    assertEquals(admin.rpcCalls.length, 1);
    assertEquals(admin.rpcCalls[0].name, "ingest_external_event");
    const args = admin.rpcCalls[0].args;
    const payload = args.p_normalized as Record<string, unknown>;
    assertEquals(args.p_importer_user_id, "fixture-user");
    assertEquals("p_user_email" in args, false);
    assertEquals("p_user_name" in args, false);
    assertEquals(payload.all_day, fixture.allDay);
    assertEquals(
      payload.start_date,
      fixture.start.replace(".000Z", ".000000Z"),
    );
    assertEquals(payload.end_date, fixture.end);
    assertEquals(payload.category, "unknown");
    assertEquals(args.p_normalization_version, 1);
    assertEquals("start_calendar_date" in payload, false);
    assertEquals("end_calendar_date" in payload, false);
  });
}

Deno.test("invalid source civil date rejects before importer write", async () => {
  const admin = new FakeImporterSubmissionClient();
  await assertRejects(
    async () => {
      const prepared = prepareFixtureSource({ startDay: "2026-02-30" });
      await ingestExternalEvent(
        admin as unknown as SupabaseClient<Database>,
        prepared,
        "fixture-user",
      );
    },
    Error,
    "Invalid fixture source civil input",
  );
  assertEquals(admin.rpcCalls, []);
});

Deno.test("ingest transport preserves record, linked Event, existing pending and no-pending outcomes", async () => {
  const prepared = prepareFixtureSource({
    startDay: "2026-10-02",
    startClock: "12:00",
  });
  for (
    const expected of [
      {
        record_id: 5,
        event_id: null,
        pending_submission_id: 17,
        pending_created: true,
      },
      {
        record_id: 5,
        event_id: 12,
        pending_submission_id: 17,
        pending_created: false,
      },
      {
        record_id: 5,
        event_id: 12,
        pending_submission_id: null,
        pending_created: false,
      },
    ]
  ) {
    const admin = {
      rpc: () =>
        Promise.resolve({
          data: [{ outcome: "ingested", ...expected }],
          error: null,
        }),
    };
    assertEquals(
      await ingestExternalEvent(
        admin as unknown as SupabaseClient<Database>,
        prepared,
        "configured-user",
      ),
      expected,
    );
  }
});

Deno.test("ingest transport rejects failed and malformed RPC outcomes", async () => {
  const prepared = prepareFixtureSource({
    startDay: "2026-10-02",
    startClock: "12:00",
  });
  for (
    const response of [
      { data: null, error: { message: "database unavailable" } },
      { data: [], error: null },
      { data: [{ outcome: "normalization_mismatch" }], error: null },
      {
        data: [{
          outcome: "ingested",
          record_id: null,
          event_id: null,
          pending_submission_id: null,
          pending_created: false,
        }],
        error: null,
      },
      {
        data: [{
          outcome: "ingested",
          record_id: 5,
          event_id: null,
          pending_submission_id: null,
          pending_created: true,
        }],
        error: null,
      },
      {
        data: [{
          outcome: "ingested",
          record_id: 5,
          event_id: null,
          pending_submission_id: 17,
        }],
        error: null,
      },
    ]
  ) {
    const admin = { rpc: () => Promise.resolve(response) };
    await assertRejects(
      () =>
        ingestExternalEvent(
          admin as unknown as SupabaseClient<Database>,
          prepared,
          "configured-user",
        ),
      Error,
      "External ingest failed",
    );
  }
});

Deno.test("invalid normalized Event start/chronology/all-day state never invokes ingest RPC", async () => {
  const prepared = prepareFixtureSource({
    startDay: "2026-10-02",
    startClock: "12:00",
  });
  for (
    const patch of [
      { start_date: null },
      { start_date: "2026-02-30T10:00:00Z" },
      { end_date: "2026-10-02T09:59:59.999999Z" },
      { all_day: true },
    ]
  ) {
    const admin = new FakeImporterSubmissionClient();
    await assertRejects(() =>
      ingestExternalEvent(
        admin as unknown as SupabaseClient<Database>,
        {
          ...prepared,
          normalized: { ...prepared.normalized, ...patch },
        } as PreparedExternalEvent,
        "configured-user",
      )
    );
    assertEquals(admin.rpcCalls, []);
  }
});

Deno.test("creation budget reaches later identities on repeated runs and repeated appearances cost no slots", async () => {
  const base = prepareFixtureSource({
    startDay: "2026-10-02",
    startClock: "12:00",
  });
  const a = { ...base, externalId: "A", sourceId: 1 };
  const b = { ...base, externalId: "B", sourceId: 2 };
  const records = new Map<string, { recordId: number; name: unknown }>();
  const calls: string[] = [];
  const admin = {
    rpc: (_name: string, args: Record<string, unknown>) => {
      const id = String(args.p_external_id);
      calls.push(id);
      const existing = records.get(id);
      const recordId = existing?.recordId ?? records.size + 1;
      records.set(id, {
        recordId,
        name: (args.p_normalized as Record<string, unknown>).name,
      });
      return Promise.resolve({
        data: [{
          outcome: "ingested",
          record_id: recordId,
          event_id: null,
          pending_submission_id: recordId + 10,
          pending_created: !existing,
        }],
        error: null,
      });
    },
  } as unknown as SupabaseClient<Database>;
  const first = await ingestPreparedObservations(
    admin,
    [a, b],
    "configured-user",
    1,
  );
  assertEquals(calls, ["A"]);
  assertEquals(first.created, 1);
  assertEquals(first.limitReached, true);
  calls.length = 0;
  const second = await ingestPreparedObservations(
    admin,
    [a, a, b],
    "configured-user",
    1,
  );
  assertEquals(calls, ["A", "A", "B"]);
  assertEquals(second.created, 1);
  assertEquals(second.limitReached, false);
  assertEquals(records.size, 2);
  calls.length = 0;
  const updatedB = {
    ...b,
    normalized: { ...b.normalized, name: "Later updated B" },
  };
  const third = await ingestPreparedObservations(
    admin,
    [a, a, updatedB],
    "configured-user",
    1,
  );
  assertEquals(calls, ["A", "A", "B"]);
  assertEquals(records.get("B")?.name, "Later updated B");
  assertEquals(third.created, 0);
  assertEquals(third.limitReached, false);
});

class ClaimImporterClient {
  readonly calls: Array<{ functionName: string; args: unknown }> = [];
  constructor(private readonly outcomes: string[]) {}
  rpc(functionName: string, args: unknown): Promise<RpcResponse> {
    this.calls.push({ functionName, args });
    return Promise.resolve({
      data: [{ outcome: this.outcomes.shift()! }],
      error: null,
    });
  }
}
const sourceAssetObservation = {
  record_id: 1,
  event_id: null,
  pending_submission_id: 7,
  pending_created: false,
};
const sourceAssetImage =
  "https://eventimolise.it/wp-content/uploads/fixture.png";
Deno.test("Edge eligible current image claims existing pending before upload and association", async () => {
  const client = new ClaimImporterClient(["claimed", "created"]);
  let uploads = 0;
  const result = await importSourceAssetIfEligible(
    client as unknown as SupabaseClient<Database>,
    {
      event: { imageUrl: sourceAssetImage },
      observation: sourceAssetObservation,
      cloudinary: cloudinaryConfig,
    },
    {
      uploadRemoteImage: ({ sourceUrl }) => {
        assertEquals(sourceUrl, sourceAssetImage);
        assertEquals(client.calls, [{
          functionName: "claim_external_event_source_asset",
          args: { p_submission_id: 7 },
        }]);
        uploads++;
        return Promise.resolve(uploadedAsset);
      },
      destroyCloudinaryImage: () => Promise.resolve(),
    },
  );
  assertEquals(result, "uploaded");
  assertEquals(uploads, 1);
  assertEquals(client.calls.map((call) => call.functionName), [
    "claim_external_event_source_asset",
    "add_submission_assets",
  ]);
});
Deno.test("Edge no image/ineligible image/linked/no pending never claims or uploads; nonwinner skips", async () => {
  for (
    const [imageUrl, observation] of [
      [null, sourceAssetObservation],
      ["https://other.example.test/image.png", sourceAssetObservation],
      [sourceAssetImage, { ...sourceAssetObservation, event_id: 19 }],
      [sourceAssetImage, {
        ...sourceAssetObservation,
        pending_submission_id: null,
      }],
    ] as const
  ) {
    const client = new ClaimImporterClient([]);
    assertEquals(
      await importSourceAssetIfEligible(
        client as unknown as SupabaseClient<Database>,
        { event: { imageUrl }, observation, cloudinary: cloudinaryConfig },
      ),
      "skipped",
    );
    assertEquals(client.calls, []);
  }
  for (
    const outcome of [
      "already_claimed",
      "source_already_linked",
      "assets_present",
      "not_pending",
      "not_imported",
      "not_found",
    ]
  ) {
    const client = new ClaimImporterClient([outcome]);
    assertEquals(
      await importSourceAssetIfEligible(
        client as unknown as SupabaseClient<Database>,
        {
          event: { imageUrl: sourceAssetImage },
          observation: sourceAssetObservation,
          cloudinary: cloudinaryConfig,
        },
        {
          uploadRemoteImage: () => Promise.reject(new Error("must not upload")),
          destroyCloudinaryImage: () => Promise.resolve(),
        },
      ),
      "skipped",
    );
    assertEquals(client.calls.length, 1);
  }
});
