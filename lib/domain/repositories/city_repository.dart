import 'package:moliseis/data/dtos/city_dto.dart';
import 'package:moliseis/utils/synchronizable.dart';

/// Domain interface for city data access.
///
/// [Synchronizable] is parameterized with [CityDto] from the data layer so
/// the concrete DTO type flows through `prepareSync`/`commitSync` at
/// compile time. The `data/dtos` import is a deliberate outward
/// dependency: the `SyncDto` base contract is in the domain, but the
/// concrete subtypes stay in the data layer to keep serialization and
/// ObjectBox annotations out of domain code.
abstract class CityRepository with Synchronizable<CityDto> {}
