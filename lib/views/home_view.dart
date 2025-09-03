import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../models/bot_model.dart';
import '../controllers/history_controller.dart';
import '../models/history_message.dart';

class HomeView extends StatefulWidget {
  final AuthController auth;
  final HomeController home;
  final HistoryController history;

  const HomeView({
    super.key,
    required this.auth,
    required this.home,
    required this.history,
  });

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _inputCtrl = TextEditingController();

  String _short(String s) => s.length <= 24
      ? s
      : '${s.substring(0, 12)}…${s.substring(s.length - 12)}';

  @override
  void initState() {
    super.initState();
    widget.home.loadDefaultBot();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final home = widget.home;
    final history = widget.history;

    final username = auth.user?.name ?? '';
    final email = auth.user?.email ?? '';
    final role = auth.user?.role ?? 'user';
    final id = auth.user?.id ?? '';

    return Scaffold(
      resizeToAvoidBottomInset: true,

      // APP BAR
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: AnimatedBuilder(
          animation: home,
          builder: (_, __) {
            if (home.busy) {
              return const Text(
                'Đang tải...',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              );
            }
            final BotModel? bot = home.bot;
            final String title = (bot == null || bot.name.trim().isEmpty)
                ? ''
                : bot.name;
            return Row(
              children: [
                if (bot?.image != null && bot!.image!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        bot.image!,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.smart_toy, color: Colors.black87),
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            );
          },
        ),
      ),

      // DRAWER
      drawer: SizedBox(
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () {
                                // TODO: điều hướng nạp tiền
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () async {
                                await auth.logout();
                                if (mounted) {
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
                      _MenuItem(
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: 'Chat',
                        active: true,
                        onTap: () => Navigator.pop(context),
                      ),
                      _MenuItem(
                        icon: const Icon(Icons.receipt_long),
                        label: 'Thanh toán và sử dụng',
                        onTap: () {
                          Navigator.pop(context);
                          // Navigator.pushNamed(context, '/usage');
                        },
                      ),
                      if (role == 'admin')
                        _MenuGroup(
                          icon: const Icon(Icons.shield_outlined),
                          label: 'Danh sách cho Admin',
                          labelColor: Colors.pink.shade400,
                          children: const [
                            _SubItem('Quản lý người dùng', onTap: null),
                            _SubItem('Cấu hình hệ thống', onTap: null),
                          ],
                        ),
                      // Danh sách trợ lý AI (dynamic)
                      _MenuGroup(
                        icon: const Icon(Icons.support_agent_outlined),
                        label: 'Danh sách trợ lý AI',
                        maxListHeight: 220,
                        scrollable: true,
                        children: [
                          FutureBuilder<List<BotModel>>(
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
                              if (bots.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 4,
                                  ),
                                  child: Text('Chưa có trợ lý nào'),
                                );
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: bots.map((bot) {
                                  final isActive = home.bot?.id == bot.id;
                                  final Widget leading =
                                      (bot.image != null &&
                                          bot.image!.isNotEmpty)
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Image.network(
                                            bot.image!,
                                            width: 22,
                                            height: 22,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.smart_toy_outlined,
                                                ),
                                          ),
                                        )
                                      : const Icon(Icons.smart_toy_outlined);

                                  return _MenuItem(
                                    icon: leading,
                                    label: bot.name,
                                    active: isActive,
                                    onTap: () async {
                                      await home.setBot(bot);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                      _MenuGroup(
                        icon: const Icon(Icons.history),
                        label: 'Danh sách lịch sử tin nhắn',
                        labelColor: Colors.deepPurple,
                        children: [
                          FutureBuilder<List<HistoryMessage>>(
                            future: history
                                .getHistoryFuture(), // <-- history: HistoryController
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

                              // Nghe selected thay đổi để highlight item đang active
                              return AnimatedBuilder(
                                animation: history,
                                builder: (_, __) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: list.map((item) {
                                      final isActive =
                                          history.selected?.id == item.id;
                                      return _MenuItem(
                                        label:
                                            item.name ??
                                            '', // tuỳ field của HistoryMessage
                                        active: isActive,
                                        onTap: () async {
                                          history.selectHistory(item);
                                          if (context.mounted) {
                                            Navigator.pop(
                                              context,
                                            ); // đóng drawer/menu
                                          }
                                        },
                                      );
                                    }).toList(),
                                  );
                                },
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
      ),

      // BODY
      body: AnimatedBuilder(
        animation: home,
        builder: (_, __) {
          if (home.busy) {
            return const Center(child: CircularProgressIndicator());
          }
          if (home.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(home.error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => home.loadDefaultBot(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final BotModel? bot = home.bot;

          return LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 24,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Center(
                            child: Container(
                              width: 128,
                              height: 128,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 18,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child:
                                  (bot != null &&
                                      bot.image != null &&
                                      bot.image!.isNotEmpty)
                                  ? Image.network(
                                      bot.image!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.smart_toy, size: 64),
                                    )
                                  : const ColoredBox(
                                      color: Color(0xFFEFF3F8),
                                      child: Icon(Icons.smart_toy, size: 64),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            (bot?.name ?? '').toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (bot?.description.isNotEmpty == true)
                                ? bot!.description
                                : "",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color?.withOpacity(.75),
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),

      // Thanh nhập chat — đẩy theo chiều cao bàn phím
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(.4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 4,
                      scrollPadding: const EdgeInsets.only(bottom: 120),
                      decoration: const InputDecoration(
                        hintText: 'please chat here...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  // Ảnh
                  IconButton(
                    tooltip: 'Ảnh',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: [
                          'png',
                          'jpg',
                          'jpeg',
                          'webp',
                          'gif',
                        ],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final file = result.files.first;
                        debugPrint(
                          'Ảnh được chọn: ${file.name} - ${file.path}',
                        );
                        // TODO: upload/gửi file này
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                  ),
                  // Tài liệu (PDF, TXT, DOCX)
                  IconButton(
                    tooltip: 'Tài liệu',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'txt', 'docx'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final file = result.files.first;
                        debugPrint(
                          'Document được chọn: ${file.name} - ${file.path}',
                        );
                        // TODO: upload/gửi file này
                      }
                    },
                    icon: const Icon(Icons.description_outlined),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      // TODO: gửi tin nhắn
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===== Widgets phụ cho Drawer =====

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
                child: icon ?? SizedBox.shrink(),
              ),
              const SizedBox(width: 10),
              Expanded(
                // <-- QUAN TRỌNG
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
    // Nếu scrollable, bọc phần children bằng SingleChildScrollView (KHÔNG có Scrollbar)
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

class _SubItem extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _SubItem(this.text, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(text),
      onTap: onTap,
    );
  }
}
