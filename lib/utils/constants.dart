const double kGridViewCardWidth = 288; // 356.0;

const double kGridViewCardHeight = 216; // 276.0;

const double kListViewCardWidth = 600;

const double kListViewCardHeight = 96;

const double kButtonHeight = 40;

const String kAssetMapTilerIconPath =
    'assets/icons/maptiler-icon-dark_64x69_optimized.png';

/// The default network request timeout in seconds.
///
/// Equals to `10`.
const int kDefaultNetworkTimeoutSeconds = 10;

const String kUserAgent = 'it.benitomatteobercini.moliseis/2.1';

/// Maximum size, in bytes, of a single asset uploaded to Cloudinary.
///
/// Mirrors Cloudinary's free-tier upload limit (10 MiB). Files larger than
/// this are rejected client-side before any network bytes are transferred, so
/// the user gets immediate feedback instead of a `http_400
/// "File size too large"` failure after the upload has already streamed.
const int kCloudinaryMaxUploadBytes = 10 * 1024 * 1024;

/// Maximum number of assets associated with one content submission.
const int kMaximumSubmissionAssetCount = 5;
