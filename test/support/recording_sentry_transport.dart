import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Records capture attempts and waits for their actual transport delivery.
class RecordingSentryTransport implements Transport, EventProcessor {
  /// Events observed by the scope processor, before asynchronous enrichment.
  final List<SentryEvent> events = [];

  /// Envelopes delivered after all Sentry processors have completed.
  final List<SentryEnvelope> envelopes = [];

  /// Real recording spans observed by the streaming SDK pipeline.
  final List<SentrySpanV2> spans = [];

  Completer<void> _spanDelivery = Completer<void>();
  Completer<void> _delivery = Completer<void>();

  /// Attach to SentryOptions.beforeSendSpan to observe ended recording spans.
  void recordSpan(SentrySpanV2 span, Hint hint) {
    spans.add(span);
    _spanDelivery.complete();
    _spanDelivery = Completer<void>();
  }

  /// Waits for the expected number of real streaming pipeline callbacks.
  Future<void> settleSpans(int count) async {
    while (spans.length < count) {
      await _spanDelivery.future.timeout(const Duration(seconds: 5));
    }
  }

  @override
  SentryEvent apply(SentryEvent event, Hint hint) {
    events.add(event);
    return event;
  }

  @override
  Future<SentryId> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    _delivery.complete();
    _delivery = Completer<void>();
    return envelope.header.eventId ?? SentryId.newId();
  }

  /// Waits for captures started by the preceding synchronous logger call.
  Future<void> settleCaptures() async {
    // In sentry 10.0.0-rc.2, Hub.captureException awaits scope cloning before
    // applying processors; async sanitized scopes also require microtasks.
    // Observe attempts here, before Linux enrichment starts /proc/meminfo IO,
    // so a forbidden capture cannot pass an empty-envelope assertion.
    await Future<void>(() {});
    while (events.any(
      (event) => !envelopes.any(
        (envelope) => envelope.header.eventId == event.eventId,
      ),
    )) {
      await _delivery.future.timeout(const Duration(seconds: 5));
    }
  }
}
