import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginView extends StatefulWidget {
  final AuthController auth;
  const LoginView({super.key, required this.auth});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;

    return Scaffold(
      backgroundColor: Colors.greenAccent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedBuilder(
                animation: auth,
                builder: (_, __) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.network(
                        'https://aiknvm.hn.ss.bfcplatform.vn/aiknvm/Asset/logo.png',
                        width: 64,
                        height: 64,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aiknvm',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ai kỷ nguyên vươn mình',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: auth.busy
                              ? null
                              : () async {
                                  final ok = await auth.loginWithGoogle();
                                  if (!mounted) return;
                                  if (ok) {
                                    Navigator.of(
                                      context,
                                    ).pushReplacementNamed('/home');
                                  }
                                },
                          icon: SvgPicture.asset(
                            'assets/images/google.svg', // <-- dùng SVG asset
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                          label: Text(
                            auth.busy ? 'Đang xử lý…' : 'Đăng nhập với Google',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            side: const BorderSide(color: Color(0xFFE0E0E0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          auth.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
