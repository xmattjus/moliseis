import 'package:moliseis/domain/core/sync_cursor_source.dart';
import 'package:moliseis/utils/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the stateless canonical sync cursor through the client role's RPC.
final class SupabaseSyncCursorSource implements SyncCursorSource {
  SupabaseSyncCursorSource(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<DateTime>> getCurrentCursor() async {
    try {
      final response = await _client.rpc<Object?>('get_content_sync_cursor');
      if (response is! String) {
        return const Result.error(
          FormatException('Content sync cursor must be a timestamp.'),
        );
      }
      return Result.success(DateTime.parse(response).toUtc());
    } on Exception catch (exception) {
      return Result.error(exception);
    }
  }
}
