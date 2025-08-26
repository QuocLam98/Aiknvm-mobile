import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../controllers/home_controller.dart';
import '../models/bot_model.dart';

class HomeView extends StatefulWidget {
  final AuthController auth;
  final HomeController home; // <-- thêm controller bot

  const HomeView({super.key, required this.auth, required this.home});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  String _short(String s) => s.length <= 24 ? s : '${s.substring(0, 12)}…${s.substring(s.length - 12)}';

  @override
  void initState() {
    super.initState();
    // gọi API lấy bot mặc định ngay khi vào màn
    widget.home.loadDefaultBot(bearerToken: widget.auth.session?.jwt);
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final home = widget.home;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          IconButton(
            tooltip: 'Tải lại bot',
            onPressed: () => home.refresh(bearerToken: auth.session?.jwt),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
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
                    onPressed: () => home.loadDefaultBot(bearerToken: auth.session?.jwt),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }

          final BotModel? bot = home.bot;
          final jwtShort = _short(auth.session?.jwt ?? 'null');

          if (bot == null) {
            return const Center(child: Text('Không có dữ liệu bot'));
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                elevation: 0,
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar bot (nếu có)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: bot.image != null && bot.image!.isNotEmpty
                            ? Image.network(bot.image!, width: 72, height: 72, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy, size: 48))
                            : const Icon(Icons.smart_toy, size: 48),
                      ),
                      const SizedBox(width: 16),
                      // Thông tin bot
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bot.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(
                              bot.description.isEmpty ? 'Không có mô tả' : bot.description,
                              style: const TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(label: Text('Trạng thái: ${bot.status}')),
                                Chip(label: Text('ID: ${_short(bot.id)}')),
                              ],
                            ),
                            const Divider(height: 24),
                            Text('JWT rút gọn: $jwtShort', style: const TextStyle(fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
