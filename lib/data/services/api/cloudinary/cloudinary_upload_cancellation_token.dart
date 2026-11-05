import 'dart:async' show AsyncError, Completer, unawaited;
import 'dart:io' show HttpClientRequest;

import 'package:moliseis/utils/logging/logging.dart';

/// Coordinates cancellation of an in-flight Cloudinary upload.
class CloudinaryUploadCancellationToken {
  /// The token consumes early/late request faults; the client owns reporting.
  CloudinaryUploadCancellationToken({required Logger logger})
    : _logger = logger;

  final Logger _logger;
  AsyncError? _requestFailure;
  bool _finished = false;
  bool _reported = false;

  /// Publishes at most one terminal error, retaining a passive request cause.
  void reportFailure(
    CloudinaryRequestFailed event,
    Object error,
    StackTrace? stackTrace,
  ) {
    if (_cancelled || _reported) return;
    _reported = true;
    _logger.log(
      event,
      error: _requestFailure?.error ?? error,
      stackTrace: _requestFailure?.stackTrace ?? stackTrace,
    );
  }

  /// Retains a recoverable cause locally without a terminal alert.
  void reportRetry(CloudinaryUploadRetry event, Exception error) {
    _logger.log(
      event,
      error: _requestFailure?.error ?? error,
      stackTrace: _requestFailure?.stackTrace,
    );
    _requestFailure = null;
    _attachment?.superseded = true;
  }

  /// Settles reporting even when the main path never awaited request.close().
  void finish() {
    _finished = true;
    _reportPendingFailure();
  }

  void _reportPendingFailure() {
    final failure = _requestFailure;
    if (_finished && failure != null) {
      reportFailure(
        const CloudinaryRequestFailed(
          stage: CloudinaryFailureStage.upload,
          category: CloudinaryFailureCategory.transport,
        ),
        failure.error,
        failure.stackTrace,
      );
    }
  }

  _RequestAttachment? _attachment;
  final _cancelledCompleter = Completer<void>();
  bool _cancelled = false;

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled;

  /// Completes once [cancel] is called, including when no request is active.
  Future<void> get whenCancelled => _cancelledCompleter.future;

  /// Attaches the token to the active request.
  ///
  /// If [cancel] was already called, the request is aborted immediately.
  void attach(HttpClientRequest request) {
    final attachment = _RequestAttachment(request);
    _attachment = attachment;
    // Consume the future immediately; it may fail before close() is awaited.
    // Client settlement gives both observers one reporting owner.
    unawaited(
      request.done.then(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          if (!_cancelled && !attachment.superseded) {
            _requestFailure ??= AsyncError(error, stackTrace);
            _reportPendingFailure();
          }
        },
      ),
    );
    if (_cancelled) {
      attachment.request.abort();
    }
  }

  /// Cancels the upload. Safe to call multiple times.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancelledCompleter.complete();
    _attachment?.request.abort();
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
    final attachment = _attachment;
    if (attachment == null) return;
    attachment
      ..superseded = true
      ..request.abort();
  }
}

final class _RequestAttachment {
  _RequestAttachment(this.request);

  final HttpClientRequest request;
  bool superseded = false;
}
