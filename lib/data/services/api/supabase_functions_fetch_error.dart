import 'package:supabase_flutter/supabase_flutter.dart';

/// Recovers a fetch failure for the application's exception-based Result API.
///
/// Keeps the Supabase wrapper when its details cannot be returned as an
/// [Exception], preserving the original diagnostic information.
Exception recoverSupabaseFunctionsFetchError(FunctionsFetchException error) {
  final details = error.details;
  return details is Exception ? details : error;
}
