// The installed integration requires this package-internal binding contract.
// ignore_for_file: invalid_use_of_internal_member

import 'package:sentry_flutter/src/native/sentry_native_binding.dart';

/// Returns deterministic native enrichment without requiring a device SDK.
class NativeContextBinding implements SentryNativeBinding {
  NativeContextBinding(this.contexts);

  final Map<String, dynamic> contexts;

  @override
  bool get supportsLoadContexts => true;

  @override
  Future<Map<String, dynamic>?> loadContexts() async => contexts;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
