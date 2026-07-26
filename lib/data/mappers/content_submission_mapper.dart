import 'package:moliseis/data/dtos/content_submission_dto.dart';
import 'package:moliseis/domain/models/content_submission.dart';

/// Conversion extensions from [ContentSubmission] to [ContentSubmissionDto].
extension ContentSubmissionMapper on ContentSubmission {
  ContentSubmissionDto toDto({required String userId}) => ContentSubmissionDto(
    city: city,
    name: name,
    description: description,
    latitude: latitude,
    longitude: longitude,
    address: address,
    startDate: startDate,
    endDate: endDate,
    category: category,
    userEmail: userEmail,
    userName: userName,
    userId: userId,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
  );
}
