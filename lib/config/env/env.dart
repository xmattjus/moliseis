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

  @EnviedField(varName: 'CLOUDINARY_PROD_CLOUD_NAME', obfuscate: true)
  static final String cloudinaryProdCloudName = _Env.cloudinaryProdCloudName;

  @EnviedField(varName: 'CLOUDINARY_PROD_API_KEY', obfuscate: true)
  static final String cloudinaryProdApiKey = _Env.cloudinaryProdApiKey;

  @EnviedField(varName: 'CLOUDINARY_PROD_API_SECRET', obfuscate: true)
  static final String cloudinaryProdApiSecret = _Env.cloudinaryProdApiSecret;
}
