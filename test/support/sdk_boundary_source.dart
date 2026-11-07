import 'dart:io';

final _stringOrComment = RegExp(
  r'//[^\r\n]*|/\*[\s\S]*?\*/'
  r"|r'''[\s\S]*?'''"
  r'|r"""[\s\S]*?"""'
  r"|'''(?:\\[\s\S]|(?!''')[^\\])*'''"
  r'|"""(?:\\[\s\S]|(?!""")[^\\])*"""'
  r"|r'[^'\r\n]*'"
  r'|r"[^"\r\n]*"'
  r"|'(?:\\[^\r\n]|[^'\\\r\n])*'"
  r'|"(?:\\[^\r\n]|[^"\\\r\n])*"',
);
final _nonLineBreak = RegExp(r'[^\r\n]');

/// Masks Dart strings and comments while preserving source offsets and lines.
String maskDartCode(String source) => source.replaceAllMapped(
  _stringOrComment,
  (match) => match[0]!.replaceAll(_nonLineBreak, ' '),
);

/// Checks that production wires both Sentry privacy options in its init call.
bool productionSentryPrivacyConfigured(String source) {
  final code = maskDartCode(source);
  final initCalls = RegExp(
    r'SentryFlutter\s*\.\s*init\s*\(\s*\(options\)\s*=>\s*options([\s\S]*?),\s*appRunner\s*:',
  ).allMatches(code).toList();
  if (initCalls.length != 1) return false;
  final options = initCalls.single.group(1)!;
  final printSettings = RegExp(
    r'\.\.enablePrintBreadcrumbs\s*=\s*([^,\r\n]+)',
  ).allMatches(options).map((match) => match.group(1)!.trim());
  final sendSettings = RegExp(
    r'\.\.beforeSend\s*=\s*([^,\r\n]+)',
  ).allMatches(options).map((match) => match.group(1)!.trim());
  return printSettings.length == 1 &&
      printSettings.single == 'false' &&
      sendSettings.length == 1 &&
      sendSettings.single == 'AppLogger.beforeSend';
}

/// Finds direct Sentry and Talker SDK use outside the approved boundaries.
///
/// This is a source-level regression gate, not a Dart parser. It deliberately
/// recognizes the SDK's static capture/configuration APIs and imports of the
/// Talker package; it cannot prove the behavior of dynamically obtained
/// objects or arbitrary wrapper APIs.
List<String> findSdkBoundaryViolations(Map<String, String> sources) {
  final violations = <String>[];
  final sentryImport = RegExp(
    r'''^\s*import\s+['"]package:sentry(?:_flutter|_supabase)?/[^'"]+['"](?:\s+as\s+(\w+))?''',
    multiLine: true,
  );
  final directSentryApi = RegExp(
    r'\b(Sentry)\s*\.\s*(capture\w*|addBreadcrumb|configureScope|withScope|currentHub|bindClient|startTransaction|startSpan\w*|logger|setUser|setTag|setExtra|setContext)\b',
  );
  final aliasedSentryApi = RegExp(
    r'\b(\w+)\s*\.\s*Sentry\s*\.\s*(capture\w*|addBreadcrumb|configureScope|withScope|currentHub|bindClient|startTransaction|startSpan\w*|logger|setUser|setTag|setExtra|setContext)\b',
  );
  final hubAdapterConstruction = RegExp(
    r'\b(?:(\w+)\s*\.\s*)?Hub(?:Adapter)?\s*\(',
  );
  final talkerImport = RegExp(
    r'''^\s*import\s+['"]package:talker(?:_flutter)?/[^'"]+['"]''',
    multiLine: true,
  );
  final directGlobalTalkerUse = RegExp(r'\$talker\s*[!?]?\s*\.\s*\w+\s*\(');
  const allowedSentryOperations = <String, Set<String>>{
    'lib/main.dart': {'close'},
    'lib/utils/logging/app_logger.dart': {'captureEvent', 'addBreadcrumb'},
    'lib/utils/logging/run_traced_result.dart': {'startSpan'},
  };
  const allowedTalkerFiles = <String>{
    'lib/main.dart', // Typed Replay masking rules for diagnostic widgets.
    'lib/config/dependencies.dart',
    'lib/routing/router.dart',
    'lib/ui/core/ui/logging_screen.dart',
    'lib/utils/logging/app_logger.dart',
    'lib/utils/logging/app_log_level_mapper.dart',
  };

  for (final entry in sources.entries) {
    final path = entry.key.replaceAll(r'\', '/');
    final source = entry.value;
    // Keep lines and offsets for import matching.
    // shortcut: interpolation code is masked, use an analyzer if needed.
    final code = maskDartCode(source);
    final importSource = source.replaceAllMapped(_stringOrComment, (match) {
      final token = match[0]!;
      return token.startsWith('//') || token.startsWith('/*')
          ? token.replaceAll(_nonLineBreak, ' ')
          : token;
    });
    bool isCodeImport(RegExpMatch match) =>
        code.substring(match.start, match.end).trimLeft().startsWith('import');
    final sentryImports = sentryImport
        .allMatches(importSource)
        .where(isCodeImport)
        .toList();
    final importedAliases = sentryImports
        .map((match) => match.group(1))
        .whereType<String>()
        .toSet();
    final hasUnaliasedSentryImport = sentryImports.any(
      (match) => match.group(1) == null,
    );
    final isBusinessLayer =
        path.startsWith('lib/domain/') ||
        path.startsWith('lib/data/repositories/');
    final importsSentryFromBusinessLayer =
        isBusinessLayer && sentryImports.isNotEmpty;
    final apiOperations = <String>{
      ...directSentryApi.allMatches(code).map((match) => match.group(2)!),
      ...aliasedSentryApi
          .allMatches(code)
          .where((match) => importedAliases.contains(match.group(1)))
          .map((match) => match.group(2)!),
    };
    if (importsSentryFromBusinessLayer) {
      violations.add('$path: business code must not import the Sentry SDK');
    }
    final constructsSentryHubAdapter = hubAdapterConstruction
        .allMatches(code)
        .any((match) {
          final prefix = match.group(1);
          return prefix == null
              ? hasUnaliasedSentryImport
              : importedAliases.contains(prefix);
        });
    if (constructsSentryHubAdapter) {
      violations.add(
        '$path: direct Sentry Hub construction bypasses the logging boundary',
      );
    }
    for (final operation in apiOperations) {
      final allowed = allowedSentryOperations[path];
      if (!importsSentryFromBusinessLayer &&
          (allowed == null || !allowed.contains(operation))) {
        violations.add(
          '$path: direct Sentry $operation requires an approved adapter',
        );
      }
    }

    if (!allowedTalkerFiles.contains(path) &&
        talkerImport.allMatches(importSource).any(isCodeImport)) {
      violations.add(
        '$path: direct Talker use requires an approved logging boundary',
      );
    }
    if (directGlobalTalkerUse.hasMatch(code)) {
      violations.add('$path: direct global Talker use bypasses Logger.log');
    }
  }
  return violations;
}

/// Reads Dart sources under [root] and applies [findSdkBoundaryViolations].
Map<String, String> readProductionDartSources(Directory root) => {
  for (final file in root.listSync(recursive: true).whereType<File>())
    if (file.path.endsWith('.dart') && !_isGeneratedDart(file.path))
      file.path.replaceAll(r'\', '/'): file.readAsStringSync(),
};

bool _isGeneratedDart(String path) {
  const generatedSuffixes = ['.g.dart', '.mapper.dart', '.init.dart'];
  return generatedSuffixes.any(path.endsWith);
}
