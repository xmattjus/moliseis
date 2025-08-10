import 'package:moliseis/data/repositories/core/supabase_table_base.dart';

class EventSupabaseTable implements SupabaseTableBase {
  @override
  String get tableName => 'events';

  String get idTitle => 'title';
  String get idDescription => 'description';
  String get startDate => 'start_date';
  String get endDate => 'end_date';
  String get idCreatedAt => 'created_at';
  String get idModifiedAt => 'modified_at';
  String get idPlace => 'place_id';
}
