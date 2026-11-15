# Image rendering implementation evidence

This records deterministic checks of the implementation based on planning PR
#43 (`5707389`), using Flutter 3.47.5 and cached_network_image_ce 4.13.1.
It supplements, rather than reuses as acceptance, the historical experiments.

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

## Outstanding physical/backend acceptance

Physical Android Profile-mode memory/cache pressure, normal/panorama scrolling,
frame quantiles and raster behavior remain NOT VERIFIED until run on identified
hardware. Physical iOS memory-pressure/scrolling/raster checks remain NOT
VERIFIED; merge approval does not authorize an iOS release with that gap.
Screen-reader tree assertions do not verify TalkBack/VoiceOver behavior.
Backends below the required 1728 texture-dimension envelope and untested
HEIC/HEIF or other platform codecs are NOT VERIFIED. Neither software codec tests
nor estimated RGBA buffers replace those gates.

## Native functional compatibility

`flutter build ios --simulator --debug --no-pub` succeeded with Xcode 26.6.
`flutter test --no-pub integration_test/image_presentation_test.dart -d <simulator>`
passed both tests on iPhone 17 Pro / iOS 26.5 Simulator. The native tests verify
the actual local cover output/crop and terminal network-error loading, compact
geometry and unique semantics. These are functional simulator observations,
not physical memory/GPU/Profile results. No production credentials or bootstrap
are required by that test target.

## Verification and handoff

The implementation branch is based on planning PR #43 head `5707389`; fetched
main is `8865564`. The original checkout and planning branch are unchanged.
No backend, domain, staging, upload, persistence, bucket/cache limits or dependency
inputs changed. Source media dimensions remain in their domain/navigation models;
only the six AppNetworkImage call sites drop unused width/height metadata.

The slideshow keeps slot handles and live-child/request leases locally. Current
readiness is invalidated on remount/request replacement and revoked on slot
replacement/reorder/removal, including ABA and in-place list changes. Deferred
publication schedules a frame and reads latest authority. A State-lifetime ticker,
rebound visibility listener and Future-owned gallery pause share one admission
gate. Fourteen slideshow tests include actual provider decode/error, failed and
evicted B remount, synchronous cached remount, queued callbacks, partial changes,
visibility, manual pause, count changes, gallery return/error/disposal. Its local
page State exists to own the child lifetime, not as another application state
layer; the cohesive owner code stays in one file despite the file-size heuristic.

Final commands and observations:

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

The implementation PR is stacked on the still-open planning branch. Remote CI
is NOT RUN for this base because the existing workflow filters pull requests to
`main`; rerun its checks when the implementation PR can target main. Task 5.2
therefore remains open despite completed local checks. Tasks 5.3 and 5.4 remain
open for device/assistive-technology acceptance. No merge, release, canonical
spec synchronization or archival is authorized by this handoff.
