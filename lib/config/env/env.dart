import 'package:envied/envied.dart';

part 'env.g.dart';

/// A class containing the app environment variables.
@Envied(path: '.env')
final class Env {
  /// The Cloudinary production instance key.
  @EnviedField(varName: 'CLOUDINARY_PROD_API_KEY', obfuscate: true)
  static final String cloudinaryProdApiKey = _Env.cloudinaryProdApiKey;

  /// The Cloudinary production instance secret.
  @EnviedField(varName: 'CLOUDINARY_PROD_API_SECRET', obfuscate: true)
  static final String cloudinaryProdApiSecret = _Env.cloudinaryProdApiSecret;

  /// The Cloudinary production instance URL.
  @EnviedField(varName: 'CLOUDINARY_PROD_CLOUD_NAME', obfuscate: true)
  static final String cloudinaryProdCloudName = _Env.cloudinaryProdCloudName;

  /// The Sentry instance URL.
  @EnviedField(varName: 'SENTRY_URL', obfuscate: true)
  static final String sentryUrl = _Env.sentryUrl;

  /// The Supabase production instance key.
  @EnviedField(varName: 'SUPABASE_PROD_KEY', obfuscate: true)
  static final String supabaseProdApiKey = _Env.supabaseProdApiKey;

  /// The Supabase production instance URL.
  @EnviedField(varName: 'SUPABASE_PROD_URL', obfuscate: true)
  static final String supabaseProdUrl = _Env.supabaseProdUrl;
}
