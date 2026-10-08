# main-navigation-shell Specification

## Purpose

Define persistent main navigation and navigation correctness for the Molise Is
stateful shell, including responsive chrome exposure, exact branch Back
semantics, `go_router` 18.x Semantics compatibility and supported restoration.

## Requirements

### Requirement: Every stateful-shell destination renders main navigation

Every destination owned by the `StatefulShellRoute` SHALL render the responsive
main navigation for the current window size. Chrome visibility SHALL NOT depend
on the current child path, route name or content type.

Compact and medium layouts SHALL use `ResponsiveNavigationBar`. Medium layouts
SHALL use horizontal destination labels and fixed destination widths. Expanded
and larger layouts SHALL use `AppNavigationRail`; the rail SHALL initially be
collapsed in expanded layouts and extended in large and larger layouts.

#### Scenario: Branch root is displayed

- **WHEN** Explore, Favourites, Events or Map root is visible
- **THEN** the corresponding main navigation destination is selected and the
  responsive navigation bar or rail is present

#### Scenario: Category is displayed

- **WHEN** a Category is visible under Explore, Favourites or Events
- **THEN** the owning section remains selected and main navigation remains
  present

#### Scenario: Post is displayed

- **WHEN** a Post is visible directly under a section, Category or Search
  Results
- **THEN** the owning section remains selected and main navigation remains
  present

#### Scenario: Search Results is displayed

- **WHEN** `/home/search_results?q=<query>` is visible
- **THEN** Explore remains selected and main navigation is present

#### Scenario: Map selection changes

- **WHEN** Map changes between default state and canonical selected content
- **THEN** Map remains selected and shell chrome does not change mode

### Requirement: Shell chrome requires no route-specific visibility state

`ScaffoldShell` SHALL NOT expose or consume a `showNavigation`-style flag, and
the router SHALL NOT maintain an equivalent path/name/metadata policy solely to
decide whether shell navigation is visible.

#### Scenario: Shell page builds

- **WHEN** the stateful shell page is built
- **THEN** its navigation bar or rail is rendered directly from window size and
  `StatefulNavigationShell.currentIndex`

#### Scenario: Child route changes inside a branch

- **WHEN** navigation moves among branch root, Category, Search Results and Post
- **THEN** no shell-level chrome visibility state is recalculated or toggled

### Requirement: Shell chrome remains exposed to accessibility semantics

Main navigation chrome and the active routed content SHALL coexist in the
Semantics tree on supported compact, medium, expanded and larger shell layouts.

#### Scenario: Compact shell route changes

- **WHEN** a compact shell navigates from a branch root to Category, Post or
  Search Results
- **THEN** the bottom navigation Semantics and active routed content Semantics
  remain exposed together with the owning section selected

#### Scenario: Expanded shell route changes

- **WHEN** an expanded shell navigates between a branch root and a nested shell
  destination
- **THEN** the navigation rail Semantics and active routed content Semantics
  remain exposed together

### Requirement: Gallery remains a full-screen root-owned route

Gallery SHALL remain outside the stateful branch Navigators and SHALL cover the
shell with an opaque full-screen root page when pushed. The retained shell
beneath Gallery SHALL keep its ordinary persistent chrome.

#### Scenario: Gallery is opened from a shell destination

- **WHEN** Gallery is pushed from Post, Category, Search Results, Map or a
  section root
- **THEN** Gallery occupies the full screen while the originating branch
  remains mounted with its shell chrome underneath

#### Scenario: Predictive Gallery pop is cancelled

- **WHEN** a predictive-back gesture over Gallery is cancelled
- **THEN** Gallery remains visible and neither the underlying route nor shell
  geometry/state changes

#### Scenario: Predictive Gallery pop is committed

- **WHEN** a predictive-back gesture over Gallery is committed
- **THEN** exactly Gallery is removed and the same originating shell
  destination is revealed with main navigation already present

### Requirement: Persistent chrome does not own navigation stack semantics

Rendering persistent main navigation SHALL NOT change Navigator ownership,
branch retention, declarative parentage or Back eligibility. Existing
`StatefulShellRoute`, `ShellRouteVisibility` and `BranchDetailPopScope`
responsibilities SHALL remain authoritative.

#### Scenario: User changes section from a detail

- **WHEN** the user selects another main section from Post, Category or Search
  Results
- **THEN** the destination branch becomes active without discarding the
  originating branch stack

#### Scenario: User returns to the originating section

- **WHEN** a retained branch containing Post, Category or Search Results is
  selected again
- **THEN** its retained route and state are restored

#### Scenario: User reselects the active section

