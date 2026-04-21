import 'package:meta/meta.dart';

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
  final String cityName;
  final String areaName;
}
