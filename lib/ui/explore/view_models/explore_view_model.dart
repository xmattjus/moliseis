import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_category.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/utils/extensions/extensions.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

class ExploreViewModel extends ChangeNotifier {
  ExploreViewModel({required PlaceRepository placeRepository})
    : _placeRepository = placeRepository {
    loadLatest = createResultCommandNoParam<void>(
      _loadLatest,
      debugName: 'explore_view_model.loadLatest',
    );
    loadLatest.run();
  }

  final PlaceRepository _placeRepository;

  late final ResultCommand<void, void> loadLatest;
  var _latest = <Place>[];

  UnmodifiableListView<Place> get latest => UnmodifiableListView(_latest);

  UnmodifiableListView<ContentCategory> get types =>
      UnmodifiableListView(ContentCategory.values.minusUnknown);

  bool _disposed = false;

  Future<Result<void>> _loadLatest() async {
    if (_disposed) {
      return Result.error(Exception('Discovery owner unavailable'));
    }
    final result = await _placeRepository.getLatest();
    if (_disposed) return result.map((_) {});

    return result.map((places) {
      _latest = places;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // The owner may be revoked from its own synchronous notification.
    scheduleMicrotask(super.dispose);
    final command = loadLatest;
    var queued = false;
    var invalidated = false;
    var released = false;
    late VoidCallback onRunningChanged;
    void requestCleanup() {
      if (queued || released) return;
      queued = true;
      invalidated = false;
      // Leave this dispatch and upstream's terminal notification/finally work.
      scheduleMicrotask(() {
        unawaited(
          Future<void>(() {
            queued = false;
            if (released || command.isRunningSync.value) return;
            if (invalidated) {
              requestCleanup();
              return;
            }
            command.isRunningSync.removeListener(onRunningChanged);
            released = true;
            command.dispose();
          }),
        );
      });
    }

    onRunningChanged = () {
      invalidated = true;
      if (!command.isRunningSync.value) requestCleanup();
    };
    command.isRunningSync.addListener(onRunningChanged);
    if (!command.isRunningSync.value) requestCleanup();
  }
}
