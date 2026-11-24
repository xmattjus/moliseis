# Image rendering implementation evidence

This records deterministic checks of the PR #44 implementation, using Flutter
3.47.5 and cached_network_image_ce 4.13.1. The implementation was first built
on planning PR #43 head `5707389`; #43 has since merged to `main` as `a872161`,
which is PR #44's base. It supplements, rather than reuses as acceptance, the
historical experiments.

## Provider contract and checked sources

`BoundedCoverImage` delegates acquisition and codec/completer ownership to the
original provider. Its immutable key includes the resolved source key and both
physical target dimensions. Stock `ResizeImage` uses a different key type.
Equivalent retained requests reuse decoding; incompatible fit/cover requests and
different targets remain isolated even when the output ceiling produces equal
sizes. No target is passed as a disk-resize argument.

The implementation follows the checked SDK `painting/image_provider.dart`
`ResizeImage.loadImage` decoder delegation and ephemeral outer-key error
eviction. It intentionally uses the source Future's `then` directly: this keeps
FileImage and CachedNetworkImageProvider synchronous keys synchronous while also
forwarding asynchronous key errors (covered with a synthetic provider). The
production providers inspected return SynchronousFuture keys; the synthetic
error does not establish a production key failure.

The checked FileImage implementation acquires a buffer from its owned file;
cached_network_image_ce's IO loader acquires bytes through the existing manager
and forwards its decoder callback. Its default `animate: true` and 100ms minimum
GIF frame duration remain untouched. Existing source eviction is preserved;
failed outer keys are also evicted with a microtask and an ephemeral listener,
which does not keep an unused stream alive. Tests release listeners and assert
zero pending/live entries after completion and error recovery.

`dart:ui` target sizing sees codec-reported intrinsic dimensions. The committed
400×300 JPEG EXIF orientation-6 fixture decodes to 86×115, confirming oriented
300×400 dimensions on the software test codec. Other codec/platform combinations
remain subject to device verification. The engine's
`lib/ui/painting/image_descriptor.cc` passes target dimensions to SingleFrameCodec
but constructs MultiFrameCodec with its generator alone. The two-frame 1800×2 GIF
fixture requests 1728×2 and still produces 1800×2 frames; both frames retain
100ms duration and different pixels. This is a codec compatibility limitation,
not an observed-output guarantee or an animated-process-memory bound.

## Reproducible decoding checks

Run:

```
flutter test --no-pub test/ui/core/ui/media/bounded_cover_image_test.dart
flutter test --no-pub test/ui/content_submission/widgets/content_submission_file_thumbnail_test.dart
```

Fixtures are generated as real opaque RGBA PNGs. Rows below summarize tested
outputs; estimated bytes assume RGBA8888 (4 bytes/pixel). They exclude compressed
source buffers, temporary codec allocations, native caches, process and GPU
memory. Full-resolution behavior remains the original provider request, subject
to the codec/backend; no bounded-cover ceiling is applied in the gallery.

| PNG intrinsic | Physical target | Old fit | Bounded cover | Cover pixels | Cover bytes |
| --- | --- | --- | --- | ---: | ---: |
| 4000×3000 | 864×864 | 864×648 | 1152×864 | 995328 | 3981312 |
| 4000×3000 | 1728×1728 | 1728×1296 | 1728×1296 | 2239488 | 8957952 |
| 12000×1000 | 258×258 | 258×21 | 1728×144 | 248832 | 995328 |
| 12000×1000 | 864×864 | 864×72 | 1728×144 | 248832 | 995328 |
| 12000×1000 | 1728×1728 | 1728×144 | 1728×144 | 248832 | 995328 |
| 1000×12000 | 258/864/1728 square | transpose of above | 144×1728 | 248832 | 995328 |
| 4000×4000 | 1728×1728 | 1728×1728 | 1728×1728 | 2985984 | 11943936 |
| 16×8 | 86/172/226/258 square | 16×8 | 16×8 | 128 | 512 |

The full-resolution comparison also observes 12000×1000 and 1000×12000 PNGs
at their intrinsic dimensions on this software codec (12000000 pixels /
48000000 estimated bytes), and 4000×4000 at intrinsic dimensions (16000000
pixels / 64000000 estimated bytes). Those observations do not establish a
physical backend texture limit.

The real local consumer keeps an 86×86 logical slot. Its ordinary 400×300 PNG
matrix observes the following physical requests and actual output:

| Slot | DPR | Physical target | Expected/observed cover | Pixels | Estimated RGBA bytes |
| --- | ---: | --- | --- | ---: | ---: |
| 86×86 | 1 | 86×86 | 115×86 | 9890 | 39560 |
| 86×86 | 2 | 172×172 | 230×172 | 39560 | 158240 |
| 86×86 | 2.625 | 226×226 | 302×226 | 68252 | 273008 |
| 86×86 | 3 | 258×258 | 344×258 | 88752 | 355008 |

The actual RawImage dimensions match the decoder frame, the rendered square
stays 86×86, and applyBoxFit produces a square crop filling the destination for
each tested ratio. Source substitution and disposal reject captured obsolete
error builders. Missing, empty, corrupt and unreadable sources retain the same
slot and exactly one neutral semantics label; logs retain the cause and stack
with the fixed `staged-local-image` event source and do not repeat on rebuild.
The unreadable fixture uses a directory at the image path so the result is
consistent even when CI privileges bypass ordinary permission bits.

The committed 400×300 JPEG with EXIF orientation 6 at an 86×86 physical target
decodes to 86×115 (9890 pixels / 39560 estimated bytes), confirming that the
oriented 300×400 dimensions drive cover sizing on the software test codec.

Network consumers use the same provider through `AppNetworkImage` and the real
`CachedNetworkImageProvider`. `app_network_image_lifecycle_test.dart` asserts
these actual RawImage outputs (PNG sources, DPR 2, unchanged buckets):

| PNG intrinsic | Logical slot | Bucket | Fit | Old fit | Observed output | Pixels | Estimated RGBA bytes |
| --- | --- | --- | --- | --- | --- | ---: | ---: |
| 4000×3000 | 86×86 | 216×216 | cover | 216×162 | 288×216 | 62208 | 248832 |
| 4000×3000 | 300×300 | 720×720 | cover | 720×540 | 960×720 | 691200 | 2764800 |
| 4000×3000 | 300×300 | 720×720 | contain | 720×540 | 720×540 (stock fit) | 388800 | 1555200 |
| 2400×2400 | 1000×1000 | 1728×1728 | cover | 1728×1728 | 1728×1728 | 2985984 | 11943936 |
| 2400×2400 | gallery | none | contain | 2400×2400 | 2400×2400 (full resolution) | 5760000 | 23040000 |

The full-resolution 4000×3000 decode observed by the interoperability test is
4000×3000: 12000000 pixels and an estimated 48000000-byte buffer. The ordinary
864-square fit is 559872 pixels / 2239488 bytes; bounded cover is 995328 pixels /
3981312 bytes. The extra detail is later cropped. The 1728 output bound accepts
short-axis enlargement for panoramas and ordinary 1728-square requests.

Pure sizing covers 1:1, 4:3, 3:4, 4:1, 1:4, both extreme panorama orientations,
small/one-pixel-axis sources, square and nonsquare targets and DPR 1/2/2.625/3.
Real decoder cases include both panorama orientations at 258/864/1728 square,
ordinary 864 cover and 1728 bound, and full square coverage. The same source is
decoded through cover→fit and fit→cover sequences with exactly two decodes per
retained pair. One-pixel ceil guards are tested as intersecting per-axis scale
intervals; they are not independent geometric resizing.

## Released default-cache cohorts

