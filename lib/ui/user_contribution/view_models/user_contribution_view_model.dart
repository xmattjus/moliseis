import 'dart:collection' show UnmodifiableListView;
import 'dart:io' show File;

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:moliseis/data/data-sources/user_contribution.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/repositories/user_contribution_repository.dart';
import 'package:moliseis/utils/command.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/string_validator.dart';

/// Pairs a picked [XFile] with its SHA-1 [digest] string for deduplication.
typedef _MediaEntry = ({XFile file, String digest});

class UserContributionViewModel extends ChangeNotifier {
  UserContributionViewModel({
    required Logger logger,
    required UserContributionRepository userContributionRepository,
    ImagePicker? imagePicker,
  }) : _logger = logger,
       _userContributionRepository = userContributionRepository,
       _imagePicker = imagePicker ?? ImagePicker() {
    addMedia = Command0(_addMedia);
    removeMediaAt = Command1(_removeMediaAt);
    send = Command0(_send);
    retrieveLostMedia = Command0(_retrieveLostMedia);
  }

  final Logger _logger;
  final UserContributionRepository _userContributionRepository;
  final ImagePicker _imagePicker;

  String? authorEmail;
  String? authorName;
  String? city;
  String? description;
  DateTime? _endDate;
  final _mediaEntries = <_MediaEntry>[];
  String? place;
  DateTime? _startDate;
  ContentCategory? type;

  DateTime? get endDate => _endDate;
  UnmodifiableListView<XFile> get mediaFileList =>
      UnmodifiableListView<XFile>(_mediaEntries.map((e) => e.file).toList());
  DateTime? get startDate => _startDate;

  late Command0<void> addMedia;
  late Command1<void, int> removeMediaAt;
  late Command0<void> send;

  /// Recovers media files lost during a previous image-picker session due to
  /// Android activity recreation. Only runs on Android; is a no-op on all
  /// other platforms. Errors are not propagated to the UI because there is no
  /// recoverable alternative path for the user to take.
  late Command0<void> retrieveLostMedia;

  Future<void> _calculateHashAndAdd(XFile media) async {
    // SHA-1 is used purely for content-based deduplication; collision
    // resistance beyond accidental duplicates is not required here.
    final digest = await sha1.bind(media.openRead()).first;
    final digestString = digest.toString();

    if (!_mediaEntries.any((e) => e.digest == digestString)) {
      _mediaEntries.add((file: media, digest: digestString));
    }
  }

  Future<Result<void>> _addMedia() async {
    try {
      final pickedMedia = await _imagePicker.pickMultipleMedia();

      for (final media in pickedMedia) {
        await _calculateHashAndAdd(media);
      }

      notifyListeners();

      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const UserContributionMediaAddFailed(),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
    }
  }

  Future<Result<void>> _removeMediaAt(int index) async {
    try {
      _mediaEntries.removeAt(index);

      notifyListeners();

      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const UserContributionMediaRemovalFailed(),
        error: exception,
        stackTrace: stackTrace,
      );

      return Result.error(exception);
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

    for (final entry in _mediaEntries) {
      final result = await _userContributionRepository.uploadImage(
        File(entry.file.path),
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
      media: mediaUrls,
    );

    final result = await _userContributionRepository.upload(userContribution);

    switch (result) {
      case Success():
        return const Result.success(null);
      case Error():
        return Result.error(result.error);
    }
  }

  void _handleRetrieveLostMediaErrors(Object error, StackTrace? stackTrace) {
    _logger.log(
      const UserContributionMediaRetrievalFailed(),
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Implements the lost-data recovery pattern recommended by image_picker.
  /// See: https://github.com/flutter/packages/blob/e37fa8ff337214ed3d5dc83f9ba229c6b9ccc1c0/packages/image_picker/image_picker/example/lib/main.dart#L308
  Future<Result<void>> _retrieveLostMedia() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return const Result.success(null);
    }

    final response = await _imagePicker.retrieveLostData();

    if (response.isEmpty) {
      return const Result.success(null);
    }

    if (response.file != null) {
      _logger.log(const UserContributionMediaRetrievalStarted());

      try {
        // When files is non-null it contains all recovered files; file points
        // to the first item. Fall back to file for single-result responses.
        final files = response.files ?? [response.file!];
        for (final file in files) {
          await _calculateHashAndAdd(file);
        }

        notifyListeners();
      } on Object catch (error, stackTrace) {
        _handleRetrieveLostMediaErrors(error, stackTrace);
      }
    } else if (response.exception != null) {
      final exception = response.exception!;
      _handleRetrieveLostMediaErrors(
        exception,
        StackTrace.fromString(exception.stacktrace ?? ''),
      );
    }

    // Lost media recovery is best-effort; surfacing errors to the UI would
    // block the flow with no actionable recovery step for the user.
    return const Result.success(null);
  }

  String formatDate(Locale locale, DateTime date) =>
      intl.DateFormat.yMd(locale.languageCode).format(date);

  String formatTime(Locale locale, DateTime date) =>
      intl.DateFormat.jm(locale.languageCode).format(date);

  bool validateEmail(String? text) => StringValidator.isValidEmail(text);
}
