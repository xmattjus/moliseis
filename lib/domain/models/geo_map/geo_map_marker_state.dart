import 'package:meta/meta.dart';
import 'package:moliseis/domain/models/attraction/attraction_type.dart';

@immutable
class GeoMapMarkerState {
  final List<double> coordinates;
  final AttractionType type;
  final String name;

  const GeoMapMarkerState({
    required this.coordinates,
    required this.type,
    required this.name,
  });
}