The test clears the cache between cohorts, preserves the default 100MiB/1000
entry limits and uses the same files/order for each fit/cover comparison. Every
first-frame listener and ImageInfo is released before the next request. The
revisit traverses the same order. There is no manager or HTTP activity in these
local-file cohorts: these are decoder/ImageCache measurements.

| Cohort at 864 square | Policy | Decoded size | Retained entries | Retained estimated bytes | Live/pending | Revisit decodes |
| --- | --- | --- | ---: | ---: | --- | ---: |
| 20 distinct 12000×1000 PNGs | fit | 864×72 | 20 | 4976640 | 0/0 | 0 |
| same 20 files | bounded cover | 1728×144 | 20 | 19906560 | 0/0 | 0 |
| 30 distinct 4000×3000 PNGs | fit | 864×648 | 30 | 67184640 | 0/0 | 0 |
| same 30 files | bounded cover | 1152×864 | 26 | 103514112 | 0/0 | 30 |

The same released panorama test also runs clean cohorts of 1, 5 and 10 identities;
each retains its complete working set, returns live/pending to zero and performs
zero revisit decodes for both policies.

The ordinary cover cohort exceeds default retained capacity. Sequential revisit
then evicts the next needed older entries and decodes all thirty again. This is
an observed cache-pressure cost, not an assumed cache-hit parity or a measured
user-visible performance regression. Physical normal-photo-density acceptance
must assess its effect. No cache limit or acquisition policy was changed.

## Network acquisition and effective requests

`network_image_acquisition_test.dart` uses the installed real default manager,
real HTTP over loopback, a temporary original-file disk cache, and equal
fit/cover sequences. Manager reads are recorded separately from server sends.
Both pipelines observed:

| Condition | Manager reads | HTTP sends |
| --- | ---: | ---: |
| First 864-square decode, cold original | 1 | 1 |
| Retained equivalent decode | 0 additional | 0 additional |
| New 432-square decode, warm original | 1 additional | 0 additional |
| Concurrent cold 864/864/432 | 2 | 2 |
| Deterministically expired original, refresh | 1 | 1 |

URL, null explicit cache key, and original on-disk path are preserved across
sizes. Equivalent pending requests share their decoded stream; different sizes
need not coalesce acquisition. The expiry fixture stores the original with an
already elapsed validity interval and observes the refresh frame/HTTP request.
There is no size-derived persistent variant or new manager configuration.

`AppNetworkImage` fences source/manager/bucket/fit/full-resolution replacements
with a per-request identity. Its loading bool is deduplicated; success and
handled failure settle false. Tests cover actual late acquisitions, captured
obsolete/disposed builders, retained synchronous hits, same-URL target/fit
replacement, actual cover/contain outputs, and unbucketed gallery output.
The 1000-square logical/DPR2 test observes 1728-square bounded decoding and
2400-square full-resolution decoding from the same source. Display enlargement
above the bucket remains intentional. Fade duration/curve and synchronous-hit
bypass are preserved; full-resolution retains its original no-fade behavior.

The real network provider also plays both different-pixel frames of the committed
1800×2 GIF through bounded and full-resolution widgets, with one manager
acquisition and loading transitions `[true, false]`. Observed frame dimensions
remain 1800×2 on this codec, independently of the 1728 requested ceiling.

## Empty states and image errors

`EmptyView` remains generic, with all three constructors and widget-valued
fields unchanged. A standard non-primary shrink-wrapped vertical scrollview
preserves centered content when it fits and exposes overflowing content/actions.
In unbounded sliver hosts it has a finite content-sized viewport and zero scroll
extent, rather than an unbounded nested viewport. This also supports intrinsic
measurement without LayoutBuilder or custom render-object exceptions.

`ImageErrorPlaceholder` alone owns the fixed image-unavailable label. It measures
the actual styled/scaled text at available width: normal EmptyView is used at
width ≥104 and height ≥96 + measured label height. Otherwise a single centered
broken-image icon, positive and ≤40 within both positive slot axes, is used
without scrolling. One semantic boundary excludes only this noninteractive
composition's decorative descendants. Arbitrary action-bearing EmptyView
semantics remain intact.

Tests assert actual icon/label rectangles for 32/48/72/86 squares at scale1/2,
±0.01 height fit boundaries, minimum width, RTL, accessibility spacing/bold and
custom typography. Spacious icon/text/action rectangles equal the original
composition. The actual NearbyContentHorizontalList inner 320×216 error at
scale2 scrolls to its ≥48px retry target and activates its callback through tap,
Tab/Enter and semantics. SliverToBoxAdapter, intrinsic SliverFillRemaining and
small action viewports are covered. The real gallery under the light app theme
uses the existing photo-viewer theme for its image subtree; its error icon/text
contrast against black exceeds 3:1/4.5:1, with one accessible description.

## Current acceptance status

