import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/city.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';

/// A media asset (image) attached to a [Place] or [Event].
@immutable
class Media {
  const Media({
    required this.remoteId,
    this.title,
    this.author,
    this.license,
    this.licenseUrl,
    required this.url,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.modifiedAt,
    required this.areaName,
    required this.cityName,
  });

  final int remoteId;
  final String? title;
  final String? author;
  final String? license;
  final String? licenseUrl;
  final String url;
  final int width;
  final int height;
  final DateTime createdAt;
  final DateTime modifiedAt;

  /// The [City] name this media is related to.
  final String cityName;

  /// The [Event] or [Place] name this media is related to.
  final String areaName;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Media &&
        other.remoteId == remoteId &&
        other.title == title &&
        other.author == author &&
        other.license == license &&
        other.licenseUrl == licenseUrl &&
        other.url == url &&
        other.width == width &&
        other.height == height &&
        other.createdAt.isAtSameMomentAs(createdAt) &&
        other.modifiedAt.isAtSameMomentAs(modifiedAt) &&
        other.cityName == cityName &&
        other.areaName == areaName;
  }

  @override
  int get hashCode => Object.hash(
    remoteId,
    title,
    author,
    license,
    licenseUrl,
    url,
    width,
    height,
    createdAt.millisecondsSinceEpoch,
    modifiedAt.millisecondsSinceEpoch,
    cityName,
    areaName,
  );
}
