import 'package:flutter_test/flutter_test.dart';
import 'package:moliseis/data/core/relation_update.dart';

/// ---------------------------------------------------------------------------
/// Fake ObjectBox relation
/// ---------------------------------------------------------------------------

class FakeToOneRelation {
  FakeToOneRelation(this.targetId);

  int targetId;
}

class FakeEntity {
  final relation = FakeToOneRelation(100);
}

/// ---------------------------------------------------------------------------
/// Synchronization logic
/// ---------------------------------------------------------------------------

void applyRelationUpdate(
  RelationUpdate<int> update,
  FakeToOneRelation relation,
) {
  switch (update) {
    case Keep():
      break;

    case Clear():
      relation.targetId = 0;

    case Assign(:final value):
      relation.targetId = value;
  }
}

/// ---------------------------------------------------------------------------
/// Unit tests
/// ---------------------------------------------------------------------------

void main() {
  group('RelationUpdate synchronization semantics', () {
    test(
      'Keep should preserve existing relation targetId',
      () {
        final entity = FakeEntity();

        applyRelationUpdate(
          const Keep(),
          entity.relation,
        );

        expect(entity.relation.targetId, equals(100));
      },
    );

    test(
      'Clear should remove existing relation',
      () {
        final entity = FakeEntity();

        applyRelationUpdate(
          const Clear(),
          entity.relation,
        );

        expect(entity.relation.targetId, equals(0));
      },
    );

    test(
      'Assign should update relation targetId',
      () {
        final entity = FakeEntity();

        applyRelationUpdate(
          const Assign(42),
          entity.relation,
        );

        expect(entity.relation.targetId, equals(42));
      },
    );

    test(
      'Assign should replace previous relation value',
      () {
        final entity = FakeEntity();

        entity.relation.targetId = 12;

        applyRelationUpdate(
          const Assign(99),
          entity.relation,
        );

        expect(entity.relation.targetId, equals(99));
      },
    );

    test(
      'Clear should remove previously assigned relation',
      () {
        final entity = FakeEntity();

        entity.relation.targetId = 55;

        applyRelationUpdate(
          const Clear(),
          entity.relation,
        );

        expect(entity.relation.targetId, equals(0));
      },
    );
  });

  group('backend payload semantics', () {
    test(
      'Keep should represent omitted backend field',
      () {
        const update = Keep<int>();

        final result = switch (update) {
          Keep<int>() => 'unchanged',
          Clear<int>() => 'cleared',
          Assign<int>() => 'updated',
        };

        expect(result, equals('unchanged'));
      },
    );

    test(
      'Clear should represent explicit backend null',
      () {
        const update = Clear<int>();

        final result = switch (update) {
          Keep<int>() => 'unchanged',
          Clear<int>() => 'cleared',
          Assign<int>() => 'updated',
        };

        expect(result, equals('cleared'));
      },
    );

    test(
      'Assign should represent explicit backend value',
      () {
        const update = Assign<int>(123);

        final result = switch (update) {
          Keep<int>() => 'unchanged',
          Clear<int>() => 'cleared',
          Assign(:final value) => value,
        };

        expect(result, equals(123));
      },
    );
  });

  group('partial synchronization behavior', () {
    test(
      'multiple updates should preserve untouched relations',
      () {
        final projectRelation = FakeToOneRelation(10);
        final ownerRelation = FakeToOneRelation(20);

        applyRelationUpdate(
          const Keep(),
          projectRelation,
        );

        applyRelationUpdate(
          const Assign(50),
          ownerRelation,
        );

        expect(projectRelation.targetId, equals(10));
        expect(ownerRelation.targetId, equals(50));
      },
    );

    test(
      'Clear should be distinguishable from Keep',
      () {
        final keepRelation = FakeToOneRelation(77);
        final clearRelation = FakeToOneRelation(77);

        applyRelationUpdate(
          const Keep(),
          keepRelation,
        );

        applyRelationUpdate(
          const Clear(),
          clearRelation,
        );

        expect(keepRelation.targetId, equals(77));
        expect(clearRelation.targetId, equals(0));
      },
    );
  });

  group('pattern matching exhaustiveness', () {
    test(
      'switch expressions should exhaustively handle all relation operations',
      () {
        const updates = <RelationUpdate<int>>[
          Keep(),
          Clear(),
          Assign(5),
        ];

        final results = updates.map((update) {
          return switch (update) {
            Keep() => 'keep',
            Clear() => 'clear',
            Assign(:final value) => 'assign:$value',
          };
        }).toList();

        expect(
          results,
          equals([
            'keep',
            'clear',
            'assign:5',
          ]),
        );
      },
    );
  });
}
