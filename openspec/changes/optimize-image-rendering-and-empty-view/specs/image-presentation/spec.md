# image-presentation Specification

## ADDED Requirements

### Requirement: Cover images decode proportionally for their physical rendering targets

Local staged thumbnails and bounded remote images painted with `BoxFit.cover` SHALL decode at a size based on decoder-reported intrinsic dimensions and the destination's physical width and height, preserving source aspect ratio and avoiding avoidable render-time upscaling. The requested decode dimensions SHALL NOT exceed the source's intrinsic resolution merely to satisfy a larger display target. Integer rounding and fractional device-pixel ratios SHALL NOT systematically undershoot a cover target that the source can satisfy.

#### Scenario: Non-square local photo in a square thumbnail

- **GIVEN** a valid staged local photo with a 4:3, 3:4, 4:1 or 1:4 aspect ratio
- **WHEN** the Admin or Public Content Submission form displays its 86×86 logical thumbnail at a supported device-pixel ratio
- **THEN** the image is decoded at an aspect-ratio-preserving size that covers the required physical rectangle where intrinsic source resolution permits
- **AND** painting with `BoxFit.cover` crops without stretching or avoidable upscaling
- **AND** neither form introduces an additional file copy, metadata-only read, persistent cache or independently owned asynchronous preview state

#### Scenario: Small original photograph

- **GIVEN** the intrinsic image is smaller than the target along an axis
- **WHEN** its preview is decoded
- **THEN** the decoder does not request pixels above intrinsic source resolution to manufacture detail
- **AND** rendering remains proportional and displays the best available source without distortion

#### Scenario: Oriented photo and fractional DPR

- **GIVEN** an image whose actual codec intrinsic dimensions reflect orientation metadata, and a destination with fractional DPR or non-square geometry
- **WHEN** the cover decode size is determined
- **THEN** sizing uses the actual decoder-reported dimensions rather than unverified database metadata
- **AND** the result preserves orientation and source proportions within decoder rounding tolerances

### Requirement: ImageProvider reuse preserves framework cache and error contracts

The shared cover-aware `ImageProvider` SHALL delegate actual byte acquisition and decoding to its wrapped provider without replacing local file, HTTP or cache-manager ownership. It SHALL use a stable immutable image-cache key distinguishing inner source identity and requested physical decode size; correctly propagate decode errors and allow normal eviction and subsequent resolution. It SHALL preserve synchronous cache-hit behavior when the underlying provider resolves synchronously.

#### Scenario: Same source and requested bucket

- **GIVEN** the same local staged source or remote URL and same image decode target
- **WHEN** the consumer rebuilds with an equivalent provider
- **THEN** the image-cache identity is equal and a retained decoded image is reused without avoidable new file or network reads

#### Scenario: Source or size changes

- **WHEN** the content-addressed staged path or remote provider identity changes, or a network image moves into a different size bucket
- **THEN** the image-cache key changes appropriately and the corresponding content/size is decoded
- **AND** obsolete source completions do not replace the current displayed image

#### Scenario: Underlying decode fails

- **WHEN** the wrapped file or network decoder emits an error
- **THEN** the error reaches the image display's failure handling without an unhandled Flutter framework exception
- **AND** failed decoding does not leave a permanently poisoned key that blocks a future fresh resolution

### Requirement: Network image sizing preserves network and disk-cache behavior

`AppNetworkImage` SHALL continue to derive physical decode targets from its explicit logical bounds and `ImageSizeBucket`. It SHALL use cover-aware proportional decoding for `BoxFit.cover`, contain-compatible decoding for `BoxFit.contain`/`BoxFit.scaleDown`, and an explicitly safe policy for other supported fits. Full-resolution gallery images SHALL remain unbounded by thumbnail buckets. Decode sizing SHALL NOT add URL variants, server-side transformations, network requests or disk-cache entries merely for additional decoded sizes.

#### Scenario: Same remote URL displayed in multiple sizes

- **WHEN** the same remote URL is displayed in two network size buckets and later revisited in the first
- **THEN** the remote/disk identity remains the same original URL
- **AND** each physical decode target has its appropriate in-memory cache identity
- **AND** revisiting a still-cached target does not generate an unnecessary extra cache-manager read or network fetch

#### Scenario: Gallery shows full-resolution image

- **WHEN** a user opens an image in the zoomable gallery
- **THEN** the displayed image uses its full intrinsic resolution with `BoxFit.contain` in the current gallery path
- **AND** the display keeps its existing gallery navigation/zoom/pan behavior
- **AND** shared error/loading handling is available without replacing the full-resolution path with a thumbnail decode

#### Scenario: Bounded contain or unusual fit

- **WHEN** `AppNetworkImage` is configured with `BoxFit.contain`, `scaleDown` or another supported fit
- **THEN** its decoding strategy does not produce aspect-ratio distortion or avoidable undersampling for that fit
- **AND** changes preserve existing visual geometry and network caching

### Requirement: Local and remote image failures provide accessible empty states

Failed local image reads/decodes and remote image loads/decodes, including full-resolution gallery images, SHALL display a meaningful `EmptyView` containing a Material Symbols `broken_image` icon and an accessible neutral image-unavailable description. A corrupt file SHALL NOT present a per-image retry control; the existing admin staged-path resolution retry SHALL remain a separate, unchanged recovery action. The failure view SHALL obey the image slot's bounds without overflow.

#### Scenario: Local file is unreadable, absent, empty or corrupt

- **WHEN** the local thumbnail provider fails to read or decode a staged file
- **THEN** a bounded `EmptyView` with the broken-image symbol replaces the failed image, and error semantics remain available even if visible text cannot fit
- **AND** no raw staging path is rendered or unnecessarily reported in telemetry
- **AND** no retry button is added for retrying the corrupt image decoder

#### Scenario: Remote image fails in list, card, slideshow or gallery

- **WHEN** a remote image fails to load or decode
- **THEN** the same neutral image-unavailable presentation is available in every `AppNetworkImage` constructor
- **AND** the existing typed image-failure diagnostic is emitted under the established logging privacy policy without repeated rebuild noise
- **AND** the error does not remain a blank/black image with no user feedback
- **AND** terminal failure does not leave a consumer's loading callback or slideshow behavior stuck in an incorrect loading state

#### Scenario: Admin cannot resolve a staged path

- **WHEN** the admin staged-file repository cannot resolve an available staged descriptor
- **THEN** the existing path-resolution placeholder and guarded `Riprova anteprima foto` action remain available
- **AND** this recovery is not confused with a retry of an already resolved but corrupt image

### Requirement: Network image API exposes only effective parameters

`AppNetworkImage` SHALL document its bounded and full-resolution constructors, fit, dimensions, cache and loading semantics and SHALL NOT require unused source `imageWidth` or `imageHeight` arguments. Existing domain and persisted media metadata SHALL remain unchanged.

#### Scenario: All current consumers migrate to the effective API

- **WHEN** bounded cards/lists/carousel/slideshow/admin media and full-resolution gallery construct `AppNetworkImage`
- **THEN** they pass only functional parameters and compile without `imageWidth` or `imageHeight`
- **AND** the unchanged intrinsic metadata remains available to unrelated domain and navigation contracts
- **AND** the widget documentation describes the actual image-sizing, loading, cache and error behavior
