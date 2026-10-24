import 'dart:async';
import 'dart:collection' show UnmodifiableListView;

import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/use-cases/post_use_case.dart';
import 'package:moliseis/utils/result.dart';
import 'package:moliseis/utils/result_command.dart';

class PostViewModel extends ChangeNotifier {
  PostViewModel({required PostUseCase postUseCase})
    : _postUseCase = postUseCase {
    loadEvent = createResultCommand<int, void>(
      _loadEvent,
      debugName: 'post_view_model.loadEvent',
    );
    loadNearContent = createResultCommand<LatLng, void>(
      _loadNearContent,
      debugName: 'post_view_model.loadNearContent',
    );
    loadPlace = createResultCommand<int, void>(
      _loadPlace,
      debugName: 'post_view_model.loadPlace',
    );
  }

  final PostUseCase _postUseCase;
  bool _disposed = false;

  late final ResultCommand<int, void> loadEvent;
  late final ResultCommand<LatLng, void> loadNearContent;
  late final ResultCommand<int, void> loadPlace;

  late ContentBase _content;
  final _nearContent = <ContentBase>[];

  ContentBase get content => _content;
  UnmodifiableListView<ContentBase> get nearContent =>
      UnmodifiableListView(_nearContent);

  Future<Result<void>> _loadEvent(int id) async {
    if (_disposed) return Result.error(Exception('Post owner unavailable'));

    final result = await _postUseCase.getEventById(id);
    return result.map((content) {
      if (_disposed) return;
      _content = content;
      notifyListeners();
    });
  }

  Future<Result<void>> _loadNearContent(LatLng coordinates) async {
    if (_disposed) return Result.error(Exception('Post owner unavailable'));
    _nearContent.clear();

    final eventsResult = await _postUseCase.getNearEventsByCoords(
      coordinates.latitude,
      coordinates.longitude,
    );
    // Do not start the places request after disposal; preserve an events error.
    if (_disposed) return eventsResult.map((_) {});

    final events = eventsResult.getOrNull();
    if (events != null) _nearContent.addAll(events);

    final placesResult = await _postUseCase.getNearPlacesByCoords(
      coordinates.latitude,
      coordinates.longitude,
    );
    if (!_disposed) {
      final places = placesResult.getOrNull();
      if (places != null) _nearContent.addAll(places);
      notifyListeners();
    }

    // Return the first error encountered, or the places result.
    if (eventsResult.isError) return eventsResult;
    return placesResult;
  }

  Future<Result<void>> _loadPlace(int id) async {
    if (_disposed) return Result.error(Exception('Post owner unavailable'));

    final result = await _postUseCase.getPlaceById(id);
    return result.map((content) {
      if (_disposed) return;
      _content = content;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    scheduleMicrotask(super.dispose);
    _releaseWhenSettled(loadEvent);
    _releaseWhenSettled(loadPlace);
    _releaseWhenSettled(loadNearContent);
  }

  // Keep settlement/reporting alive after owner revocation; release outside
  // synchronous results/value/owner dispatch, using the existing local barrier.
  void _releaseWhenSettled<P>(ResultCommand<P, void> command) {
    var queued = false;
    var invalidated = false;
    var released = false;
    late VoidCallback onRunningChanged;
    void requestCleanup() {
      if (queued || released) return;
      queued = true;
      invalidated = false;
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
