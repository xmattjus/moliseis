import { assertEquals } from "jsr:@std/assert@1";
import {
  calendarDateInRome,
  normalizeDedupText,
  sameEventCandidateDay,
} from "./external_event_candidates.ts";
Deno.test("Candidate evidence reuses Italian normalized text and Rome calendar day across DST/midnight", () => {
  assertEquals(
    normalizeDedupText("  ＣＯＮＣＥＲＴＯ\n  Café "),
    "concerto café",
  );
  assertEquals(calendarDateInRome("2026-10-02T22:30:00Z"), "2026-10-03");
  assertEquals(
    sameEventCandidateDay("2026-10-25T00:30:00Z", "2026-10-25T01:30:00Z"),
    true,
  );
});
