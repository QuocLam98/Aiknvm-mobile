import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'controllers/auth_controller.dart';
import 'services/auth_repository.dart';
import 'routes.dart';
import 'navigation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tải biến môi trường:
  // - Web: đọc file '/.env' từ thư mục public (web/.env) nếu có
  // - Mobile/Desktop: chỉ dùng --dart-define/--dart-define-from-file (không bundle .env)

  // 1) Lấy giá trị từ --dart-define (ưu tiên cao nhất)
  final fromDefines = <String, String>{
    'API_BASE_URL': const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    ),
    'GOOGLE_CLIENT_ID': const String.fromEnvironment(
      'GOOGLE_CLIENT_ID',
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
  };

  // 2) Nếu chạy Web, thử fetch '/.env' (không cần liệt kê vào assets)
  final fromPublic = <String, String>{};
  if (kIsWeb) {
    try {
      final resp = await http.get(Uri.parse('/.env'));
      if (resp.statusCode == 200 && resp.body.isNotEmpty) {
        for (final line in resp.body.split('\n')) {
          final raw = line.trim();
          if (raw.isEmpty || raw.startsWith('#')) continue;
          final eq = raw.indexOf('=');
          if (eq <= 0) continue;
          final key = raw.substring(0, eq).trim();
          var value = raw.substring(eq + 1).trim();
          if ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'"))) {
            value = value.substring(1, value.length - 1);
          }
          fromPublic[key] = value;
        }
      }
    } catch (_) {
      // Bỏ qua nếu không có file .env public
    }
  }

  // 3) Merge: file public (web) < dart-define (ưu tiên override)
  final merged = <String, String>{...fromPublic, ...fromDefines};

  // Không bundle .env vào assets; chỉ nạp map đã merge.
  await dotenv.load(isOptional: true, mergeWith: merged);

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
      navigatorObservers: [routeObserver],
      onUnknownRoute: (_) => MaterialPageRoute(
        builder: (_) =>
            const Scaffold(body: Center(child: Text('Route not found'))),
      ),
    );
  }
}
