import 'dart:io' show File;

import 'package:moliseis/data/sources/suggestion.dart';
import 'package:moliseis/utils/result.dart';

abstract class SuggestionRepository {
  Future<Result> upload(Suggestion suggestion);

  Future<Result<String>> uploadImage(File image);
}
