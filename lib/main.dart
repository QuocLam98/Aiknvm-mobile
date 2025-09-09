import 'package:flutter/material.dart';
import 'controllers/auth_controller.dart';
import 'services/auth_repository.dart';
import 'routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Không đọc .env runtime trên mobile
  await AuthRepository.init(); // đọc GOOGLE_WEB_CLIENT_ID từ --dart-define

  final repo = AuthRepository();
  final auth = AuthController(repo);

  runApp(MyApp(auth: auth));
}

class MyApp extends StatelessWidget {
  final AuthController auth;
  const MyApp({super.key, required this.auth});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (s) => onGenerateRoute(s, auth),
    );
  }
}
