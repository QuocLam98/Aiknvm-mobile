import 'package:flutter/material.dart';
import 'package:aiknvm/services/auth_service.dart';
import 'package:aiknvm/views/chat_view.dart';

class LoginView extends StatefulWidget {
  static const route = '/login';
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _auth = AuthService();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final ok = await _auth.signInWithGoogleAndExchange();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChatView()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login canceled')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FlutterLogo(size: 56),
                    const SizedBox(height: 12),
                    Text('Welcome to AI Chat',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in with Google to continue.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _login,
                        icon: const Icon(Icons.login),
                        label: Text(_loading ? 'Signing in...' : 'Sign in with Google'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Base URL: ${_auth.baseUrl}'),
                        ),
                      ),
                      child: const Text('Server info'),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'By continuing you agree to our Terms & Privacy.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.outline,
                      ),
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
