import 'dart:io' show File;

import 'package:logging/logging.dart';
import 'package:moliseis/data/services/api/cloudinary_client.dart';
import 'package:moliseis/data/sources/user_contribution.dart';
import 'package:moliseis/data/sources/user_contribution_supabase_table.dart';
import 'package:moliseis/domain/repositories/user_contribution_repository.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserContributionRepositoryImpl extends UserContributionRepository {
  UserContributionRepositoryImpl({
    required Supabase supabase,
    required UserContributionSupabaseTable supabaseTable,
    required CloudinaryClient cloudinaryClient,
  }) : _supabase = supabase,
       _supabaseTable = supabaseTable,
       _cloudinaryClient = cloudinaryClient;

  final _log = Logger('UserContributionRepositoryImpl');

  final Supabase _supabase;
  final UserContributionSupabaseTable _supabaseTable;
  final CloudinaryClient _cloudinaryClient;

  @override
  Future<Result> upload(UserContribution userContribution) async {
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
        _supabaseTable.idImages: userContribution.images,
      });

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(
        'An exception occurred while uploading user contribution.',
        error,
        stackTrace,
      );
      return Result.error(error);
    }
  }

  @override
  Future<Result<String>> uploadImage(File image) =>
      _cloudinaryClient.uploadImage(image);
}
