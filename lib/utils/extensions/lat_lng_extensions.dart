import 'package:latlong2/latlong.dart';

extension LatLngExtensions on LatLng {
  bool get isValid {
    if (latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180) {
      return true;
    }

    return false;
  }
}
