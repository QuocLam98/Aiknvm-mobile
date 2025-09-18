import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../navigation.dart';

import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/history_controller.dart';
import '../models/bot_model.dart';
import '../widgets/app_drawer.dart';
import '../models/chat_message_model.dart';
import '../widgets/drawer_key.dart';
import '../services/chat_repository.dart';

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

class _HomeViewState extends State<HomeView> with RouteAware {
  // Messages rendered inline on Home
  final _messages = <ChatMessageModel>[];
  final _listCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  String? _historyId; // Session-scoped on Home
  bool _sending = false;

  void _handleDrawerSelect(DrawerKey key) {
    switch (key.kind) {
      case DrawerKind.chat:
        // Already on Home; could reset chat if desired
        break;
      case DrawerKind.usage:
        Navigator.pushNamed(context, '/usage');
        break;
      case DrawerKind.adminUsers:
        Navigator.pushNamed(context, '/admin/users');
        break;
      case DrawerKind.adminConfig:
        Navigator.pushNamed(context, '/admin/config');
        break;
      case DrawerKind.bot:
        if (key.id == null) return;
        final id = key.id!;
        () async {
          if (widget.home.bot?.id != id) {
            try {
              await widget.home.loadBotById(id);
            } catch (_) {}
          }
          if (!mounted) return;
          setState(() {
            _messages.clear();
            _historyId = null;
          });
        }();
        break;
      case DrawerKind.history:
        Navigator.pushReplacementNamed(context, '/history', arguments: key.id!);
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.home.loadDefaultBot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _listCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  // Called when a covered route is popped and this route shows again
  @override
  void didPopNext() {
    // Reset chat state so Home is fresh when revisited
    setState(() {
      _messages.clear();
      _historyId = null;
      _inputCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final home = widget.home;
    final history = widget.history; // for Drawer

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
      drawer: AppDrawer(
        auth: auth,
        home: home,
        history: history,
        current: const DrawerKey(DrawerKind.chat),
        onSelect: (key) => _handleDrawerSelect(key),
      ),
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
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Column(
              children: [
                const SizedBox(height: 8),
                if (_messages.isEmpty) ...[
                  Row(
                    children: [
                      if (bot != null &&
                          bot.image != null &&
                          bot.image!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              bot.image!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.smart_toy),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bot?.name ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (bot?.description.isNotEmpty == true)
                                  ? bot!.description
                                  : '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color?.withOpacity(.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: ListView.builder(
                    controller: _listCtrl,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final isUser = m.role == 'user';
                      return _bubble(m, isUser: isUser);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
                  IconButton(
                    tooltip: 'Ảnh',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowMultiple: false,
                        allowedExtensions: const [
                          'jpg',
                          'jpeg',
                          'png',
                          'webp',
                          'gif',
                        ],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final file = result.files.first;
                        debugPrint(
                          'Ảnh được chọn: ${file.name} - ${file.path}',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã chọn ảnh (chưa gửi).'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                  ),
                  IconButton(
                    tooltip: 'Tài liệu',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowMultiple: false,
                        allowedExtensions: const ['pdf', 'doc', 'docx', 'txt'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final file = result.files.first;
                        debugPrint(
                          'Tài liệu được chọn: ${file.name} - ${file.path}',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Đã chọn tài liệu (chưa gửi).'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.description_outlined),
                  ),
                  FilledButton(
                    onPressed: _sending
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                            final text = _inputCtrl.text.trim();
                            if (text.isEmpty) return;
                            final userId = widget.auth.user?.id;
                            final botId = widget.home.bot?.id;
                            if (userId == null ||
                                userId.isEmpty ||
                                botId == null ||
                                botId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Thiếu user hoặc bot để chat'),
                                ),
                              );
                              return;
                            }

                            setState(() => _sending = true);
                            setState(() {
                              _messages.add(
                                ChatMessageModel(
                                  id: 'local_${DateTime.now().millisecondsSinceEpoch}_u',
                                  text: text,
                                  role: 'user',
                                  createdAt: DateTime.now(),
                                ),
                              );
                            });

                            try {
                              final bool creatingNewHistory =
                                  (_historyId == null || _historyId!.isEmpty);
                              final repo = ChatRepository.fromEnv();
                              final res = await repo.createMessageMobile(
                                userId: userId,
                                botId: botId,
                                content: text,
                                historyChat: _historyId,
                              );

                              if (!mounted) return;
                              setState(() {
                                _historyId ??= res.history;
                                _messages.add(
                                  ChatMessageModel(
                                    id: '${res.id}_b',
                                    text: res.contentBot,
                                    role: 'bot',
                                    createdAt: res.createdAt,
                                  ),
                                );
                                _inputCtrl.clear();
                              });

                              if (creatingNewHistory &&
                                  _historyId != null &&
                                  _historyId!.isNotEmpty) {
                                try {
                                  await widget.history.refreshHistory();
                                } catch (_) {}
                              }

                              await Future.delayed(
                                const Duration(milliseconds: 50),
                              );
                              if (_listCtrl.hasClients) {
                                _listCtrl.animateTo(
                                  _listCtrl.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                );
                              }
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Gửi thất bại: $e')),
                              );
                            } finally {
                              if (mounted) {
                                setState(() => _sending = false);
                              }
                            }
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

  // Simple bubble used in HomeView inline chat
  Widget _bubble(ChatMessageModel m, {required bool isUser}) {
    final bg = isUser ? Colors.black : const Color(0xFFEFF3F8);
    final fg = isUser ? Colors.white : Colors.black87;
    final align = isUser ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: align,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(m.text, style: TextStyle(color: fg, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
