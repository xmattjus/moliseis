# Native integration assessment — November 7, 2026

This is new source inspection for tasks 9.1–9.3, performed from planning
baseline `5f04486526756c124a655efccec52637384f4db1`. It is not a new native
runtime privacy pass. The archived investigation remains unchanged.

## Resolved sources and entry points

- `sentry_flutter` resolves to `10.0.0-rc.2`; its installed
  `darwin/sentry_flutter/Package.swift` pins Cocoa `9.27.0` and its
  `android/build.gradle` pins Android `8.56.0`.
- `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved` pins Cocoa
  revision `aaf96c4a417d30208b3c25d90910d6156ddc973d`. The inspected local
  Cocoa checkout reports exactly that HEAD, tag `9.27.0`, and a clean worktree.
- The Android `8.56.0` core JAR and Android/NDK AARs exist in the dependency
  cache. The version-tagged upstream sources below were also inspected.
- The application hosts contain no alternate telemetry initialization:
  `ios/Runner/AppDelegate.swift` registers plugins, and Android `MainActivity`
  extends `FlutterActivity`. Production initialization remains consent-gated
  in Dart. The installed Flutter plugin manifest removes `SentryInitProvider`.

Paths below beginning `lib/`, `darwin/` or `android/` identify files in the
installed `sentry_flutter` package, rather than application-owned files.

| Boundary | Entry and acquired fields | Available callback and ordering | Consequence |
| --- | --- | --- | --- |
| Cocoa NSError / bridged Swift Error | `SentryClient.m` `buildErrorEvent` / `exceptionForError`: underlying-error chain, optional debug/Swift description, NSError domain/code, mechanism description/data and `contexts["user info"]` | Cocoa public `Options.beforeSend` can transform the event. Flutter's `darwin/.../SentryFlutterPlugin.swift` `initNativeSdk` installs its own callback inside `SentrySDK.start`; that callback adds origin/SDK information. | Dart `beforeSend` is not this callback. PII-off does not gate these descriptions. Error domain is caller-controlled too; retaining it without review is not a bounded type policy. |
| Cocoa automatic crash recovery | `SentryStoredCrashReportProcessor` converts the stored report and invokes the hub's fatal-event capture. `SentryCrashReportConverter` restores exception reason/user-info, thread/queue names, frames and binary-image paths. | Native startup installs integrations; recovered reports enter the native event pipeline. Cocoa `SentryClient` executes native `beforeSend`, then native event processors. | A post-start callback replacement is too late to establish startup/recovery privacy. Thread names and absolute binary paths also require review; deleting descriptions alone is insufficient. |
| Android Java exception / uncaught exception | `SentryExceptionFactory` converts Throwable class/package, message, cause chain and stack frames. | Public Android options support `BeforeSendCallback` and processors. Flutter's internal JNI `configureAndroidOptions` calls `SentryFlutterPlugin.setupBeforeSend`, which installs the plugin callback. | Private Throwable text is independent of the Dart filter. There is no application callback argument in the installed Flutter options/configuration path. |
| Android NDK / outbox recovery | Native crash envelopes are recovered through `OutboxSender`; event items re-enter `captureEvent`, while other envelope items have separate handling. | Java `SentryClient` processes option processors and `beforeSend` for event capture. Flutter still owns initial options construction. | Java event tests alone cannot prove NDK attachment/cache privacy. A callback must be present before recovery starts, with final whole-envelope controls. |
| Dart event transported through native SDK | Flutter `captureEnvelope` sends an already built envelope to native transport; Cocoa plugin explicitly notes native `beforeSend` does not run for this entry. | Dart filter and native-origin callback protect different paths. | Native callback work cannot replace the Dart filter, and native enrichment tests cannot replace native-origin tests. |
| Shutdown and buffers | Flutter `NativeSdkIntegration.close` closes the native binding. Cocoa bridge calls `SentrySDK.close`; Android bridge calls `ScopesAdapter.getInstance().close`, after Replay teardown. | Existing consent owns SDK lifecycle. Native failures may be logged/swallowed outside automated test mode. | A facade success alone is insufficient evidence of cessation. Previously acquired cache delivery must be distinguished from new capture. No new shutdown guarantee was inferred here. |

Authoritative native sources:

