import 'package:moliseis/data/repositories/core/supabase_table_base.dart';

class ParagraphSupabaseTable extends SupabaseTableBase {
  @override
  String get tableName => 'paragraphs';

  String get idHeading => 'heading';
  String get idSubheading => 'subheading';
  String get idBody => 'body';
  String get idStory => 'story_id';
  String get idCreatedAt => 'created_at';
  String get idModifiedAt => 'modified_at';
}
