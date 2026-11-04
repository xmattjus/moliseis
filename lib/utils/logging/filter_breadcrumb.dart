import 'package:sentry_flutter/sentry_flutter.dart';

/// Drops framed Talker console fragments, including multiline errors/stacks.
Breadcrumb? filterBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
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
