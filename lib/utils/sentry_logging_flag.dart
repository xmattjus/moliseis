/// Mutable bridge between settings persistence and SentryTalkerObserver.
/// Intentionally not immutable because runtime settings can change.
class SentryLoggingFlag {
  bool enabled;

  SentryLoggingFlag({required bool initialValue}) : enabled = initialValue;
}
