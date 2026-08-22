import { load } from "npm:cheerio@1.0.0/slim";

const BASE_URL = "https://eventimolise.it";
const SEARCH_RESULTS_URL = `${BASE_URL}/search-results/`;
const EVENTS_TODAY_URL = `${BASE_URL}/wp-json/custom/v1/events-today`;
const FETCH_TIMEOUT_MS = 20_000;
const FETCH_MAX_ATTEMPTS = 2;
const FETCH_RETRY_DELAY_MS = 500;
const DEFAULT_MAX_SEARCH_PAGES = 20;

const ITALIAN_MONTHS: Record<string, string> = {
  gennaio: "01",
  febbraio: "02",
  marzo: "03",
  aprile: "04",
  maggio: "05",
  giugno: "06",
  luglio: "07",
  agosto: "08",
  settembre: "09",
  ottobre: "10",
  novembre: "11",
  dicembre: "12",
};

const ITALIAN_DATE_REGEX = new RegExp(
  `\\b(\\d{1,2})\\s+(${Object.keys(ITALIAN_MONTHS).join("|")})\\s+(\\d{4})\\b`,
  "giu",
);

export type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

function isAbortError(error: unknown): boolean {
  return error instanceof Error && error.name === "AbortError";
}

async function sleep(milliseconds: number): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function fetchWithRetry(
  url: string | URL,
  init: RequestInit,
  fetchImpl: FetchLike,
): Promise<Response> {
  let lastError: unknown;

  for (let attempt = 1; attempt <= FETCH_MAX_ATTEMPTS; attempt += 1) {
    const controller = new AbortController();
    const startedAt = Date.now();
    const timeout = setTimeout(
      () => controller.abort(),
      FETCH_TIMEOUT_MS,
    );

    try {
      const response = await fetchImpl(url, {
        ...init,
        signal: controller.signal,
      });

      console.log("EventiMolise request completed", {
        url: String(url),
        attempt,
        status: response.status,
        durationMs: Date.now() - startedAt,
      });

      return response;
    } catch (error) {
      lastError = error;

      console.warn("EventiMolise request failed", {
        url: String(url),
        attempt,
        durationMs: Date.now() - startedAt,
        timedOut: isAbortError(error),
        error: error instanceof Error ? error.message : String(error),
      });

      if (!isAbortError(error) || attempt === FETCH_MAX_ATTEMPTS) {
        throw error;
      }

      await sleep(FETCH_RETRY_DELAY_MS * attempt);
    } finally {
      clearTimeout(timeout);
    }
  }

  throw lastError;
}

export type EventiMoliseEvent = {
  id: number;
  title: string;
  time: string;
  endTime: string | null;
  date: string;
  endDate: string | null;
  location: string | null;
  locations: string[];
  categories: string[];
  organizers: string[];
  url: string;
  image: string | null;
};

export type EventiMoliseDateResult = {
  events: EventiMoliseEvent[];
  invalidCount: number;
};

export type DiscoveryResult = {
  dates: string[];
  pagesFetched: number;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asTrimmedString(value: unknown): string | null {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((entry): entry is string => typeof entry === "string")
    .map((entry) => entry.trim())
    .filter(Boolean);
}

export function isIsoCalendarDate(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year &&
    date.getUTCMonth() === month - 1 &&
    date.getUTCDate() === day;
}

export function isClockTime(value: string): boolean {
  if (!/^\d{2}:\d{2}$/.test(value)) return false;
  const [hour, minute] = value.split(":").map(Number);
  return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
}

export function extractStartDatesFromSearchHtml(html: string): string[] {
  const $ = load(html);
  // Cheerio's .text() concatenates adjacent text nodes without inserting a
  // separator. EventiMolise renders date parts in separate HTML elements, so a
  // visually rendered "21 Agosto 2026" can become "21Agosto2026" here.
  //
  // Keep the normal DOM text, but also build a tag-separated representation of
  // the raw HTML. This preserves boundaries between day/month/year even when
  // the source markup wraps them in different elements.
  const textCandidates = [
    $.root().text(),
    html
      .replace(/<script\b[^>]*>[\s\S]*?<\/script>/giu, " ")
      .replace(/<style\b[^>]*>[\s\S]*?<\/style>/giu, " ")
      .replace(/<!--[\s\S]*?-->/gu, " ")
      .replace(/<[^>]+>/gu, " ")
      .replace(/&nbsp;|&#160;|&#xA0;/giu, " "),
  ];
  const dates = new Set<string>();

  for (const text of textCandidates) {
    for (const match of text.matchAll(ITALIAN_DATE_REGEX)) {
      const day = match[1].padStart(2, "0");
      const monthName = match[2].toLocaleLowerCase("it-IT");
      const month = ITALIAN_MONTHS[monthName];
      if (!month) continue;

      const date = `${match[3]}-${month}-${day}`;
      if (isIsoCalendarDate(date)) dates.add(date);
    }
  }

  return [...dates].sort();
}

export function extractNextSearchPageUrl(
  html: string,
  currentPage: number,
): string | null {
  const $ = load(html);
  const candidates: Array<{ page: number; url: string }> = [];

  $("a[href]").each((_, element) => {
    const href = $(element).attr("href");
    if (!href) return;

    try {
      const url = new URL(href, BASE_URL);
      if (url.hostname !== "eventimolise.it") return;
      const match = url.pathname.match(/^\/search-results\/page\/(\d+)\/?$/);
      if (!match) return;
      const page = Number(match[1]);
      if (Number.isInteger(page) && page > currentPage) {
        candidates.push({ page, url: url.toString() });
      }
    } catch {
      // Ignore malformed links from the page.
    }
  });

  candidates.sort((left, right) => left.page - right.page);
  return candidates[0]?.url ?? null;
}

function localCalendarDate(now: Date, timeZone: string): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(now);

  const values = Object.fromEntries(
    parts.map((part) => [part.type, part.value]),
  );
  return `${values.year}-${values.month}-${values.day}`;
}

async function fetchText(
  url: string,
  fetchImpl: FetchLike,
): Promise<string> {
  const response = await fetchWithRetry(
    url,
    {
      headers: {
        Accept: "text/html,application/xhtml+xml",
        "User-Agent": "MoliseIs-ExternalEventsImporter/1.0",
      },
    },
    fetchImpl,
  );

  if (!response.ok) {
    throw new Error(`EventiMolise listing returned HTTP ${response.status}`);
  }

  return await response.text();
}

export async function discoverFutureStartDates(params: {
  now?: Date;
  fetchImpl?: FetchLike;
  maxPages?: number;
} = {}): Promise<DiscoveryResult> {
  const now = params.now ?? new Date();
  const fetchImpl = params.fetchImpl ?? fetch;
  const maxPages = params.maxPages ?? DEFAULT_MAX_SEARCH_PAGES;
  const today = localCalendarDate(now, "Europe/Rome");
  const dates = new Set<string>();
  const visited = new Set<string>();

  let page = 1;
  let url: string | null = SEARCH_RESULTS_URL;

  while (url && page <= maxPages && !visited.has(url)) {
    visited.add(url);
    const html = await fetchText(url, fetchImpl);

    for (const date of extractStartDatesFromSearchHtml(html)) {
      if (date >= today) dates.add(date);
    }

    url = extractNextSearchPageUrl(html, page);
    page += 1;
  }

  // A successful HTTP crawl that discovers zero dates is much more likely to
  // mean that EventiMolise changed its markup than that the importer genuinely
  // has nothing to do. Fail loudly instead of silently returning a successful
  // zero-import report for days or weeks.
  if (visited.size > 0 && dates.size === 0) {
    throw new Error(
      "EventiMolise discovery found no dates; source markup may have changed",
    );
  }

  return {
    dates: [...dates].sort(),
    pagesFetched: visited.size,
  };
}

function parseSourceUrl(value: unknown): string | null {
  const raw = asTrimmedString(value);
  if (!raw) return null;

  try {
    const url = new URL(raw);
    if (
      url.protocol !== "https:" ||
      url.hostname !== "eventimolise.it" ||
      !url.pathname.startsWith("/event/")
    ) {
      return null;
    }
    return url.toString();
  } catch {
    return null;
  }
}

export function isAllowedEventImageUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "https:" &&
      url.hostname === "eventimolise.it" &&
      url.pathname.startsWith("/wp-content/uploads/");
  } catch {
    return false;
  }
}

