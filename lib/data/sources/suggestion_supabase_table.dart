import 'package:moliseis/data/repositories/supabase_table_base.dart';

class SuggestionSupabaseTable implements SupabaseTableBase {
  @override
  String get tableName => 'suggestions';

  String get idCity => 'city';
  String get idPlace => 'place';
  String get idDescription => 'description';
  String get idType => 'type';
  String get idStartDate => 'start_date';
  String get idEndDate => 'end_date';
  String get idAuthorEmail => 'author_email';
  String get idAuthorName => 'author_name';
  String get idImages => 'images';
}
