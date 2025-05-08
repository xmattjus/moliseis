import 'package:moliseis/domain/models/story/story.dart';
import 'package:moliseis/utils/result.dart';

abstract class StoryRepository {
  Future<Result<List<Story>>> get allStories;

  /// Returns a future containing the list of all [Story]s from a given
  /// [Attraction] id.
  Future<Result<List<Story>>> getStoriesFromAttractionId(int id);

  Future<Result<void>> synchronize();
}
