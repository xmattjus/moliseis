import 'package:moliseis/data/mappers/submission_asset_mapper.dart';
import 'package:moliseis/domain/models/content_submission.dart';
import 'package:moliseis/domain/models/submission_asset.dart';

/// Maps the allowlisted public Content Submission request body.
Map<String, dynamic> contentSubmissionToWireMap({
  required String clientSubmissionId,
  required ContentSubmission contentSubmission,
  required List<SubmissionAsset> submissionAssets,
}) => <String, dynamic>{
  'client_submission_id': clientSubmissionId,
  'category': contentSubmission.category?.name,
  'city': contentSubmission.city,
  'name': contentSubmission.name,
  'description': contentSubmission.description,
  'description_delta': contentSubmission.descriptionDelta,
  'latitude': contentSubmission.latitude,
  'longitude': contentSubmission.longitude,
  'address': contentSubmission.address,
  'start_date': contentSubmission.startDate?.toUtc().toIso8601String(),
  'end_date': contentSubmission.endDate?.toUtc().toIso8601String(),
  'user_email': contentSubmission.userEmail,
  'user_name': contentSubmission.userName,
  'assets': submissionAssets.map((asset) => asset.toDto().toMap()).toList(),
};
