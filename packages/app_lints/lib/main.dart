import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:app_lints/rules/no_base_exception_throw_rule.dart';
import 'package:app_lints/rules/no_raw_string_in_log_rule.dart';

final plugin = AppLints();

class AppLints extends Plugin {
  @override
  String get name => 'app_lints';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(NoBaseExceptionThrowRule());
    registry.registerWarningRule(NoRawStringInLogRule());
  }
}
