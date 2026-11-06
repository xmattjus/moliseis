import 'dart:io';

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
  final stringLiteral = RegExp(
    r'''(?:r)?(?:'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*")''',
  );
  final comment = RegExp(r'//[^\n]*|/\*[\s\S]*?\*/');
  final talkerImport = RegExp(
    r'''^\s*import\s+['"]package:talker(?:_flutter)?/[^'"]+['"]''',
    multiLine: true,
  );
  final directGlobalTalkerUse = RegExp(r'\$talker\.\w+\s*\(');
  const allowedSentryOperations = <String, Set<String>>{
    'lib/main.dart': {'close'},
    'lib/utils/logging/app_logger.dart': {'captureEvent', 'addBreadcrumb'},
    'lib/utils/logging/run_traced_result.dart': {'startSpan'},
  };
  const allowedTalkerFiles = <String>{
    'lib/config/dependencies.dart',
    'lib/routing/router.dart',
    'lib/ui/core/ui/logging_screen.dart',
    'lib/utils/logging/app_logger.dart',
    'lib/utils/logging/app_log_level_mapper.dart',
  };

  for (final entry in sources.entries) {
    final path = entry.key.replaceAll(r'\', '/');
    final source = entry.value;
    // Mask ordinary string literals and comments to avoid matching examples
    // or prose. This intentionally remains a lightweight source check, not a
    // Dart lexer; SDK calls inside interpolated strings are outside its scope.
    final code = source.replaceAll(stringLiteral, ' ').replaceAll(comment, ' ');
    final importSource = source.replaceAll(comment, ' ');
    final sentryImports = sentryImport.allMatches(importSource).toList();
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
        isBusinessLayer && sentryImport.hasMatch(importSource);
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

    if (talkerImport.hasMatch(importSource) &&
        !allowedTalkerFiles.contains(path)) {
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
