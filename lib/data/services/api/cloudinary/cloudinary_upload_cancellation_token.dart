import 'dart:async' show unawaited;
import 'dart:io' show HttpClientRequest;

import 'package:moliseis/utils/logging/logging.dart';

/// Coordinates cancellation of an in-flight Cloudinary upload.
class CloudinaryUploadCancellationToken {
  /// Creates a token.
  ///
  /// [logger] is used to surface genuine errors emitted by `request.done`
  /// (i.e. failures that are NOT caused by an `abort` from this token).
  /// Errors that follow a [cancel] are silently ignored: they are expected
  /// and are already handled by the upload pipeline's `request.close()`
  /// await path.
  CloudinaryUploadCancellationToken({required Logger logger})
    : _logger = logger;

  final Logger _logger;

  HttpClientRequest? _request;
  bool _cancelled = false;

  /// Whether the currently attached request was aborted via
  /// [abortCurrentRequest] (i.e. a per-attempt timeout). Reset to `false`
  /// whenever a fresh request is attached so a later attempt's genuine
  /// `request.done` errors are still logged.
  bool _abortedForRetry = false;

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled;

  /// Attaches the token to the active request.
  ///
  /// If [cancel] was already called, the request is aborted immediately.
  void attach(HttpClientRequest request) {
    _request = request;
    _abortedForRetry = false;
    // `request.done` is the same future returned by `request.close()`. The
    // upload pipeline awaits `request.close()` and routes its errors through
    // the surrounding try/catch, but `request.done` still needs a passive
    // listener so that an abort-induced error never becomes an unhandled
    // asynchronous error. Genuine (non-abort) errors are logged here instead
    // of being silently swallowed.
    unawaited(
      request.done.then(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          if (!_cancelled && !_abortedForRetry) {
            _logger.log(
              const CloudinaryRequestFailed(detail: 'request_done_error'),
              error: error,
              stackTrace: stackTrace,
            );
          }
        },
      ),
    );
    if (_cancelled) {
      request.abort();
    }
  }

  /// Cancels the upload. Safe to call multiple times.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _request?.abort();
  }

  /// Aborts the currently attached request without marking the token as
  /// cancelled.
  ///
  /// Used by the upload pipeline to abort a single attempt after a timeout
  /// so the retry loop can attach a fresh request. Unlike [cancel], this does
  /// not flip [isCancelled], so subsequent attempts (and any caller-driven
  /// [cancel]) continue to work, and the passive `request.done` listener is
  /// silenced for the aborted request so the timeout-induced socket closure
  /// is not logged as a genuine error.
  void abortCurrentRequest() {
    _abortedForRetry = true;
    _request?.abort();
  }
}
