import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../controllers/history_controller.dart';
import '../models/bot_model.dart';
import '../models/history_message.dart'; // nếu body cần
import '../widgets/app_drawer.dart'; // <-- quan trọng: import Drawer tái sử dụng
import '../widgets/drawer_key.dart';
import '../views/chat_view.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  void _handleDrawerSelect(DrawerKey key) {
    switch (key.kind) {
      case DrawerKind.chat:
        // đang ở Home -> có thể pop về Home hoặc làm gì tùy bạn
        // Navigator.pushReplacementNamed(context, '/home');
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
        final imgId = dotenv.env['CREATE_IMAGE']?.trim();
        final imgPremiumId = dotenv.env['CREATE_IMAGE_PREMIUM']?.trim();
        // Ưu tiên bot CREATE_IMAGE trước
        if (imgId != null && imgId.isNotEmpty && id == imgId) {
          Navigator.pushNamed(context, '/chat_image', arguments: id);
        } else if (imgPremiumId != null && imgPremiumId.isNotEmpty && id == imgPremiumId) {
          Navigator.pushNamed(context, '/chat_image/premium', arguments: id);
        } else {
          Navigator.pushNamed(context, '/chat', arguments: id);
        }
        break;

      case DrawerKind.history:
        // tùy bạn có màn riêng không
        Navigator.pushReplacementNamed(context, '/history', arguments: key.id!);
        break;
    }
  }

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

      // DRAWER: dùng widget tái sử dụng
      drawer: AppDrawer(
        auth: auth,
        home: home,
        history: history,
        current: const DrawerKey(DrawerKind.chat),
        onSelect: (key) => _handleDrawerSelect(key), // <-- bỏ context
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
                  // Tài liệu
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