function parseEvent(
  value: unknown,
  requestedDate: string,
): EventiMoliseEvent | null {
  if (!isRecord(value)) return null;

  const id = value.id;
  const title = typeof value.title === "string" ? value.title.trim() : "";
  const time = asTrimmedString(value.time);
  const date = asTrimmedString(value.date);
  const url = parseSourceUrl(value.url);
  const rawImage = asTrimmedString(value.image);

  if (
    typeof id !== "number" ||
    !Number.isSafeInteger(id) ||
    id <= 0 ||
    !time ||
    !isClockTime(time) ||
    !date ||
    date !== requestedDate ||
    !isIsoCalendarDate(date) ||
    !url
  ) {
    return null;
  }

  const rawEndDate = asTrimmedString(value.end_date);
  const rawEndTime = asTrimmedString(value.end_time);
  const endDate = rawEndDate && isIsoCalendarDate(rawEndDate)
    ? rawEndDate
    : null;
  const endTime = rawEndTime && isClockTime(rawEndTime) ? rawEndTime : null;

  const rawLocations = asStringArray(value.locations);
  const location = asTrimmedString(value.location);
  const locations = rawLocations.length > 0
    ? rawLocations
    : location
    ? [location]
    : [];

  return {
    id,
    title,
    time,
    endTime,
    date,
    endDate,
    location,
    locations,
    categories: asStringArray(value.categories),
    organizers: asStringArray(value.organizers),
    url,
    image: rawImage && isAllowedEventImageUrl(rawImage) ? rawImage : null,
  };
}

export function parseEventsTodayPayload(
  value: unknown,
  requestedDate: string,
): EventiMoliseDateResult {
  if (
    !isRecord(value) || value.success !== true || !Array.isArray(value.events)
  ) {
    throw new Error(
      "EventiMolise events-today response has an unexpected shape",
    );
  }

  if (typeof value.date === "string" && value.date !== requestedDate) {
    throw new Error(
      "EventiMolise events-today response date does not match request",
    );
  }

  const events: EventiMoliseEvent[] = [];
  let invalidCount = 0;

  for (const rawEvent of value.events) {
    const event = parseEvent(rawEvent, requestedDate);
    if (event) events.push(event);
    else invalidCount += 1;
  }

  return { events, invalidCount };
}

export async function fetchEventsForDate(
  date: string,
  fetchImpl: FetchLike = fetch,
): Promise<EventiMoliseDateResult> {
  if (!isIsoCalendarDate(date)) {
    throw new Error("Invalid EventiMolise date");
  }

  const url = new URL(EVENTS_TODAY_URL);
  url.searchParams.set("date", date);

  const response = await fetchWithRetry(
    url,
    {
      headers: {
        Accept: "application/json",
        "User-Agent": "MoliseIs-ExternalEventsImporter/1.0",
      },
    },
    fetchImpl,
  );

  if (!response.ok) {
    throw new Error(`EventiMolise API returned HTTP ${response.status}`);
  }

  return parseEventsTodayPayload(await response.json(), date);
}
