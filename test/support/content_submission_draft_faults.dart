import 'package:moliseis/domain/models/content_submission_draft.dart';

/// Draft whose [toString] throws on a selected call for diagnostics tests.
final class DraftWithFailingToString extends ContentSubmissionDraft {
  DraftWithFailingToString({required this.throwOnCall}) : super(city: 'Rome');

  final int throwOnCall;
  final List<int> _calls = [0];

  int get toStringCalls => _calls.single;

  @override
  String toString() {
    _calls[0]++;
    if (_calls[0] == throwOnCall) {
      throw Exception('diagnostic rendering failed');
    }
    return super.toString();
  }
}
