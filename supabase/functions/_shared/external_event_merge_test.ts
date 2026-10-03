import { assertEquals } from "jsr:@std/assert@1";
import { calculateExternalEventMerge } from "./external_event_merge.ts";
import { canonicalizeExternalEvent } from "./external_event_normalization.ts";

const base = canonicalizeExternalEvent({
  name: "Source",
  category: "unknown",
  description: null,
  description_delta: null,
  city: "City",
  latitude: null,
  longitude: null,
  start_date: "2026-10-02T10:00:00.123456Z",
  end_date: null,
  all_day: false,
});
Deno.test("Unchanged source/moderation leaves placeholder groups unapplied despite editorial Event enrichment", () => {
  const result = calculateExternalEventMerge(base, base, base, {
    ...base,
    category: "experience",
    city: null,
    latitude: "41",
    longitude: "14",
  });
  assertEquals(result.groups_to_apply, []);
  assertEquals(
    result.groups.every((g) =>
      !g.provider_changed && !g.moderator_changed && !g.apply && !g.overwrite
    ),
    true,
  );
  assertEquals(result.groups[4].current.city, null);
});
Deno.test("Provider-only, moderator-only and combined changes select complete groups and detect editorial overwrite", () => {
  const source = {
    ...base,
    name: "Provider revision",
    start_date: "2026-10-02T11:00:00.123456Z",
  };
  const moderated = {
    ...source,
    category: "experience" as const,
    city: "New city",
    latitude: "42",
    longitude: "15",
  };
  const result = calculateExternalEventMerge(base, source, moderated, {
    ...base,
    name: "Editorial title",
    category: "history",
  });
  assertEquals(result.groups_to_apply, [
    "name",
    "category",
    "schedule",
    "location",
  ]);
  assertEquals(
    result.groups.map((
      g,
    ) => [g.provider_changed, g.moderator_changed, g.overwrite]),
    [[true, false, true], [false, true, true], [false, false, false], [
      true,
      false,
      false,
    ], [false, true, false]],
  );
  assertEquals(result.groups[3].moderated, {
    start_date: moderated.start_date,
    end_date: null,
    all_day: false,
  });
  assertEquals(result.groups[4].moderated, {
    city: "New city",
    latitude: "42",
    longitude: "15",
  });
});
Deno.test("Description/plain Delta, schedule, and location are indivisible and current-equals-moderated avoids overwrite", () => {
  const moderated = canonicalizeExternalEvent({
    ...base,
    description: "Text",
    description_delta: [{ insert: "Text\n", attributes: { bold: true } }],
    end_date: "2026-10-02T12:00:00Z",
    longitude: "14",
  });
  const result = calculateExternalEventMerge(base, base, moderated, moderated);
  assertEquals(result.groups_to_apply, ["description", "schedule", "location"]);
  assertEquals(result.groups.map((g) => g.overwrite), [
    false,
    false,
    false,
    false,
    false,
  ]);
  assertEquals(result.groups[2].moderated, {
    description: "Text",
    description_delta: [{ insert: "Text\n", attributes: { bold: true } }],
  });
});
Deno.test("Source and moderator changes can cancel to the base while preserving apply semantics", () => {
  const source = { ...base, name: "Changed" };
  const result = calculateExternalEventMerge(base, source, base, base);
  assertEquals(result.groups[0].provider_changed, true);
  assertEquals(result.groups[0].moderator_changed, true);
  assertEquals(result.groups[0].apply, true);
  assertEquals(result.groups[0].overwrite, false);
});
