import 'package:flutter/foundation.dart';

class AppEvents extends ChangeNotifier {
  AppEvents._();
  static final AppEvents instance = AppEvents._();

  void notifyBotsChanged() {
    notifyListeners();
  }
}
