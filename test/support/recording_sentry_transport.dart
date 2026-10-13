import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Records capture attempts and waits for their actual transport delivery.
class RecordingSentryTransport implements Transport, EventProcessor {
  /// Events observed by the scope processor, before asynchronous enrichment.
  final List<SentryEvent> events = [];

  /// Envelopes delivered after all Sentry processors have completed.
  final List<SentryEnvelope> envelopes = [];

  Completer<void> _delivery = Completer<void>();

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
    // applying scope processors. Its continuation is queued before this one.
    // Observe attempts here, before Linux enrichment starts /proc/meminfo IO,
    // so a forbidden capture cannot pass an empty-envelope assertion.
    await Future<void>.value();
    while (envelopes.length < events.length) {
      await _delivery.future.timeout(const Duration(seconds: 5));
    }
  }
}
