import 'package:flutter/foundation.dart';
import 'package:moliseis/domain/models/content_type.dart';

/// Complete remote identity; event and place IDs belong to different tables.
typedef GeoMapContentIdentity = ({int id, ContentType type});

/// The one authoritative semantic presentation of the Map.
@immutable
sealed class GeoMapMode {
  const GeoMapMode();
}

/// Discovery around the separately committed Explore anchor.
final class GeoMapExplore extends GeoMapMode {
  const GeoMapExplore();
}

/// Results for an accepted query; execution status belongs to the command.
final class GeoMapSearchResults extends GeoMapMode {
  const GeoMapSearchResults(this.query);

  final String query;
}

/// A selected identity, independently of whether its content has resolved.
final class GeoMapPostDetail extends GeoMapMode {
  const GeoMapPostDetail(this.identity);

  final GeoMapContentIdentity identity;
}
