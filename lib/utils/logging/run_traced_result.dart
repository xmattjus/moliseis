import 'package:moliseis/utils/result.dart';
import 'package:sentry/sentry.dart';

/// Traces one Result action without changing its outcome or reporting errors.
Future<Result<T>> runTracedResult<T>(
  String name,
  Future<Result<T>> Function() action,
) => Sentry.startSpan(name, (span) async {
  final result = await action();
  if (result.isError) span.status = SentrySpanStatusV2.error;
  return result;
});
