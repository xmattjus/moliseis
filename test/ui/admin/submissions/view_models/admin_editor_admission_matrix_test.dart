import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/utils/result_command.dart';

import '../../../../support/admin_editor_command_harness.dart';

void main() {
  const matrix = [
    'SNNNNNNNNNN',
    'NSNNNNNNNNY',
    'NNSNNNNNNNY',
    'NNNSNNNNNNY',
    'NNNNSNNNNNY',
    'NNNNNSNNNNY',
    'NNNNNNSNNNY',
    'NNNNNNNSNNY',
    'NNNNNNNNSNY',
    'NIIIIINIISY',
    'NIIIIIIIIYS',
  ];
  for (final phase in ['before entry', 'repository pending']) {
    for (var row = 0; row < matrix.length; row++) {
      for (var column = 0; column < matrix.length; column++) {
        test('A1/A2 ${AdminEditorCommandHarness.laneNames[row]} → '
            '${AdminEditorCommandHarness.laneNames[column]} $phase', () async {
          // Each pair is also exercised with both physical release orders.
          for (final newerFirst in [true, false]) {
            final harness = AdminEditorCommandHarness();
            try {
              await harness.initialize();
              expect(harness.owner.mergePreview, isNotNull);
              harness.hold();
              expect(harness.requests[row](), isTrue);
              expect(harness.snapshots[row].isRunning, isTrue);
              if (phase == 'repository pending') {
                await pumpEventQueue(times: 4);
                expect(harness.calls[row], 1);
              } else {
                expect(harness.calls[row], 0);
              }
              final ids = harness.executionIds;
              final snapshots = harness.snapshots;
              final calls = harness.calls;
              final input = harness.owner.candidateSearch;
              var notifications = 0;
              harness.owner.addListener(() => notifications++);
              final expected = matrix[row][column];
              final admitted = harness.requests[column]();
              expect(admitted, expected == 'Y' || expected == 'I');
              if (!admitted) {
                expect(harness.executionIds, ids);
                for (var lane = 0; lane < matrix.length; lane++) {
                  expect(
                    identical(harness.snapshots[lane], snapshots[lane]),
                    isTrue,
                  );
                }
                expect(harness.calls, calls);
                expect(harness.owner.candidateSearch, input);
                expect(notifications, 0);
              } else {
                expect(harness.executionIds[column], isNot(ids[column]));
                expect(harness.snapshots[column].isRunning, isTrue);
              }
              await pumpEventQueue(times: 4);
              expect(harness.calls[row], 1);
              if (admitted) expect(harness.calls[column], 1);
              if (admitted && newerFirst) {
                harness.releaseLane(column);
                await pumpEventQueue(times: 4);
              }
              harness.releaseLane(row);
              await pumpEventQueue(times: 4);
              if (admitted && !newerFirst) {
                harness.releaseLane(column);
                await pumpEventQueue(times: 4);
              }
              expect(harness.snapshots[row].isRunning, isFalse);
              if (admitted) {
                expect(harness.snapshots[column].isRunning, isFalse);
              }
              if (expected == 'I') {
                expect(harness.snapshots[row].hasFailure, isFalse);
                expect(harness.snapshots[row].completed, isFalse);
              }
              expect(harness.owner.debugCommandDisposalCounts, everyElement(0));
            } finally {
              harness.owner.dispose();
              harness.release();
              await pumpEventQueue(times: 4);
            }
          }
        });
      }
    }
  }

  test(
    'A2 simultaneous Preview and Candidates use both admission rows',
    () async {
      final harness = AdminEditorCommandHarness();
      try {
        await harness.initialize();
        harness.hold();
        expect(harness.owner.requestPreview(), isTrue);
        expect(harness.owner.requestFindCandidates(), isTrue);
        expect(harness.owner.requestKeepCurrent(harness.group), isFalse);
        expect(harness.owner.requestLoad(), isFalse);
        expect(harness.owner.requestSave(), isTrue);
        expect(harness.owner.requestFindCandidates(), isFalse);
        await pumpEventQueue(times: 4);
        expect(harness.calls[9], 1);
        expect(harness.calls[10], 1);
        expect(harness.calls[1], 1);
        harness.releaseLane(1);
        await pumpEventQueue(times: 4);
        harness
          ..releaseLane(10)
          ..releaseLane(9);
        await pumpEventQueue(times: 4);
        expect(harness.owner.previewSnapshot.hasFailure, isFalse);
        expect(harness.owner.findCandidatesSnapshot.hasFailure, isFalse);
      } finally {
        harness.owner.dispose();
        harness.release();
        await pumpEventQueue(times: 4);
      }
    },
  );
}
