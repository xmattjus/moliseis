# Design

## Context

See proposal.md for motivation and the three delta specifications for observable contracts. This document records the design intent implemented in [Draft PR #26](https://github.com/xmattjus/moliseis/pull/26). [tasks.md](tasks.md) records completed automated acceptance and the pending native gates 7.1–7.5; implementation does not imply native acceptance or release.

### Verified baseline and boundaries

Planning inspected `80223649dc09d94abc8d1558418ed257d4331906` on 2026-10-30 after fetching origin and fast-forwarding the clean primary main worktree from `ae6f9a2`. Definition lives on `docs/harden-sentry-consent-and-replay-privacy` in a dedicated worktree based on that commit. `openspec context` resolves that worktree, the configured schema is `spec-driven`, and no other active change remains. The previously superseded admin-editor proposal was explicitly retired upstream; do not recreate it.

Tracked `pubspec.lock` resolves sentry/sentry_flutter/sentry_supabase 10.0.0-rc.2, http 1.6.0, cronet_http 1.10.0, cupertino_http 3.1.0 and command_it 9.5.2. Installed matching package sources were inspected in the primary checkout. A new worktree does not contain its ignored package/build outputs; no dependency resolution or application tests were run there during definition. Previous investigation's 62 settings-related and 113 admin widget passes and network-free close probe are reported historical evidence, not fresh verification.

| Evidence at this commit | Design consequence |
| --- | --- |
| `lib/main.dart:49-73,88-120,146-159` initializes Sentry before Supabase/ObjectBox/settings, shares one HTTP instance, then closes only on startup opt-out | Read consent first and isolate resources before runtime close |
| `lib/utils/http_client.dart:9-45` uses one global fallback socket client | Independent wrappers alone are insufficient |
| `lib/config/dependencies.dart:85-105,261-267` supplies app HTTP/weather and Settings dependencies | Wire the bounded consent owner through existing Provider composition |
| `settings_repository_impl.dart:29-50,78-80` in `lib/data/repositories/` applies defaults on read error, updates cache after save success | Preserve fallback and persistence; keep telemetry eligibility separate |
| `lib/data/data-sources/app_settings.dart:10-17`, `settings_local_data_source.dart:21-42` default consent true; map expected persistence Exceptions to Result errors | Missing row differs from unreadable settings; no new store |
| `lib/ui/settings/view_models/settings_view_model.dart:37-57` reconciles shared flag after save even if disposed | Transfer only application lifecycle authority, never UI authority |
| `lib/ui/settings/widgets/settings_screen.dart:124-164` guards command admission, mounted/current owner and enable-only success | Reuse its accepted-run ownership and Snackbar path for both directions |
| `lib/utils/logging/app_logger.dart:57-64` gates only custom forwarding | Flag is an effective forwarding gate, not an SDK-state detector |
| `lib/ui/admin/submissions/widgets/admin_submission_list_item.dart:35-37` combines contributor/date | Separate rendered identity from date to preserve date visibility |
| `admin_submission_editor_screen.dart:1185-1209`, `admin_submission_editor_route.dart:188-194`, editor ViewModel `:106-107,1667-1673` under the same feature | Mask edit-mode contributor fields; retain authenticated create-mode account context |
| `lib/ui/content_submission/widgets/content_submission_screen.dart:517-568` already masks contributor fields | Reuse existing SentryMask behavior |

### Exact SDK behavior and native resolution

Source references below are relative to the installed version's package `lib/`, unless a native path is specified. Version-matched upstream package sources: https://github.com/getsentry/sentry-dart/tree/10.0.0-rc.2/packages . Installed source is the evidence used when individual web retrieval is unavailable.

- sentry `src/sentry.dart:297-304`: global facade becomes NoOpHub before awaiting the old hub. `isEnabled` describes that facade only.
- sentry `src/hub.dart:524-560`: sequential integration teardown precedes client close and old-hub disablement; no overall deadline. Integration errors can abort subsequent cleanup; client-close errors normally log and are swallowed.
- sentry `src/sentry_client.dart:538-544`: flushes telemetry then closes configured HTTP client. Shutdown can transmit buffered data. Existing captures, old-hub references and native workers can still act while teardown is pending.
- sentry_flutter `src/exception/flutter_error_integration.dart:110-117` and `on_error_integration.dart:98-105`: restore owned handlers; binding observer integration removes its observer. A startup Zone, where used, remains installed, but its old hub becomes disabled after successful teardown. Current mobile initialization prefers PlatformDispatcher when supported; do not assume all platforms run in the same Sentry Zone.
- sentry_flutter `src/sentry_widget.dart:31-45`: screenshot/interaction wrappers can remain mounted after close. Their presence does not initialize the SDK again. Test post-close input/rendering and error ownership rather than rebuilding the app root.
- sentry_flutter `src/native/native_sdk_integration.dart:47-62` and `src/native/sentry_native_invoker.dart:8-44`: native close errors are logged/swallowed outside automated test mode. There is no public native shutdown-status API. Never enable internal automatedTestMode in production or import private SDK internals to manufacture confirmation.
- sentry_flutter `src/native/java/sentry_native_java.dart:142-149` stops Replay/worker before channel close; `android/src/main/kotlin/io/sentry/flutter/SentryFlutterPlugin.kt:100-108` closes scopes and tears down Replay. `android/build.gradle:65` declares native Android 8.56.0; verify the actual Gradle-resolved build at native acceptance.
- Darwin `darwin/sentry_flutter/Sources/sentry_flutter/SentryFlutterPlugin.swift:405-408` calls `SentrySDK.close()`. SPM package manifest pins Cocoa 9.27.0. Runner links FlutterGeneratedPluginSwiftPackage (`ios/Runner.xcodeproj/project.pbxproj:197-199,225-227,759-767`); primary checkout's generated package references sentry_flutter 10.0.0-rc.2. Both Xcode project/workspace `swiftpm/Package.resolved` files pin Cocoa 9.27.0 at `aaf96c4a417d30208b3c25d90910d6156ddc973d`. Old CocoaPods metadata is not evidence of an active dependency defect. No new Xcode resolution/build was executed.
- sentry_flutter `src/native/c/binding.dart:771-784` documents backend-specific crash-handler retention and draining. This does not prove this app's Android/iOS path continues capture, nor prove all native handlers are removed.
- sentry_flutter `src/screen_capture/sentry_privacy_options.dart:35-47`, `widget_filter.dart:70-87`, `recorder.dart:257-258` implement marker-based screenshot obscuring before native recording. Widget placement alone does not prove native output.

### Existing specification reconciliation

Canonical `command-execution-concurrency/spec.md` requirement `Only authoritative completion can commit asynchronous data` expressly forbids new I/O during post-dispose consent reconciliation. That constraint was designed for a synchronous flag, not SDK shutdown. The delta copies the entire requirement/scenarios and introduces only the app-owned telemetry exception, retaining no-new-repository-phase and all presentation restrictions. It also extends `Ordinary operation feedback reflects the current execution` to distinguish saved preference from shutdown failure.

Archived `2026-10-25-migrate-simple-view-model-commands/design.md:390-402` and tasks 2.2/2.3 document the consent-cache repair and deliberately do not serialize Settings/Theme persistence. Archived `2026-10-25-simplify-migrated-view-model-commands` retains that boundary. Preserve those histories; do not retrofit them. No existing privacy or Sentry lifecycle capability duplicates these new capabilities. Existing admin-session, Save, exit and route contracts remain unchanged.

## Goals / Non-Goals

**Goals:** implement the approved direction using two independent HTTP ownership domains, a consent-first startup branch and one small application-owned consent operation. Expose saved preference, effective reporting and presentation optimism as distinct facts. Keep device evidence separate from mocked acceptance.

**Non-Goals:** no general lifecycle bus, event journal, second consent store, command framework rewrite, write-order redesign, new state-management system, custom privacy framework, new packages, automatic restart, runtime opt-in, SDK upgrade, backend change or opportunistic logger/network cleanup. Do not mask `Creato come` merely because its account identity resembles contributor fields.

## Decisions

### D1. Independent transport first

Keep the existing application HTTP factory/platform choices. Make each fallback factory invocation own a newly created `dart:io HttpClient` with the existing user agent, rather than wrapping the global fallback resource. Give Sentry its own client from this factory, never the app client or a decorator around it. Sentry then owns disposal of that telemetry client; app providers/Supabase retain their own client and existing disposal boundary. Keep platform HTTP2/cache/timeout behavior and public factory signature unless testing exposes a necessary bounded adjustment. For a newly allocated Cronet engine, set `closeEngine: true` so its sole client releases it: cronet_http 1.10.0 `lib/src/cronet_client.dart:728-733` otherwise defaults this to false. This is resource ownership, not a new networking policy.

This is smaller than a non-closing proxy (which obscures ownership), a new HTTP library or splitting all application services into new pools. Verify Cronet engine, Cupertino session and IO socket ownership, including when the platform factory falls back after an exception. Removing `options.httpClient = appClient` alone is insufficient while the fallback remains shared.

### D2. Resolve ObjectBox consent before telemetry

Initialize Flutter binding and local command logging, then create ObjectBox and initialize SettingsRepository once. Keep the existing setup-error handling if the store fails; consent is unknown so do not initialize Sentry to report that failure. On a successful settings read, including the existing missing-row default true, initialize Sentry only if consent is true. On read error, keep ordinary repository defaults but set effective telemetry eligibility false for this process. Do not equate the fallback true value with known consent.

Continue through one bounded normal-startup routine for Supabase initialization, anonymous-session establishment, cache/provider composition and runApp. Run it through Sentry's appRunner in the enabled branch and directly otherwise; avoid duplicating that application work. ObjectBox/settings construction moves before Supabase because neither requires Supabase, and this avoids any pre-consent SDK/native instrumentation of anonymous-session startup. Initialize the SDK only once and mount SentryWidget only in the enabled branch. Disabled/unknown startup must not initialize-then-close. Failures of Supabase retain existing behavior; no new anonymous-session policy is introduced.

Keep any Sentry-specific binding initialization behind eligibility where possible and preserve binding/Zone consistency. Existing code initializes the ordinary binding before SentryWidgetsFlutterBinding; the SDK returns an existing binding rather than replacing it. This change must not silently broaden into binding instrumentation repair.

### D3. One application-owned consent operation

Introduce one small application-scoped operation in `lib/domain/use_cases/` (working name `SetCrashReportingUseCase`), injected once from `config/dependencies.dart` into SettingsViewModel. It depends on SettingsRepository, the existing effective forwarding gate, and an injected asynchronous SDK-close callback, with no Sentry/data/UI imports in domain. A small immutable outcome distinguishes enabled-for-next-start, disabled, shutdown-unconfirmed and superseded/no-feedback; Result.error remains an expected persistence failure. The root supplies the SDK callback and initial effective state. Reuse existing Result and ordinary ResultCommand; do not add a service interface, lifecycle framework or parallel state store just for this operation. Exact public names are implementation details.

The operation owns the accepted repository write and its mandatory reconciliation after settlement. The ViewModel retains synchronous admission and optimism before invoking it. If disposed by an optimistic observer before persistence entry, start nothing. Once persistence starts, disposing/replacing Settings cannot cancel application reconciliation. On success or expected failure, inspect the repository's current committed consent, never the request argument or old owner's optimistic switch. Reconcile before awaiting any shutdown and recheck current intent for terminal feedback. Expected failed writes do not invent a consent change; concurrent successful writes remain authoritative.

Do not serialize repository writes across owners or other setting lanes. Dedupe only SDK teardown. If false is current when reconciliation runs, set forwarding false and synchronously latch the first close Future before yielding. If a later completion sees committed true before shutdown began, it must not close based on an obsolete false request. If shutdown was validly initiated while false was current, later true cannot undo it. All rechecks use current cache; a small current-intent token is allowed only to suppress ABA/stale feedback, not to claim request-order persistence. No persisted generation/journal is needed.

The operation distinguishes process reporting state: active, inactive (never initialized or closed), closing and shutdown-unconfirmed. The flag is true only while reporting is active and current consent permits it. Opt-in never changes an inactive/closing/unconfirmed process to active. It does not force an already-active process to stop. State belongs to the process, never to a Settings widget.

### D4. Shutdown settlement and honest failure

Use official `Sentry.close()` on independent resources. Cache the original physical Future; the facade's second close returning no-op cannot prove first-close completion. Observe it with a fixed 10-second deadline, tested with fake time rather than wall-clock sleeps. Timeout does not cancel native work. Retain and observe the physical Future after timeout so it cannot produce an unhandled late error or trigger overlapping close attempts. A late successful settlement can move application state to inactive but cannot replay feedback. Cupertino HTTP 3.1.0 `lib/src/cupertino_client.dart:204-211` can throw StateError when closed with running requests; SDK client-close swallowing also limits observation of telemetry-transport cleanup. Include this source-level case in transport/native diagnostics without confusing it with application-client ownership. A failed physical close remains unconfirmed for the process; subsequent facade no-ops cannot upgrade it to success. A fresh process with stored false never initializes telemetry.

Define effective revocation as completed shutdown under the verified native behavior, not the tap, optimistic switch, persistence completion or facade swap. Custom forwarding stops at committed opt-out; automatic/native work can have a bounded-observation teardown interval. Previously acquired telemetry may drain during close and cannot be recalled. Do not promise deletion of cached server/native data or zero post-tap traffic.

**SDK limitation:** public close completion and `Sentry.isEnabled == false` cannot detect internally swallowed native errors. Production cannot truthfully surface every such failure with current public APIs. The outcome handles observable errors/timeouts; native acceptance validates normal supported shutdown and failure behavior separately. This is a documented residual limitation, not a fabricated native success signal. No private imports, production test mode or speculative native bridge is planned. If native tests show continued new capture or make the required disable claim untenable, stop that release gate and review the smallest demonstrated platform remedy; a deferred-only Snackbar is not the fallback privacy fix. An SDK upgrade is not pre-authorized without a verified blocker.

### D5. Separate presentation outcome from persistence

SettingsViewModel's command can return the operation's typed outcome rather than void. Keep ordinary single-flight admission and existing lifecycle cleanup. Restore optimistic state from currently committed preference on expected persistence failure, not by negating a potentially stale value. Do not roll back false after shutdown failure: persistence succeeded. Unexpected throws retain raw command reporting; do not convert generic Object into Result.error. Keep existing late-error/disposal protections.

Use `showSnackBar` from `lib/ui/core/ui/custom_snack_bar.dart`, existing success treatment for both directions, and error treatment only for errors. Authorize feedback only for the original accepted operation, mounted/current non-disposed owner, and still-current intent. Enable success: `La segnalazione degli errori sarà attivata al prossimo avvio dell'app.` Disable success: `La segnalazione di nuovi errori è stata disattivata.`

Expected persistence failure: `Non è stato possibile salvare la preferenza. Riprova.` Saved preference but shutdown unconfirmed: `Preferenza salvata; arresto non confermato. Vale dal prossimo avvio.` Do not notify success on timeout, error, supersession or a joined/rejected duplicate. Do not replay error/success after returning to Settings. The existing Snackbar limits visible content to two lines (`custom_snack_bar.dart:114,221`); keep error copy concise and expose the complete saved-versus-effective status in the existing subtitle, testing narrow widths and text scaling rather than redesigning the shared component. Keep the existing switch/layout; adjust its subtitle only as needed so optimistic off, closing/unconfirmed and enabled-for-next-start do not assert an already-effective state. No dialogs, retry buttons or restart controls.

### Consent transition table

P = committed repository preference; E = process reporting state; UI optimism is separate. Current cache, not request/delivery order, governs reconciliation.

| Input / settlement | P | E and forwarding | Current eligible feedback |
| --- | --- | --- | --- |
| Successful startup read true / missing row | true | active after one init, forwarding on | none |
| Startup stored false | false | inactive, forwarding off, no init | none |
| Startup read failure | fallback true, unknown consent | inactive, forwarding off, no init | existing startup diagnostic only |
| ObjectBox failure | unavailable | no telemetry init; setup-error app | existing fallback |
| Opt-out save pending | unchanged | unchanged until commit | none; optimistic switch is not effective state |
| Opt-out commits while active/current false | false | closing, forwarding off | wait for shutdown observation |
| Successful shutdown | current P | inactive, forwarding off even if P later true | disable only if originating opt-out is still current |
| Opt-in commits while inactive/closing/unconfirmed | true | no initialization; forwarding stays off | next-start enable success if current |
| Opt-in while already active | true | active, no reinitialization | prescribed next-start preference copy |
| Expected save failure | unchanged by this attempt | reconcile any other committed write; no effect from failed argument | restore committed switch and error if current |
| Observable shutdown failure / deadline | false unless another write committed | unconfirmed, forwarding off; physical teardown retained | saved-preference error if current |
| Stale false delivery after current true, before close | true | no obsolete close | no stale feedback |
| Disposal/replacement during started write | actual committed value | application reconciliation continues | none from old owner |
| Duplicate/reentrant tap in one command | unchanged by refused attempt | no extra write or shutdown | none from refused attempt |

### D6. Exact Replay boundaries

Keep both global mask flags false and public form masks intact. In the dashboard, split the current combined name/date text into a simple bounded composition so only the name's rendered area is under SentryMask; retain date and list readability/accessibility. In edit mode wrap each optional contributor name/email Text individually. Do not wrap a whole card, editor form, sliver or public description. Leave `Creato come` unchanged: its provenance is authenticated administrator account context and the user explicitly approved retaining it. No custom masking rules/framework or new dependency.

Search for the same contributor fields found these display sites, not another direct UI identity path. Draft diagnostic `toString` records identity lengths (`lib/domain/models/content_submission_draft.dart:107-114`); no explicit raw contributor logging/URL interpolation was established. UI masking is not payload scrubbing; report any concrete additional leak rather than claiming universal privacy.

### D7. Verified unrelated-settings concurrency repair

The implementation request additionally authorized reproducing and fixing stale full-entity settings writes. Both a controllable data source and a real temporary ObjectBox store reproduced opt-out false being overwritten by an overlapping theme update. `SettingsLocalDataSource.update` now applies a synchronous field-only transform to the latest singleton in an ObjectBox write transaction; repository completion merges that same field change into current cache. Domain repository signatures and direct data-source save remain unchanged. This fixes the responsible persistence boundary without a write queue or request-order serialization. Focused real-store failure tests retain the previous committed opt-out.

## Risks / Trade-offs

- **Native errors can be swallowed** → distinguish SDK completion from native proof; require isolated Android/iOS gates, retain documented runtime observability limits. Never equate a flag with all-signal shutdown.
- **Bootstrap reorder moves local-store work before Supabase** → preserve one-time startup/error routines and anonymous-session behavior with ordered spies and fallback tests. Early local-store errors intentionally remain local when consent is unknown.
- **Saved default true after read failure differs from effective false** → separate eligibility from repository fallback; later opt-in remains deferred and copy must remain honest.
- **Irreversible shutdown races later enable** → current cache decides whether to begin close; once begun, no runtime re-enable. Preserve write-order semantics rather than inventing persistence serialization.
- **Long/hung shutdown** → 10-second observation, retained physical Future and distinct saved-preference error; no automatic retry/reset or leaked late errors.
- **Factory changes affect every fallback caller** → preserve user agent/platform policy and verify separate socket ownership, both existing and new requests, Supabase/auth/weather and image loading.
- **Mask wrapper layout/semantics drift** → widget boundary assertions plus narrow-screen/accessibility checks and actual Replay pixels with synthetic data.
- **Dependency metadata drift** → use tracked lock and active Xcode SPM chain, recheck actual native resolution at acceptance. Do not run upgrades to resolve stale unused Pods.

## Verification strategy

Definition-time baseline evidence is distinct from the executed implementation verification recorded in tasks.md. Reuse `test/support/settings_consent_support.dart`, `fake_repositories.dart`, `recording_sentry_transport.dart` and existing lifecycle harnesses. Before test edits, load repository unit/widget/test-support and mounted-context skills as applicable; ObjectBox tests use the real temporary-store harness. Add only the smallest bootstrap/lifecycle/transport seams needed for discriminating tests.

| Gate | Automated evidence to add or preserve |
| --- | --- |
| Settings persistence/lifecycle | Extend `test/ui/settings/view_models/settings_view_model_test.dart`, existing repository/local-source tests and a focused application-operation test: success/failure, both commit-vs-delivery orders, disposal before entry vs during write, replacement, duplicate/reentrant taps, raw throw remains raw, committed-value rollback |
| Shutdown state | Inject delayed/throwing/never-settling close; assert forwarding, one physical close, 10-second deadline, late success/error observation, false→true while closing, inactive enable remains deferred, no second-no-op false confirmation |
| Settings UI | Extend `test/ui/settings/widgets/settings_screen_test.dart`: exact both-success messages and same component/style, persistence error, saved-false shutdown error without rollback, subtitle timing, owner/mounted/intent checks; no error or success from stale/joined callers |
| Transport | Real Dart Sentry close with recording transport and independently owned local HTTP clients; controlled loopback server tests pending/subsequent requests. Exercise fallback directly, plus throwing-platform-factory path, without public-network dependencies or a dependency upgrade |
| Supabase/auth/application | Existing SDK clients against a local fake server: auth/session and application/weather request before/after close; image-cache client remains usable. This proves request survival, not real backend authentication correctness |
| Bootstrap | Focused startup policy/ordering tests: stored false, true, missing row, read failure, store failure; telemetry init counts, flag/root choice, preserved SetupErrorApp, Supabase/anonymous-session counts, fresh-process harness reads saved enable. Test the actual startup decision seam, not only a duplicated policy function |
| Caller compatibility | Update affected composition in `test/config/dependencies_test.dart`, `test/support/sync_harness.dart`, `ordinary_view_model_lifecycle_support.dart`, Settings constructors and routing test providers found by caller search; retain original late-error regression |
| Replay widgets | Extend dashboard/editor tests for name-only/date-visible masks, both optional edit identities, finalized display and unchanged create account context; preserve title/city/status/images and existing public form masks |
| Static/full regression | Run focused tests first, scoped format/analyze, then full `flutter test` for shared factory/bootstrap/composition impact. Record pre-existing diagnostics distinctly; no global lint fixes |

### Separate native release gates (not satisfied by automated rows)

1. Build the actually resolved Android/iOS app against an isolated telemetry project and synthetic submissions. Record package/native versions, platform/build mode and identifiers outside source; do not use production identities. Force deterministic Replay sampling only in the test configuration.
2. Before opt-out, prove the isolated destination receives controlled automatic errors and a Replay. Inspect public form, dashboard contributor/date and edit `Proposto da`; contributor identity must be unreadable while title, date, city, status and tourism image remain visible. Confirm approved `Creato come` visibility.
3. Persist opt-out during an active recorded session. Observe shutdown timing, app input/rendering with mounted SentryWidget, and Supabase/auth/weather/image requests. Trigger uniquely tagged framework, unhandled-Dart and native crash probes only after effective shutdown. Inspect received/cached envelopes, later relaunch and Replay timeline for new acquisition, separately identifying data captured before effective revocation. Native crash tests use separate controlled launches and recovery, not a production crash.
4. Enable again: no current-process reinitialization or forwarding when closed; terminate and launch a fresh process to verify activation. Resume/navigation/hot reload are negative controls.
5. Verify startup false/unreadable-consent policy on native builds and observable failure handling where platform fault injection is feasible. Public APIs do not expose every internally swallowed native failure; explicitly record that limit. Any observed continued new capture blocks immediate-disable acceptance and triggers a bounded reviewed correction, not a passing status or blanket mask/restart workaround.

Keep summaries and remaining limits in tasks.md when future execution is authorized. Temporary logs, analyzer dumps, test-generated recordings and synthetic telemetry identifiers stay outside the repository; do not create append-only investigation artifacts. No production credentials or secret-bearing SDK/network payloads belong in planning files.

## Migration Plan

No schema/data migration or backend deployment. After independent review and explicit apply authorization, implement independent transport first; prove ownership before wiring runtime close. Then add the bounded lifecycle operation, consent-first bootstrap and Settings outcome wiring, and selective masks. Run automated and native gates separately; unchecked native gates cannot be called complete. Normal release uses the existing app delivery path. Rollback is a cohesive code revert preserving saved settings; reverting the privacy fix reintroduces the original limitations and must not be described as retaining its guarantees. The subsequent implementation request authorizes apply, commits and a Draft PR, but not release, PR merge, spec sync or archive.

## Open Questions

No product decision is deferred: buffer draining is accepted, unknown consent fails closed for telemetry, first-install default stays true and create-mode administrator context remains visible. Remaining evidence gates are native shutdown/recording behavior and fresh build resolution, not permission to choose deferred-only opt-out, private SDK APIs or an upgrade. A failed gate requires a focused design update with concrete evidence before release; it does not justify speculative infrastructure now.
