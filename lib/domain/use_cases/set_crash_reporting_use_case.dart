import 'dart:async';

import 'package:moliseis/domain/repositories/settings_repository.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/sentry_logging_flag.dart';

/// Observable process state, independent of the saved preference.
enum CrashReportingState {
  /// The SDK was initialized in this process and has not begun shutdown.
  active,

  /// The SDK was never initialized or its close operation completed.
  inactive,

  /// The original physical close is still within its observation deadline.
  closing,

  /// Close failed or exceeded its deadline; native success is not established.
  unconfirmed,
}

/// Timing of a successfully persisted consent change.
enum CrashReportingOutcome {
  /// Reporting will activate only in a fresh process.
  enabledForNextStart,

  /// No SDK is active, or the supported close operation completed.
  disabled,

  /// Consent was saved, but shutdown could not be confirmed.
  shutdownUnconfirmed,

  /// A later committed intent owns feedback.
  superseded,
}

/// A consent result whose feedback authority expires on later reconciliation.
class CrashReportingUpdate {
  const CrashReportingUpdate._(this.outcome, this._revision, this._preference);

  /// Describes effect timing without conflating persistence and shutdown.
  final CrashReportingOutcome outcome;
  final int _revision;
  final bool _preference;
}

/// Owns persisted consent and one process shutdown across presentation owners.
///
/// Public SDK completion cannot expose internally swallowed native failures;
/// native acceptance remains separate from this observable operation.
class SetCrashReportingUseCase {
  /// [initiallyEnabled] is bootstrap eligibility, never fallback consent.
  SetCrashReportingUseCase({
    required SettingsRepository settingsRepository,
    required SentryLoggingFlag sentryLoggingFlag,
    required bool initiallyEnabled,
    required Future<void> Function() closeSentry,
  }) : _repository = settingsRepository,
       _flag = sentryLoggingFlag,
       _closeSentry = closeSentry,
       _state = initiallyEnabled
           ? CrashReportingState.active
           : CrashReportingState.inactive {
    _flag.enabled = initiallyEnabled;
  }

  final SettingsRepository _repository;
  final SentryLoggingFlag _flag;
  final Future<void> Function() _closeSentry;
  late CrashReportingState _state;
  late Future<bool> _shutdownObservation;
  int _revision = 0;
  bool _timedOut = false;

  /// The committed preference, which can differ from effective process state.
  bool get preference => _repository.crashReporting;

  /// Current observable SDK state; inactive is not native device verification.
  CrashReportingState get state => _state;

  /// Whether this result still owns feedback for the committed intent.
  bool isCurrent(CrashReportingUpdate update) =>
      update._revision == _revision && update._preference == preference;

  /// Persists first and reconciles cache even after presentation disposal.
  ///
  /// Expected persistence errors remain Results. Unexpected errors stay raw.
  Future<Result<CrashReportingUpdate>> call({required bool enable}) async {
    final result = await _repository.setCrashReporting(enable: enable);
    final revision = ++_revision;
    final committed = preference;
    _flag.enabled = committed && _state == CrashReportingState.active;
    if (!committed && _state == CrashReportingState.active) {
      _state = CrashReportingState.closing;
      _shutdownObservation = _observeShutdown();
    }
    if (result case Error<void>(:final error)) return Result.error(error);
    if (committed != enable) {
      return Result.success(
        CrashReportingUpdate._(
          CrashReportingOutcome.superseded,
          revision,
          enable,
        ),
      );
    }
    var outcome = CrashReportingOutcome.enabledForNextStart;
    if (!enable) {
      if (_state == CrashReportingState.inactive) {
        outcome = CrashReportingOutcome.disabled;
      } else {
        final closed = await _shutdownObservation;
        outcome = closed
            ? CrashReportingOutcome.disabled
            : CrashReportingOutcome.shutdownUnconfirmed;
      }
    }
    final update = CrashReportingUpdate._(outcome, revision, enable);
    return Result.success(
      isCurrent(update)
          ? update
          : CrashReportingUpdate._(
              CrashReportingOutcome.superseded,
              revision,
              enable,
            ),
    );
  }

  Future<bool> _observeShutdown() async {
    final physical = Future<void>.sync(_closeSentry).then<void>(
      (_) {
        _state = CrashReportingState.inactive;
      },
      onError: (Object error, StackTrace stack) {
        _state = CrashReportingState.unconfirmed;
        // A timed-out command cannot report an unexpected late physical error.
        if (_timedOut && error is! Exception) {
          Zone.current.handleUncaughtError(error, stack);
        }
        return Future<void>.error(error, stack);
      },
    );
    try {
      await physical.timeout(const Duration(seconds: 10));
      return true;
    } on TimeoutException {
      _timedOut = true;
      _state = CrashReportingState.unconfirmed;
      return false;
    } on Exception {
      _state = CrashReportingState.unconfirmed;
      return false;
    }
  }
}
