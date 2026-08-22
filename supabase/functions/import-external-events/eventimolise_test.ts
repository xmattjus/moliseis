import { assertEquals } from "jsr:@std/assert@1";
import {
  extractNextSearchPageUrl,
  extractStartDatesFromSearchHtml,
  parseEventsTodayPayload,
} from "./eventimolise.ts";

Deno.test("extracts and normalizes Italian dates from listing HTML", () => {
  const html = `
    <article>14 Agosto 2026</article>
    <article>2 settembre 2026</article>
    <aside>14 Agosto 2026</aside>
  `;

  assertEquals(extractStartDatesFromSearchHtml(html), [
    "2026-08-14",
    "2026-09-02",
  ]);
});

Deno.test("extracts a date when day month and year are split across HTML nodes", () => {
  const html = `
    <article>
      <span class="day">21</span>
      <span class="month">Agosto</span>
      <span class="year">2026</span>
    </article>
  `;

  assertEquals(extractStartDatesFromSearchHtml(html), [
    "2026-08-21",
  ]);
});

Deno.test("finds the next search-results page without depending on CSS classes", () => {
  const html = `
    <nav>
      <a href="https://eventimolise.it/search-results/page/4/">4</a>
      <a href="/search-results/page/3/">Avanti</a>
    </nav>
  `;

  assertEquals(
    extractNextSearchPageUrl(html, 2),
    "https://eventimolise.it/search-results/page/3/",
  );
});

Deno.test("parses the structured events-today payload and keeps duplicate source rows", () => {
  const result = parseEventsTodayPayload({
    success: true,
    date: "2026-08-14",
    count: 2,
    events: [
      {
        id: 18008,
        title: "Eventi Estivi a Bagnoli del Trigno",
        time: "18:30",
        end_time: "22:00",
        date: "2026-08-14",
        end_date: "2026-08-30",
        location: "Bagnoli del Trigno",
        locations: ["Bagnoli del Trigno"],
        categories: ["Altro", "Cibo"],
        organizers: [],
        url:
          "https://eventimolise.it/event/bagnoli-del-trigno/altro/eventi-estivi-a-bagnoli-del-trigno/",
        image: "https://eventimolise.it/wp-content/uploads/2026/07/example.png",
      },
      {
        id: 18009,
        title: "Eventi Estivi a Bagnoli del Trigno",
        time: "18:30",
        end_time: "22:00",
        date: "2026-08-14",
        end_date: "2026-08-30",
        location: "Bagnoli del Trigno",
        locations: ["Bagnoli del Trigno"],
        categories: ["Altro", "Cibo"],
        organizers: [],
        url:
          "https://eventimolise.it/event/bagnoli-del-trigno/altro/eventi-estivi-a-bagnoli-del-trigno-2/",
        image: "https://eventimolise.it/wp-content/uploads/2026/07/example.png",
      },
    ],
  }, "2026-08-14");

  assertEquals(result.events.length, 2);
  assertEquals(result.invalidCount, 0);
  assertEquals(result.events[0].id, 18008);
  assertEquals(result.events[1].id, 18009);
});
