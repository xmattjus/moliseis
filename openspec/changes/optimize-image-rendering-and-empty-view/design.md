# Design

## Context

At the inspected baseline (`main` = `886556409ef8e7254e8c241a77d643c5e9403fd1`), Admin and Public Content Submission share `ContentSubmissionFileThumbnail`: an 86×86 logical slot using `ResizeImagePolicy.fit` and `BoxFit.cover`. See proposal.md for the resulting undersampling defect.

There are five bounded `AppNetworkImage` call sites: content grid card, content list item, explore suggestions, post slideshow and admin associated media. They use cover. One full-resolution gallery call site uses contain for zoom/pan. `imageWidth/imageHeight` are supplied but unused. Flutter 3.47.5 and the locked `cached_network_image_ce` 4.13.1 are the compatibility baseline; no dependency update is part of this change. The app leaves the network provider's animation setting at its existing default, which is enabled.

`AppNetworkImage.fullResolution` currently bypasses the usual error/loading builders. Local thumbnails have no error builder. `EmptyView` uses a centered Column, 16 px outer padding, 16/16/16/8 icon padding and a default 40 px icon. It also serves spacious loading/error/action states and unbounded-height sliver hosts.

Focused follow-up experiments support three planning decisions. Bounded proportional output corrects the observed independent-axis decoder clamp; a 1728 output bound keeps ordinary 864-square cover decodes unchanged and retains a released cohort of 20 panoramas in the unchanged 100 MiB cache. Callback/widget experiments show cross-page slideshow state corruption and a dependency on repeated child notifications. Actual semantics trees show that explicit image-error labels survive icon-only presentation; an existing non-image action state also needs bounded vertical reachability. These are disposable feasibility/regression experiments, not implemented production features. The [curated historical evidence](../../../docs/performance/image-decoding-pr43-evidence.md) records methods, measured results and verification limits; [PR #43 file history](https://github.com/xmattjus/moliseis/pull/43/files) provides a stable provenance locator if this change directory is later archived. This evidence does not replace implementation or device acceptance.

The supplied audits establish useful source/decode evidence, not device performance acceptance. Repository sources and applicable AGENTS.md, Flutter UI, async safety and logging/privacy contracts remain authoritative.

## Goals / Non-Goals

**Goals**
- Improve proportional bounded decoding against local physical targets and unchanged network buckets, with an explicit source/output-bound quality exception.
- Share one cover-only wrapper without changing acquisition, cache ownership or staging lifecycle.
- Preserve network bucket limits, full-resolution gallery behavior, existing animation behavior and loading fade.
- Provide neutral accessible failure feedback and useful privacy-safe diagnostics; preserve admin path-resolution retry.
- Separate explicit compact image-error semantics from focused shared EmptyView vertical reachability; preserve constructors, spacious layouts and usable actions.
- Establish reproducible decode/memory comparisons and device acceptance without promising constant memory independent of aspect ratio.

**Non-goals**
- Metadata-only reads, new caches, staging copies, server transforms, URL variants, dependencies or dependency/SDK upgrades.
- A configurable decode-policy wrapper, strategy hierarchy, extra provider subclasses for non-cover fits, request coalescing or network infrastructure.
- Changes to staging/upload, domain metadata, persistence, gallery navigation, theme, animation policy or fade design.
- Compact constructors/flags, a responsive framework, per-corrupt-image retry, new logging services or remote event families.

## Decisions

### 1. One cover-specific provider

Use one small delegating `ImageProvider` shared by local thumbnails and bounded network cover images. Flutter's stock `ResizeImage` exposes fit/exact sizing but no equivalent intrinsic-aware cover policy; delegating its decoder callback avoids a separate metadata read or reimplementation of HTTP/file codecs.

The selected pure sizing rule uses positive actual decoder-reported intrinsic dimensions, including orientation as exposed by the codec, and positive physical requested targets:

```
scale = min(1,
            max(targetWidth / intrinsicWidth, targetHeight / intrinsicHeight),
            1728 / max(intrinsicWidth, intrinsicHeight))
```

Request `ceil(intrinsicWidth * scale)` × `ceil(intrinsicHeight * scale)`, guarding each result to at least one pixel and at most its intrinsic dimension and 1728. Both axes use the same factor; final one-pixel quantization guards are not independent geometric resizing. Document and test integer/codec tolerance against observed output, not only the requested rectangle. Do not use database dimensions or perform a metadata pre-read.

**Why 1728:** this is the smallest dimension ceiling that preserves the existing largest 1728-square requested decode. For any current requested rectangle whose axes are at most 1728, this sizing is no lower resolution than the old proportional fit (within integer tolerance), while still improving normal 864-square cover: 4000×3000 decodes at 1152×864 instead of 864×648. A 12000×1000 panorama at 864-square decodes at 1728×144 instead of fit's 864×72 or unbounded cover's observed distorted 8192×864. The bounded panorama is about 0.949 MiB at four bytes/pixel, versus 27 MiB observed unbounded cover. Its 20-entry released cohort reused all entries under the unchanged default cache. This is not a promise that every mixed working set remains cached.

**Quality exception:** when the bound binds, the short axis may not cover the destination without enlargement, even if the source has enough detail. The same panorama at a local 258-square target uses 1728×144 rather than ideal 3096×258. At the largest network bucket a normal 4000×3000 source becomes 1728×1296, matching old fit rather than ideal 2304×1728. Small sources remain bounded by intrinsic resolution. State these exceptions rather than promising unconditional no-upscale or full cover. Full-resolution gallery decoding is unchanged.

**Rejected alternatives:** 2048 gives modest additional detail but raises output/storage demand above the established maximum dimension; 4096 retains useful detail but 20 tested panoramas exceed retained-cache capacity and require repeated decoding. A one-megapixel budget retained that cohort but unnecessarily reduces large square/ordinary images and alone cannot bound an arbitrarily long axis below a texture limit. Selective stock-fit fallback is safe within the existing target compatibility envelope but throws away more useful detail at smaller destinations than proportional dimension limiting. One dimension ceiling is sufficient for the demonstrated problem; add no second pixel budget, policy enum, runtime knobs or strategy hierarchy.

**Portability boundary:** getTargetSize/ImageProvider and the examined dart:ui APIs do not expose the active backend's maximum texture dimension. The observed 8192 clamp is not a portable guarantee. The no-engine-clamp argument requires a backend capable of at least the existing 1728 dimension. OpenGL ES 3.0 specifies at least 2048; OpenGL ES 2.0's specification alone does not establish that floor. No GPU query, platform support filter or manifest change is authorized. Test the bounded path on the supported backend/device envelope before device acceptance; lower-capability legacy backends and untested iOS/other configurations remain NOT VERIFIED, not implicitly supported by this experiment. Below that envelope, stop and resolve the supported-device contract rather than silently raising the cap or claiming universal protection. The output bound does not constrain transient full-source codec allocations, total live consumers, GPU memory or process memory.

Delegate `loadImage` to `FileImage` or `CachedNetworkImageProvider`, forwarding the bounded-cover `getTargetSize`. Preserve synchronous `obtainKey` resolution and normal error propagation. Use a distinct immutable cover-key type containing the resolved inner source key and requested target dimensions. Equivalent cover requests reuse that key; stock `ResizeImage` keys must never collide with it. Error eviction must address the outer cover key as well as preserve underlying provider behavior. Use ephemeral error handling rather than a retained listener that keeps an unused stream alive. Avoid descriptors retained beyond codec ownership or new asynchronous thumbnail state.

Keep the wrapper exclusively cover-specific: no policy property or non-cover strategy. For contain/scaleDown retain stock `ResizeImage(policy: ResizeImagePolicy.fit)` where compatible. Other fits keep their existing Flutter path and geometry, without expanding the wrapper or claiming that this change fixes every pre-existing fit limitation. Verify cover→contain, contain→cover and repeated equivalent requests using actual decoded results, not just runtime types.

### 2. Targets, identity and compatibility

Local thumbnails use `ceil(86 * DPR)` on both axes and continue painting with cover. Bounded network images keep `ImageSizeBucket.resolveAndClamp` on logical bounds and DPR. Their normal-case coverage guarantee is relative to the resulting bucket, capped at 1728 px per requested axis, subject independently to the intrinsic/output-bound exception, not the unrestricted screen target. For example, 1000×1000 logical at DPR 2 requests a 1728×1728 bucket, so render-time upscale to 2000×2000 is accepted. This intentional cap differs from the fit/cover mismatch being fixed. The bucket still describes the requested rectangle. The separate proportional output ceiling now also limits each decoded axis to 1728; do not change ImageSizeBucket to implement it or confuse the two contracts.

Keep five separate invariants:

| Boundary | Preserved contract |
| --- | --- |
| URL/cache key | Original URL and existing underlying cache-key configuration; no size-derived variants |
| Persistent disk cache | Same original entry; do not pass decode targets as disk-resize parameters or add persistent variants |
| Flutter ImageCache | Distinct entries for incompatible source/target/provider keys; equivalent retained requests reuse their decoded stream |
| Cache-manager activity | No unnecessary extra reads relative to the old pipeline under equivalent conditions; a retained decoded hit bypasses acquisition |
| Actual HTTP requests | No unnecessary increase relative to the old pipeline with equivalent cache state and access pattern; no single-request promise for concurrent cold misses |

Different buckets can require separate decodes and manager reads while sharing disk identity. The real manager can issue multiple HTTP requests for concurrent cold reads of one URL and may refresh expired entries. Regression checks must measure manager reads and HTTP sends separately: same/different buckets, warm cache, concurrent cold cache and deterministic expiry where practical. Retain existing manager, cache limits and configuration; add no coalescing layer. Different requested buckets keep distinct outer keys even when the bound makes their output sizes equal. A sharper or mixed working set may still evict entries; compare reads only under declared retention conditions, not a universal no-extra-read promise.

Full-resolution images keep their original unresized provider request, subject to existing codec/backend output limits, and gallery contain/zoom/pan behavior; the bounded-cover ceiling does not apply. Preserve network provider animation configuration and multiframe completer behavior in both paths; a compatibility fixture checks that delegation does not freeze or break existing playback. Preserve the bounded loading fade, including synchronous-hit behavior, by default. Device checks look for regressions, not a fade optimization workstream or new configuration API.

Remove unused `imageWidth/imageHeight` from both AppNetworkImage constructors and all six call sites/tests. Retain domain, persistence and navigation dimensions. Document effective fit, bounds, DPR/buckets, cache, loading/error and animation compatibility contracts.

### 3. Failure feedback, diagnostics and loading callbacks

Use the explicit image-error composition described below, with existing EmptyView where it fits, `Symbols.broken_image` and neutral feedback such as "Immagine non disponibile" for local missing/empty/corrupt/unreadable files and remote timeout/HTTP/decode failures, including full-resolution gallery. Keep clipping and slot geometry; ensure gallery feedback remains visible against its background. Add no per-image corrupt-media retry. The existing admin staged-path resolution retry remains unchanged and separate.

Separate presentation, local Debug diagnostics and approved remote telemetry. For network errors retain `ImageLoadFailed`, original error/stack and AppLogger's existing bounded projection. For resolved local-file decode/read failures, reuse that typed logging boundary with a fixed non-sensitive source label rather than a private path in the event's URL field; retain the original cause/stack for Debug inspection. Do not pre-render exception messages. The existing event has no application exception capture and its remote projection excludes raw URL/message/stack; keep that policy, consent and terminal-owner rules unchanged. This preserves useful local evidence when errorBuilder consumes the framework error without adding a logger or remote event family. Suppress repeated diagnostics caused only by rebuilds of the same failure locally, without global deduplication or concealing a genuinely new failure.

Both constructors' `onImageLoading` describe the current effective image request (source/provider identity, fit/target/full-resolution path as relevant). Terminal success **or failure** publishes non-loading. Reject obsolete-request callbacks and post-disposal access at entry and after deferral; suppress unchanged frame/build notifications. Preserve synchronous retained-hit admission and original animation/fade behavior. Do not require a particular redundant initial callback sequence.

### 4. Slideshow owns active-page admission

The bool callback API remains unchanged. AppNetworkImage knows its own request; it cannot know which PageView page may control the slideshow. PostMediaSlideshow retains readiness only for its current valid page owners, including built/prefetched offscreen pages, and defines the active index through PageView's page-change contract. Offscreen events may update their own readiness but cannot directly start/stop the active page. Selecting a settled offscreen page reads stored readiness without expecting a replay from a deduplicated child; an unknown active owner is pending.

Keep an independent snapshot of ordered `(remoteId, URL)` slot identities, including in-place list changes. Preserve readiness and a stable local owner handle for an unchanged slot; renew/revoke it when that slot's identity changes or disappears, and prune obsolete entries. Bind child identity/callback to that owner (a small per-slot token/key is sufficient); do not use a global list generation that loses unchanged readiness. Index/source equality alone can accept an old callback after a list A→C→A replacement. The adversarial ABA reproduction invokes a captured consumer callback; it is not evidence that a correctly guarded native image callback escapes its child. An equivalent owner-revocation mechanism is acceptable, without a universal state machine.

Delayed UI publication must read the latest authoritative active-owner state or validate captured ownership at execution. A mounted check alone cannot validate a page, source or queued bool. All autoplay start/resume paths read that same current state and require mounted, multiple media, visible, enabled/user intent, no local gallery suspension and a settled current owner; success and handled failure both settle. Preserve manual pause/user-scroll decisions, existing five-second timing, gallery pause/return behavior and loading fade. Scroll visibility does not represent an awaited gallery route: retain a small local in-flight suspension around that existing Future, reject duplicate opens while it is owned, and release it on success/error without swallowing route failures. A late image completion must not restart the ticker during that pause; return rechecks current owner, visibility and user intent, and disposal must not access State.widget/context or disposed resources. This is local admission bookkeeping, not gallery navigation redesign. Repeated frame notifications currently mask a pending-parent-rebuild admission defect; fix the parent together with child deduplication.

Own the ticker for State lifetime independently of current media count (one initialized ticker, always disposed, is sufficient). Subscribe/rebind/unsubscribe visibility notification ownership. Reconcile controller/active index on source replacement, reorder, removal and empty/single/multiple transitions, without out-of-range or obsolete page publication. No ViewModel, event bus, callback API expansion, new state framework or gallery architecture change.

### 5. Explicit image-error semantics and narrow shared reachability

Keep EmptyView, EmptyView.error and EmptyView.loading signatures, widget-valued fields, default typography/icon and roomy layout. Do not attempt to extract strings from arbitrary widgets or generically hide shared text while promising its semantic description survives.

The local/network image-error consumer owns the known neutral description, such as "Immagine non disponibile", independently of visual Text. Use one small noninteractive image-error composition shared by these real consumers. A Semantics boundary with the explicit label excludes its decorative/icon/text descendants to avoid duplicate announcements. It must never wrap or exclude an action-bearing EmptyView that way. No source URL/path is part of that description. Preserve masks, clipping and gallery contrast.

This image-only composition uses the normal EmptyView when its actual known text, icon and decorations fit; otherwise center a visible broken-image icon within the slot, retaining the same semantic owner. Use actual parent constraints and effective rendered typography/scaling to assess the known label, not a widget-tree extraction heuristic or an arbitrary image-height breakpoint. Existing composition requires at least 104 logical pixels of width and `96 + measured label height` vertically: outer padding32, icon40 and icon padding16/16/16/8. A measured-label fit check is sufficient; reuse existing typography conventions for TextScaler, direction/locale and effective style/accessibility overrides. Exact mechanism remains a local implementation detail. In compact mode use a nonzero icon at most 40 and within both slot axes. Test 32/48/72/86 squares and fit boundaries, with no clipping/overflow and exactly one description. Do not suppress text scaling or shrink the entire state with FittedBox.

Independently, a real NearbyContentHorizontalList error/retry state in its finite 216-height slot overflows at width 320 and text scale 2. Thus focused shared vertical reachability is justified beyond image slots. Under finite height, preserve all arbitrary content/actions in a bounded scroll fallback with the viewport minimum height so normal content stays centered and roomy geometry remains equivalent. Under unbounded scroll/sliver height, retain a shrink-wrapped content path without another unbounded viewport or flex error. Do not hide or shrink actions, exclude their semantics, or apply the compact square matrix to them. Verify actual supported parent geometry, text scaling, focus/keyboard/tap, screen-reader semantics and reachability after scrolling. A viewport smaller than a 48-square target cannot expose that entire target at once; test reachable usable geometry honestly. No generic responsive framework or new EmptyView API.

### 6. Verification and memory acceptance

Use real local/network-provider decodes for ratios 1:1, 4:3, 3:4, 4:1, 1:4 and an extreme panorama, small sources, non-square targets and DPR 1/2/2.625/3. Include EXIF orientation where feasible. Compare old fit, proposed cover and full-resolution dimensions using the same fixture and target. Deterministic acceptance requires proportional output within documented codec rounding, no requested dimensions above source, normal coverage where source and output ceiling permit, explicit bounded-quality exceptions, and network coverage relative to the authorized bucket including accepted above-cap display upscale.

Record a reproducible table with fixture dimensions/format/orientation, slot, DPR, bucket, expected and observed decode dimensions, pixel counts and estimated buffer cost `decodedWidth * decodedHeight * bytesPerPixel`. State the pixel-format assumption (for example 4 bytes for RGBA8888); this is a buffer estimate, not total decoder/native/GPU/cache/process memory. Cover can cost substantially more than fit because it retains pixels later cropped. Memory proportionality depends on destination geometry and source/target aspect-ratio mismatch, not compressed file bytes or slot area alone. Preserve existing cache limits/network buckets and the selected single output ceiling; add no transforms. Check a released homogeneous panorama working set up to 20 against a clean default cache, equal-key reuse and incompatible fits separately. The per-axis bound implies at most 1728² output pixels, not a universal total-memory budget. Do not require the previous full benchmark campaign as an implementation prerequisite.

Device-dependent acceptance compares the same fixtures, list/grid density and scrolling interaction on representative supported hardware, recording device/build, memory pressure, scrolling/raster observations and residual risks. The expected sharper decode cost is not itself a regression failure; unexplained extra decoding/reads or observed memory-pressure/scroll failures require investigation before declaring the performance DoD complete. Unavailable devices, formats or observations remain explicit verification gaps, never invented passes. No universal memory budget or constant-memory claim is made.

Tasks assign decode/cache, source-local lifecycle, active-page lifecycle, remote/gallery and image-error/shared EmptyView regressions to their owning components. Deterministic widget/semantics/decode checks are separate from physical-device performance acceptance. Integration acceptance additionally runs analyzer, relevant suite and CI, verifies both Notion DoDs and records the device comparison. Do not commit scratch logs, experimental harnesses or generated evidence clutter.

## Risks / Tradeoffs

- **Extreme aspect ratios** → apply the output ceiling and document remaining sharpness loss/device impact; cache and pixel bounds do not promise a process-memory bound.
- **Provider lifecycle** → verify synchronous keys, policy separation, error eviction, listener release and late source changes against the locked dependency.
- **Page ownership** → preserve prefetched readiness without allowing stale owners or queued values to control the active page.
- **Shared EmptyView** → keep known-label compact semantics local; test finite reachability, action semantics and unbounded hosts without changing roomy geometry.
- **Handled errors** → preserve original local diagnostics and the existing sanitized remote boundary without duplicate capture.
