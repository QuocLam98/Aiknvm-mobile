// lib/widgets/drawer_key.dart
enum DrawerKind { chat, usage, adminUsers, adminConfig, bot, history }

class DrawerKey {
  final DrawerKind kind;
  final String? id;
  const DrawerKey(this.kind, {this.id});
}
