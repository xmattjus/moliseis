import 'package:envied/envied.dart';

part 'env.g.dart';

// ignore: avoid_classes_with_only_static_members
@Envied(path: '.env')
final class Env {
  @EnviedField(varName: 'SUPABASE_PROD_URL', obfuscate: true)
  static final String supabaseProdUrl = _Env.supabaseProdUrl;

  @EnviedField(varName: 'SUPABASE_PROD_KEY', obfuscate: true)
  static final String supabaseProdApiKey = _Env.supabaseProdApiKey;

  @EnviedField(varName: 'SENTRY_URL', obfuscate: true)
  static final String sentryUrl = _Env.sentryUrl;
}
