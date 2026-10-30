# Tasks

Definition only: every checkbox below is unimplemented and unchecked. Apply requires a new explicit authorization after independent review. Native gates are separate from automated acceptance and cannot be inferred from mocked, flag or widget checks.

## 1. Independent HTTP ownership (prerequisite for runtime shutdown)

- [ ] 1.1 Make fallback HTTP factory calls own independent underlying socket clients and preserve existing platform selection/user agent and release each solely owned Cronet engine with its client; add focused tests proving one client can close without disabling another, including the platform-construction-failure fallback path.
- [ ] 1.2 Allocate a Sentry-owned client distinct from application/Supabase resources in startup composition; verify with an actual Dart Sentry close and local recording transport that telemetry disposal closes only its own client and repeated close is safe.
- [ ] 1.3 Verify pending and subsequent application HTTP requests survive telemetry close using controlled local-server tests, including Supabase/auth/session requests, weather and the image-cache client. Record which parts exercise real clients versus fake endpoints; require 1.1–1.3 before runtime close is wired into Settings.

## 2. Application-owned consent and shutdown

- [ ] 2.1 Add the single application-owned consent operation described in design D3 with Result persistence failure and distinct saved-preference/shutdown outcomes; unit-test current committed-cache reconciliation, no runtime enable, active/inactive state and forwarding-gate transitions.
- [ ] 2.2 Implement the one physical close Future and 10-second observation deadline without overlapping shutdown or false second-no-op success; use deterministic fake-time tests for success, rejection, timeout, late success/error and no reinitialization after false→true during close. Preserve raw unexpected-error policy; document public native-status limitations in the operation's API comments.
- [ ] 2.3 Prove both old/new-owner commit-versus-delivery orders with the existing deferred repository support, including stale false after committed true before close and valid false followed by true during close. Assert no new persistence serialization or request-order promise and no obsolete lifecycle decision.

## 3. Consent-first bootstrap and composition

- [ ] 3.1 Move ObjectBox/settings resolution before telemetry initialization using one shared normal-startup routine; add bootstrap ordering tests for stored true, stored false, missing row, read failure and ObjectBox failure, verifying initialization counts, root choice and existing SetupErrorApp behavior.
- [ ] 3.2 Keep unreadable-consent telemetry eligibility false independently of repository fallback defaults; verify normal Supabase initialization, anonymous-session behavior and cache/provider composition still execute once without telemetry, and a fresh-process harness activates a previously saved opt-in.
- [ ] 3.3 Inject one consent operation through existing Provider composition and update affected constructors/harnesses (`dependencies_test`, sync and ordinary-lifecycle support, Settings and routing test providers); run the affected composition/routing tests and verify no domain import of Sentry/data/UI or new dependency is introduced.

## 4. Settings behavior and feedback

- [ ] 4.1 Route the existing ordinary Settings command through the application operation while retaining optimism, single-flight admission and lifecycle cleanup; extend ViewModel tests for persistence rollback from current cache, failure, raw throw, duplicate/reentrant taps, disposal before entry versus during write, and replacement-owner shared reconciliation without late notification.
- [ ] 4.2 Use the existing Snackbar helper for both exact success messages and distinct persistence/shutdown error feedback; add widget tests proving identical success styling/eligibility, no saved-false rollback on shutdown failure, and no feedback after supersession, disposal, unmount, replacement or refused duplicate admission.
- [ ] 4.3 Keep the existing Settings layout while making subtitle timing honest for pending shutdown, shutdown-unconfirmed and next-start enable; verify narrow-screen and increased-text-scale rendering makes effective versus saved state understandable without dialogs, restart controls or truncated essential failure information.

## 5. Selective Replay protection

- [ ] 5.1 Separate dashboard contributor name from its date and mask only the name with the existing primitive; extend dashboard widget coverage to assert mask ancestry and visible date/title/city/type/status with usable layout and semantics.
- [ ] 5.2 Mask each present contributor name/email in edit-mode `Proposto da`, including finalized submissions; extend editor widget tests for both fields and optional-field branches while preserving descriptions, tourism images and editorial controls.
- [ ] 5.3 Preserve existing public-form masks, globally unmasked text/images and unmasked `Creato come` account context; add focused boundary regressions distinguishing create/edit provenance and inspect the affected contributor-field paths for concrete separate payload exposure without expanding into blanket masking.

## 6. Automated integration and regression acceptance

- [ ] 6.1 Run the focused lifecycle/bootstrap/HTTP/Settings/logger/admin tests from groups 1–5 together, preserving existing 62-test/113-test historical regression surfaces without claiming those prior counts as a fresh result; summarize actual commands, results and limits concisely in this file, with temporary output outside source.
- [ ] 6.2 Run scoped formatting/static analysis and the full Flutter test suite because factory/bootstrap/composition are shared; distinguish existing unrelated diagnostics from regressions, verify dependency/generated-file diffs remain intentional and run `git diff --check` plus strict OpenSpec validation.
- [ ] 6.3 Independently review the implemented connected paths and delta contracts for shutdown ownership, stale outcomes, persistence-versus-effective-state behavior, HTTP resource lifetime and mask scope; resolve material findings and rerun only affected checks before native acceptance is reported.

## 7. Native Android and iOS release acceptance (separate gates)

- [ ] 7.1 Produce controlled native builds with an isolated telemetry destination, synthetic identities and deterministic test-only Replay sampling; verify actual Android dependency resolution and iOS Xcode/SPM Cocoa pin, record platform/build mode, and establish positive pre-opt-out automatic-error and Replay controls without committing secrets or recordings.
- [ ] 7.2 On Android, verify official close and mounted-root usability, post-effective-shutdown framework/unhandled-Dart/native-error probes, continued app/Supabase/auth/weather/image networking and startup stored-false behavior; distinguish pre-revocation drains from new capture, including after later relaunch. Record observable failure behavior and internal-error visibility limits; continued new capture leaves this gate unmet.
- [ ] 7.3 On iOS, perform the same shutdown, post-revocation capture, networking, stored-false startup and drain-versus-new-acquisition checks against the active SPM build; do not infer success/failure from stale Pods or Dart facade state. Record actual native results and limitations separately from Android.
- [ ] 7.4 Inspect actual Android and iOS Replay pixels for synthetic identity masking in the public form, dashboard and `Proposto da`, with visible tourism titles/descriptions/images/date/city/status and unchanged `Creato come`; verify enable remains deferred through navigation/resume and takes effect only after full process restart.
- [ ] 7.5 Reconcile native and automated evidence against every acceptance scenario. Leave failed/unexecuted platform gates unchecked; if SDK limitations invalidate the required immediate-disable behavior, document the concrete failing path and obtain a bounded design correction before release rather than substituting deferred-only feedback, global masks or an unverified upgrade.
