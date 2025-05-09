import 'package:moliseis/domain/models/paragraph/paragraph.dart';
import 'package:moliseis/utils/result.dart';

abstract class ParagraphRepository {
  Future<Result<List<Paragraph>>> getParagraphsFromStoryId(int id);
}
