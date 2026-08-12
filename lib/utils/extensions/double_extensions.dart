import 'package:latlong2/latlong.dart';

extension ListDoubleExtensions on List<double> {
  /// Converts a list of double into a [LatLng] object.
  /// The list must contain exactly two elements:
  /// the first element is treated as latitude and the second as longitude.
  LatLng get toLatLng {
    assert(
      length == 2,
      'A LatLng requires exactly two values: latitude and longitude.',
    );
    assert(
      this[0] >= -90 && this[0] <= 90,
      'Latitude must be between -90 and 90 degrees; got ${this[0]}.',
    );
    assert(
      this[1] >= -180 && this[1] <= 180,
      'Longitude must be between -180 and 180 degrees; got ${this[1]}.',
    );

    return LatLng(this[0], this[1]);
  }
}
