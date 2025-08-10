import 'package:logging/logging.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ObjectBox {
  late final Store store;

  ObjectBox._create(this.store);

  static Future<ObjectBox> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final store = await openStore(directory: p.join(docsDir.path, 'db_v2'));
    return ObjectBox._create(store);
  }
}

/// Removes the objects not available in [remote] from the [Box].
void removeLeftovers<T extends dynamic>(Box<T> box, Set<T> remote) {
  final local = Set<T>.unmodifiable(box.getAll());

  final objects = local.difference(remote);

  final ids = objects
      .map((toElement) => toElement.remoteId as int)
      .toList(growable: false);

  if (ids.isNotEmpty) {
    final log = Logger('ObjectBox');

    log.info('Removing leftovers: $ids');

    box.removeManyAsync(ids);
  }
}
