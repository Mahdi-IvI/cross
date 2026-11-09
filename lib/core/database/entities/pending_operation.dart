import 'package:objectbox/objectbox.dart';

@Entity()
class PendingOperation {
  PendingOperation({
    this.id = 0,
    required this.scope,
    required this.itemId,
    required this.action,
  });

  @Id()
  int id;
  @Index()
  String scope;
  int itemId;
  // createFolder, upload, update, delete. Upload bytes live in the app-private directory.
  String action;
}
