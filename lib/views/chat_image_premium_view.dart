import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/history_controller.dart';
import '../models/bot_model.dart';
import '../widgets/app_drawer.dart';
import '../widgets/drawer_key.dart';

class ChatImagePremiumView extends StatefulWidget {
  final AuthController auth;
  final HomeController home;
  final HistoryController history;
  final String? botId;

  const ChatImagePremiumView({
    super.key,
    required this.auth,
    required this.home,
    required this.history,
    this.botId,
  });

  @override
  State<ChatImagePremiumView> createState() => _ChatImagePremiumViewState();
}

class _ChatImagePremiumViewState extends State<ChatImagePremiumView> {
  final _inputCtrl = TextEditingController();
  late Future<BotModel> _botFuture;

  @override
  void initState() {
    super.initState();
    _botFuture = _loadBot();
  }

  Future<BotModel> _loadBot() async {
    if (widget.botId != null && widget.botId!.isNotEmpty) {
      final bot = await widget.home.loadBotById(widget.botId!);
      await widget.home.setBot(bot);
      return bot;
    }
    await widget.home.loadDefaultBot();
    final bot = widget.home.bot;
    if (bot == null) throw Exception('Không lấy được bot mặc định');
    await widget.home.setBot(bot);
    return bot;
  }

  void _handleDrawerSelect(DrawerKey key) {
    switch (key.kind) {
      case DrawerKind.chat:
        Navigator.pushReplacementNamed(context, '/chat');
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
        if (key.id == widget.botId) return;
        Navigator.pushReplacementNamed(
          context,
          '/chat_image/premium',
          arguments: key.id!,
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: .5,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: FutureBuilder<BotModel>(
          future: _botFuture,
          builder: (_, s) {
            if (!s.hasData)
              return const Text(
                'Đang tải...',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              );
            final bot = s.data!;
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
                Expanded(
                  child: Text(
                    bot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
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
        current: (widget.botId != null && widget.botId!.isNotEmpty)
            ? DrawerKey(DrawerKind.bot, id: widget.botId)
            : const DrawerKey(DrawerKind.chat),
        onSelect: _handleDrawerSelect,
      ),
      body: FutureBuilder<BotModel>(
        future: _botFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          final bot = snapshot.data!;
          final desc = bot.description.isNotEmpty ? bot.description : '';
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
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
                    child: (bot.image != null && bot.image!.isNotEmpty)
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
                  const SizedBox(height: 16),
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
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
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
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
                      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
                    );
                    if (result != null && result.files.isNotEmpty) {
                      final f = result.files.first;
                      debugPrint('Ảnh được chọn: ${f.name} - ${f.path}');
                      // TODO: upload/gửi file ảnh
                    }
                  },
                  icon: const Icon(Icons.image_outlined),
                ),
                FilledButton(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    // TODO: gửi tin nhắn text; bot phản hồi bằng ảnh
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
    );
  }
}
