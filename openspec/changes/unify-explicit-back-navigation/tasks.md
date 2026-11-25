# Tasks

## 1. Qualify the shared routing decision

- [ ] 1.1 Implement and unit-test the production decision in `lib/routing/back_navigation.dart` for source authority, predecessor, pop disposition, dispatch, and canonical Explore no-op. Use ordinary GoRouter pop and named Home. Leave denied or obsolete requests without a second dispatch.
- [ ] 1.2 Bind actions to the live route, owner and displayed identity. Reuse existing screen keys and shell ownership and add only the local imperative Page settings check. Verify saved callbacks with a popup, root coverage, branch changes before a frame, removal, A → B → A, equal rebuilds and restoration. Verify a refresh replacing the imperative result before build causes a no-op and a later fresh tap can pop.
- [ ] 1.3 Run routing regressions with `buildAppRouter` for standalone and pushed Settings, Login over Settings, standalone Login, Category, Search and Posts, Gallery over a retained branch and Home with a retained Explore detail. Assert the exact predecessor, route identity, retained state, query `q` and one live result. Interleave immediate refresh, redirect and a new push with pop; check repeated Home and a later independent navigation before a frame.

## 2. Connect the ordinary controls

- [ ] 2.1 Migrate Settings, ordinary Route Error, Gallery and Gallery Unavailable. Test both ordinary error actions, visibility and reuse of the same binding across leading and text. Verify unmatched and matched error routing, and preserve Gallery gesture and local controls.
- [ ] 2.2 Keep Dashboard account, visit, route generation, refresh and recovery authority. Delegate its terminal decision after existing checks and shared preflight. Test both AppBars, one revocation and dispatch, sign-out and stale view callbacks, a failed preflight and retained Settings beneath the Login replacement. Preserve logout.

## 3. Separate malformed Admin diagnostics from editor exit

- [ ] 3.1 Add the protected error sibling and redirect only when the existing ID codec rejects the editor parameter. Preserve diagnostics, original query and fragment, valid editor and named paths, New, and Save Progress. Verify that a historical malformed imperative entry restored to the original editor route renders the diagnostic without editor activation and retains protected predecessor-only Back. Narrow editor-specific admission after the existing auth and pending checks. Verify direct and named entry, ID boundary and encoding, foreign session hints, pushes, restoration, Sync and auth redirects.
- [ ] 3.2 On the dedicated Admin diagnostic route, connect the leading and text controls to one source-qualified predecessor-only action. With the real router exercise repeated and mixed explicit/system requests, a later independent Back, obsolete actions after replacement/disposal, synchronous commit and immediate refresh, same-key refresh before and after rebuild, and exact live result completion. Verify predictive cancel/commit and iOS swipe without a new platform Back owner.
- [ ] 3.3 Verify ownership over the exact Dashboard and dirty editor, with a controlled pending editor lookup and authorization revocation. Verify that a declaration removing an editor still respects its veto and that a permitted declaration manufactures no push result. Keep checkpoint, recovery, activation and editor exit policies intact.

## 4. Adopt native presentation and run compatibility checks

- [ ] 4.1 Adopt `material_ui.BackButton` with the existing API. Test Android, iOS, macOS, icon override, Italian and English, RTL, semantics, custom callback without GoRouter, backgrounds and explicit padding. Compare actual edge hits, semantic bounds and face/glyph placement in AppBar, SliverAppBar, SearchBar, Gallery, GeoMap, Dashboard and Editor hosts. Test desktop and document any constrained axes.
- [ ] 4.2 Run focused routing and widget regressions for protected editors, Save Progress, submission, Search, GeoMap and picker. Preserve direct stale-callback tests, feature-specific results and negative visibility. Check simulated system Back and physical predictive/cancel and native iOS swipe independently. Preserve NAV-01 and compare OpenSpec validation with the inherited canonical baseline.
