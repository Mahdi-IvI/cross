import 'package:path/path.dart' as p;

import '../../objectbox.g.dart';
import 'entities/cached_item.dart';
import 'entities/pending_operation.dart';

class AppDatabase {
  AppDatabase(this.store);
  final Store store;
  Box<CachedItem> get items => store.box<CachedItem>();
  Box<PendingOperation> get operations => store.box<PendingOperation>();

  static Future<AppDatabase> open(String directory) async =>
      AppDatabase(await openStore(directory: p.join(directory, 'library-db')));

  void close() => store.close();
}
