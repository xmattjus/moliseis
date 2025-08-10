import 'package:moliseis/data/repositories/core/supabase_table_base.dart';

class MediaSupabaseTable implements SupabaseTableBase {
  @override
  String get tableName => 'media';
}
