import 'package:flutter/material.dart';
import 'controllers/auth_controller.dart';
import 'services/auth_repository.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthRepository.init();
  final auth = AuthController(AuthRepository());
  runApp(MyApp(auth: auth));
}

class MyApp extends StatelessWidget {
  final AuthController auth;
  const MyApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App',
      theme: ThemeData(useMaterial3: true),
      initialRoute: '/',                                       // Splash -> /login|/home
      onGenerateRoute: (settings) => onGenerateRoute(settings, auth),
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(child: Text('Route not found')),
        ),
      ),
    );
  }
}
