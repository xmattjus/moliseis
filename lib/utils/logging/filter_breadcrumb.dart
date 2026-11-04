import 'package:sentry_flutter/sentry_flutter.dart';

/// Drops framed Talker console fragments, including multiline errors/stacks.
Breadcrumb? filterBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  // Both locked SDK print integrations identify their output as console.
  if (breadcrumb?.category != 'console') return breadcrumb;
  final message = breadcrumb?.message;
  if (message != null &&
      (message.contains('┌') ||
          message.contains('│') ||
          message.contains('└') ||
          message.contains('─\u001b['))) {
    return null;
  }
  return breadcrumb;
}
