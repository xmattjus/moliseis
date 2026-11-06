part of 'package:moliseis/utils/logging/log_event.dart';

/// A handled unexpected command failure, with a non-sensitive command name.
final class CommandExecutionFailed extends LogEvent {
  /// Receives only an allow-listed name from the command reporting boundary.
  const CommandExecutionFailed({required this.debugName});

  /// A constant command identifier, never a parameter or user input.
  final String debugName;

  @override
  Map<String, Object?> get data => {'debugName': debugName};

  @override
  AppLogLevel get level => AppLogLevel.error;

  @override
  String get name => 'command_execution_failed';
}

/// Keeps only reviewed application command identities in remote diagnostics.
String safeCommandDebugName(String? name) =>
    const {
      'SettingsViewModel.setCrashReporting',
      'ThemeViewModel.setThemeBrightness',
      'ThemeViewModel.setThemeType',
      'admin_login',
      'admin_logout',
      'admin_submission_editor_add_asset',
      'admin_submission_editor_apply',
      'admin_submission_editor_delete_asset',
      'admin_submission_editor_find_candidates',
      'admin_submission_editor_keep_current',
      'admin_submission_editor_link',
      'admin_submission_editor_load',
      'admin_submission_editor_preview',
      'admin_submission_editor_promote',
      'admin_submission_editor_reconcile',
      'admin_submission_editor_reject',
      'admin_submission_editor_save',
      'admin_submissions_load',
      'admin_submissions_load_ignored',
      'admin_submissions_unignore',
      'category_view_model.load',
      'category_view_model.setSort',
      'content_submission_add_asset',
      'content_submission_clear',
      'content_submission_remove_asset',
      'content_submission_retrieve_lost_assets',
      'content_submission_submit',
      'event_view_model.loadAll',
      'event_view_model.loadByDate',
      'event_view_model.loadNext',
      'event_view_model.loadOngoing',
      'explore_view_model.loadLatest',
      'favourite_view_model.load',
      'geo_map_markers',
      'geo_map_nearby',
      'geo_map_selection',
      'post_view_model.loadEvent',
      'post_view_model.loadNearContent',
      'post_view_model.loadPlace',
      'search_history_read',
      'search_history_write',
      'search_results',
      'search_suggestions',
      'suggestion_view_model.load',
      'sync_view_model.sync',
      'weather.current',
      'weather.daily',
      'weather.hourly',
    }.contains(name)
    ? name!
    : 'command';
