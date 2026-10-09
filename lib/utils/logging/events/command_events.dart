part of 'package:moliseis/utils/logging/log_event.dart';

/// A handled unexpected command failure, with a non-sensitive command name.
final class CommandExecutionFailed extends LogEvent {
  /// Receives only an allow-listed name from the command reporting boundary.
  const CommandExecutionFailed({required this.debugName});

  /// A constant command identifier, never a parameter or user input.
  final String debugName;

  @override
  Map<String, Object?> get data => {'debugName': debugName};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'command_execution_failed';
}
