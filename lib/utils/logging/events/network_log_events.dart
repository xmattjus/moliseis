part of 'package:moliseis/utils/logging/log_event.dart';

/// Fired when an HTTP request times out.
class NetworkRequestTimeout extends LogEvent {
  const NetworkRequestTimeout();

  @override
  Map<String, Object?> get data => const {};

  @override
  AppLogLevel get level => AppLogLevel.warning;

  @override
  String get name => 'network_request_timeout';
}
