import 'package:latlong2/latlong.dart';

extension ListDoubleExtensions on List<double> {
  /// Converts a list of double into a [LatLng] object.
  /// The list must contain exactly two elements:
  /// the first element is treated as latitude and the second as longitude.
  LatLng get toLatLng {
    assert(length == 2);
    assert(this[0] >= -90 && this[0] <= 90);
    assert(this[1] >= -180 && this[1] <= 180);

    return LatLng(this[0], this[1]);
  }
}
