/// Mutable bridge between settings persistence and AppLogger Sentry
/// integration.
///
/// Intentionally not immutable because runtime settings can change.
class SentryLoggingFlag {
  SentryLoggingFlag({required bool initialValue}) : enabled = initialValue;

  /// Whether events will be logged to Sentry or not.
  bool enabled;
}
