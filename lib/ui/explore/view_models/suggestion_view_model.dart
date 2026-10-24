import 'dart:async';

import 'package:collection/collection.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/place.dart';
import 'package:moliseis/domain/repositories/place_repository.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

class SuggestionViewModel extends ChangeNotifier {
  SuggestionViewModel({required PlaceRepository placeRepository})
    : _placeRepository = placeRepository {
    load = createResultCommandNoParam<void>(
      _load,
      debugName: 'suggestion_view_model.load',
    );

    load.run();
  }

  final PlaceRepository _placeRepository;

  /// Command for loading the suggested places.
  late final ResultCommand<void, void> load;

  var _suggestions = <Place>[];

  /// An unmodifiable list of suggested places.
  UnmodifiableListView<Place> get suggestions =>
      UnmodifiableListView(_suggestions);

  bool _disposed = false;

  Future<Result<void>> _load() async {
    if (_disposed) {
      return Result.error(Exception('Discovery owner unavailable'));
    }
    final result = await _placeRepository.getSuggestions();
    if (_disposed) return result.map((_) {});

    _suggestions = result.getOrNull() ?? [];

    notifyListeners();

    return result;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // The owner may be revoked from its own synchronous notification.
    scheduleMicrotask(super.dispose);
    final command = load;
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
