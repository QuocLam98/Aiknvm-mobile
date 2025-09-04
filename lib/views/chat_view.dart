import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/history_controller.dart';
import '../models/bot_model.dart';
import '../widgets/app_drawer.dart';
import '../widgets/drawer_key.dart';

class ChatView extends StatefulWidget {
  final AuthController auth;
  final HomeController home;
  final HistoryController history;
  final String botId;

  const ChatView({
    super.key,
    required this.auth,
    required this.home,
    required this.history,
    required this.botId,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _inputCtrl = TextEditingController();
  late Future<BotModel> _botFuture; // fetch 1 lần

  @override
  void initState() {
    super.initState();
    _botFuture = _load(); // load bot + setBot để đồng bộ highlight
  }

  Future<BotModel> _load() async {
    // Bạn đang dùng home.loadBotById; giữ nguyên cho khớp code hiện tại.
    final bot = await widget.home.loadBotById(widget.botId);
    await widget.home.setBot(bot); // đảm bảo Drawer highlight đúng bot
    return bot;
  }

  void _handleDrawerSelect(DrawerKey key) {
    switch (key.kind) {
      case DrawerKind.chat:
        // quay về màn Home/Chat nếu muốn
        Navigator.pushReplacementNamed(context, '/home');
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
        // Nếu chọn cùng bot hiện tại thì không cần push thêm
        if (key.id == widget.botId) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatView(
              auth: widget.auth,
              home: widget.home,
              history: widget.history,
              botId: key.id!,
            ),
          ),
        );
        break;
      case DrawerKind.history:
        Navigator.pushNamed(context, '/history', arguments: key.id);
        break;
    }
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

    return Scaffold(
      resizeToAvoidBottomInset: true,

      // APP BAR
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: FutureBuilder<BotModel>(
          future: _botFuture, // dùng 1 future cho cả appbar & body
          builder: (_, snapshot) {
            if (!snapshot.hasData) {
              return const Text(
                'Đang tải...',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              );
            }
            final bot = snapshot.data!;
            return Row(
              children: [
                if (bot.image != null && bot.image!.isNotEmpty)
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
                  bot.name,
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

      // DRAWER: truyền current để highlight đúng bot
      drawer: AppDrawer(
        auth: auth,
        home: home,
        history: history,
        current: DrawerKey(DrawerKind.bot, id: widget.botId),
        onSelect: _handleDrawerSelect,
      ),

      // BODY
      body: FutureBuilder<BotModel>(
        future: _botFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lỗi: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => setState(() => _botFuture = _load()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final bot = snapshot.data!;
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
                                  (bot.image != null && bot.image!.isNotEmpty)
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
                            bot.name.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (bot.description.isNotEmpty == true)
                                ? bot.description
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

      // BOTTOM INPUT
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
                        allowedExtensions: [
                          'png',
                          'jpg',
                          'jpeg',
                          'webp',
                          'gif',
                        ],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final f = result.files.first;
                        debugPrint('Ảnh được chọn: ${f.name} - ${f.path}');
                        // TODO: upload/gửi file
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                  ),
                  IconButton(
                    tooltip: 'Tài liệu',
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'txt', 'docx'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final f = result.files.first;
                        debugPrint('Doc được chọn: ${f.name} - ${f.path}');
                        // TODO: upload/gửi file
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
