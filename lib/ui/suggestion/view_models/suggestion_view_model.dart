import 'dart:collection' show UnmodifiableListView;
import 'dart:io' show File;

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:logging/logging.dart';
import 'package:moliseis/data/repositories/suggestion/suggestion_repository.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';
import 'package:moliseis/domain/models/suggestion/suggestion.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/string_validator.dart';

class SuggestionViewModel extends ChangeNotifier {
  SuggestionViewModel({required SuggestionRepository suggestionRepository})
    : _suggestionRepository = suggestionRepository {
    addImages = Command0(_addImages);
    removeImageAtIndex = Command1(_removeImageAtIndex);
    uploadSuggestion = Command0(_uploadSuggestion);
  }

  final _log = Logger('SuggestionViewModel');

  final SuggestionRepository _suggestionRepository;

  String? authorEmail;
  String? authorName;
  String? city;
  String? description;
  DateTime? _endDate;
  final _imagePicker = ImagePicker();
  final _images = <String>[];
  final _mediaFileList = <XFile>[];
  final _mediaFileHashes = <int>[];
  String? place;
  DateTime? _startDate;
  AttractionType? type;
  final _types = AttractionType.values;

  DateTime? get endDate => _endDate;
  UnmodifiableListView<XFile> get mediaFileList =>
      UnmodifiableListView<XFile>(_mediaFileList);
  UnmodifiableListView<AttractionType> get types =>
      UnmodifiableListView<AttractionType>(_types);
  DateTime? get startDate => _startDate;

  late Command0<void> addImages;
  late Command1<void, int> removeImageAtIndex;
  late Command0<void> uploadSuggestion;

  Future<Result<void>> _addImages() async {
    try {
      // The hash function used to calculate the digest of images to upload.
      const hashFunc = sha1;

      final pickedImages = await _imagePicker.pickMultiImage();

      for (final image in pickedImages) {
        // Calculates the hash of each image to upload.
        final digests = hashFunc.bind(image.openRead());
        final digest = await digests.first;

        // Adds the image to the upload list only if it hasn't been added
        // before already.
        if (!_mediaFileHashes.contains(digest.hashCode)) {
          _mediaFileList.add(image);
          _mediaFileHashes.add(digest.hashCode);
        }
      }

      notifyListeners();

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(null, error, stackTrace);

      return Result.error(error);
    }
  }

  Future<Result<void>> _removeImageAtIndex(int index) async {
    try {
      _mediaFileList.removeAt(index);
      _mediaFileHashes.removeAt(index);

      notifyListeners();

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(null, error, stackTrace);

      return Result.error(error);
    }
  }

  void setEndDate(DateTime? date) {
    _endDate = date;
    notifyListeners();
  }

  void setStartDate(DateTime? date) {
    _startDate = date;

    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      _endDate = date;
    }

    notifyListeners();
  }

  Future<Result<String>> _uploadImage(XFile image) async {
    final upload = await _suggestionRepository.uploadImage(File(image.path));

    switch (upload) {
      case Error<String>():
        _log.severe(upload.error);

        return Result.error(upload.error);
      case Success<String>():
        return Result.success(upload.value);
    }
  }

  Future<Result<void>> _uploadSuggestion() async {
    for (final file in _mediaFileList) {
      final result = await _uploadImage(file);

      switch (result) {
        case Success<String>():
          _images.add(result.value);
        case Error<String>():
          _log.severe(result.error);
      }
    }

    final suggestion = Suggestion(
      city: city,
      place: place,
      description: description,
      type: type,
      startDate: _startDate,
      endDate: _endDate,
      authorEmail: authorEmail,
      authorName: authorName,
      images: _images,
    );

    final result = await _suggestionRepository.upload(suggestion);

    switch (result) {
      case Success():
        return const Result.success(null);
      case Error():
        return Result.error(result.error);
    }
  }

  String formatDate(DateTime date) => DateFormat('dd/MM/y').format(date);

  bool validateEmail(String? text) => StringValidator.isValidEmail(text);
}
