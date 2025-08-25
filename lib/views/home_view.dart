import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';


class HomeView extends StatelessWidget {
  final AuthController auth;
  const HomeView({super.key, required this.auth});


  String _short(String s) => s.length <= 24 ? s : '${s.substring(0, 12)}…${s.substring(s.length - 12)}';


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        actions: [
          IconButton(
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
      body: Center(
        child: AnimatedBuilder(
          animation: auth,
          builder: (_, __) {
            final jwt = auth.session?.jwt ?? 'null';
            return Text('JWT rút gọn: ' + _short(jwt));
          },
        ),
      ),
    );
  }
}