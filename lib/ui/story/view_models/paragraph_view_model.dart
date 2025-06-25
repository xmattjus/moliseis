import 'dart:collection' show UnmodifiableListView;

import 'package:flutter/material.dart';
import 'package:moliseis/data/repositories/story/paragraph_repository.dart';
import 'package:moliseis/domain/models/paragraph/paragraph.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';

class ParagraphViewModel extends ChangeNotifier {
  ParagraphViewModel({required ParagraphRepository paragraphRepository})
    : _paragraphRepository = paragraphRepository {
    load = Command1(_load);
  }

  final ParagraphRepository _paragraphRepository;
  List<Paragraph> _paragraphs = [];

  UnmodifiableListView<Paragraph> get paragraphs =>
      UnmodifiableListView(_paragraphs);

  late final Command1<void, int> load;

  Future<Result<void>> _load(int id) async {
    final result = await _paragraphRepository.getParagraphsFromStoryId(id);

    switch (result) {
      case Success<List<Paragraph>>():
        _paragraphs = result.value;
      case Error<List<Paragraph>>():
        return Result.error(result.error);
    }

    notifyListeners();

    return result;
  }
}
