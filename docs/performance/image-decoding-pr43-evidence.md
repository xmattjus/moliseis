# PR #43 image-decoding experimental evidence

## 1. Purpose and scope

[PR #43](https://github.com/xmattjus/moliseis/pull/43), OpenSpec change `optimize-image-rendering-and-empty-view`, addresses fit decoding followed by cover painting. When source and destination proportions differ, the fit bitmap can be enlarged during painting, causing softness despite sufficient source resolution. Simply switching to unconstrained proportional cover introduces another problem: extreme sources produce disproportionately large buffers, churn the decoded cache, and can encounter backend axis clamps that distort proportions.

This record preserves two investigations and the accepted planning decisions. It records observed decoder output, estimated buffers, process measurements, cache behavior, limited visual inspection and experimental widget behavior separately. Temporary prototypes demonstrated feasibility; production implementation and acceptance remain outstanding.

## 2. Tested implementation and environment

Both investigations were recorded on **2026-11-13**, against application baseline `886556409ef8e7254e8c241a77d643c5e9403fd1`. The original planning-only PR head was `9b5c9286d52b844b6fbdfe1992ee6cdd5f3b1961`. The prototypes were disposable copies/exports, not modifications to production widgets.

| Characteristic | Tested configuration |
| --- | --- |
| Flutter / Dart | 3.47.5 / 3.13.4 |
| Network provider | Locked `cached_network_image_ce` 4.13.1 |
| Android | API 37, arm64 emulator; no physical device |
| Emulator resources | 2 GiB configured RAM, 4 virtual CPUs |
| Display | 1280×2856 physical pixels, DPR 3, approximately 60 Hz |
| Device benchmarks | Flutter Profile mode |
| Rendering | Impeller OpenGLES through ANGLE/SwiftShader; software graphics |
| Flutter ImageCache | Unchanged defaults: 100 MiB maximum retained bytes, 1000 entries |
| Persistent cache | Existing manager configuration retained: 200 objects, seven-day stale period, ten-second HTTP timeout |

Requested DPR variants were generated explicitly; the emulator display itself remained DPR 3. Cache byte limits concern retained decoded entries, not all live images or transient codec allocations. No cache tuning, dependencies or production architecture changed.

Authoritative baseline sources: [AppNetworkImage](https://github.com/xmattjus/moliseis/blob/886556409ef8e7254e8c241a77d643c5e9403fd1/lib/ui/core/ui/media/app_network_image.dart), [ImageSizeBucket](https://github.com/xmattjus/moliseis/blob/886556409ef8e7254e8c241a77d643c5e9403fd1/lib/ui/core/ui/media/image_size_bucket.dart), [local thumbnail](https://github.com/xmattjus/moliseis/blob/886556409ef8e7254e8c241a77d643c5e9403fd1/lib/ui/content_submission/widgets/content_submission_file_thumbnail.dart), [slideshow](https://github.com/xmattjus/moliseis/blob/886556409ef8e7254e8c241a77d643c5e9403fd1/lib/ui/post/widgets/components/post_media_slideshow.dart) and [EmptyView](https://github.com/xmattjus/moliseis/blob/886556409ef8e7254e8c241a77d643c5e9403fd1/lib/ui/core/ui/empty_view.dart).

## 3. Experimental methodology

### First investigation: decode, cache, memory and scrolling

Deterministic varied-content PNG fixtures measured 3000×3000, 4000×3000, 3000×4000, 8000×2000, 2000×8000, 12000×1000, 1000×12000 and 320×240. A 1190×767 JPEG added a photographic source. These were valid encoded files, not mocked metadata or exclusively uniform-color images.

The **108 decoded-size observations** comprised nine sources × six targets × two policies: stock `ResizeImage(policy: ResizeImagePolicy.fit)` and unconstrained intrinsic-aware proportional cover. Targets included 86-square logical thumbnails at DPR 1/2/2.625/3 (86/172/226/258 physical), 864×576 physical (288×192 logical at DPR 3), and the 1728-square largest network bucket. Additional memory/cache/scroll scenarios used 864-square physical slots. The real provider/codec path recorded source, requested and observed output dimensions. Decode durations were collected, but single cold timings do not establish a decoder speed ranking.

Buffer estimates use **RGBA8888, four bytes per decoded pixel**, divided by 1,048,576 for MiB. They exclude codec intermediates, compressed data, native overhead, GPU copies and process memory. Cache probes distinguished retained, live and pending streams, source/target key separation, disposal, release and revisit. Distinct identities could share identical encoded content: this isolates cache geometry rather than representing twenty different photographs. Controlled network checks separated manager access, HTTP acquisition and bitmap decoding.

There were **80 accepted memory workloads**: 48 at 864-square (three sources × two policies × four counts × two repetitions), plus 32 at 1728-square (two sources × two policies × four counts × two repetitions). Counts were 1/5/10/20; sources covered an ordinary PNG, panorama and, for the smaller target, JPEG. Comparable runs used fresh processes and reversed ordering. Android `dumpsys meminfo` supplied **1,048 samples** across before/during/held/released/cache-cleared phases. During sequential decoding, sampling was approximately every half-second; other phases generally took three samples. Explicit cache clearing was a diagnostic phase, not a proposed application optimization.

The **18 scrolling trials** comprised three sources × two policies × three repetitions. An 80-row lazy list used 288-square logical slots and twenty cyclic identities, with three timed 0→15000→0 logical-pixel sweeps (three seconds per direction), settling, FrameTiming build/raster statistics and memory sampling. No extra repaint boundaries or cache tuning were added. Identical timed scrolling does not guarantee identical visited frames under different raster delays; fixed released-working-set probes independently establish cache churn.

### Second investigation: focused alternatives and widget contracts

The final matrix contained **84 observations**, twelve source/target cases × seven policies. It prioritized both 12000×1000 orientations at 258/864/1728-square targets, ordinary-aspect-ratio PNG fixtures at 864-square, and selected largest-bucket cases. Candidates were fit, unbounded cover, dimension ceilings 1728/2048/4096, a 1,048,576-pixel budget and stock-fit fallback when ideal cover exceeded 1728.

**55 completed released-working-set cohorts** compared 1/5/10/20 panorama identities at 864/1728-square targets under unchanged cache limits. One attempted unbounded twenty-image/1728 cohort was interrupted and excluded; its cause was not established. **Two controlled network cohorts**, five identities each, exercised fit then bounded cover with warm persistent files, retained hits and released revisits. This order does not establish equivalent cold-HTTP performance. Retained revisits caused no additional HTTP acquisition in those cohorts.

The probe exported **21 rendered crops** across seven policies; recorded human inspection covered **10**, including calibration circles/bars and a photographic crop. This was a limited softness/distortion comparison, not a blinded perceptual study. Separate isolated tests compared baseline and corrected slideshow behavior, and baseline/proposed EmptyView geometry and actual Flutter semantics trees.

## 4. Main decoding results

For a **12000×1000 panorama at an 864×864 physical target**, final matrix and twenty-identity cohort records agree:

| Strategy | Observed dimensions | Estimated buffer MiB | Additional revisit decodes, 20 images |
| --- | --- | ---: | ---: |
| Stock fit | 864×72 | 0.237 | 0 |
| Unbounded cover | 8192×864 | 27.000 | 20 |
| Dimension cap 1728 | 1728×144 | 0.949 | 0 |
| Dimension cap 2048 | 2048×171 | 1.336 | 0 |
| Dimension cap 4096 | 4096×342 | 5.344 | 20 |
| One-megapixel budget | 3547×295 | 3.992 | 0 |
| Selective fit fallback | 864×72 | 0.237 | 0 |

Unbounded cover requested **10368×864**, but the backend produced **8192×864**: independent-axis clamping changed the 12:1 ratio to approximately 9.48:1, about 21% relative ratio error. The observed 8192 limit is not a Flutter-wide guarantee. Integer rounding explains small bounded-policy ratio differences; it cannot explain this clamp.

The 1728 policy is the smallest dimension ceiling preserving an existing 1728-square request. It improves ordinary 4000×3000 → 864-square decoding from fit's 864×648 to **1152×864**, while limiting panorama amplification. Its panorama still requires sixfold enlargement along the short axis at 864-square; fit requires twelvefold. At 258-square it produces 1728×144 instead of ideal 3096×258. At 1728-square, ordinary 4000×3000 becomes 1728×1296, matching fit rather than ideal cover. These are explicit quality compromises, supported by geometry and limited crop inspection.

2048 offered additional detail without a new application target requiring it. 4096 left eighteen panorama entries retained; sequentially revisiting the twenty identities caused twenty further decodes through cascading eviction. Unbounded cover retained only three such entries. The 1728 cohort retained all twenty (19,906,560 bytes, approximately 18.984 MiB), with zero live/pending images after release and no additional revisit decoding. These are homogeneous clean-cache results, not guarantees for mixed production working sets.

The one-megapixel budget retained this cohort but reduces large square/ordinary targets unnecessarily, and a pixel count alone cannot bound an arbitrarily long axis below a backend texture limit. Selective fit fallback discarded useful detail that proportional limiting retained. No combined budget, transformation pipeline or policy framework was justified.

## 5. Memory and scrolling findings

The first investigation's panorama scrolling trials produced these process measurements:

| Policy | Trials | Observed peak PSS range, MiB | Median peak PSS, MiB |
| --- | ---: | ---: | ---: |
| Fit | 3 | 112.5–125.1 | 113.7 |
| Unbounded cover | 3 | 257.6–306.8 | 295.1 |

The median difference was **+181.4 MiB, approximately +159.5%** in this controlled emulator scenario. These medians were recomputed from per-trial sampled maxima; they are not measurements of the final bounded policy. All 80 accepted memory workloads and 1,048 phase samples belong to the first campaign; they must not be merged with the second campaign's cache cohorts.

PSS is apportioned process residency, not complete image/GPU residency. Sampling can miss transient peaks, and guest graphics accounting did not reliably expose software graphics allocations. Releasing consumers and clearing retained entries need not immediately restore initial PSS because allocators and the runtime retain memory. **No OOM, process-memory leak or physical-device frame-rate regression was demonstrated in accepted runs.** The interrupted uncapped stress attempt is not evidence of OOM.

Frame build/raster quantiles and slow-frame counts were instrumented against approximately 16.67 ms. SwiftShader rasterization was heavily over budget, preventing a useful claim about physical-device smoothness or attribution solely to decoding. Memory and fixed-order cache evidence support rejecting unlimited cover; emulator frame timing does not establish a production FPS regression or a final bounded-policy performance pass.

## 6. Second investigation and corrective evidence

The final 84-row matrix contained **four expected unbounded-cover proportionality failures**, covering the two extreme orientations at 864/1728-square. The earlier 108-row matrix had three failures under its different target selection; these counts are not contradictory or interchangeable. The bounded-policy checks passed within the stated one-pixel/codec quantization tolerance, without requests above intrinsic resolution. Actual decoded output, not the sizing formula alone, supported the correction.

The 55 completed cohorts demonstrated materially different retained-cache behavior among candidate policies, as the table shows. The two controlled network cohorts supported delegation and unchanged acquisition identity in the tested warm-cache conditions; they did not establish all expiry, concurrency or format behavior. Twenty-one exported crops and ten recorded inspections showed the expected sharpness tradeoff and corrected geometry, without proving universal perceptual quality.

No equivalent new process-memory or physical-device scrolling campaign was run for the final 1728 policy. Its measured bitmap/cache improvement must not be restated as measured production PSS savings.

## 7. Slideshow lifecycle findings

Baseline consumer-boundary probes reproduced active/offscreen callback interference: the same bool callback allowed an inactive page's success/error to alter the visible pending page's controls and ticker admission. Deferred captured values could publish after their original ownership changed. Twelve baseline probes yielded five passes and seven failures; they exercised actual PageView/control behavior with injected image callbacks, not twelve native decoder races.

Three additional real cache-manager → provider → Image success/error tests failed on baseline and passed with the temporary correction. Mutation probes showed that ignoring all inactive callbacks loses prefetched readiness, and clearing every owner's readiness on any list change loses unchanged slots. Child notification deduplication also exposed a parent-rebuild admission dependency previously masked by repeated frame notifications.

The correction retained readiness for valid slot owners, revoked replaced owners, and read current authoritative state when publishing/admitting autoplay. List A→C→A captured-callback tests establish ownership rejection, not proof that a native callback escapes an independently guarded child. Visibility subscription/rebinding and State-owned ticker lifetime were exercised; the surrounding production visibility wrapper already rebuilds, so isolated notifier tests do not demonstrate a wrapper-wide production failure.

Five gallery-route probes used the actual awaited GoRouter route Future with an opaque placeholder. Read-only ticker inspection was needed because route TickerMode can mask a restarted ticker. The ungated variant passed four of five; gallery-in-flight suspension passed five of five, including real image completion while the route remained pending. The complete gallery UI was not tested by that placeholder.

The final combined experimental suite passed **28 tests**. This supports separate source-local image lifecycle and slideshow active-owner responsibilities, the unchanged bool API, prefetched readiness and local gallery suspension. It is not a production implementation or proof of every navigation/disposal permutation.

## 8. EmptyView accessibility findings

Arbitrary widget-valued text cannot reliably become a semantic string. A known-label image-error caller therefore owns an explicit neutral description independently of optional visual text. Its narrow noninteractive Semantics boundary excludes duplicate decorative descendants; it must not exclude action-bearing shared content or announce a URL/private path.

Experimental widget/semantics checks covered **32/48/72/86 logical squares** at normal/enlarged text, a nonzero bounded broken-image icon, one meaningful label, fit boundaries and roomy equivalence. Baseline probes reproduced a zero-width icon at 32 and overflow at larger compact sizes. Separately, the actual Nearby error/retry composition at 320×216 and text scale 2 overflowed by 72 pixels, justifying a shared finite-height reachability fix beyond image slots.

The shared prototype preserved content and descendant semantics, scroll-reachable actions, at least 48-pixel supported action geometry, tap/focus/keyboard activation and unbounded sliver hosting. It kept existing constructors and roomy composition. Six expected baseline failures and **18 passing final experimental widget/semantics tests** supported these boundaries. Effective typography/accessibility overrides still require production integration checks. **Semantics-tree assertions do not verify actual TalkBack or VoiceOver speech.**

## 9. Architectural decision record

The accepted plan retains one specialized cover provider and one pure sizing function:

```text
scale = min(
  1,
  max(targetWidth / intrinsicWidth, targetHeight / intrinsicHeight),
  1728 / max(intrinsicWidth, intrinsicHeight)
)
```

Use positive codec-reported oriented dimensions and targets; ceil proportional dimensions, with positive/intrinsic/1728 integer guards. Preserve actual proportions within supported codec rounding. The ceiling derives from the largest existing requested network bucket, not a global memory budget or universal GPU guarantee. Supported backends must accommodate that dimension; lower-capability and untested backends remain unverified. Examined public sizing/provider APIs do not expose a portable active texture-limit query.

Keep original URL/persistent cache identity and configuration, separate immutable decoded keys for incompatible requests, stock non-cover behavior, and full-resolution gallery **unresized requests** subject to existing backend limits. Preserve animation configuration and loading fade. Add no cache manager, preprocessing, disk variants, pixel-budget layer, packages or configurable policy hierarchy.

AppNetworkImage owns its effective request and terminal loading transition; PostMediaSlideshow owns valid page readiness and active admission, including current-state deferred publication, visibility, user pause, State lifetime and awaited-gallery suspension. A small local owner mechanism suffices; no new state framework is justified.

Compact image errors own explicit semantics at their caller boundary. Shared EmptyView keeps its public constructors and arbitrary content; only independently demonstrated finite-height action reachability is shared. Compact image omission rules do not apply to interactive states.

## 10. Verification limits and future regression coverage

The experimental tests are **not integrated into production repository tests**. All implementation tasks remain unchecked. Implementation must add focused permanent regressions for actual output proportions/dimensions, intrinsic resolution/orientation, decoded-key separation and reuse, error eviction/lifecycle and released working sets under unchanged limits. Source/target changes, synchronous hits, animation compatibility and acquisition/decode accounting require integration coverage.

Slideshow coverage must verify obsolete owners/deferred callbacks, retained prefetched readiness, list mutation/reordering, visibility/disposal, user intent and gallery suspension through actual controls/ticker outcomes. EmptyView coverage must verify compact semantics, typography, unchanged roomy layouts and interactive action reachability/focus under finite/unbounded hosts.

**NOT VERIFIED:** physical Android devices; relevant iOS hardware/backends; complete animation/format/lifecycle permutations; real TalkBack/VoiceOver speech; physical-device memory and frame performance. Backend compatibility and focused Profile-mode comparisons remain release gates. Neither passing widget tests nor estimated buffers replace those checks; repeating the entire exploratory campaign is not required.

## 11. Reproduction guidance and provenance

The numerical totals and seven comparison rows were cross-checked against retained matrix, cohort, process-sample and scrolling records before publication; final widget pass counts were checked against retained test output. Preliminary/interrupted cohorts were excluded as described above. Recorded crop inspection is human evidence, distinct from automated assertions.

Repository checks available on the finalized PR checkout are:

```sh
flutter --version
openspec validate optimize-image-rendering-and-empty-view --strict
git diff --check
```

The OpenSpec command applies while the active change exists. For historical source inspection, use the immutable source links above or `git show` with the baseline SHA. The [PR file history](https://github.com/xmattjus/moliseis/pull/43/files) preserves the planning context if the change is later archived; this document remains independent of that directory.

Temporary experimental harnesses, generated fixtures/crops, raw JSON/JSONL, logs, APKs and machine-specific scripts **were not committed**. Consequently, the repository alone cannot rerun the exact historical campaign. Full numerical reproduction requires the retained disposable material or a newly constructed harness following the fixture/target/provider/cache/phase protocols above. No permanent benchmark executable or CI job is implied. New work should preserve source and policy versions, requested versus observed geometry, callback/decode counts, cache ownership and sample cohorts explicitly; do not substitute formula-only estimates for real decodes.
