import 'package:moliseis/data/repositories/core/supabase_table_base.dart';

class ImageSupabaseTable implements SupabaseTableBase {
  @override
  String get tableName => 'images';

  String get idTitle => 'title';
  String get idAuthor => 'author';
  String get idLicense => 'license';
  String get idLicenseUrl => 'license_url';
  String get idUrl => 'url';
  String get idWidth => 'width';
  String get idHeight => 'height';
  String get idCreatedAt => 'created_at';
  String get idModifiedAt => 'modified_at';
  String get idAttraction => 'attraction_id';
}