- [Cocoa client and NSError conversion, 9.27.0](https://github.com/getsentry/sentry-cocoa/blob/9.27.0/Sources/Sentry/SentryClient.m)
- [Cocoa SDK startup, 9.27.0](https://github.com/getsentry/sentry-cocoa/blob/9.27.0/Sources/Sentry/SentrySDKInternal.m)
- [Cocoa stored-crash processing, 9.27.0](https://github.com/getsentry/sentry-cocoa/blob/9.27.0/Sources/Sentry/SentryStoredCrashReportProcessor.m)
- [Cocoa crash conversion, 9.27.0](https://github.com/getsentry/sentry-cocoa/blob/9.27.0/Sources/Sentry/SentryCrashReportConverter.m)
- [Cocoa public SDK API, 9.27.0](https://github.com/getsentry/sentry-cocoa/blob/9.27.0/Sources/Swift/Helper/SentrySDK.swift)
- [Cocoa private global processor, 9.27.0](https://github.com/getsentry/sentry-cocoa/blob/9.27.0/Sources/Swift/Integrations/SentryGlobalEventProcessor.swift)
- [Android initialization, 8.56.0](https://github.com/getsentry/sentry-java/blob/8.56.0/sentry-android-core/src/main/java/io/sentry/android/core/SentryAndroid.java)
- [Android exception conversion, 8.56.0](https://github.com/getsentry/sentry-java/blob/8.56.0/sentry/src/main/java/io/sentry/SentryExceptionFactory.java)
- [Android event processing, 8.56.0](https://github.com/getsentry/sentry-java/blob/8.56.0/sentry/src/main/java/io/sentry/SentryClient.java)
- [Android outbox recovery, 8.56.0](https://github.com/getsentry/sentry-java/blob/8.56.0/sentry/src/main/java/io/sentry/OutboxSender.java)

## Integration decision and affected-task stop

The owner subsequently instructed: “Keep this evidence, do not make any
changes to the SDK native reporting.” Native production code therefore remains
unchanged by explicit disposition. This is not a waiver or pass for native
privacy acceptance; any later implementation requires renewed scope authority.


**Task 9.2 is blocked by the integration mechanism, not by an unavailable
simulator.** No production native edits were made. The installed
`SentryFlutterOptions` has no native options-configuration callback; inspecting
the complete Android plugin methods and static companion confirms there is no
application customization registration hook hidden beside `setupBeforeSend`.
Cocoa public SDK API configures options at `start`; its global processor and
current-options access are private SPI. Android permits modifying current
options, but doing so after Flutter initialization leaves a recovery/startup
window. Replacing callbacks after startup, polling, swizzling, intercepting the
plugin channel or using private JNI/SPI access would not establish a reliable
supported privacy boundary.

The supported Flutter `autoInitializeNativeSdk=false` escape hatch is designed
for an already initialized native SDK. Using it here would transfer native
initialization and configuration into an application-owned bridge. Startup
before Dart consent resolution would violate the persisted-consent contract;
consent-gated startup afterward would need a reviewed bridge that preserves
Replay, trace/scope synchronization, SDK metadata, crash recovery and shutdown.
That is a substantial integration change requiring explicit authorization.

The smallest recommended next decision is to authorize a supported pre-start
native-options hook in the Flutter integration, preferably upstream, and its
version/pin policy. A dependency fork/upgrade is not silently introduced. The
alternative is an explicitly approved consent-gated application-owned native
initialization bridge. Neither disabling native crashes nor applying only the
Dart sanitizer meets the requirement.

Once that hook exists, choose a field contract in the native callback: exclude
exception descriptions/values, arbitrary NSError domains/user-info/mechanism
data, user/tags/extra/request content and unreviewed breadcrumb/attachment
payloads; retain reviewed exception identity, numeric error codes, mechanism
handled/fatal classification, correlation, release/platform and normalized
technical thread/frame/image identities. This is a required review checklist,
not an implemented or verified sanitizer. Existing callback origin/SDK work
must be composed rather than discarded. Cached envelopes require their own
controls because event reconstruction is not attachment filtering.

Task 9.1 has source and mechanism assessment evidence, but no accepted
implementable mitigation selection. Tasks 9.2 and 9.3 remain uncompleted. The
expanded native privacy guarantee remains unmet; historical NSError evidence
is not counted as new verification.

## Runtime availability and smallest subsequent acceptance procedure

Read-only inventories were executed on November 7. Initially sandboxed
`xcrun simctl list devices booted` failed to connect to CoreSimulator. The same
inventory with authorized host access succeeded: iOS 26.5 is installed and no
simulator is booted. `xcrun simctl list devices available` lists iPhone/iPad
simulators. `adb devices -l` lists no attached Android device;
`emulator -list-avds` lists `Pixel_10_Pro`. Thus neither platform is established
as unavailable; no new native app, crash, relaunch or envelope test was run
while the integration choice is blocked. No telemetry was sent to production.

After the integration decision and implementation, the owner/test runner must:

1. Launch isolated synthetic test processes on Android and iOS using only a
   local envelope receiver/fake DSN and a dedicated cache directory. Reuse the
   existing native consent integration harness; never import production
   credentials. First establish a transported positive event control.
2. Emit native nonfatal errors with canaries separately in exception values,
   NSError debug description/user-info/domain/mechanism data, scope fields,
   names/paths and attachments. Decode final native envelopes; assert event,
   type/code, safe frames/threads/images and correlation survive, with zero
   private canaries across all envelope items.
3. Cause representative Android Java RuntimeException and iOS native crash
   in dedicated test processes, then relaunch against the same isolated
   destination/cache. Verify positive automatic crash/recovery acquisition
   and filtering before asserting absence. Keep Java/NDK and simulator/device/
   debug/release evidence distinct.
4. Repeat before and after persisted opt-out and effective SDK shutdown,
   retaining valid observation/recovery for both old buffered events and new
   probes. Verify ordinary networking and local diagnostics remain usable.
   Run deferred opt-in/fresh-process and framework-error controls separately.
5. Record tested SHA, native/Dart SDK pins, platform/build, event counts,
   field utility/loss and the remaining unobserved mechanisms. Keep 9.3 open
   until both mandatory platform controls succeed.

No production safeguards were weakened, dependencies changed, native APIs
replaced, or runtime privacy acceptance claimed by this assessment.
