import 'dart:async';

import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:file/memory.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/utils/logging/logging.dart';
import 'package:provider/provider.dart';

import 'fake_cache_manager.dart';
import 'typography_harness.dart';

/// Gives each actual provider acquisition an independently controlled response.
class ControlledImageCacheManager extends FakeCacheManager {
  final requests =
      <({String url, String? key, StreamController<FileResponse> stream})>[];
  final _files = MemoryFileSystem();

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    final stream = StreamController<FileResponse>();
    requests.add((url: url, key: key, stream: stream));
    return stream.stream;
  }

  /// Supplies actual bytes to the production network provider and codec.
  void complete(int index, List<int> bytes) {
    final request = requests[index];
    final file = _files.file('/response-$index.png')..writeAsBytesSync(bytes);
    request.stream.add(
      FileInfo(file, FileSource.Cache, DateTime.utc(2030), request.url),
    );
    unawaited(request.stream.close());
  }

  /// Fails acquisition with the original cause and an inspectable stack.
  void fail(int index, Object error) {
    requests[index].stream.addError(error, StackTrace.current);
    unawaited(requests[index].stream.close());
  }

  @override
  Future<void> dispose() async {
    for (final request in requests) {
      if (!request.stream.isClosed) unawaited(request.stream.close());
    }
  }
}

/// Supplies the same cache/logger boundaries and typography as image consumers.
Widget networkImageHarness({
  required CacheManager manager,
  required Widget child,
  Logger? logger,
}) => MultiProvider(
  providers: [
    Provider<CacheManager>.value(value: manager),
    Provider<Logger?>.value(value: logger),
  ],
  child: typographyHarness(
    child: Scaffold(body: Center(child: child)),
  ),
);
