import 'package:moliseis/utils/logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ensures that Supabase has an anonymous session without making startup fatal.
///
/// A session restored during Supabase initialization is reused as-is. When no
/// session exists, anonymous sign-in is attempted once; expected Supabase Auth
/// failures are logged and startup continues without an authenticated user.
Future<void> ensureAnonymousSupabaseSession({
  required GoTrueClient authClient,
  required Logger logger,
}) async {
  if (authClient.currentUser != null) return;

  try {
    await authClient.signInAnonymously();
  } on AuthException catch (error, stackTrace) {
    logger.log(
      const SupabaseAuthAnonymousLoginFailed(),
      error: error,
      stackTrace: stackTrace,
    );
  }
}
