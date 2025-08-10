import 'package:moliseis/data/repositories/core/supabase_table_base.dart';

class CitySupabaseTable implements SupabaseTableBase {
  @override
  String get tableName => 'cities';

  String get idName => 'name';
  String get idCreatedAt => 'created_at';
  String get idModifiedAt => 'modified_at';
}
