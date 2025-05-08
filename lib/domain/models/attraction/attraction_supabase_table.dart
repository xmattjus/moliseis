import 'package:moliseis/data/repositories/core/supabase_table_base.dart';

class AttractionSupabaseTable implements SupabaseTableBase {
  @override
  String get tableName => 'attractions';

  String get idName => 'name';
  String get idSummary => 'summary';
  String get idDescription => 'description';
  String get idHistory => 'history';
  String get idCoordinates => 'coordinates';
  String get type => 'type';
  String get idCreatedAt => 'created_at';
  String get idModifiedAt => 'modified_at';
  String get idPlace => 'place_id';
}
