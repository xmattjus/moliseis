import 'package:moliseis/data/repositories/settings_repository_impl.dart';
import 'package:moliseis/utils/result.dart';

/// Real cache/commit logic with independently controlled Future delivery.
///
/// Used to prove that an older owner's continuation reads current consent even
/// when a newer commit overtakes delivery of its successful persistence Result.
class DeferredSettingsRepository extends SettingsRepositoryImpl {
  DeferredSettingsRepository(super._dataSource);

  /// Holds delivery after the real repository has updated its cache.
  Future<void> Function({required bool enable})? beforeDelivery;

  @override
  Future<Result<void>> setCrashReporting({required bool enable}) async {
    final result = await super.setCrashReporting(enable: enable);
    final wait = beforeDelivery;
    if (wait != null) await wait(enable: enable);
    return result;
  }
}
