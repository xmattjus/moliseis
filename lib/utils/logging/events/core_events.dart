part of 'package:moliseis/utils/logging/log_event.dart';

/// Fired when an image failed to load.
class ImageLoadFailed extends LogEvent {
  /// Creates an event for a failed image load.
  const ImageLoadFailed({required this.url});

  /// The url of the requested image to load.
  final String url;

  @override
  Map<String, Object?> get data => {'url': url};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'image_load_failed';
}

/// Fired when the router error screen is shown for an unmatched or invalid
/// route location.
class RouteErrorScreenShown extends LogEvent {
  /// Creates an event for the displayed [uri], optionally carrying the
  /// [reason] that prevented the location from being rendered.
  const RouteErrorScreenShown({required this.uri, this.reason});

  /// The location that could not be matched or parsed.
  final String uri;

  /// Human-readable description of the failure, when available.
  final String? reason;

  @override
  Map<String, Object?> get data =>
      reason == null ? {'uri': uri} : {'uri': uri, 'reason': reason};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'route_error_screen_shown';
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
