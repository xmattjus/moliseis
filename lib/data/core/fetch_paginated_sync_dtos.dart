import 'package:moliseis/domain/core/sync_dto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Retrieves complete sync rows using ascending identity pagination.
///
/// A null [modifiedAtOrAfter] bootstraps all content. Otherwise the lower
/// marker bound is inclusive. Only an empty page ends retrieval, since the
/// server may cap responses below the requested page size. Any request or
/// decoding failure rejects the entire result before local writes begin.
Future<List<T>> fetchPaginatedSyncDtos<T extends SyncDto>(
  SupabaseClient client,
  String tableName,
  T Function(Map<String, dynamic>) mapper, {
  DateTime? modifiedAtOrAfter,
}) async {
  final dtos = <T>[];
  int? lastId;

  while (true) {
    var query = client.from(tableName).select();
    if (modifiedAtOrAfter != null) {
      query = query.gte(
        'modified_at',
        modifiedAtOrAfter.toUtc().toIso8601String(),
      );
    }
    if (lastId != null) query = query.gt('id', lastId);

    final rows = await query.order('id', ascending: true).limit(500);
    if (rows.isEmpty) return dtos;

    final page = rows.map(mapper).toList();
    dtos.addAll(page);
    lastId = page.last.id;
  }
}