- **WHEN** the user activates the already selected section while a non-root
  shell destination is visible
- **THEN** the existing `goBranch(initialLocation: true)` behavior resets that
  branch to its initial location

### Requirement: Predictive Back removes exactly one active branch level

Android predictive Back on a visible shell detail SHALL operate on the active
branch's declarative parent and SHALL NOT skip parent levels or mutate retained
inactive branches.

The Back contract SHALL identify the direct Post's section-root parent path,
the Category Post's Category parent path, or `/home/search_results` with the
original canonical `q` for Search Post. The presence or absence of `type` on a
parent URI after Back SHALL NOT be constrained; explicit `type` remains required
on the canonical Post URI before Back.

#### Scenario: Predictive Back commits from a direct Post

- **WHEN** predictive Back is committed from a direct Post
- **THEN** exactly that Post is removed and its section root is revealed

#### Scenario: Predictive Back commits from a Category Post

- **WHEN** predictive Back is committed from a Post nested under Category
- **THEN** exactly the Post is removed and the same Category is revealed

#### Scenario: Predictive Back commits from a Search Post

- **WHEN** predictive Back is committed from a Post nested under Search Results
- **THEN** exactly the Post is removed and Search Results is revealed with the
  same canonical `q`

#### Scenario: Predictive Back is cancelled from a branch Post

- **WHEN** a predictive-back gesture starts, progresses and is cancelled
- **THEN** the current URI, branch stack and visible Post state/identity remain
  unchanged

### Requirement: Compact shell chrome does not make content unreachable

On compact and medium layouts, persistent bottom navigation SHALL NOT make the
final meaningful or interactive content of Post, Category or Search Results
unreachable. Expanded layouts SHALL retain the existing rail/content
relationship.

#### Scenario: Post is scrolled to its end

- **WHEN** a compact or medium Post is scrolled to its final content
- **THEN** that content can be brought above the app navigation bar and used

#### Scenario: Category is scrolled to its end

- **WHEN** a compact or medium Category list/grid is scrolled to its final
  content
- **THEN** its final item/content can be brought above the app navigation bar
  and used

#### Scenario: Search Results is scrolled to its end

- **WHEN** compact or medium Search Results contains enough items to scroll
- **THEN** its final result can be brought above the app navigation bar and
  activated

#### Scenario: Expanded shell destination is displayed

- **WHEN** Post, Category or Search Results is displayed in an expanded window
  size
- **THEN** the navigation rail is visible without introducing a bottom-bar
  overlap workaround

### Requirement: Supported shell restoration preserves canonical route identity

Process restoration SHALL preserve the current supported shell branch,
declarative parentage and canonical query identity rather than restoring only a
coarser root path.

#### Scenario: Selected Map is restored

- **WHEN** a shell containing `/map?contentId=<id>&type=<type>` is restored
- **THEN** Map retains the same canonical `contentId` and `type` selection

#### Scenario: Search Post is restored

- **WHEN** a canonical Search Post with `q` and explicit `type` is restored
- **THEN** the same Post path, `q`, `type` and Search parent ancestry are
  reconstructed

#### Scenario: Back follows a restored Search Post parent

- **WHEN** Back is committed after restoring a Search Post
- **THEN** exactly the Post is removed and the restored Search Results parent
  remains with its original `q`

### Requirement: Upstream inactive-branch predictive-back behavior is not hidden by app changes

The application SHALL retain NAV-01 for the known inactive-`StatefulShellBranch`
system/predictive-back boundary tracked by flutter/flutter#188018 and
flutter/packages#11910. The expected invariant SHALL remain that an inactive
Post branch does not consume Map-root Back or change its retained stack/state.
The application SHALL NOT weaken that expectation or mutate hidden branch state
merely to make the regression pass.

At the approved 2026-10-07 baseline, this upstream gate remains open with
`go_router` 18.0.2: the unskipped probe returns `handlePopRoute() == true`, while
the inactive Post stack and mounted State identity remain unchanged. NAV-01 is
intentionally skipped and annotated; this is an unresolved upstream limitation,
not an application-implemented fix.

#### Scenario: Upstream defect still reproduces

- **WHEN** the resolved `go_router` version still exhibits the known inactive
  branch Back defect
- **THEN** the regression remains explicitly skipped/annotated with the exact
  expected behavior and no app-specific workaround is introduced

#### Scenario: Upstream behavior is fixed

- **WHEN** a future dependency release is resolved and the same regression
  passes for the intended branch-activity reason
- **THEN** the test is enabled without changing the expected branch-preservation
  contract
