import 'package:meta/meta.dart';

@immutable
class GeoMapState {
  const GeoMapState({
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.attractionId = -1,
  });

  final double latitude;
  final double longitude;
  final int attractionId;

  @override
  bool operator ==(Object other) =>
      other is GeoMapState &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.attractionId == attractionId;

  @override
  int get hashCode => Object.hash(latitude, longitude, attractionId);

  GeoMapState copyWith({
    double? latitude,
    double? longitude,
    int? attractionId,
  }) => GeoMapState(
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    attractionId: attractionId ?? this.attractionId,
  );

  /// Whether [latitude] and [longitude] are not equal to 0.0.
  ///
  /// Theoretically 0.0 is a valid value for both latitude and
  /// longitude, but its impossible those will be ever used
  /// in the app.
  bool get hasValidCoords => latitude != 0.0 && longitude != 0.0;

  /// Whether the [attractionId] is not equal to -1.
  bool get hasValidId => attractionId != -1;
}
