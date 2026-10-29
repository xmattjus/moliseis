# Implementation verification

Verified on 2026-10-29 in timezone `Europe/Rome`.

## Scope and baseline

Implementation continues on `plan/harden-admin-dirty-exit` in PR #21, from planning commit `b028879273a7f1eb3afe01eca11a2c884880e6c5`. The original main baseline is `c7250f5db274c8b00af53cdd83846076918fd226`. Within PR #21, no backend, schema, dependency, generated model, tracked platform configuration or canonical specification changed. The primary checkout remains on main and clean.

After Android signing PR [#22](https://github.com/xmattjus/moliseis/pull/22) merged, the primary checkout was fast-forwarded to `5f51a39f59d73a5cc2ce68a6173871db39341874`. PR #21 rebased without conflicts from `ad0625e7949bdb6f5eb155c3bf873ffcc004637f` to `1359eb9e82bb646662bbdc00ca11abbe61602c9f`; range-diff and byte-for-byte patch comparison preserved all three original commits' changes. Push used an explicit remote-HEAD lease. The earlier follow-up changed the discard hydration notification, its focused regression and verification records. The later native OS-input follow-up below adds the narrowly scoped predictive-transition/readiness corrections; PR #21 remains Draft.

## Automated verification

- Flutter 3.47.5 / Dart 3.13.4; go_router 18.0.2, material_ui 1.5.0, command_it 9.5.2.
- Focused Admin/Public/domain/dialog run: **1,314 passed**. Subsequent final routing and restoration run: **111 passed**, including new obsolete-callback regressions.
- Pre-rebase implementation autonomous suite: **3,780 passed, 4 existing skips**, across **180 test files**. File selection follows `.github/workflows/pull-request.yml`, explicitly excluding `test/integration/`; `TZ=Europe/Rome`, `flutter test --no-pub --reporter expanded`.
- Post-rebase source including the discard-controller correction: **3,781 passed, 4 existing skips**, across **180 test files**, using the same autonomous-suite selection and Rome timezone. `flutter analyze --no-pub`: **No issues found**.
- Native acceptance follow-up, final source: **3,790 passed, 4 existing skips**, across the same **180 autonomous test files**; `TZ=Europe/Rome`, `--no-pub --reporter expanded --concurrency=2`, excluding `test/integration/`. The six focused Admin routing/ViewModel suites passed **184 tests**. Full `flutter analyze --no-pub`: **No issues found**. Initial disk-full test/build attempts were excluded from behavioral results; only ignored generated caches were removed.
- Analyzer before implementation and after original implementation changes: **No issues found** using `flutter analyze --no-pub`.
- `openspec validate harden-admin-dirty-exit --strict` and diff whitespace checks pass. Documentation links, task retention, path hygiene and protected-file scope are checked manually because this checkout has no dedicated documentation-audit command.
- The new worktree needed the ignored ObjectBox 5.3.2 test runtime. The existing primary-checkout binary was version-checked and copied into the ignored local runtime location; no tracked dependency/configuration changed.

Regression coverage includes reviewed A superseded before serialized entry (no write), B typed during an admitted A write (P/E=A, C=B dirty, no exit), C:=E with P different, recovery obligations and receipts/intents preserved, single-flight invocation ownership, invalid session hints refused before field effects, different-ID and query transitions, terminal Progress-only/full-stack navigation, auth revocation, authorized moderation, platform Back/Escape and responsive/focus/semantics checks. Shared dialog tests cover every requested width, both themes, default/2.0 text scaling and narrow landscape.

## Independent review and fixes

Independent adversarial review identified and verified corrections for terminal Progress full-stack removal, invalid resume hints mutating source work before refusal, and obsolete Back callbacks borrowing a replacement activation. Focused tests additionally caught notification during Navigator rebuild, unavailable pushed-page/source identity, and restoration-time route-state lookup. Source identity now comes from the router builder and actual page handles; stale callback regressions were executed RED then GREEN. Final static review has no outstanding material finding. Runtime results are the execution evidence above, not inferred from the review.

## Earlier native-runtime verification

All runtime smoke uses an explicitly local fake-auth/fake-repository fixture with the production router, widgets and application theme. It never invokes the production Supabase bootstrap and does not establish real backend authorization or native storage durability. Temporary drivers, service metadata, screenshots and logs are excluded from the repository.

| Platform | Actually verified | Remaining native acceptance |
| --- | --- | --- |
| iOS Simulator: iPhone 17 Pro, iOS 26.5; Xcode 26.6 | Pre-rebase implementation source `flutter build ios --simulator --debug --no-codesign` passed. Earlier local fixture launched; programmatic clean exit, dirty dialog, Cancel, local checkpoint exit and discard to E passed with zero exit-driven remote writes/uploads. | **NOT VERIFIED:** real edge gestures, physical AppBar taps, complete Progress interaction and iOS auth-revocation smoke. Progress reached the editor URI with newer dirty fields, but its rendering-readiness assertion timed out; this is not counted as a passed native scenario. UI automation was not reliable enough to establish gestures. |
| macOS 26.5.2 | Existing locked CocoaPods setup generated the missing workspace without tracked changes. Debug fixture build/process startup and six programmatic checks passed: clean exit, dirty dialog, Cancel, checkpoint exit, discard with zero remote work, and simulated auth revocation removing private UI. | **NOT VERIFIED:** foreground/OS keyboard interaction. Flutter reported `Failed to foreground app; open returned 1`; background runtime and widget-tree assertions still completed. |
| Android: existing Pixel 10 Pro AVD, Android 17 / API 37, arm64 | After PR #22, the rebased local fixture compiled and launched without release-signing properties. Corrected Dart source was hot-restarted. Programmatic native-runtime checks passed: clean New/Edit exit, dirty dialog, Cancel, local Save and Exit, effective-baseline Discard and Exit, obsolete Back callback after target replacement, Flutter `handlePopRoute` dispatch and simulated auth revocation. Exit scenarios made zero fake Create/Update/association/deletion/moderation/upload calls. | **NOT VERIFIED:** OS system Back, actual predictive edge-gesture start/cancel/commit, physical AppBar/dialog taps and native storage durability. The available UI-control surface could not expose the emulator window. Automated Flutter Back tests and native-runtime synthetic dispatch do not establish these native inputs. |

The iOS runtime smoke predates the original implementation's final callback/restoration guards; the pre-rebase iOS source was rebuilt successfully. The macOS fixture smoke used the pre-rebase implementation source. Neither platform was rerun for the discard-hydration follow-up.

### Android follow-up and discovered defect

A raw Navigator route covering the editor immediately after successful Discard caused the exit policy to refuse removal. Native-runtime inspection reproduced session C restored to E while the retained name controller still showed discarded text; the next edit reintroduced that text. The minimal correction increments the existing hydration revision after successful, still-owned discard, before notifying. A deterministic production-router widget regression failed on the stale name controller before the fix, then passed for both name/city controllers and subsequent typing. All 47 tests in the affected routing file pass. The same retained-name scenario passed in the corrected Android runtime with zero checkpoint or remote-mutation/upload calls. Independent follow-up review found no material defect.

Programmatic Android Progress checks used an explicitly admitted, Completer-controlled fake Update and matching fake readback: running Progress blocked Flutter Back dispatch, and completed/conflict terminal return removed only Progress while retaining newer dirty session fields without a second Update or parent dirty-exit dialog. The completed case performed exactly one intentional fake Update and no other mutation/upload. Initial temporary-driver attempts edited before Save capture or returned stale fake readback; they failed their completed-Save assertions and are not counted as completed-Save passes. The controlled rerun passed. These observations concern programmatic runtime/model behavior, not physical input or native persistence.

The first follow-up widget-test attempt failed because the local disk was full; it is not counted as behavioral RED. Only newly generated signing-worktree build outputs were removed to recover space, then the genuine controller-mismatch RED and GREEN runs were executed. Temporary fixture extensions, drivers, logs and runtime evidence remain outside tracked files.

## Native OS-input acceptance follow-up

This follow-up started at `03d041066a5ee3a7297db6679cd9312095902bfb`, with main at `5f51a39f59d73a5cc2ce68a6173871db39341874` and Android signing PR #22 merged. PR #21 remains Draft. The results below supersede the earlier platform-input limitations for Android and iOS, but not macOS.

### Environment and evidence boundary

- Android: existing Pixel 10 Pro AVD, Android 17 / API 37, arm64, gesture navigation mode 2, 1280×2856 pixels at 480 dpi. The debug fixture APK built and installed; final Dart source was hot-restarted in that native process.
- iOS: iPhone 17 Pro **Simulator**, iOS 26.5, 402×874 dp; Xcode 26.6 (17F113). The explicitly selected fake fixture built successfully; final Dart source was hot-restarted before the final XCUITest run.
- Host: macOS 26.5.2 (25F84). No physical handset was tested. Emulator/simulator OS input is reported as such, under the explicitly requested acceptance environment.
- All counted acceptance uses the existing repository fakes/harness with the production router, editor, dialog and theme. The local service extension observes C/E/P, route/animation authority and repository counters, and controls fixture authentication, recovery baselines and deferred responses. It does not inject the Back, touch, dialog-choice or Save events counted as native input. Newer fields underneath Progress and competing programmatic requests are explicitly controlled setup, not evidence of native typing there. These tests establish application behavior, not real backend authentication or native database durability.
- A discovery-only activation of an already installed iOS binary displayed public Explore. It was immediately stopped, with no taps, authentication entry or mutation actions. Its bootstrap/network behavior was not observed. It is excluded from acceptance; subsequent counted checks verified the explicitly rebuilt fake environment before input.

Android input used the installed SDK's `adb shell input`: `keyevent KEYCODE_BACK`, `tap`, `text`, Delete/Move-End keys and `touchscreen motionevent DOWN/MOVE/UP`. UI Automator supplied actual accessibility labels/bounds. Predictive tests held a touch at the left edge, moved x=1→40→120→250→450 at y=1500, then either released at 450 or reversed to 1 before release. `dumpsys activity service com.android.systemui/.SystemUIService WMShell` independently reported `mBackGestureStarted=true`, tracker `ACTIVE`, and `mTriggerBack=true`; reversal changed the trigger to false before release. A linear completed swipe or Flutter synthetic pop alone is not counted as cancellation evidence.

Apple input used a temporary XCUITest target: `XCUIElement.tap`, `typeText`, `swipeUp` and `XCUICoordinate.press(forDuration:thenDragTo:withVelocity:thenHoldForDuration:)`. Clean cancellation dragged x=1→80 at y=400, 250 px/s, then held 0.3 s; completion dragged to x=350. A passive Navigator gesture notifier and read-only route animation observations distinguish actual gesture initiation from a final retained route. No permanent UI-test framework or production dependency was added.

### Android acceptance

| Scenario | Input / controlled setup | Expected | Observed evidence | Result | Limitation |
| --- | --- | --- | --- | --- | --- |
| New/Edit launch and clean exit | Native dashboard card/New taps; OS `KEYCODE_BACK` | Open exact editor; clean exit without prompt/write | Editor/target observed, then dashboard; no exit checkpoint | PASS | AVD, fake data |
| Dirty System Back | Native name-field tap and keyboard events, then OS Back after IME dismissal | One three-choice dialog | Exact typed C retained; one owned dialog | PASS | Back hiding the IME is distinguished from route Back |
| Cancel | Native dialog tap; separately OS Back on modal | Retain fields and editor | C unchanged, no checkpoint or underlying pop | PASS | None beyond fixture boundary |
| Save and Exit | Native `Salva ed esci` tap | Checkpoint reviewed A locally, then exit | C=E=P=A, one checkpoint, zero remote calls | PASS | Persistence is the controlled local repository |
| Discard and Exit | Native AppBar and `Esci senza salvare` taps | Restore E without changing P or durable work | C=E; checkpoint count and remote counters unchanged | PASS | Durable metadata invariants also have deterministic domain coverage |
| Repeated Back | Two OS Back events from a native-opened modal | No shared permission or double-pop | Editor/fields retained, no extra checkpoint, no competing modal | PASS | Distinct later cancellation attempts may open a fresh decision |
| Clean predictive start | Native DOWN/MOVE held | Start actual system gesture | Android controller ACTIVE/trigger true | PASS | Emulator gesture, not physical handset |
| Clean predictive cancellation | Reverse MOVE to edge, then UP | Cancel without removal | Native trigger false before release; editor at animation 1 | PASS | No synthetic Flutter cancel used |
| Clean predictive completion | DOWN/MOVE then UP away from edge | Remove editor once | Dashboard, no field dialog or extra write | PASS | None beyond AVD |
| Dirty predictive start/cancel | Same held/reversed native touch with typed C | Retain unconfirmed work on cancellation | Native ACTIVE then trigger false; C unchanged, no dialog/write | PASS | None beyond AVD |
| Dirty predictive completion | Native edge completion, then modal Back/Cancel | Show owned decision; cancellation restores complete editor | One dialog, animation completed at 1, no gesture ownership or extra pop | PASS | Before-fix failure and correction described below |
| Running Progress | Native Save tap; controlled Update response held; System Back and edge completion | Running Save blocks removal without parent dialog/retry | Progress retained, exactly one admitted Update | PASS | Intentional fake remote Save, not exit-driven work |
| Terminal Progress return | Actual OS Back after controlled completion | Remove only Progress, preserving dirty parent | Newer prepared B retained, no parent dialog or second Update | PASS | B beneath Progress is explicit fixture setup |
| Deferred checkpoint and resume hint | Native checkpoint tap or controlled competing request; real edge start/cancel/commit in both operation orderings | Refusal must leave complete source and release only its owner | Animation 1, balanced gesture ownership, source retained while gate waits; clean native gesture works after settlement | PASS | Deferred writes/reads are controlled; no fake Back injection |
| Recovery and interrupted exit | Controlled accepted E over distinct P; native typing, modal Back/Discard, dashboard return and New tap | Preserve obligation through removal/return; refuse unsafe replacement | C restores E, P unchanged, same session/obligation retained; New refused without dialog; explicit native checkpoint settles proof | PASS | Recovery baseline is fixture setup |
| Auth during dialog and Progress | Native-opened presentation; fake signed-out event, then original deferred completion | Immediate removal of private UI; no stale publication | Login, no editor/dialog/Progress, current private state cleared; late completion stays private | PASS | Simulated auth event, no production service |

All exit-only Android runs recorded zero Create, Update, upload, association, deletion and moderation calls. Progress runs recorded only their intentionally admitted fake Update, with no exit retry or other mutation.

### iOS Simulator acceptance

| Scenario | Native input / controlled setup | Expected | Observed evidence | Result | Limitation |
| --- | --- | --- | --- | --- | --- |
| Clean swipe cancellation | Actual short XCUI edge drag/hold/release | Begin then cancel native interaction | Gesture count increments; source retained at animation 1 | PASS | Simulator touch |
| Clean swipe completion | Actual full XCUI edge drag | Keep clean native Back available | Gesture count increments again; dashboard reached | PASS | Simulator touch |
| Dirty edge refusal | Native field typing, then the same real edge drag | Block before gesture begins or reveals underlying page | `popGestureEnabled=false` before drag; gesture count unchanged, animation 1, editor retained without dialog | PASS | Passive notifier observes, never initiates, gestures |
| AppBar Back and Cancel | Actual AppBar/Cancel taps | Present shared choices; retain reviewed fields | Exact C retained, no write or route removal | PASS | None beyond fixture |
| Local Save and Exit | Actual dialog tap | One reviewed local checkpoint and exit | C/E/P agree, one local write, zero remote mutations/uploads | PASS | Fake local repository |
| Discard and Exit | Actual dialog tap | Restore effective fields | E restored without an extra checkpoint or remote call | PASS | None beyond fixture |
| Interrupted discard | Actual Discard tap with controlled covering-route interruption | Refuse removal while restoring appropriate fields | C/E and retained name/city controllers agree; no remote work | PASS | The temporary blank cover's later dismissal is excluded; obsolete callback identities are verified by routing regressions |
| Running Progress | Native swipes to actual Save control, Save tap, then edge drag | Admit Save once and block ongoing Progress Back | Progress remains while fake Update is held | PASS | Controlled backend response |
| Terminal Progress return | Actual `Torna all’editor` tap | Pop only Progress | Newer prepared fields retained, no parent dialog or duplicate Update | PASS | Newer fields beneath Progress are setup |
| Auth during dialog / running Progress | Native-opened presentation; fake sign-out and later response completion | Immediate private UI revocation | Login with no private editor/dialog/Progress; obsolete completion has no effect | PASS | No real backend auth claim |

The final frozen-source iOS XCUITest completed **1 test, 0 failures, 17.214 s**, with eight acceptance markers. The separately executed terminal-Progress touch test completed **1 test, 0 failures, 5.853 s**. The earlier Progress rendering-readiness timeout was resolved using controlled fake response timing and actual Save admission; no application rendering defect was established.

### macOS acceptance and remaining manual checks

| Scenario | Attempted native mechanism | Expected | Observed evidence | Result | Limitation |
| --- | --- | --- | --- | --- | --- |
| Editor Escape and modal Escape | Foreground activation, Accessibility/event APIs, temporary XCTest | Open decision; cancel only modal | No reliable native key delivery established | NOT VERIFIED | AX trust, event-post and event-listen preflight all false |
| Tab/Shift-Tab, Enter/Space, all choices and focus retention | Same OS automation mechanisms | Closed-loop focus; activate focused control only; no underlying pop | No native test method/input executed | NOT VERIFIED | XCTest runner could not connect |
| Representative native resizing/text scaling | Native foreground/window automation | Reachable actions and no platform overflow at representative sizes/scaling | Existing widget matrix remains separate; no native desktop result | NOT VERIFIED | Foreground UI control unavailable |
| Auth revocation during keyboard-owned presentation | Native keyboard presentation, then controlled auth event | Immediate retirement of private effects | Earlier programmatic macOS evidence retained; native presentation not established | NOT VERIFIED | Cannot substitute background model checks |

The explicit macOS fixture built and started, but Flutter foregrounding returned 1. `NSRunningApplication.activate` returned true while the app remained inactive; a console display session existed. Accessibility trust, event posting and event listening checks were false; Developer mode was disabled. The temporary macOS XCTest target built/launched but failed after **370.471 s** with “test runner hung before establishing connection,” before any test input. The existing CUA alternative also stalled and was cancelled. No system security policy or permission was changed.

Only the following manual scope remains: use an authorized foreground macOS session to (1) check editor/modal Escape, Tab/Shift-Tab containment and Enter/Space for Cancel/Save/Discard without an underlying pop; (2) resize representative 700/1300 dp windows and apply 2.0 text scaling, checking every action remains reachable; (3) revoke fixture auth during the owned dialog and Progress, including a late original response. Repeating Android/iOS touch checks or the complete widget responsiveness matrix is not a substitute for these desktop gaps.

### Native-discovered defect and correction

At the follow-up baseline, a real Android predictive commit followed by Cancel left the retained editor's animation at approximately **0.734897**, status `forward`, with native gesture eligibility false. Controlled Flutter regressions independently reproduced value **0.3**. An initial start-time guard did not cover the reverse ordering: a clean gesture could start before a checkpoint/hint barrier, or finish beneath an already owned dialog. Those orderings were also reproduced before correction.

The final fix stays in the existing Admin exit policy: normalize only the exact still-authorized, current Android source and unchanged route configuration, before guarded refusal/awaits and at non-leaving settlement. The public `handleStartBackGesture(progress: 1)` / `handleCancelBackGesture()` pair completes and balances synchronously; it grants no navigation permission. Clean admissible previews, iOS, Public, covered routes and stale activations are excluded. The experimental Android `PopScope` change was removed entirely.

Ordinary local checkpoints publish an identity-qualified exit-readiness obligation before suspension and release only their own token; their existing serialized snapshot selection is unchanged. Deferred resume-hint reads reuse the existing reviewed exit reservation and release it before a fresh incoming decision. There is no new coordinator, session manager, dependency or backend change. Independent final source review found no material issue; native execution and automated suite results remain separate evidence.

Seven predictive regression cases were exercised RED then GREEN, covering dirty cancellation, running Save, checkpoint/hint barriers in both orderings, and completion beneath an owned modal. The six focused router/ViewModel suites passed **184 tests**. Final full-suite/analyzer results are recorded in the automated-verification section.

## Remaining acceptance

**Task 5.3 remains unchecked: native acceptance NOT VERIFIED.** The available automated work is complete (21/22 tasks); Android and iOS OS-input acceptance is recorded above; required macOS keyboard/focus/scaling acceptance remains unsupported. This does not establish release readiness. PR #21 was not merged; no canonical-spec sync or archive was performed. No architectural scope deviation was required.
