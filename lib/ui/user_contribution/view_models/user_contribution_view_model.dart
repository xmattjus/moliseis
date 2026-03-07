import 'dart:collection' show UnmodifiableListView;
import 'dart:io' show File;

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:logging/logging.dart';
import 'package:moliseis/data/sources/user_contribution.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/repositories/user_contribution_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/string_validator.dart';

class UserContributionViewModel extends ChangeNotifier {
  UserContributionViewModel({
    required UserContributionRepository userContributionRepository,
  }) : _userContributionRepository = userContributionRepository {
    addImages = Command0(_addImages);
    removeImageAtIndex = Command1(_removeImageAtIndex);
    send = Command0(_send);
  }

  final _log = Logger('UserContributionViewModel');

  final UserContributionRepository _userContributionRepository;

  String? authorEmail;
  String? authorName;
  String? city;
  String? description;
  DateTime? _endDate;
  final _imagePicker = ImagePicker();
  final _mediaFileList = <XFile>[];
  final _mediaFileHashes = <int>[];
  String? place;
  DateTime? _startDate;
  ContentCategory? type;

  DateTime? get endDate => _endDate;
  UnmodifiableListView<XFile> get mediaFileList =>
      UnmodifiableListView<XFile>(_mediaFileList);
  DateTime? get startDate => _startDate;

  // TODO(xmattjus): rename this method to addMedia.
  late Command0<void> addImages;
  // TODO(xmattjus): rename this method to removeMediaAt.
  late Command1<void, int> removeImageAtIndex;
  late Command0<void> send;

  // TODO(xmattjus): rename this method to _addMedia.
  Future<Result<void>> _addImages() async {
    try {
      // The hash function used to calculate the digest of media to upload.
      const hashFunc = sha1;

      final pickedMedia = await _imagePicker.pickMultipleMedia();

      for (final media in pickedMedia) {
        // Calculates the hash of each media to upload.
        final digests = hashFunc.bind(media.openRead());
        final digest = await digests.first;

        // Adds the media to the upload list only if it hasn't been added
        // before already.
        if (!_mediaFileHashes.contains(digest.hashCode)) {
          _mediaFileList.add(media);
          _mediaFileHashes.add(digest.hashCode);
        }
      }

      notifyListeners();

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while adding media to the upload list.',
        error,
        stackTrace,
      );

      return Result.error(error);
    }
  }

  // TODO(xmattjus): rename this method to _removeMediaAt.
  Future<Result<void>> _removeImageAtIndex(int index) async {
    try {
      _mediaFileList.removeAt(index);
      _mediaFileHashes.removeAt(index);

      notifyListeners();

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while removing media at index $index from the upload list.',
        error,
        stackTrace,
      );

      return Result.error(error);
    }
  }

  void setEndDate(DateTime? date) {
    _endDate = date;
    notifyListeners();
  }

  void setStartDate(DateTime? date) {
    _startDate = date?.copyWith(
      hour: _startDate?.hour,
      minute: _startDate?.minute,
    );

    if (_startDate != null &&
        _endDate != null &&
        _endDate!.isBefore(_startDate!)) {
      _endDate = date?.copyWith(hour: 23, minute: 55, second: 55);
    }

    notifyListeners();
  }

  void setStartTime(DateTime? date) {
    _startDate = _startDate?.copyWith(hour: date?.hour, minute: date?.minute);

    notifyListeners();
  }

  Future<Result<void>> _send() async {
    final mediaUrls = <String>[];

    for (final file in _mediaFileList) {
      final result = await _userContributionRepository.uploadImage(
        File(file.path),
      );

      switch (result) {
        case Success<String>():
          mediaUrls.add(result.value);
        case Error<String>():
          return Result.error(result.error);
      }
    }

    final userContribution = UserContribution(
      city: city,
      place: place,
      description: description,
      type: type,
      startDate: _startDate,
      endDate: _endDate,
      authorEmail: authorEmail,
      authorName: authorName,
      images: mediaUrls,
    );

    final result = await _userContributionRepository.upload(userContribution);

    switch (result) {
      case Success():
        return const Result.success(null);
      case Error():
        return Result.error(result.error);
    }
  }

  String formatDate(Locale locale, DateTime date) =>
      DateFormat.yMd(locale.languageCode).format(date);

  String formatTime(Locale locale, DateTime date) =>
      DateFormat.Hm(locale.languageCode).format(date);

  bool validateEmail(String? text) => StringValidator.isValidEmail(text);
}
