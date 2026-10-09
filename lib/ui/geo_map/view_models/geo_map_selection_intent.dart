import 'package:moliseis/domain/models/content_base.dart';
import 'package:moliseis/domain/models/event.dart';
import 'package:moliseis/domain/models/place.dart';

/// One selection ownership domain spanning event, place and default Map.
sealed class GeoMapSelectionIntent {
  const GeoMapSelectionIntent();

  /// Validates repository identity before either model commit or UI feedback.
  bool matchesPayload(ContentBase? content) => switch (this) {
    EventSelection(:final id) => content is Event && content.remoteId == id,
    PlaceSelection(:final id) => content is Place && content.remoteId == id,
    ClearSelection() => content == null,
  };
}

/// Requests an event by its remote identity.
final class EventSelection extends GeoMapSelectionIntent {
  const EventSelection(this.id);

  /// The requested remote event identifier.
  final int id;
}

/// Requests a place by its remote identity.
final class PlaceSelection extends GeoMapSelectionIntent {
  const PlaceSelection(this.id);

  /// The requested remote place identifier.
  final int id;
}

/// Revokes pending content and returns to an unselected Map.
final class ClearSelection extends GeoMapSelectionIntent {
  const ClearSelection();
}