See [Physical Android Profile acceptance](#physical-android-profile-acceptance--2026-11-24)
for the current PR head, native results, Definition of Done and remaining
gates. The handoff and remediation records below describe earlier runs.

## Native functional compatibility

`flutter build ios --simulator --debug --no-pub` succeeded with Xcode 26.6.
`flutter test --no-pub integration_test/image_presentation_test.dart -d <simulator>`
passed both tests on iPhone 17 Pro / iOS 26.5 Simulator. The native tests verify
the actual local cover output/crop and terminal network-error loading, compact
geometry and unique semantics. These are functional simulator observations,
not physical memory/GPU/Profile results. No production credentials or bootstrap
are required by that test target.

## Verification and handoff

The implementation branch was created from planning PR #43 head `5707389`
while `main` was `8865564`. #43 has since merged (`a872161`), and PR #44 now
targets `main` directly.
No backend, domain, staging, upload, persistence, bucket/cache limits or dependency
inputs changed. Source media dimensions remain in their domain/navigation models;
only the six AppNetworkImage call sites drop unused width/height metadata.

The slideshow keeps slot handles and live-child/request leases locally. Current
readiness is invalidated on remount/request replacement and revoked on slot
replacement/reorder/removal, including ABA and in-place list changes. Deferred
publication schedules a frame and reads latest authority. A State-lifetime ticker,
rebound visibility listener and Future-owned gallery pause share one admission
gate. Nineteen slideshow tests (after the remediation below) include actual
provider decode/error, failed and evicted B remount, synchronous cached remount,
bucket/DPR/cache-manager replacement, offscreen completion, ABA/reorder,
partial changes, queued callbacks, visibility, manual pause, count changes and
gallery return/error/disposal. Its local
page State exists to own the child lifetime, not as another application state
layer; the cohesive owner code stays in one file despite the file-size heuristic.

Initial implementation handoff (2026-11-15, historical) commands and
observations:

- Formatter check on all 32 changed Dart files: unchanged.
- `git diff --check`: clean.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded` with the CI-equivalent explicit
  autonomous file list (all 217 test files except `test/integration/`):
  4406 passed, 4 skipped, zero failures. Existing skips were not changed.
- `flutter build ios --simulator --debug --no-pub`: succeeded.
- Native iOS simulator image integration test: 2 passed.
- `openspec validate optimize-image-rendering-and-empty-view --strict`: valid.
- Independent gallery/slideshow rerun: 17 passed; the review's actual-gallery
  contrast finding was fixed and rechecked, with no further material finding.

The initial focused run lacked the ignored native ObjectBox test library in the
new worktree; the installed original-checkout library was then made available.
The first complete run encountered one compile failure while a slideshow test
was being edited. The stable full rerun above supersedes both attempts. Neither
was hidden by changing assertions or excluding affected autonomous tests.

At that handoff the PR was stacked on the then-open planning branch, so remote
CI could not run. Once PR #44 targeted `main`, the `Pull request checks`
workflow ran on head `a7041ac`: `Flutter analyze` and `Autonomous Flutter tests`
both succeeded.

## Adversarial review remediation (2026-11-16)

Review findings were treated as hypotheses and checked by mutation: each
guard was temporarily removed or altered, the focused test was run, and the
production code was restored. No mutated code is committed.

- Generation keys (F1). With both `ObjectKey(generation)` keys deleted, all 291
  pre-existing media, thumbnail, slideshow and gallery tests still passed,
  confirming the gap. Flutter 3.47.5's `_ImageState._updateSourceStream` does
  not clear `_lastException`, so a retained Image State renders a pending
  replacement through its new error builder. New real-provider tests fail a
  request (network acquisition failure; corrupt staged file), replace it while
  the parent State is retained, assert no placeholder, loading `true`, no second
  log while pending, then complete the real decode and assert the output,
  86×86 geometry and terminal `false`. Each fails without its key (stale
  `ImageErrorPlaceholder`) and passes with it.
- Slideshow request tracking (F2): retained. Removing the parent-side
  bucket/manager tracking and the page request lease left the bucket and
  cache-manager tests green. Parent rebuilds eagerly rebuild built
  `PageView` children before the pause overlay sibling. A DPR change rebuilds
  only `MediaQuery` dependents, though. Without tracking, the pause control was
  still enabled in the first frame of a pending DPR replacement, so the test
  failed. A child-to-parent request protocol would replace the tracking with
  comparable machinery, so the tracking was kept.
- Image-widget `mounted`/generation guards: evaluated and retained. They
  directly enforce the contract that obsolete and post-disposal publications
  are rejected. Removing them would save about eight lines and has no
  correctness or maintenance benefit.
- Owner model (`valid`, child lease, request): retained unchanged. Slot
  identity, owner validity, child lifetime, effective request and readiness
  remain separate; mounted alone does not establish ownership.
- Unconditional `_queuePublication()` in `didUpdateWidget`: simplified. It now
  runs only when the visibility notifier is replaced; owner and request
  changes already queue their own deferred publication. Unchanged parent
  rebuilds no longer schedule an extra frame. Restoring the unconditional call
  fails the new no-extra-frame assertion. Removing the queued reconcile on a
  notifier swap fails the new hidden→visible swap test. The visible→hidden
  direction is also stopped by `_onTick` rechecking admission.
- Weak slideshow tests (F3): rewritten with controlled real providers. The
  reorder case now captures the callback that is live immediately before the
  reorder and shows it has authority, then shows it loses authority and that the
  new active page stays pending until its own request completes. Closure-identity
  assertions became observable checks: no new acquisition after the decoded
  cache is cleared, controls stay enabled in the first frame, and autoplay
  advances from the retained slot. Identity-blind slot reuse, no slot reuse and
  any-owner admission each fail at least one rewritten test. The one remaining
  synthetic test is labelled adversarial. It checks the slideshow's own
  request revocation, which `AppNetworkImage` generations otherwise hide.
- New controlled-provider coverage: bucket, DPR and cache-manager replacement
  of a terminal and a pending request, including late obsolete completion. Also:
  retained-bucket synchronous admission, unchanged rebuilds without new
  requests, offscreen completion and gallery/visibility interaction. A cache
  manager change alone reuses the URL-keyed retained decode as a valid
  synchronous hit. That test clears the decoded cache to observe a pending
  request.

Remediation verification (Linux, Flutter 3.47.5, `TZ=Europe/Rome`):

- `dart format --set-exit-if-changed` on changed Dart files, `git diff --check`
  and `flutter analyze --no-pub`: clean. `dart format test/` also reports three
  pre-existing unrelated files, left untouched.
- `flutter test --no-pub --reporter expanded` with the CI-equivalent explicit
  autonomous file list (217 files): 4413 passed, 4 skipped, zero failures.
  Existing skips were not changed; the seven additional passes are the new
  test instances.
- The 38 tests in the changed media/thumbnail/slideshow/gallery lifecycle files
  passed five times in file order and once each with random ordering seeds
  1, 42, 777, 2026 and 31337.
- `openspec validate optimize-image-rendering-and-empty-view --strict`: valid.
- Native integration tests were not rerun: no simulator or device is available
  in the remediation environment.

Tasks 5.3 and 5.4 remain open for device and assistive-technology acceptance.
No merge, release, canonical spec synchronization or archival is authorized by
this handoff.

## Physical Android Profile acceptance — 2026-11-24

GitHub PR [#44](https://github.com/xmattjus/moliseis/pull/44) and the clean
`codex/implement-image-rendering` checkout both resolved to
`29ecb7cd9125b44c047cdb2d244dbad45710c617` before verification. The PR targeted
`main` at `8722856e854699e03f373f65fe4acff68cca1779`. The current-head
[analyzer](https://github.com/xmattjus/moliseis/actions/runs/45174979470/job/137693762874)
and [autonomous Flutter suite](https://github.com/xmattjus/moliseis/actions/runs/45174979470/job/137693762473)
succeeded. The GitHub workflow ran the applicable autonomy-suitable test suite.
The earlier simulator and emulator observations above retain their original
provenance.

### Device and comparison protocol

- Samsung SM-S938B, Android 17 / API 37, Qualcomm SM8750 and Adreno 830.
  Android reported 10.85 GiB total usable RAM and about 2.56 GiB available
  at preflight. The app had a 1080×2340 physical Flutter view and DPR 2.625.
  Flutter Display and the sampled SurfaceFlinger modes reported 120 Hz
  (8.33 ms at that mode). Flutter startup identified Impeller on Vulkan.
- Flutter 3.47.5 stable (`6a19cca564`), Dart 3.13.4, ARM64 Android Profile
  APK, verified as Profile by the running Dart entry point. Relevant locks
  were `cached_network_image_ce` 4.13.1, `material_ui` 1.5.0,
  `go_router` 18.0.2 and `swipe_image_gallery` 0.11.0. The installed SDK
  and repository dependency versions were used.
- A disposable checkout used a distinct application ID, a standalone entry
  point, the normal Flutter engine/rendering flags, and a disposable cache
  namespace. It enabled cleartext for the local fixture transport, served
  over ADB reverse to a host loopback server. No production bootstrap or
  authentication was used. The cover APK retained the actual production
  image providers and consumers. The fit APK substituted stock
  `ResizeImage(policy: ResizeImagePolicy.fit)` only at the bounded network and
  local thumbnail provider selections, preserving `BoxFit.cover`, crop,
  fade, callbacks and cache settings. This compares two decoding policies
  within PR #44's presentation implementation. The Git base source
  independently confirmed stock fit decoding followed by cover paint.
- The primary workload reused the actual `ContentBaseCardGridItem` at the
  Nearby horizontal list's 288×216 logical size with its 8 px separation and
  16 px side padding. The 411.43 logical px viewport presented roughly 1.4
  cards across and used bucket 792×576. The probe omitted unrelated card
  controls and application chrome. The ordinary workload used 48 distinct
  JPEGs alternating 4000×3000 and 3000×4000; 45 were generated textured
  fixtures and three were cropped [landscape](https://images.unsplash.com/photo-1472214103451-9374bd1c798e),
  [mountain](https://images.unsplash.com/photo-1464822759023-fed622ff2c3b) and
  [portrait-format forest](https://images.unsplash.com/photo-1473448912268-2022ce9509d8)
  photographs. The panorama workload used ten 12000×1000 JPEGs and ten
  1000×12000 JPEGs. A compact-list diagnostic reused the actual 72×72
  `ContentBaseListItem` image slots, 96 logical row extent and 8 px spacing
  at bucket 216×216.
- Each process started with fresh decoded and persistent caches. Both
  policies mounted the same order, waited 0.8 seconds, traversed to the
  end in a 9-second linear scripted scroll, let active images settle,
  unmounted the consumers, and repeated the forward traversal against
  retained decoded entries and warm originals. The harness measured three
  samples per policy for each card workload, alternating first policy
  within the planned pairs. It separately ran one pair of compact-list
  diagnostics. A 36-image pilot fit inside the cover cache at this geometry
  and prompted the 48-image cohort. It was excluded from the comparison.
- The production cache-manager implementation kept its existing limits.
  The default Flutter decoded cache was 1,000 entries / 104,857,600 bytes.
  The manager probe recorded reads, including warm originals. The loopback
  server counted image HTTP requests; startup fixture loads and control
  messages are excluded. Retained hits bypass both acquisition paths.

### Native codec and sizing observations

The codec matrix used the physical Samsung, Android 17, Flutter 3.47.5
Impeller/Vulkan process. Each cell lists the decoder output for a square
physical target. For the bounded single-frame rows, the outputs below also
match the expected requests derived from the oriented intrinsic dimensions.
The 226-square target is `ceil(86 × 2.625)`. The unresized reference is a
direct provider request. The actual gallery uses that same unresized
provider contract through `AppNetworkImage.fullResolution`.

| Format and fixture | Intrinsic/oriented | Cover @226 | Cover @864 | Cover @1728 | Unresized output | Result |
| --- | --- | --- | --- | --- | --- | --- |
| JPEG, square | 4000×4000 | 226×226 | 864×864 | 1728×1728 | 4000×4000 | PASS |
| JPEG, landscape | 4000×3000 | 302×226 | 1152×864 | 1728×1296 | 4000×3000 | PASS |
| JPEG, portrait | 3000×4000 | 226×302 | 864×1152 | 1296×1728 | 3000×4000 | PASS |
| JPEG, wide | 12000×1000 | 1728×144 | 1728×144 | 1728×144 | 12000×1000 | PASS |
| JPEG, tall | 1000×12000 | 144×1728 | 144×1728 | 144×1728 | 1000×12000 | PASS |
| JPEG, small | 16×8 | 16×8 | 16×8 | 16×8 | 16×8 | PASS |
| JPEG, EXIF 6 | 400×300 stored, 300×400 oriented | 226×302 | 300×400 | 300×400 | 300×400 | PASS |
| HEIC, HEVC still image | 4000×3000 | 302×226 | 1152×864 | 1728×1296 | 4000×3000 | PASS for this fixture and Flutter codec path |
| GIF, two frames | 1800×2 | 1800×2 | 1800×2 | 1800×2 | 1800×2 | PASS for frame delivery. The codec ignores the requested 1728×2 resize. |

All measured single-frame cover outputs stayed within intrinsic size and the
1728 output ceiling. Paired axes matched the common scale within one pixel.
For the extreme 12:1 inputs the observed 144-pixel short axis has to enlarge
1.57× into the 226-pixel local slot and 6× into an 864-square target. At a
1728-square target the ordinary 4000×3000 source also enlarges along the
short axis (1728 / 1296). These are the planned ceiling exceptions.
Two GIF frame deliveries occurred at each target on this device, consistent
with the documented multiframe limit. Other HEIF profiles, HEIC sequences,
and untested codecs, devices and lower-capability backends remain
**NOT VERIFIED**. Backends below the design's minimum 1728-pixel texture
envelope are outside the supported acceptance envelope. The exercised
codecs did not return an unsupported-format failure. The unresized
12000-pixel axes in this table are decoder observations,
without a corresponding guarantee of full-size GPU texture rendering.

The physical stock-fit reference observed these outputs:

| Fixture | Fit @226 | Fit @864 | Fit @1728 | Unresized output |
| --- | --- | --- | --- | --- |
| square0.jpg | 226×226 | 864×864 | 1728×1728 | 4000×4000 |
| land0.jpg | 226×169 | 864×648 | 1728×1296 | 4000×3000 |
| portrait0.jpg | 169×226 | 648×864 | 1296×1728 | 3000×4000 |
| wide0.jpg | 226×18 | 864×72 | 1728×144 | 12000×1000 |
| tall0.jpg | 18×226 | 72×864 | 144×1728 | 1000×12000 |
| small0.jpg | 16×8 | 16×8 | 16×8 | 16×8 |
| orientation_6.jpg | 169×226 | 300×400 | 300×400 | 300×400 |
| animated_1800x2.gif | 1800×2 | 1800×2 | 1800×2 | 1800×2 |
| land.heic | 226×169 | 864×648 | 1728×1296 | 4000×3000 |

### Measurement and interpretation

Flutter FrameTiming batches reported build, raster and total span separately.
The tables apply the sampled 120 Hz budget (8.33 ms) to each duration. Span
includes pipeline scheduling. These counts do not estimate dropped display
frames. Phase windows include mounting, scripted traversal and end settling.
The callback batches and changing animation activity can produce different
frame counts. Continuous panel refresh telemetry was not collected.

`dumpsys meminfo` sampled the test process approximately every 1.2 seconds.
The memory table reports PSS/RSS in MiB at the highest-PSS sample for each
phase, with native, graphics and Java summary PSS at the overall peak.
Java reporting does not account separately for every Dart runtime allocation.
The samples can miss transient codec allocations and GPU residency outside
Android's process accounting. Retaining decoded cache entries after
consumer release and allocator reuse can keep process PSS above baseline.
No OOM or process termination occurred in the accepted samples. The main
runs remained USB-powered and charging, 62–65% battery, 24.3–26.0 °C battery
temperature and Android thermal status 0 throughout the sampled conditions.

### Cache and memory disposition

The 48-entry ordinary fit workload settled at 63.28 MiB of retained decoded
data. Bounded cover settled at 99.70 MiB and 40 entries. Other than the
three active card-cache neighbors at the end of traversal, no live or
pending images remained after consumer release in any ordinary or panorama
run. Retained byte totals agreed across repetitions. At least eight
ordinary entries had been evicted by the end of the first cover traversal.
The revisit order caused cascading eviction and 48 warm-original reads
every time. The exact decoder callback counts were checked separately.
The panorama cohort retained all 20 entries for both policies and made zero
revisit reads. The compact-list diagnostic retained all 48 with zero revisit
reads under both policies. No workload showed additional HTTP requests on
revisit. This supports equivalence for cold acquisition and warm persistent
originals in the measured workloads.

For the ordinary 792×576 bucket, landscape/portrait fit buffers were
768×576 and 432×576 (1,769,472 and 995,328 bytes at four bytes per pixel).
Cover buffers were 792×594 and 792×1056 (1,881,792 and 3,345,408 bytes).
The portrait geometry drives most of the increase. The unresized
4000×3000 or 3000×4000 buffer estimate is 48,000,000 bytes. In the panorama
cohort the cover buffers were 1728×144 and 144×1728 (995,328 bytes each);
the fit buffers were 792×66 and 48×576 (209,088 and 110,592 bytes).
These RGBA8888 estimates account for decoded pixels only. Whole-source
decode/transient allocation, process and graphics costs are separate.

Peak sampled PSS for ordinary cards was 371–381 MiB fit and 443–499 MiB
cover. Cover's highest samples were during warm-original revisit in all
three pairs. Panorama peak was 274–286 MiB fit and 313–319 MiB cover.
The memory increase was reproducible on this device. The recorded frame
durations and observed image readiness are evaluated separately below.

#### Frame timings by run

| Run | Phase | Frames | Build ms p50/90/95/99 | Raster ms p50/90/95/99 | Total span ms p50/90/95/99 | Build slow | Raster slow | Span slow |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Ordinary 1 fit | initial | 1084 | 0.35 / 0.78 / 1.18 / 2.41 | 0.43 / 0.54 / 0.61 / 2.28 | 1.41 / 2.42 / 3.35 / 5.39 | 0 (0.00%) | 1 (0.09%) | 3 (0.28%) |
| Ordinary 1 fit | revisit | 962 | 0.25 / 0.48 / 0.74 / 1.92 | 0.66 / 0.76 / 0.81 / 1.29 | 1.51 / 2.23 / 2.59 / 5.05 | 0 (0.00%) | 0 (0.00%) | 5 (0.52%) |
| Ordinary 1 cover | initial | 1081 | 0.24 / 0.64 / 1.06 / 2.50 | 0.40 / 0.52 / 0.56 / 2.37 | 1.16 / 2.30 / 3.38 / 4.92 | 0 (0.00%) | 1 (0.09%) | 5 (0.46%) |
| Ordinary 1 cover | revisit | 1085 | 0.31 / 0.83 / 1.06 / 2.08 | 0.70 / 0.82 / 0.87 / 2.53 | 1.77 / 2.71 / 3.54 / 5.30 | 0 (0.00%) | 0 (0.00%) | 4 (0.37%) |
| Panorama 1 cover | initial | 1050 | 0.36 / 0.66 / 0.88 / 2.13 | 0.43 / 0.52 / 0.58 / 1.07 | 1.44 / 1.98 / 2.44 / 5.09 | 0 (0.00%) | 1 (0.10%) | 4 (0.38%) |
| Panorama 1 cover | revisit | 964 | 0.39 / 0.50 / 0.74 / 1.85 | 0.69 / 0.76 / 0.80 / 0.94 | 1.89 / 2.42 / 2.67 / 3.92 | 0 (0.00%) | 0 (0.00%) | 5 (0.52%) |
| Panorama 1 fit | initial | 1050 | 0.38 / 0.60 / 0.84 / 2.40 | 0.43 / 0.52 / 0.58 / 1.12 | 1.45 / 1.93 / 2.50 / 4.42 | 0 (0.00%) | 1 (0.10%) | 2 (0.19%) |
| Panorama 1 fit | revisit | 966 | 0.40 / 0.50 / 0.75 / 1.85 | 0.69 / 0.77 / 0.82 / 0.95 | 1.90 / 2.47 / 2.74 / 3.97 | 0 (0.00%) | 0 (0.00%) | 3 (0.31%) |
| Ordinary 2 cover | initial | 1082 | 0.28 / 0.66 / 1.11 / 2.38 | 0.45 / 0.62 / 0.75 / 2.40 | 1.35 / 2.39 / 3.41 / 5.32 | 0 (0.00%) | 1 (0.09%) | 3 (0.28%) |
| Ordinary 2 cover | revisit | 1089 | 0.22 / 0.45 / 0.77 / 1.14 | 0.65 / 0.78 / 0.84 / 3.29 | 1.32 / 2.00 / 2.53 / 5.28 | 0 (0.00%) | 0 (0.00%) | 2 (0.18%) |
| Ordinary 2 fit | initial | 1082 | 0.27 / 0.64 / 1.00 / 2.50 | 0.41 / 0.52 / 0.56 / 2.59 | 1.24 / 2.26 / 3.48 / 5.72 | 0 (0.00%) | 1 (0.09%) | 5 (0.46%) |
| Ordinary 2 fit | revisit | 965 | 0.40 / 0.69 / 1.13 / 2.06 | 0.69 / 0.78 / 0.84 / 0.93 | 1.99 / 2.63 / 3.21 / 4.10 | 0 (0.00%) | 0 (0.00%) | 4 (0.41%) |
| Panorama 2 fit | initial | 1054 | 0.36 / 0.62 / 0.91 / 2.29 | 0.43 / 0.53 / 0.59 / 1.09 | 1.44 / 2.01 / 2.45 / 4.97 | 1 (0.09%) | 1 (0.09%) | 3 (0.28%) |
| Panorama 2 fit | revisit | 965 | 0.40 / 0.51 / 0.72 / 1.86 | 0.69 / 0.77 / 0.82 / 1.09 | 1.94 / 2.42 / 2.85 / 5.34 | 0 (0.00%) | 0 (0.00%) | 5 (0.52%) |
| Panorama 2 cover | initial | 1055 | 0.36 / 0.60 / 0.80 / 2.29 | 0.44 / 0.53 / 0.58 / 1.05 | 1.45 / 2.11 / 2.76 / 4.66 | 0 (0.00%) | 0 (0.00%) | 1 (0.09%) |
| Panorama 2 cover | revisit | 965 | 0.40 / 0.53 / 0.71 / 1.84 | 0.69 / 0.77 / 0.81 / 0.90 | 1.93 / 2.50 / 2.93 / 4.09 | 0 (0.00%) | 0 (0.00%) | 4 (0.41%) |
| Ordinary 3 fit | initial | 1077 | 0.27 / 0.69 / 1.07 / 2.31 | 0.46 / 0.74 / 0.93 / 3.01 | 1.35 / 2.56 / 3.56 / 7.57 | 1 (0.09%) | 0 (0.00%) | 7 (0.65%) |
| Ordinary 3 fit | revisit | 965 | 0.35 / 0.58 / 0.80 / 2.00 | 0.67 / 0.75 / 0.79 / 1.43 | 1.80 / 2.46 / 3.19 / 4.38 | 0 (0.00%) | 1 (0.10%) | 4 (0.41%) |
| Ordinary 3 cover | initial | 1082 | 0.24 / 0.65 / 1.15 / 2.44 | 0.41 / 0.53 / 0.58 / 2.08 | 1.15 / 2.43 / 3.36 / 5.16 | 0 (0.00%) | 1 (0.09%) | 2 (0.18%) |
| Ordinary 3 cover | revisit | 1085 | 0.35 / 0.88 / 1.22 / 2.15 | 0.71 / 0.82 / 0.86 / 2.19 | 1.83 / 2.93 / 3.70 / 5.62 | 0 (0.00%) | 0 (0.00%) | 8 (0.74%) |
| Panorama 3 cover | initial | 1051 | 0.35 / 0.52 / 0.87 / 2.28 | 0.42 / 0.54 / 0.60 / 2.35 | 1.41 / 1.91 / 2.42 / 4.37 | 0 (0.00%) | 1 (0.10%) | 3 (0.29%) |
| Panorama 3 cover | revisit | 966 | 0.37 / 0.49 / 0.64 / 1.93 | 0.69 / 0.77 / 0.81 / 0.89 | 1.84 / 2.32 / 2.63 / 4.26 | 0 (0.00%) | 0 (0.00%) | 4 (0.41%) |
| Panorama 3 fit | initial | 1047 | 0.36 / 0.53 / 0.85 / 2.29 | 0.43 / 0.53 / 0.58 / 1.38 | 1.45 / 1.98 / 2.61 / 5.12 | 0 (0.00%) | 1 (0.10%) | 7 (0.67%) |
| Panorama 3 fit | revisit | 964 | 0.37 / 0.48 / 0.62 / 1.91 | 0.69 / 0.77 / 0.82 / 0.94 | 1.84 / 2.29 / 2.58 / 4.61 | 0 (0.00%) | 0 (0.00%) | 5 (0.52%) |
| Compact 1 fit | initial | 1150 | 0.48 / 0.80 / 1.09 / 2.22 | 0.62 / 0.71 / 0.80 / 2.46 | 1.76 / 2.51 / 3.43 / 5.85 | 1 (0.09%) | 1 (0.09%) | 6 (0.52%) |
| Compact 1 fit | revisit | 1108 | 0.51 / 0.74 / 0.99 / 2.05 | 0.85 / 0.93 / 0.96 / 1.09 | 2.16 / 2.77 / 3.19 / 4.60 | 1 (0.09%) | 1 (0.09%) | 6 (0.54%) |
| Compact 1 cover | initial | 1152 | 0.49 / 0.74 / 1.06 / 2.23 | 0.61 / 0.72 / 0.80 / 3.03 | 1.77 / 2.55 / 3.58 / 5.55 | 0 (0.00%) | 1 (0.09%) | 5 (0.43%) |
| Compact 1 cover | revisit | 1106 | 0.50 / 0.72 / 1.00 / 1.89 | 0.84 / 0.92 / 0.96 / 1.24 | 2.15 / 2.72 / 3.03 / 4.37 | 0 (0.00%) | 1 (0.09%) | 6 (0.54%) |

#### Process residency by run

| Run | Samples | Baseline | Initial | Released initial | Revisit | Released revisit | Peak | Native/graphics/Java at PSS peak |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Ordinary 1 fit | 23 | 257/360 | 371/474 | 370/473 | 378/480 | 377/480 | 378/480 | 34/238/10 |
| Ordinary 1 cover | 23 | 255/358 | 422/525 | 407/510 | 443/546 | 398/501 | 443/546 | 64/267/10 |
| Panorama 1 cover | 23 | 260/363 | 319/422 | 306/408 | 306/408 | 303/405 | 319/422 | 38/175/10 |
| Panorama 1 fit | 19 | 259/358 | 274/377 | 274/376 | 271/374 | 271/374 | 274/377 | 25/143/10 |
| Ordinary 2 cover | 23 | 249/348 | 423/525 | 409/511 | 493/596 | 393/495 | 493/596 | 109/267/10 |
| Ordinary 2 fit | 23 | 249/350 | 381/484 | 370/473 | 371/474 | 365/468 | 381/484 | 38/238/10 |
| Panorama 2 fit | 23 | 263/366 | 286/389 | 274/376 | 274/376 | 271/374 | 286/389 | 38/143/10 |
| Panorama 2 cover | 23 | 263/365 | 316/419 | 306/409 | 306/409 | 306/409 | 316/419 | 36/175/10 |
| Ordinary 3 fit | 23 | 251/350 | 369/471 | 369/471 | 371/474 | 350/446 | 371/474 | 35/237/10 |
| Ordinary 3 cover | 23 | 258/355 | 431/529 | 417/514 | 499/596 | 416/513 | 499/596 | 105/267/10 |
| Panorama 3 cover | 23 | 269/366 | 313/410 | 312/409 | 312/409 | 310/407 | 313/410 | 35/161/10 |
| Panorama 3 fit | 23 | 258/355 | 286/386 | 277/377 | 277/377 | 275/374 | 286/386 | 33/143/10 |
| Compact 1 fit | 25 | 263/359 | 332/432 | 319/418 | 316/415 | 316/415 | 332/432 | 40/179/10 |
| Compact 1 cover | 25 | 264/364 | 336/435 | 324/424 | 322/421 | 322/421 | 336/435 | 37/187/10 |

#### Decoded cache and acquisition by run

| Run | Initial reads | Revisit reads | HTTP sends | HTTP unique | Initial retained | Initial bytes | Revisit retained | Revisit bytes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Ordinary 1 fit | 48 | 0 | 48 | 48 | 48 | 66355200 | 48 | 66355200 |
| Ordinary 1 cover | 48 | 48 | 48 | 48 | 40 | 104544000 | 40 | 104544000 |
| Panorama 1 cover | 20 | 0 | 20 | 20 | 20 | 19906560 | 20 | 19906560 |
| Panorama 1 fit | 20 | 0 | 20 | 20 | 20 | 3196800 | 20 | 3196800 |
| Ordinary 2 cover | 48 | 48 | 48 | 48 | 40 | 104544000 | 40 | 104544000 |
| Ordinary 2 fit | 48 | 0 | 48 | 48 | 48 | 66355200 | 48 | 66355200 |
| Panorama 2 fit | 20 | 0 | 20 | 20 | 20 | 3196800 | 20 | 3196800 |
| Panorama 2 cover | 20 | 0 | 20 | 20 | 20 | 19906560 | 20 | 19906560 |
| Ordinary 3 fit | 48 | 0 | 48 | 48 | 48 | 66355200 | 48 | 66355200 |
| Ordinary 3 cover | 48 | 48 | 48 | 48 | 40 | 104544000 | 40 | 104544000 |
| Panorama 3 cover | 20 | 0 | 20 | 20 | 20 | 19906560 | 20 | 19906560 |
| Panorama 3 fit | 20 | 0 | 20 | 20 | 20 | 3196800 | 20 | 3196800 |
| Compact 1 fit | 48 | 0 | 48 | 48 | 48 | 6718464 | 48 | 6718464 |
| Compact 1 cover | 48 | 0 | 48 | 48 | 48 | 11943936 | 48 | 11943936 |

### Android visual and functional observations

The separate decoder diagnostic recorded 48 initial invocations for each
policy and 0 fit versus 48 cover during the ordinary revisit. The primary
timings used the uninstrumented production decoder path. Simultaneous
screenshots were limited to the diagnostic. The three sampled cover revisit
positions showed the next cards partially faded in where the corresponding
fit captures already showed fully opaque cards. Images were present in these
samples. This visible repeat fade is consistent with warm-original decoding
after legitimate eviction. Measured ordinary revisit raster p99 was
0.93–1.43 ms fit and 2.19–3.29 ms cover. No build or raster duration in the
three cover revisit windows exceeded 8.33 ms. The high-level evidence shows
a repeat-load quality/resource tradeoff without an observed material
scrolling stall, process-memory failure, or acquisition increase on this
device. Sparse screenshots cannot rule out short blank intervals between
samples. No global performance threshold or cache parity requirement was
applied.

Inspection of the captured fit and cover renders found the same framing and
orientation in the 86×86 logical local slot. Cover resolved finer grass,
branches and edges in the ordinary landscape and portrait. The extreme
panorama's calibration pattern was clearer and retained some softness at
the approved ceiling. No stretching or unexpected clipping was observed
in those crops. This was screenshot inspection by the verifying agent.
The shared preview replaced landscape, portrait and panorama fixtures,
displayed the same neutral error for a missing and corrupt file, and
removed the preview on request. Its Public/Admin call sites and ownership
paths were checked in source and current-head regressions. Production
sign-in, staging persistence, upload and association were outside this
isolated fixture flow. No production media or records were modified.

Real network requests to missing fixtures produced the compact icon and
the spacious icon/text presentation. The Android accessibility hierarchy
contained one image-error label per screen. A touch test activated Retry
and updated the action state. These checks do not establish spoken
TalkBack behavior.

The actual `PostMediaSlideshow` loaded, faded in, advanced after loading
and resumed autoplay following gallery return. The gallery opened from
the slideshow and switched between images, double-tap zoomed, and panned.
Rendered image diagnostics observed an unbucketed 3000×4000 photo and
12000×1000 panorama in the gallery, versus 1152×1536 and 1728×144 for the
same bounded slideshow requests. The return path produced a synchronous
retained hit. Android snapshots captured the separate bounded and gallery
compositions and confirmed the next page indicator and resumed slide.
The native two-frame GIF check and the current-head network playback
regression cover existing multiframe delivery.

### Definition of Done at the physical-device handoff

| Criterion | Status | Evidence and provenance |
| --- | --- | --- |
| TASK-43 1. Coherent proportional Public/Admin previews and documented quality exceptions | PASS | Source inspection found both forms delegate to `ContentSubmissionFileThumbnail`. Current-head widget coverage checks both forms. The Samsung isolated shared widget and native codec sizes exercise normal, portrait and panoramic previews. |
| TASK-43 2. Automated DPR, actual decode and render | PASS | Current-head CI covers multiple DPRs, actual decoded dimensions, rendered crops and error geometry. The Samsung uses DPR 2.625 and a 226-square request. The current-head iPhone 18 Pro / iOS 27.2 simulator native compatibility run passed 2/2. |
| TASK-43 3. Fit, cover and full-resolution pixel-buffer costs | PASS | Deterministic and Samsung decoder output sizes plus the stated four-byte RGBA8888 assumption. Process PSS/RSS were sampled separately. |
| TASK-43 4. Acquisition, copies, cache ownership, invalidation and release | PASS | PR diff leaves staging, domain, persistent acquisition and cache limits intact. Current-head provider tests check release and error eviction. Samsung released-consumer probes returned live/pending to zero. |
| TASK-43 5. Replacement, removal, ownership, late completion and errors | PASS | Current-head local/admin widget and staging/ownership regressions plus isolated Samsung shared-preview interactions. Late-race coverage is deterministic. |
| TASK-43 6. Contribution, upload and association regressions | PASS | Current-head CI and source diff covering public/admin forms, staging, upload and asset association. Credentialed production submission/upload/association on the phone was NOT VERIFIED. Verification used automated fixtures and isolated widgets. |
| TASK-16. Effective API and consumer contract | PASS | Production provider and consumer inspection, documented target, disk identity, gallery and loading behavior. |
| TASK-16. Dead image width/height parameters | PASS | Both constructors and all six migrated call sites checked at the PR base/head diff; domain dimensions remain available. |
| TASK-16. Decode and cache sizing | PASS | Source geometry, Samsung codec measurements, unchanged buckets/default cache limits, native working sets and deterministic capped/uncapped interoperability. |
| TASK-16. Visual quality and errors | PASS | Samsung screenshot pairs, image-error fixtures, full-resolution gallery, retained/fade behavior and navigation. Current-head deterministic rendering and accessibility coverage. |
| TASK-16. Equivalent decoded-cache hit/eviction and decode evidence | PASS | Three physical pairs per primary workload and an independent native decoder callback diagnostic, with the documented deterministic 864-square cohorts kept separate. |
| TASK-16. Cache-manager reads vs HTTP acquisition | PASS | Samsung manager instrumentation and independent loopback counts. Current-head CI covers retained, cold, warm, concurrent and expiry paths. |
| TASK-16. Representative physical Android scrolling and memory assessment | PASS | Identified hardware, two primary workloads, repeated paired samples and separate compact diagnostic. The disposition of measured impact is assessed in the next row. |
| TASK-16. Material regressions or unexplained acquisition increases resolved | PASS | Warm-original re-decodes, visible repeat fade and higher sampled PSS are recorded device-specific costs. No material slow-frame, process failure or unexplained HTTP increase was demonstrated in the measured tests. |
| Physical iOS Profile memory pressure, scrolling and raster | NOT VERIFIED | Flutter and Xcode device discovery found no connected physical iOS device. Keep the physical follow-up open. The present simulator result establishes functional compatibility. |
| Real TalkBack acceptance | PASS | The device user ran the prescribed listening and interaction checks on the Samsung at its largest font size and reported that all passed with TalkBack enabled. The check covered compact and spacious errors, one meaningful focus announcement, no path/URL or decorative speech, focus traversal, and Retry reachability and activation. No verbatim speech transcript was captured. |
| VoiceOver compact and spacious image errors | PASS | Xcode 27.2 captured actual VoiceOver output on the iPhone 18 Pro / iOS 27.2 simulator. Both cases spoke “Immagine non disponibile” for one image-error element. Reverse navigation returned to the screen title. No fixture URL/path or redundant decorative label was spoken in the captured traversal. |
| VoiceOver enlarged Nearby Retry | FAIL | With the largest accessibility text setting, the actual Nearby error widget exposed a visible, hittable 176.8×62 pt `Riprova` after scrolling. The VoiceOver service spoke the heading and error text but did not reach the action through repeated forward navigation. Touch exploration at the action still returned the error utterance in the simulator probe. Ordinary touch activated the action with VoiceOver off. No physical iOS VoiceOver comparison or verified correction is available. |

Task 5.3 was completed with the documented physical iOS deferral. Task 5.4
was left open at this handoff after the enlarged VoiceOver Retry check
failed on the simulator. See the follow-up below for the later disposition.
The original simulator focus check did not establish a regression against
the old UI.

Design §6 permits the physical iOS performance deferral for implementation
handoff after all other applicable gates pass. Any iOS release with that
gap requires an explicit recorded decision by the release owner covering
the missing checks, alternative evidence and its limits, possible memory and
scrolling/raster consequences and the pending physical follow-up. This
evidence records no release or residual-risk acceptance.

## VoiceOver Retry follow-up — 2026-11-24

The follow-up started from clean PR #44 head
`3552cc5cda1a11fd531799a20b3f1afed517f4e8`, based on
`8722856e854699e03f373f65fe4acff68cca1779`. The disposable native probe
used byte-identical production Nearby, EmptyView, image-error and theme
sources. It ran in Debug on the iPhone 18 Pro simulator with iOS 27.2
(24B8117), Xcode 27.2 (27B52) and the locked Flutter 3.47.5 engine
`af7e796e16`. The simulator viewport was 402×874 logical points at DPR 3.
The system content size was **Accessibility Extra Extra Extra Large**.
The app measured 49.882 logical points for a 16-point body font
(approximately 3.118×) and 43.647 for a 14-point font.

### Reproduction and isolation

The actual Nearby error viewport was 320×216 points with scroll range
0–392. The Flutter tree initially contained a single hidden `Riprova`
button node with a tap action and a local rect from (71.6, 530.0) to
(248.4, 592.0). The native snapshot recorded a zero frame for that
offscreen button. At offset 376 the same Flutter node had a fully visible
176.8×62-point rect from (71.6, 154.0) to (248.4, 216.0), retained its
button and enabled flags and tap action, and no longer had the hidden
flag. Native XCTest continued to identify the element as a Button.
Ordinary touch activated the expected retry callback.

The historical pre-scroll procedure was reproduced. It used ordinary
scrolling before enabling VoiceOver, then drove forward and backward
navigation with `XCUIVoiceOverService`.

| Probe | Native speech and behavior with the original procedure |
| --- | --- |
| Actual Nearby with app typography | Spoke the screen title, “Nelle vicinanze” and the error text, then repeated the error. A silent focus step returned error 3. The tested forward sequence did not speak Retry. |
| Standalone EmptyView with the same action | Reproduced error-text repetition and omission of Retry. |
| Stock SingleChildScrollView with Column, Text and TextButton | Reproduced the same omission in a 320×216 viewport without Nearby or EmptyView. The button moved from hidden at offset 0 to visible at offset 178. |
| Same stock TextButton without a scroll viewport | Spoke “Riprova Button”. Backward navigation returned to the error and forward returned to Retry. |

The results isolate the observed failure to navigation through a Flutter
scrollable on the tested iOS/VoiceOver stack and interaction sequence.
They exclude the app button implementation, Nearby-specific ancestors,
and EmptyView decoration as necessary reproduction conditions. The locked
Flutter viewport preserves offscreen children within its semantics clip
and reports scroll actions. The iOS embedder returns the superclass
accessibility frame for hidden nodes, which matched the zero native frame
observed here. [Flutter issue #192774](https://github.com/flutter/flutter/issues/192774)
documents iOS 27 implicit-scroll limitations and separately reports
visible elements being skipped. This is consistent with the offscreen
behavior in the probe. It does not independently establish the cause of
the pre-scrolled, visible-element traversal result.

### Corrected verification procedure

With VoiceOver already active, the probe advanced from the Nearby heading
to the error area and sent two actual three-finger upward swipe gestures.
After the first swipe Retry still had a zero native frame. After the
second its native frame was (112.6, 605.0, 176.8, 62.0), wholly inside the
viewport. The next forward step spoke “Riprova Button”. Moving backward
spoke the preceding error. A three-finger downward swipe returned Retry
outside the visible area. The stock scroll view also exposed and spoke its
button after an active VoiceOver scroll. This exercises Apple's documented
[VoiceOver scrolling gestures](https://support.apple.com/guide/iphone/use-voiceover-gestures-iph3e2e2281/27/ios/27).
Ordinary pre-scrolling was insufficient to establish this path.

The follow-up verifies Retry speech and supported scroll and reverse
navigation on the simulator. A single touch at the visible button
preserved the current “Riprova Button” reading and did not activate it.
Independent touch-to-focus from a different element was inconclusive:
moving backward to the long error could first scroll Retry out of view.

**VoiceOver activation remains NOT VERIFIED.** A double-tap away from
the action and the VoiceOver keyboard activation command did not invoke
the callback on either Nearby or the plain control. An on-target
double-tap did invoke each callback, but Flutter pointer logging recorded
an ordinary pointer-down at the button before each invocation. The
locked iOS bridge dispatches a semantic tap directly from
`accessibilityActivate`, so those callbacks were excluded. The
split-tap did not activate the plain control. It invoked Nearby's
callback immediately after a Flutter pointer-down at the button, so
that event was also excluded. The plain-control results prevent
attributing the activation gap to Nearby. No physical iPhone was
available for the remaining verification.

Native reproduction for follow-up: set the iPhone's accessibility text
size to its largest setting, enable VoiceOver, and open Nearby with a
retryable failure in the 320×216 viewport. Navigate to the error text,
scroll with three fingers until the whole Retry control is visible,
move focus forward to “Riprova Button”, then verify reverse navigation
back to the error. Scroll back to the control if needed. Select Retry,
double-tap using VoiceOver, and confirm the retry callback or observable
retry state changes once. Record the speech and the observed state.

Removing the viewport was a useful plain-button control. It cannot
preserve the specified 216-point overflow behavior by itself. Changing
the button or Nearby alone would leave the same behavior in the standard
scroll control. The evidence did not warrant custom semantics, forced
focus, platform branches or an engine workaround. Production behavior and
existing automated regressions were retained. The simulator test covers
native VoiceOver speech and focus. The existing Flutter tests cover
geometry, semantic nodes and callbacks, keyboard and Enter, Nearby,
Suggestion and finite and sliver hosts. The earlier Android TalkBack pass
remains applicable to the unchanged layout and semantics code.

### Checks and remaining gates

- Flutter analyze passed. Formatting passed on eight affected Dart files.
- The focused Flutter regressions passed 94 tests. A disposable run of the existing Suggestion failure/retry fixture at 320×500 and text scale 2 also passed, including scrolling to its single visible Retry action and activating it. The autonomous Flutter
  suite passed 4,428 tests with four skips.
- The two checked-in image presentation integration tests passed on iOS 27.2. The native VoiceOver comparison confirmed compact and spacious speech with one labeled element each and reverse navigation to the screen title.
- Strict OpenSpec validation, the direct documentation audit and Git diff
  checks passed. The named repository-local documentation audit skill was
  unavailable.
- At this follow-up, task 5.4 remained open for confirmed VoiceOver activation.
  The acceptance-policy amendment below supersedes that merge disposition.


## Integrated acceptance decision — 2026-11-24

On 2026-11-24, the project owner explicitly authorized deferring genuine
VoiceOver activation of the enlarged Nearby Retry action to the iOS release
gate alongside the previously approved physical iOS performance deferral.
Implementation merge may proceed once every other applicable requirement
and check is satisfied. The amendment changes verification timing only.
It grants no verification pass, residual-risk acceptance or release
authorization. Both functional delta specifications remain unchanged.
All other accessibility, deterministic correctness, lifecycle,
compatibility and Android acceptance requirements remain in force.

| Check | Current result | Evidence and disposition |
| --- | --- | --- |
| VoiceOver compact and spacious image-error speech | PASS on the tested simulator | Both variants spoke one meaningful image-error description. |
| VoiceOver enlarged Nearby Retry reachability and reverse navigation | PASS on the tested simulator | With VoiceOver active, supported three-finger scrolling exposed the button. Forward navigation spoke “Riprova Button” and reverse navigation returned to the error text. The original failed procedure remains recorded above. |
| Genuine VoiceOver enlarged Nearby Retry activation | NOT VERIFIED | The follow-up did not establish an application defect or a simulator defect. The remaining check is required at the iOS release gate. |
| Physical iOS Profile memory pressure, scrolling and raster | NOT VERIFIED | The physical-device follow-up and existing release-owner decision policy remain in force. |
| Android TalkBack | PASS within the documented boundary | Device-user verification at the largest Android font size. |
| Physical Android Profile acceptance | PASS within the documented boundary | Identified Samsung device, native codec checks and repeated Profile comparisons. |

[Flutter issue #192774](https://github.com/flutter/flutter/issues/192774) and
[merged upstream PR #195731](https://github.com/flutter/flutter/pull/195731)
are scrolling-accessibility follow-up references. The upstream change does
not establish genuine Retry activation on the intended release implementation.
Tasks 5.3 and 5.4 are complete for implementation acceptance under the
amended policy. The TASK-43 and TASK-16 evidence at the physical-device
handoff and VoiceOver follow-up satisfies the non-deferred requirements.
The Android campaign, native investigation and local Flutter suite were
reused because the implementation, tests and dependencies are unchanged.
[CI run 45481212630](https://github.com/xmattjus/moliseis/actions/runs/45481212630)
also passed Flutter analyze, autonomous Flutter tests and autonomous Deno
tests on the same implementation and tests. The documentation amendment's
own CI checks apply to the updated PR head.

## iOS release gates

Carry these open checks forward independently of OpenSpec synchronization
or archival. Both are currently **NOT VERIFIED**.

- [ ] **Genuine VoiceOver activation for enlarged Nearby Retry.** On the
  intended iOS release implementation, preferably on a physical iPhone,
  verify the spoken label, button role, reachability, reverse navigation
  and actual invocation of the retry callback with VoiceOver active.
  Follow the native procedure above. Ordinary touch, synthetic pointer
  input and direct Flutter semantics invocation cannot satisfy the gate.
  Resolve and reverify any demonstrated material accessibility defect
  before release. The next iOS release requires this verification to pass.
- [ ] **Physical iOS Profile performance.** Verify representative memory
  pressure, scrolling and raster behavior using the intended iOS release
  implementation. If suitable measurements remain unavailable at release
  time, the responsible release owner must explicitly document the missing
  checks, alternative evidence and its limits, possible memory-pressure,
  scrolling and raster consequences, who accepts the residual risk, and
  the outstanding physical-device follow-up. Such a decision leaves the
  missing results **NOT VERIFIED** and keeps the follow-up open.

The 2026-11-24 decision authorizes the implementation-merge deferrals
only. No iOS release or release-owner residual-risk decision is recorded.
