import 'dart:io' show Platform;

import 'package:logging/logging.dart';
import 'package:moliseis/generated/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ObjectBox {
  late final Store store;

  ObjectBox._create(this.store);

  static Future<ObjectBox> create() async {
    // Declare an app group name to run the app in a sandboxed environment on macOS.
    // See https://pub.dev/documentation/objectbox/latest/objectbox/Store/Store.html#:~:text=Sandboxed%20macOS%20apps
    final macOSAppGroup = Platform.isMacOS ? 'group.XIPB6vBUQJblN' : null;
    final docsDir = await getApplicationDocumentsDirectory();
    final store = await openStore(
      directory: p.join(docsDir.path, 'db_v2'),
      macosApplicationGroup: macOSAppGroup,
    );
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
