import 'package:moliseis/utils/logging/logging.dart';

part 'events/core_events.dart';
part 'events/local_persistence_log_events.dart';
part 'events/network_log_events.dart';
part 'events/repository_log_events.dart';
part 'events/service_log_events.dart';
part 'events/content_submission_events.dart';
part 'events/admin_events.dart';

/// Regex that all event names must match: 3+ snake_case segments.
final eventNamePattern = RegExp(r'^[a-z]+(_[a-z]+){2,}$');

/// Base type for all loggable events in the application.
///
/// A `LogEvent` carries the event name, severity level, and a map of
/// structured data. Subclasses (sealed hierarchies) represent specific
/// domain events.
sealed class LogEvent {
  const LogEvent();

  /// Arbitrary key-value payload associated with the event.
  Map<String, Object?> get data;

  /// Severity level of this event.
  AppLogLevel get level;

  /// Short identifier for this event, in the form `<domain>_<action>_<result>`.
  String get name;
}
