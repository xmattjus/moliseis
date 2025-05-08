import 'package:moliseis/data/repositories/core/supabase_table_base.dart';

class PlaceSupabaseTable implements SupabaseTableBase {
  @override
  String get tableName => 'places';

  String get idName => 'name';
  String get idDescription => 'description';
  String get idCreatedAt => 'created_at';
  String get idModifiedAt => 'modified_at';
}
