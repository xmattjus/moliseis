import 'dart:io' show File;

import 'package:moliseis/data/data-sources/user_contribution.dart';
import 'package:moliseis/data/data-sources/user_contribution_supabase_table.dart';
import 'package:moliseis/data/services/api/cloudinary_client.dart';
import 'package:moliseis/domain/repositories/user_contribution_repository.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserContributionRepositoryImpl extends UserContributionRepository {
  UserContributionRepositoryImpl({
    required Logger logger,
    required Supabase supabase,
    required UserContributionSupabaseTable supabaseTable,
    required CloudinaryClient cloudinaryClient,
  }) : _logger = logger,
       _supabase = supabase,
       _supabaseTable = supabaseTable,
       _cloudinaryClient = cloudinaryClient;

  final Logger _logger;

  final Supabase _supabase;
  final UserContributionSupabaseTable _supabaseTable;
  final CloudinaryClient _cloudinaryClient;

  @override
  Future<Result<void>> upload(UserContribution userContribution) async {
    _logger.log(const UserContributionUploadStarted());

    try {
      await _supabase.client.from(_supabaseTable.tableName).insert({
        _supabaseTable.idCity: userContribution.city,
        _supabaseTable.idPlace: userContribution.place,
        _supabaseTable.idDescription: userContribution.description,
        _supabaseTable.idType: userContribution.type?.name,
        _supabaseTable.idStartDate: userContribution.startDate
            ?.toIso8601String(),
        _supabaseTable.idEndDate: userContribution.endDate?.toIso8601String(),
        _supabaseTable.idAuthorEmail: userContribution.authorEmail,
        _supabaseTable.idAuthorName: userContribution.authorName,
        _supabaseTable.idImages: userContribution.media,
      });

      return const Result.success(null);
    } on Exception catch (exception, stackTrace) {
      _logger.log(
        const UserContributionUploadFailed(),
        error: exception,
        stackTrace: stackTrace,
      );
      return Result.error(exception);
    }
  }

  @override
  Future<Result<String>> uploadImage(File image) =>
      _cloudinaryClient.uploadImage(image);
}
