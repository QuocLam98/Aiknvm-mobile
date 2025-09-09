import 'package:flutter/material.dart';
import 'services/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // KHÔNG gọi dotenv.load() nữa
  await AuthRepository.init(); // sẽ đọc biến bằng String.fromEnvironment

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('Hello'))),
    );
  }
}
