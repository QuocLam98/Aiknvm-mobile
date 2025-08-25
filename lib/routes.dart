import 'package:flutter/material.dart';
import 'controllers/auth_controller.dart';
import 'views/splash_view.dart';
import 'views/login_view.dart';
import 'views/home_view.dart';


Route<dynamic> onGenerateRoute(RouteSettings settings, AuthController auth) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(builder: (_) => SplashView(auth: auth));
    case '/login':
      return MaterialPageRoute(builder: (_) => LoginView(auth: auth));
    case '/home':
      return MaterialPageRoute(builder: (_) => HomeView(auth: auth));
    default:
      return MaterialPageRoute(builder: (_) => SplashView(auth: auth));
  }
}