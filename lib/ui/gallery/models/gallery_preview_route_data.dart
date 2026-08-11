import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/media.dart';

/// Serializable data used to open the gallery route.
///
/// The encoded representation contains only message-codec primitives so the
/// router can safely persist and restore it.
@immutable
final class GalleryPreviewRouteData {
  GalleryPreviewRouteData({
    required List<Media> media,
    required this.initialIndex,
  }) : media = List<Media>.unmodifiable(media) {
    if (media.isEmpty) {
      throw ArgumentError.value(media, 'media', 'must not be empty');
    }
    if (initialIndex < 0 || initialIndex >= media.length) {
      throw RangeError.range(
        initialIndex,
        0,
        media.length - 1,
        'initialIndex',
      );
    }
  }

  /// Media displayed by the gallery.
  final List<Media> media;

  /// Zero-based page shown when the route opens.
  final int initialIndex;

  /// Encodes this data into a router-restorable primitive map.
  Map<String, Object?> toExtra() => <String, Object?>{
    'initialIndex': initialIndex,
    'media': media.map(_encodeMedia).toList(growable: false),
  };

  /// Parses external router data without throwing for malformed payloads.
  static GalleryPreviewRouteData? tryParse(Object? extra) {
    if (extra is! Map<Object?, Object?>) return null;

    final initialIndex = extra['initialIndex'];
    final encodedMedia = extra['media'];
    if (initialIndex is! int || encodedMedia is! List<Object?>) return null;

    final media = <Media>[];
    for (final encodedItem in encodedMedia) {
      final item = _tryParseMedia(encodedItem);
      if (item == null) return null;
      media.add(item);
    }
    if (media.isEmpty || initialIndex < 0 || initialIndex >= media.length) {
      return null;
    }

    return GalleryPreviewRouteData(media: media, initialIndex: initialIndex);
  }

  static Map<String, Object?> _encodeMedia(Media media) => <String, Object?>{
    'remoteId': media.remoteId,
    'title': media.title,
    'author': media.author,
    'license': media.license,
    'licenseUrl': media.licenseUrl,
    'url': media.url,
    'width': media.width,
    'height': media.height,
    'createdAt': media.createdAt.millisecondsSinceEpoch,
    'modifiedAt': media.modifiedAt.millisecondsSinceEpoch,
    'areaName': media.areaName,
    'cityName': media.cityName,
  };

  /// Parses a single map produced by [_encodeMedia].
  ///
  /// Returns `null` for any payload whose shape does not match [_encodeMedia]:
  /// missing keys, wrong value types, or timestamps outside the range accepted
  /// by [DateTime.fromMillisecondsSinceEpoch] (which throws [RangeError] for
  /// out-of-range milliseconds — the validation the manual bounds checks used
  /// to duplicate).
  static Media? _tryParseMedia(Object? encoded) {
    if (encoded is! Map<Object?, Object?>) return null;

    // Required, non-nullable fields. Each `is!` guard also promotes the local
    // to its concrete type, so the constructor call below needs no casts.
    final remoteId = encoded['remoteId'];
    if (remoteId is! int) return null;

    final url = encoded['url'];
    if (url is! String) return null;

    final width = encoded['width'];
    if (width is! int) return null;

    final height = encoded['height'];
    if (height is! int) return null;

    final createdAt = encoded['createdAt'];
    if (createdAt is! int) return null;

    final modifiedAt = encoded['modifiedAt'];
    if (modifiedAt is! int) return null;

    final areaName = encoded['areaName'];
    if (areaName is! String) return null;

    final cityName = encoded['cityName'];
    if (cityName is! String) return null;

    // Optional, nullable String fields: `null` is allowed, any other
    // non-String type is rejected. The `as String?` cast in the constructor
    // call below is safe because the guard guarantees the value is `null` or
    // a `String`.
    final title = encoded['title'];
    if (title != null && title is! String) return null;

    final author = encoded['author'];
    if (author != null && author is! String) return null;

    final license = encoded['license'];
    if (license != null && license is! String) return null;

    final licenseUrl = encoded['licenseUrl'];
    if (licenseUrl != null && licenseUrl is! String) return null;

    try {
      return Media(
        remoteId: remoteId,
        title: title as String?,
        author: author as String?,
        license: license as String?,
        licenseUrl: licenseUrl as String?,
        url: url,
        width: width,
        height: height,
        // DateTime.fromMillisecondsSinceEpoch throws RangeError when the
        // absolute value exceeds 8640000000000000 — the built-in check
        // replaces the manual timestamp bounds. RangeError is an
        // ArgumentError, so the catch below covers it.
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(modifiedAt),
        areaName: areaName,
        cityName: cityName,
      );
    } on ArgumentError {
      return null;
    }
  }
}
