import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/history_controller.dart';
import '../models/bot_model.dart';
import '../models/history_message.dart';
import '../widgets/drawer_key.dart';
import '../controllers/app_events.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppDrawer extends StatelessWidget {
  final AuthController auth;
  final HomeController home;
  final HistoryController history;

  /// Mục hiện tại để highlight (Chat/Usage/Admin/Bot/<id>/History/<id>)
  final DrawerKey current;

  /// Callback điều hướng khi chọn 1 mục trong Drawer
  final void Function(DrawerKey key)? onSelect;

  const AppDrawer({
    super.key,
    required this.auth,
    required this.home,
    required this.history,
    required this.current,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final username = auth.user?.name ?? '';
    final email = auth.user?.email ?? '';
    // final role = auth.user?.role ?? 'user';

    void _popThen(VoidCallback cb) {
      Navigator.of(context).pop();
      // gọi sau frame để tránh xung đột navigator & đảm bảo Drawer đóng hoàn toàn
      WidgetsBinding.instance.addPostFrameCallback((_) => cb());
    }

    return SizedBox(
      width: 320,
      child: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // User info
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _popThen(() {
                          Navigator.pushNamed(context, '/account');
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.black26),
                          ),
                          child: Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        email,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              _popThen(() {
                                Navigator.pushNamed(context, '/topup');
                              });
                            },
                            child: const Text(
                              'Nạp tiền',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF635BFF),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () async {
                              await auth.logout();
                              if (context.mounted) {
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed('/login');
                              }
                            },
                            icon: const Icon(
                              Icons.logout,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Đăng xuất',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),

              // MENU ITEMS
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    // Chat
                    _MenuItem(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: 'Chat',
                      active: current.kind == DrawerKind.chat,
                      onTap: () => _popThen(() {
                        Navigator.pushReplacementNamed(context, '/home');
                      }),
                    ),

                    // Usage
                    _MenuItem(
                      icon: const Icon(Icons.receipt_long),
                      label: 'Thanh toán và sử dụng',
                      active: current.kind == DrawerKind.usage,
                      onTap: () => _popThen(() {
                        onSelect?.call(const DrawerKey(DrawerKind.usage));
                      }),
                    ),

                    _MenuItem(
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: 'Trang quản trị',
                      onTap: () => _popThen(() {
                        Navigator.pushNamed(context, '/admin');
                      }),
                    ),

                    // Admin (tạm ẩn)

                    // Danh sách trợ lý AI
                    _MenuGroup(
                      icon: const Icon(Icons.support_agent_outlined),
                      label: 'Danh sách trợ lý AI',
                      maxListHeight: 220,
                      scrollable: true,
                      children: [
                        AnimatedBuilder(
                          animation: AppEvents.instance,
                          builder: (context, _) {
                            return FutureBuilder<List<BotModel>>(
                              future: home.getAllBots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      'Lỗi tải danh sách bot: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  );
                                }
                                final bots = snapshot.data ?? <BotModel>[];
                                final defaultId = dotenv.env['DEFAULT_BOT']
                                    ?.trim();
                                final listBots =
                                    (defaultId == null || defaultId.isEmpty)
                                    ? List<BotModel>.from(bots)
                                    : bots
                                          .where((b) => b.id != defaultId)
                                          .toList();

                                // Sắp xếp theo priority (thấp -> cao).
                                // Null priority đẩy xuống cuối cùng.
                                listBots.sort((a, b) {
                                  final pa = a.priority ?? 1 << 30;
                                  final pb = b.priority ?? 1 << 30;
                                  final cmp = pa.compareTo(pb); // asc
                                  if (cmp != 0) return cmp;
                                  return a.name.toLowerCase().compareTo(
                                    b.name.toLowerCase(),
                                  );
                                });

                                if (listBots.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 4,
                                    ),
                                    child: Text('Chưa có trợ lý nào'),
                                  );
                                }

                                return AnimatedBuilder(
                                  animation: home,
                                  builder: (_, __) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: listBots.map((bot) {
                                        final Widget leading =
                                            (bot.image != null &&
                                                bot.image!.isNotEmpty)
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Image.network(
                                                  bot.image!,
                                                  width: 22,
                                                  height: 22,
                                                  fit: BoxFit.cover,
                                                  gaplessPlayback: true,
                                                  frameBuilder:
                                                      (
                                                        context,
                                                        child,
                                                        frame,
                                                        wasSync,
                                                      ) {
                                                        if (frame == null) {
                                                          return Container(
                                                            width: 22,
                                                            height: 22,
                                                            color: Colors
                                                                .grey
                                                                .shade200,
                                                            child: const Center(
                                                              child: SizedBox(
                                                                width: 10,
                                                                height: 10,
                                                                child:
                                                                    CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          1.2,
                                                                    ),
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                        return AnimatedOpacity(
                                                          opacity: 1.0,
                                                          duration:
                                                              const Duration(
                                                                milliseconds:
                                                                    180,
                                                              ),
                                                          child: child,
                                                        );
                                                      },
                                                  errorBuilder: (_, __, ___) =>
                                                      const Icon(
                                                        Icons
                                                            .smart_toy_outlined,
                                                      ),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.smart_toy_outlined,
                                              );

                                        final isActive =
                                            current.kind == DrawerKind.bot &&
                                            current.id == bot.id;

                                        return _MenuItem(
                                          icon: leading,
                                          label: bot.name,
                                          active: isActive,
                                          onTap: () async {
                                            await home.setBot(bot);
                                            _popThen(() {
                                              onSelect?.call(
                                                DrawerKey(
                                                  DrawerKind.bot,
                                                  id: bot.id,
                                                ),
                                              );
                                            });
                                          },
                                        );
                                      }).toList(),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),

                    // Lịch sử chat
                    _MenuGroup(
                      icon: const Icon(Icons.history),
                      label: 'Danh sách lịch sử tin nhắn',
                      labelColor: Colors.deepPurple,
                      children: [
                        FutureBuilder<List<HistoryMessage>>(
                          future: history.getHistoryFuture(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            if (snapshot.hasError) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 4,
                                ),
                                child: Text(
                                  'Lỗi tải lịch sử: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              );
                            }

                            final list =
                                snapshot.data ?? const <HistoryMessage>[];
                            if (list.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 4,
                                ),
                                child: Text('Chưa có lịch sử nào'),
                              );
                            }

                            return _HistoryListWithDelete(
                              history: history,
                              current: current,
                              items: list,
                              onSelect: onSelect,
                              popThen: _popThen,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ====== Reusable internal widgets ======

class _MenuItem extends StatelessWidget {
  final Widget? icon; // Icon hoặc Image.network
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _MenuItem({
    this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? Colors.black : Colors.transparent;
    final fg = active ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            children: [
              IconTheme(
                data: IconThemeData(color: fg, size: 22),
                child: icon ?? const SizedBox.shrink(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: fg,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryListWithDelete extends StatefulWidget {
  final HistoryController history;
  final DrawerKey current;
  final List<HistoryMessage> items;
  final void Function(DrawerKey key)? onSelect;
  final void Function(void Function()) popThen;
  const _HistoryListWithDelete({
    required this.history,
    required this.current,
    required this.items,
    required this.onSelect,
    required this.popThen,
  });

  @override
  State<_HistoryListWithDelete> createState() => _HistoryListWithDeleteState();
}

class _HistoryListWithDeleteState extends State<_HistoryListWithDelete> {
  final Set<String> _deleting = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.items.map((item) {
        final isActive =
            widget.current.kind == DrawerKind.history &&
            widget.current.id == item.id;
        final id = item.id;
        final deleting = id != null && _deleting.contains(id);
        return Opacity(
          opacity: deleting ? 0.6 : 1.0,
          child: Row(
            children: [
              Expanded(
                child: _MenuItem(
                  label: item.name ?? '',
                  active: isActive,
                  onTap: () {
                    if (id == null || deleting) return;
                    widget.history.selectHistory(item);
                    widget.popThen(() {
                      widget.onSelect?.call(
                        DrawerKey(DrawerKind.history, id: id),
                      );
                    });
                  },
                ),
              ),
              if (id != null)
                IconButton(
                  tooltip: deleting ? 'Đang xóa...' : 'Xóa',
                  icon: deleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, size: 18),
                  onPressed: deleting
                      ? null
                      : () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Xóa lịch sử?'),
                              content: const Text(
                                'Bạn chắc chắn muốn xóa đoạn chat này?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Hủy'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                          setState(() => _deleting.add(id));
                          try {
                            await widget.history.deleteHistory(id);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Đã xóa lịch sử')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Xóa thất bại: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _deleting.remove(id));
                          }
                        },
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final Widget icon;
  final String label;
  final List<Widget> children;
  final Color? labelColor;
  final bool scrollable;
  final double maxListHeight;

  const _MenuGroup({
    required this.icon,
    required this.label,
    required this.children,
    this.labelColor,
    this.scrollable = false,
    this.maxListHeight = 260,
  });

  @override
  Widget build(BuildContext context) {
    final Widget childrenContainer = scrollable
        ? SizedBox(
            height: maxListHeight,
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.only(left: 12, bottom: 4),
        leading: icon,
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: labelColor ?? Colors.black,
          ),
        ),
        children: [childrenContainer],
      ),
    );
  }
}
