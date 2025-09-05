import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../services/bot_repository.dart';


class SplashView extends StatefulWidget {
  final AuthController auth;
  const SplashView({super.key, required this.auth});


  @override
  State<SplashView> createState() => _SplashViewState();
}


class _SplashViewState extends State<SplashView> {
  @override
  void initState() {
    super.initState();
    _boot();
  }


  Future<void> _boot() async {
    await widget.auth.restore();
    if (!mounted) return;
    if (widget.auth.isLoggedIn) {
      // Prefetch danh sách trợ lý và cache ảnh trước khi vào app
      try {
        final repo = BotRepository();
        final bots = await repo.getAllBots();
        final futures = <Future<void>>[];
        for (final b in bots) {
          final url = b.image;
          if (url != null && url.isNotEmpty) {
            futures.add(precacheImage(NetworkImage(url), context).catchError((_) {}));
          }
        }
        if (futures.isNotEmpty) {
          await Future.wait(futures);
        }
      } catch (_) {
        // Bỏ qua lỗi prefetch để không chặn vào app
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/chat');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }


  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
