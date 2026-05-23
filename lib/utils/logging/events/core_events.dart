part of 'package:moliseis/utils/logging/log_event.dart';

/// Fired when an image failed to load.
class ImageLoadFailed extends LogEvent {
  /// Creates an event for a failed image load.
  const ImageLoadFailed();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'image_load_failed';
}

/// Fired when the content id could not be parsed while loading a Post route.
class PostRouteContentIdParseFailed extends LogEvent {
  /// Creates an event with a [reason] describing the parse failure.
  const PostRouteContentIdParseFailed({required this.reason});

  /// Human-readable description of why content id parsing failed.
  final String reason;

  @override
  Map<String, Object?> get data => {'reason': reason};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'post_route_content_id_parse_failed';
}

/// Fired when a SnackBar could not be shown.
class SnackBarShowFailed extends LogEvent {
  /// Creates an event with an optional [reason] for the failure.
  const SnackBarShowFailed({this.reason});

  /// Optional context describing why the SnackBar could not be displayed.
  final String? reason;

  @override
  Map<String, Object?> get data =>
      reason != null ? {'reason': reason} : const {};

  @override
  AppLogLevel get level => AppLogLevel.warning;

  @override
  String get name => 'snack_bar_show_failed';
}
