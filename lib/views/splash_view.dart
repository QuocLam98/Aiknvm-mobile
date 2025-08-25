import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';


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
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }


  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}