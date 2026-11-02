import { canonicalizeExternalEvent } from "../_shared/external_event_normalization.ts";
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import {
  createClient,
  type SupabaseClient,
} from "npm:@supabase/supabase-js@2.112.3";

import type {
  CloudinaryConfig,
  CloudinaryUploadResult,
} from "../_shared/cloudinary.ts";
import type { Database } from "../_shared/database.types.ts";
import {
  ImportedAssetError,
  importObservedAssets,
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

const createdAssetRow = {
  outcome: "created",
  id: 71,
  url: uploadedAsset.url,
  width: uploadedAsset.width,
  height: uploadedAsset.height,
};

type RpcResponse = {
  data: unknown;
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
    data: [createdAssetRow],
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

for (const outcome of ["not_found", "not_pending", "limit_reached"]) {
  Deno.test(`cleans up only a complete SQL rejection: ${outcome}`, async () => {
    const { admin, destroyedPublicIds, persist } = persistImportedAsset({
      data: [{ outcome, id: null, url: null, width: null, height: null }],
      error: null,
    });
    const error = await assertRejects(persist, ImportedAssetError, outcome);
    assertEquals(error.phase, "association");
    assertEquals(error.outcome, "rejected");
    assertEquals(error.cleanup, "confirmed");
    assertEquals(destroyedPublicIds, [uploadedAsset.publicId]);
    assertEquals(admin.rpcCalls.length, 1);
  });
}

Deno.test("uncertain RPC responses never authorize destruction or retry", async () => {
  const rejection = {
    outcome: "not_pending",
    id: null,
    url: null,
    width: null,
    height: null,
  };
  const invalidData: unknown[] = [
    null,
    undefined,
    [],
    [createdAssetRow, createdAssetRow],
    {},
    { length: 1, 0: rejection },
    [null],
    [[]],
    ["created"],
    [{ outcome: "unknown" }],
    [{ outcome: "not_pending" }],
    [{ ...rejection, id: 1 }],
    [{ ...rejection, url: uploadedAsset.url }],
    [{ ...rejection, width: 0 }],
    [{ ...rejection, height: undefined }],
    [{ ...createdAssetRow, id: 0 }],
    [{ ...createdAssetRow, id: 1.5 }],
    [{ ...createdAssetRow, id: Number.MAX_SAFE_INTEGER + 1 }],
    [{ ...createdAssetRow, id: "1" }],
    [{ ...createdAssetRow, url: "https://other.test/image" }],
    [{ ...createdAssetRow, width: 1 }],
    [{ ...createdAssetRow, height: null }],
  ];
  for (const data of invalidData) {
    const { admin, destroyedPublicIds, persist } = persistImportedAsset({
      data,
      error: null,
    });
    const error = await assertRejects(
      persist,
      ImportedAssetError,
      "outcome unknown",
    );
    assertEquals(error.outcome, "unknown");
    assertEquals(destroyedPublicIds, []);
    assertEquals(admin.rpcCalls.length, 1);
  }
  for (const data of [null, [createdAssetRow], [rejection]]) {
    const { destroyedPublicIds, persist } = persistImportedAsset({
      data,
      error: { message: "secret-bearing upstream body" },
    });
    const error = await assertRejects(persist, ImportedAssetError);
    assertEquals(error.outcome, "unknown");
    assertEquals(error.message.includes("secret-bearing"), false);
    assertEquals(destroyedPublicIds, []);
  }
});

Deno.test("actual SDK network and decoding failures retain the upload", async () => {
  for (const body of [null, "{", "", "[]"]) {
    let requests = 0;
    const client = createClient<Database>("http://127.0.0.1:54321", "dummy", {
      auth: { persistSession: false, autoRefreshToken: false },
      global: {
        fetch: () => {
          requests++;
          if (body === null) throw new TypeError("injected transport failure");
          return Promise.resolve(
            new Response(body, {
              headers: { "Content-Type": "application/json" },
            }),
          );
        },
      },
    });
    const destroyed: string[] = [];
    const error = await assertRejects(
      () =>
        uploadAndPersistImportedAsset(client, {
          submissionId: 17,
          sourceUrl: "https://eventimolise.it/import-test.png",
          cloudinary: cloudinaryConfig,
        }, testDependencies(destroyed)),
      ImportedAssetError,
    );
    assertEquals(error.outcome, "unknown");
    assertEquals(requests, 1);
    assertEquals(destroyed, []);
  }
});

Deno.test("thrown or absent RPC response remains unknown; upload failure never associates", async () => {
  for (const response of [undefined, null, new Error("private failure")]) {
    let calls = 0;
    const client = {
      rpc: () => {
        calls++;
        if (response instanceof Error) throw response;
        return Promise.resolve(response);
      },
    };
    const destroyed: string[] = [];
    const error = await assertRejects(
      () =>
        uploadAndPersistImportedAsset(
          client as unknown as SupabaseClient<Database>,
          {
            submissionId: 17,
            sourceUrl: "https://eventimolise.it/import-test.png",
            cloudinary: cloudinaryConfig,
          },
          testDependencies(destroyed),
        ),
      ImportedAssetError,
    );
    assertEquals(error.outcome, "unknown");
    assertEquals(calls, 1);
    assertEquals(destroyed, []);
  }
  const cause = new Error("private upload response");
  const error = await assertRejects(
    () =>
      uploadAndPersistImportedAsset({
        rpc: () => {
          throw new Error("must not associate");
        },
      } as unknown as SupabaseClient<Database>, {
        submissionId: 17,
        sourceUrl: "https://eventimolise.it/import-test.png",
        cloudinary: cloudinaryConfig,
      }, {
        uploadRemoteImage: () => Promise.reject(cause),
        destroyCloudinaryImage: () => {
          throw new Error("must not destroy");
        },
      }),
    ImportedAssetError,
  );
  assertEquals(error.phase, "upload");
  assertEquals(error.cause, cause);
});

Deno.test("cleanup uncertainty preserves the primary SQL rejection", async () => {
  const cause = new Error("secret-bearing cleanup payload");
  const client = new FakeImporterAdminClient({
    data: [{
      outcome: "limit_reached",
      id: null,
      url: null,
      width: null,
      height: null,
    }],
    error: null,
  });
  const error = await assertRejects(
    () =>
      uploadAndPersistImportedAsset(
        client as unknown as SupabaseClient<Database>,
        {
          submissionId: 17,
          sourceUrl: "https://eventimolise.it/import-test.png",
          cloudinary: cloudinaryConfig,
        },
        {
          uploadRemoteImage: () => Promise.resolve(uploadedAsset),
          destroyCloudinaryImage: () => Promise.reject(cause),
        },
      ),
    ImportedAssetError,
    "limit_reached",
  );
  assertEquals(error.outcome, "rejected");
  assertEquals(error.cleanup, "unconfirmed");
  assertEquals(error.cause, cause);
  assertEquals(error.message.includes("secret-bearing"), false);
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
      data: [
        functionName === "add_submission_assets"
          ? createdAssetRow
          : { outcome: this.outcomes.shift()! },
      ],
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

function observedAsset(id: number, image = true) {
  return {
    event: {
      ...prepareFixtureSource({ startDay: "2026-11-10" }),
      sourceId: id,
      imageUrl: image
        ? `https://eventimolise.it/wp-content/uploads/${id}.png`
        : null,
    },
    observation: { ...sourceAssetObservation, pending_submission_id: id },
  };
}

Deno.test("batch reporting partitions certainty and preserves primary errors without secrets", async () => {
  let noteReads = 0, noteWrites = 0, destroyed = 0;
  const client = createClient<Database>("http://127.0.0.1:54321", "dummy", {
    auth: { persistSession: false, autoRefreshToken: false },
    global: {
      fetch: (input, init) => {
        const url = new URL(String(input));
        const payload = init?.body ? JSON.parse(String(init.body)) : null;
        let body: unknown;
        if (url.pathname.endsWith("claim_external_event_source_asset")) {
          if (payload.p_submission_id === 6) {
            throw new Error("secret claim response");
          }
          body = [{ outcome: "claimed" }];
        } else if (url.pathname.endsWith("add_submission_assets")) {
          if (payload.p_submission_id === 1) {
            throw new Error("secret association response");
          }
          body = payload.p_submission_id === 2
            ? [{
              outcome: "not_pending",
              id: null,
              url: null,
              width: null,
              height: null,
            }]
            : [createdAssetRow];
        } else {
          assertEquals(url.pathname, "/rest/v1/content_submissions");
          if (init?.method === "GET") {
            noteReads++;
            body = { internal_notes: null };
          } else {
            noteWrites++;
            body = [];
          }
        }
        return Promise.resolve(
          new Response(JSON.stringify(body), {
            headers: { "Content-Type": "application/json" },
          }),
        );
      },
    },
  });
  const report = await importObservedAssets(
    client,
    [1, 2, 3, 4, 5, 6].map((id) => observedAsset(id, id !== 5)),
    cloudinaryConfig,
    {
      uploadRemoteImage: ({ sourceUrl }) =>
        sourceUrl.endsWith("/3.png")
          ? Promise.reject(new Error("secret upload response"))
          : Promise.resolve(uploadedAsset),
      destroyCloudinaryImage: () => {
        destroyed++;
        throw new Error("secret cleanup response");
      },
    },
  );
  assertEquals([
    report.assets_uploaded,
    report.assets_failed,
    report.assets_unknown,
    report.without_asset,
  ], [1, 3, 1, 1]);
  assertEquals(
    report.errors.map(
      (e) => [e.submissionId, e.phase, e.outcome, e.cleanup, e.note],
    ),
    [
      [1, "association", "unknown", undefined, undefined],
      [2, "association", "rejected", "unconfirmed", "unconfirmed"],
      [3, "upload", "failed", undefined, "unconfirmed"],
      [6, "claim", "failed", undefined, "unconfirmed"],
    ],
  );
  assertEquals(report.errors[0].publicId, uploadedAsset.publicId);
  assertEquals(report.errors.every((e) => e.stage === "import_asset"), true);
  assertEquals(noteReads, 3);
  assertEquals(noteWrites, 3);
  assertEquals(destroyed, 1);
  assertEquals(JSON.stringify(report).includes("secret"), false);
});

Deno.test("failure notes use one stored-value CAS and diagnostic failures do not stop the batch", async (t) => {
  for (
    const previous of [
      null,
      "",
      "Persisted note & reviewer context\nSecond line",
    ]
  ) {
    for (
      const mode of [
        "ok",
        "conflict",
        "read_error",
        "read_throw",
        "missing",
        "write_error",
        "write_throw",
        "write_ambiguous",
      ]
    ) {
      await t.step(`${String(previous)} / ${mode}`, async () => {
        let reads = 0, writes = 0;
        let stored = previous;
        const client = createClient<Database>(
          "http://127.0.0.1:54321",
          "dummy",
          {
            auth: { persistSession: false, autoRefreshToken: false },
            global: {
              fetch: (input, init) => {
                const url = new URL(String(input));
                const json = (body: unknown, status = 200) =>
                  Promise.resolve(
                    new Response(JSON.stringify(body), {
                      status,
                      headers: { "Content-Type": "application/json" },
                    }),
                  );
                if (
                  url.pathname.endsWith("claim_external_event_source_asset")
                ) return json([{ outcome: "claimed" }]);
                if (url.pathname.endsWith("add_submission_assets")) {
                  const payload = JSON.parse(String(init?.body));
                  return json(
                    payload.p_submission_id === 1
                      ? [{
                        outcome: "limit_reached",
                        id: null,
                        url: null,
                        width: null,
                        height: null,
                      }]
                      : [createdAssetRow],
                  );
                }
                assertEquals(url.pathname, "/rest/v1/content_submissions");
                assertEquals(url.searchParams.get("id"), "eq.1");
                if (init?.method === "GET") {
                  reads++;
                  if (mode === "read_error") {
                    return json({ message: "secret read error" }, 520);
                  }
                  if (mode === "read_throw") {
                    throw new Error("secret read failure");
                  }
                  return json(
                    mode === "missing" ? null : { internal_notes: stored },
                  );
                }
                assertEquals(init?.method, "PATCH");
                writes++;
                assertEquals(
                  url.searchParams.get("internal_notes"),
                  previous === null ? "is.null" : `eq.${previous}`,
                );
                assertEquals(url.searchParams.get("select"), "id");
                const payload = JSON.parse(String(init?.body));
                const warning =
                  "Warning: image import failed; inspect current assets before adding an image manually";
                assertEquals(
                  payload.internal_notes,
                  previous ? `${previous}\n${warning}` : warning,
                );
                assertEquals(
                  payload.internal_notes.includes(
                    "Source-owned fixture interpretation",
                  ),
                  false,
                );
                if (mode === "conflict") {
                  stored = "Concurrent newer note";
                  return json([]);
                }
                if (mode === "write_error") {
                  return json({ message: "secret write error" }, 500);
                }
                if (mode === "write_throw") {
                  throw new Error("secret write failure");
                }
                stored = payload.internal_notes;
                if (mode === "write_ambiguous") {
                  throw new Error("response lost after note write");
                }
                return json([{ id: 1 }]);
              },
            },
          },
        );
        const report = await importObservedAssets(
          client,
          [observedAsset(1), observedAsset(2)],
          cloudinaryConfig,
          {
            uploadRemoteImage: () => Promise.resolve(uploadedAsset),
            destroyCloudinaryImage: () => Promise.resolve(),
          },
        );
        assertEquals(report.assets_failed, 1);
        assertEquals(report.assets_uploaded, 1);
        assertEquals(report.assets_unknown, 0);
        assertEquals(report.errors[0].outcome, "rejected");
        assertEquals(report.errors[0].cleanup, "confirmed");
        assertEquals(
          report.errors[0].note,
          mode === "ok" ? "confirmed" : "unconfirmed",
        );
        assertEquals(reads, 1);
        assertEquals(
          writes,
          ["read_error", "read_throw", "missing"].includes(mode) ? 0 : 1,
        );
        if (mode === "conflict") assertEquals(stored, "Concurrent newer note");
        assertEquals(JSON.stringify(report).includes("secret"), false);
      });
    }
  }
});

Deno.test("unexpected note-query exceptions preserve rejection and continue processing", async () => {
  const client = {
    rpc: (name: string, args: { p_submission_id: number }) =>
      Promise.resolve({
        data: name === "claim_external_event_source_asset"
          ? [{ outcome: "claimed" }]
          : args.p_submission_id === 1
          ? [{
            outcome: "not_found",
            id: null,
            url: null,
            width: null,
            height: null,
          }]
          : [createdAssetRow],
        error: null,
      }),
    from: () => {
      throw new Error("private note-query exception");
    },
  } as unknown as SupabaseClient<Database>;
  const report = await importObservedAssets(
    client,
    [observedAsset(1), observedAsset(2)],
    cloudinaryConfig,
    {
      uploadRemoteImage: () => Promise.resolve(uploadedAsset),
      destroyCloudinaryImage: () => Promise.resolve(),
    },
  );
  assertEquals(report.assets_uploaded, 1);
  assertEquals(
    report.errors[0].message,
    "Asset association rejected: not_found",
  );
  assertEquals(report.errors[0].note, "unconfirmed");
});
