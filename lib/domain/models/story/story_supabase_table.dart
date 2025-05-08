import 'package:moliseis/data/repositories/core/supabase_table_base.dart';

class StorySupabaseTable implements SupabaseTableBase {
  @override
  String get tableName => 'stories';

  String get idTitle => 'title';
  String get idAuthor => 'author';
  String get idShortDescription => 'short_description';
  String get idSources => 'sources';
  String get idAttraction => 'attraction_id';
  String get idCreatedAt => 'created_at';
  String get idModifiedAt => 'modified_at';
}
