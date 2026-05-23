import 'dart:io' show Platform;

import 'package:moliseis/generated/objectbox.g.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ObjectBox {
  ObjectBox._create(this.store);

  /// The ObjectBox database.
  late final Store store;

  /// Initializes the ObjectBox database instance.
  static Future<ObjectBox> create() async {
    // Declare an app group name to run the app in a sandboxed environment on
    // macOS.
    //
    // See https://pub.dev/documentation/objectbox/latest/objectbox/Store/Store.html#:~:text=Sandboxed%20macOS%20apps
    final macOSAppGroup = Platform.isMacOS ? 'group.XIPB6vBUQJblN' : null;
    final docsDir = await getApplicationDocumentsDirectory();
    final store = await openStore(
      directory: p.join(docsDir.path, 'db_v2-3'),
      macosApplicationGroup: macOSAppGroup,
    );
    return ObjectBox._create(store);
  }
}
