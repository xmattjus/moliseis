/// Log severity levels used across the application.
///
/// A logger configured with a minimum level will ignore events below that
/// threshold.
enum AppLogLevel {
  /// The least severe log level used for temporary or development-only logging.
  ///
  /// Logs with this severity are not sent to Sentry.
  debug,

  /// The log level used for general operational messages.
  info,

  /// The log level used for recoverable issues, e.g. network timeouts.
  warning,

  /// The log level used for unexpected failures.
  error,

  /// The most severe log level used for fatal or data-loss situations.
  critical,
}
