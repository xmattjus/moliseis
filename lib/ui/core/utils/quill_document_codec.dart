import 'package:collection/collection.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Converts supported Quill Delta documents at the UI boundary.
///
/// Stored content is validated before it reaches [Document] so malformed or
/// unsupported remote data can safely fall back to its legacy plain-text
/// representation.
final class QuillDocumentCodec {
  QuillDocumentCodec._();

  static const _insertKey = 'insert';
  static const _attributesKey = 'attributes';
  static const _deltaEquality = DeepCollectionEquality();

  /// Builds a [Document] from supported stored Delta operations.
  ///
  /// Returns null for absent, malformed, or unsupported data. This lets UI
  /// callers preserve the legacy plain-text fallback without exposing parser
  /// failures to the rendering path.
  static Document? documentFromDelta(Object? value) {
    final operations = _copySupportedOperations(value);
    if (operations == null) return null;

    final document = Document.fromJson(operations);
    return _deltaEquality.equals(document.toDelta().toJson(), operations)
        ? document
        : null;
  }

  /// Builds a [Document] from a legacy plain-text description.
  ///
  /// Adds one Quill-owned terminal newline without trimming author-entered
  /// whitespace or trailing newlines.
  static Document documentFromPlainText(String? description) {
    return Document.fromJson(<Map<String, dynamic>>[
      <String, dynamic>{_insertKey: '${description ?? ''}\n'},
    ]);
  }

  /// Serializes a [Document] into matching plain-text and Delta projections.
  ///
  /// An empty document is normalized to null values. Non-empty documents lose
  /// exactly one terminal newline from their plain-text projection.
  static ({String? description, List<Map<String, dynamic>>? descriptionDelta})
  serialize(Document document) {
    if (document.isEmpty()) {
      return (description: null, descriptionDelta: null);
    }

    final plainText = document.toPlainText();
    final description = plainText.endsWith('\n')
        ? plainText.substring(0, plainText.length - 1)
        : plainText;

    return (
      description: description,
      descriptionDelta: _copyDelta(document.toDelta().toJson()),
    );
  }

  /// Whether [url] is an absolute HTTP or HTTPS URL with a non-empty host.
  ///
  /// This is shared by stored-document validation and future authoring and
  /// read-only link callbacks so both paths apply the same scheme allowlist.
  static bool isValidLink(String? url) {
    if (url == null || url.isEmpty) return false;

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) return false;

    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  static List<Map<String, dynamic>>? _copySupportedOperations(Object? value) {
    if (value is! List<Object?> || value.isEmpty) return null;

    final operations = <Map<String, dynamic>>[];
    for (final rawOperation in value) {
      if (rawOperation is! Map<Object?, Object?> ||
          !_hasOnlySupportedOperationKeys(rawOperation)) {
        return null;
      }

      final insert = rawOperation[_insertKey];
      if (insert is! String) return null;

      final operation = <String, dynamic>{_insertKey: insert};
      if (rawOperation.containsKey(_attributesKey)) {
        final rawAttributes = rawOperation[_attributesKey];
        if (rawAttributes is! Map<Object?, Object?> || rawAttributes.isEmpty) {
          return null;
        }

        final attributes = _copySupportedAttributes(rawAttributes, insert);
        if (attributes == null) return null;
        operation[_attributesKey] = attributes;
      }

      operations.add(operation);
    }

    final terminalInsert = operations.last[_insertKey]! as String;
    if (!terminalInsert.endsWith('\n')) return null;

    return operations;
  }

  static bool _hasOnlySupportedOperationKeys(
    Map<Object?, Object?> operation,
  ) {
    if (!operation.containsKey(_insertKey)) return false;

    return operation.keys.every(
      (key) => key is String && (key == _insertKey || key == _attributesKey),
    );
  }

  static Map<String, dynamic>? _copySupportedAttributes(
    Map<Object?, Object?> attributes,
    String insert,
  ) {
    final copy = <String, dynamic>{};
    for (final entry in attributes.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value == null) return null;

      switch (key) {
        case 'bold':
        case 'italic':
        case 'underline':
          if (value is! bool || !value) return null;
        case 'list':
          if (insert != '\n' ||
              value is! String ||
              (value != 'ordered' && value != 'bullet')) {
            return null;
          }
        case 'link':
          if (value is! String || !isValidLink(value)) return null;
        default:
          return null;
      }

      copy[key] = value;
    }

    return copy;
  }

  static List<Map<String, dynamic>> _copyDelta(
    List<Map<String, dynamic>> operations,
  ) {
    return List<Map<String, dynamic>>.unmodifiable(
      operations.map(
        (operation) => Map<String, dynamic>.unmodifiable({
          for (final entry in operation.entries)
            entry.key: _copyJsonValue(entry.value),
        }),
      ),
    );
  }

  static Object? _copyJsonValue(Object? value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.unmodifiable({
        for (final entry in value.entries)
          entry.key: _copyJsonValue(entry.value),
      });
    }

    if (value is List<Object?>) {
      return List<Object?>.unmodifiable(value.map(_copyJsonValue));
    }

    return value;
  }
}
