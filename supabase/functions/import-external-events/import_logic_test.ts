import { assert, assertEquals } from "jsr:@std/assert@1";
import type { EventiMoliseEvent } from "./eventimolise.ts";
import {
  buildDedupKey,
  prepareEvent,
  zonedDateTimeToIso,
} from "./import_logic.ts";

function event(overrides: Partial<EventiMoliseEvent> = {}): EventiMoliseEvent {
  return {
    id: 18008,
    title: "Eventi Estivi a Bagnoli del Trigno",
    time: "18:30",
    endTime: "22:00",
    date: "2026-08-14",
    endDate: "2026-08-30",
    location: "Bagnoli del Trigno",
    locations: ["Bagnoli del Trigno"],
    categories: ["Altro", "Cibo"],
    organizers: [],
    url: "https://eventimolise.it/event/bagnoli-del-trigno/altro/eventi-estivi-a-bagnoli-del-trigno/",
    image: "https://eventimolise.it/wp-content/uploads/2026/07/example.png",
    ...overrides,
  };
}

Deno.test("converts Europe/Rome summer and winter local times to UTC", () => {
  assertEquals(
    zonedDateTimeToIso("2026-08-20", "17:00"),
    "2026-08-20T15:00:00.000Z",
  );
  assertEquals(
    zonedDateTimeToIso("2026-12-20", "17:00"),
    "2026-12-20T16:00:00.000Z",
  );
});

Deno.test("dedup key ignores start time but changes when calendar date changes", () => {
  const first = buildDedupKey(
    "Campobasso",
    "Concerto",
    zonedDateTimeToIso("2026-08-20", "20:00"),
  );
  const changedTime = buildDedupKey(
    " campobasso ",
    "CONCERTO",
    zonedDateTimeToIso("2026-08-20", "21:30"),
  );
  const changedDate = buildDedupKey(
    "Campobasso",
    "Concerto",
    zonedDateTimeToIso("2026-08-21", "20:00"),
  );

  assertEquals(first, changedTime);
  assert(first !== changedDate);
});

Deno.test("the two real Bagnoli source duplicates produce the same key", () => {
  const first = prepareEvent(event({ id: 18008 }));
  const second = prepareEvent(event({
    id: 18009,
    url: "https://eventimolise.it/event/bagnoli-del-trigno/altro/eventi-estivi-a-bagnoli-del-trigno-2/",
  }));

  assertEquals(first.dedupKey, second.dedupKey);
});

Deno.test("multiple locations use the reviewer fallback", () => {
  const prepared = prepareEvent(event({
    locations: ["Bologna", "Monterenzio"],
  }));

  assertEquals(prepared.city, "EventiMolise");
  assert(prepared.internalNotes.includes("multiple source locations"));
});

Deno.test("equal start and end timestamps omit end_date", () => {
  const prepared = prepareEvent(event({
    date: "2026-08-14",
    time: "23:30",
    endDate: "2026-08-14",
    endTime: "23:30",
  }));

  assertEquals(prepared.endDate, null);
  assert(prepared.internalNotes.includes("end_date omitted"));
});
