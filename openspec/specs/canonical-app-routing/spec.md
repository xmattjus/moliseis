# canonical-app-routing Specification

## Purpose

Define the supported canonical Category, Post, Search and Map URI contracts
after retirement of the pre-2.3.0 routing compatibility layer.

## Requirements

### Requirement: Category routes use canonical slugs without numeric migration

Category routes SHALL use the current semantic slugs and SHALL NOT convert
legacy numeric category indexes.

#### Scenario: Canonical Category is opened

- **WHEN** a Category route uses one of the supported current slugs
- **THEN** the corresponding Category is displayed in its owning branch

#### Scenario: Legacy numeric Category is opened

- **WHEN** a Category path contains a former numeric index
- **THEN** no compatibility redirect converts it and the existing canonical
  validation/error behavior applies

### Requirement: Post routes require explicit canonical content type

Post routes SHALL identify content with a valid positive id and explicit
`type=event|place`. The router SHALL NOT derive type from `isEvent` and SHALL
NOT default a missing type to `place`.

#### Scenario: Canonical event Post is opened

- **WHEN** a valid Post URI contains `type=event`
- **THEN** the event Post is resolved through the existing current flow

#### Scenario: Canonical place Post is opened

- **WHEN** a valid Post URI contains `type=place`
- **THEN** the place Post is resolved through the existing current flow

#### Scenario: Post type is missing or legacy-only

- **WHEN** a Post URI omits `type` or supplies only former `isEvent` input
- **THEN** no compatibility rewrite/default is applied and the normal Post
  validation/error behavior applies

#### Scenario: Canonical Post has an unknown stale query key

- **WHEN** a Post URI already contains a valid canonical `type` plus a query
  key that has no current app-owned meaning
- **THEN** the router does not introduce a compatibility redirect solely to
  clean that unknown key

### Requirement: Search uses query parameter q

Search Results SHALL use `/home/search_results?q=<query>`. A Post beneath
Search SHALL preserve `q` while adding its canonical Post path and explicit
`type`. Legacy `search_results/:query` route definitions SHALL not remain
registered.

#### Scenario: Canonical Search is opened

- **WHEN** Search is navigated with an arbitrary encodable `q` value
- **THEN** that value round-trips through the canonical query parameter and
  Search Results are displayed

#### Scenario: Canonical Search Post is opened

- **WHEN** a Post is opened beneath Search Results
- **THEN** the canonical URI preserves `q`, Post id and explicit `type`

#### Scenario: Legacy path-embedded Search is opened

- **WHEN** an old `search_results/:query` or
  `search_results/:query/posts/:id` location is supplied
- **THEN** no compatibility route rewrites it and normal unmatched/error
  routing applies

### Requirement: Map selection uses canonical contentId and type without random-key migration

Map SHALL use no query parameters for its default state and
`contentId=<positive-id>&type=<event|place>` for canonical selected content.
The former random `key` query parameter SHALL have no app-owned routing
semantics or cleanup redirect.

#### Scenario: Canonical Map selection is opened

- **WHEN** Map receives a valid `contentId` and canonical `type`
- **THEN** that content is selected through the current Map parsing flow

#### Scenario: Default Map is opened

- **WHEN** Map has no canonical selection
- **THEN** the default unselected Map is displayed

#### Scenario: Legacy random key is present

- **WHEN** a Map URI carries only or additionally a former random `key`
- **THEN** the application does not canonicalize or interpret that key, and it
  cannot select or identify content

### Requirement: Legacy-only routing code is removed after the compatibility cutoff

The application SHALL remove route definitions, constants, parsers,
canonicalization helpers, comments and tests whose sole purpose was to migrate
the retired pre-2.3.0 Category, Post, Search or Map formats. Current canonical
helpers and route validation SHALL remain.

#### Scenario: Production routing is audited

- **WHEN** the compatibility retirement is complete
- **THEN** no production reference remains to the retired redirect/helper
  symbols while canonical Category/Post/Search/Map navigation still works

#### Scenario: Test support mirrors production

- **WHEN** production compatibility routes are removed
- **THEN** production-mirroring fixtures do not retain shadow legacy routes
  solely for old tests

### Requirement: Current canonical deep links and restoration remain supported

Removing historical canonicalization SHALL NOT change the branch ancestry,
selected section, content identity or supported restoration behavior of current
canonical routes.

#### Scenario: App starts from a current canonical detail link

- **WHEN** the router starts at a supported Category, Post, Search Post or Map
  selection URI
- **THEN** it reconstructs the same current branch ancestry and destination
  expected before legacy retirement

#### Scenario: Supported state is restored

- **WHEN** current-format shell/branch or Gallery restoration data is restored
- **THEN** it is processed without depending on any retired pre-2.3.0 route
  parser

#### Scenario: Sync returns to a canonical detail

- **WHEN** Sync preserves a valid current internal detail URI in `from`
- **THEN** its existing validation and return behavior continue to work
