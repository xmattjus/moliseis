import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Owns the opt-in local Deno HTTP fixture and its private process channel.
final class ExternalEventTokenBridge {
  ExternalEventTokenBridge._(this._process, this._responses);

  final Process _process;
  final StreamIterator<String> _responses;
  bool _closed = false;
  bool _failed = false;

  /// Starts the fixture without exposing keys or temporary credentials.
  static Future<ExternalEventTokenBridge> start() async {
    final process = await Process.start('bash', [
      'supabase/tests/run_external_event_token_e2e_fixture.sh',
    ]);
    // Drain diagnostic output without logging potentially sensitive SDK errors.
    unawaited(process.stderr.drain<void>());
    return ExternalEventTokenBridge._(
      process,
      StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      ),
    );
  }

  /// Runs one fixture command; HTTP repository traffic remains independent.
  Future<Map<String, dynamic>> command(Map<String, dynamic> input) async {
    _process.stdin.writeln(jsonEncode(input));
    if (!await _responses.moveNext().timeout(const Duration(seconds: 30))) {
      throw StateError('Local token bridge stopped unexpectedly.');
    }
    final response = (jsonDecode(_responses.current) as Map)
        .cast<String, dynamic>();
    if (response.containsKey('error')) {
      _failed = true;
      throw StateError(
        'Local token fixture failed at ${response["stage"]}: '
        '${response["code"] ?? "unknown"}.',
      );
    }
    return response;
  }

  /// Requests SQL/Auth cleanup before stopping the process, with a timeout.
  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    try {
      if (!_failed) {
        await command({'operation': 'shutdown'});
      }
      await _process.stdin.close();
      final exit = await _process.exitCode.timeout(const Duration(seconds: 15));
      if (exit != 0 && !_failed) {
        throw StateError('Local token fixture cleanup failed.');
      }
    } finally {
      _process.kill();
      await _responses.cancel();
    }
  }
}
