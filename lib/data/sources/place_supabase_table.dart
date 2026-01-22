import 'package:moliseis/data/repositories/supabase_table_base.dart';

class PlaceSupabaseTable implements SupabaseTableBase {
  @override
  String get tableName => 'places_v2';

  String get idName => 'name';
  String get idDescription => 'description';
  String get idCoordinates => 'coordinates';
  String get idType => 'type';
  String get idCity => 'city_id';
  String get idCreatedAt => 'created_at';
  String get idModifiedAt => 'modified_at';
}
