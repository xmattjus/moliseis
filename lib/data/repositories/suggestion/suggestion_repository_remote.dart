import 'dart:io' show File;

import 'package:logging/logging.dart';
import 'package:moliseis/data/repositories/suggestion/suggestion_repository.dart';
import 'package:moliseis/data/services/remote/cloudinary.dart';
import 'package:moliseis/domain/models/suggestion/suggestion.dart';
import 'package:moliseis/domain/models/suggestion/suggestion_supabase_table.dart';
import 'package:moliseis/utils/exceptions.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuggestionRepositoryRemote extends SuggestionRepository {
  SuggestionRepositoryRemote({
    required Supabase supabase,
    required SuggestionSupabaseTable supabaseTable,
    required CloudinaryClient cloudinaryClient,
  }) : _supabase = supabase,
       _supabaseTable = supabaseTable,
       _cloudinaryClient = cloudinaryClient;

  final _log = Logger('SuggestionRepositoryRemote');

  final Supabase _supabase;
  final SuggestionSupabaseTable _supabaseTable;
  final CloudinaryClient _cloudinaryClient;

  @override
  Future<Result> upload(Suggestion suggestion) async {
    try {
      await _supabase.client.from(_supabaseTable.tableName).insert({
        _supabaseTable.idCity: suggestion.city,
        _supabaseTable.idPlace: suggestion.place,
        _supabaseTable.idDescription: suggestion.description,
        _supabaseTable.idType: suggestion.type?.name,
        _supabaseTable.idStartDate: suggestion.startDate?.toIso8601String(),
        _supabaseTable.idEndDate: suggestion.endDate?.toIso8601String(),
        _supabaseTable.idAuthorEmail: suggestion.authorEmail,
        _supabaseTable.idAuthorName: suggestion.authorName,
        _supabaseTable.idImages: suggestion.images,
      });

      return const Result.success(null);
    } on Exception catch (error, stackTrace) {
      _log.severe(const SupabaseResponseException(), error, stackTrace);
      return Result.error(error);
    }
  }

  @override
  Future<Result<String>> uploadImage(File image) =>
      _cloudinaryClient.uploadImage(image);
}
