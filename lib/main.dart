import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'controllers/auth_controller.dart';
import 'services/auth_repository.dart';
import 'routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Không đọc file .env, chỉ merge giá trị từ --dart-define
  await dotenv.load(
    isOptional: true,
    mergeWith: {
      'API_BASE_URL': const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: '',
      ),
      'GOOGLE_WEB_CLIENT_ID': const String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
        defaultValue: '',
      ),
      'DEFAULT_BOT': const String.fromEnvironment(
        'DEFAULT_BOT',
        defaultValue: '',
      ),
      'CREATE_IMAGE': const String.fromEnvironment(
        'CREATE_IMAGE',
        defaultValue: '',
      ),
      'CREATE_IMAGE_PREMIUM': const String.fromEnvironment(
        'CREATE_IMAGE_PREMIUM',
        defaultValue: '',
      ),
    },
  );

  await AuthRepository.init();
  await AuthRepository.clearSession();

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
      initialRoute: '/',
      onGenerateRoute: (settings) => onGenerateRoute(settings, auth),
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) =>
            const Scaffold(body: Center(child: Text('Route not found'))),
      ),
    );
  }
}
