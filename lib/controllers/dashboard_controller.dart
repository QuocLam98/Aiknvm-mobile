import 'package:flutter/material.dart';
import '../views/settings/settings_view.dart';


/// Controller chịu trách nhiệm quản lý state + hành vi cho dashboard
class DashboardController {
  final currentIndex = ValueNotifier<int>(0);


  void setIndex(int i) => currentIndex.value = i;


  void onFabPressed(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Do something!')),
    );
  }


  void openSettings(BuildContext context) {
    Navigator.pushNamed(context, SettingsView.route);
  }


  void dispose() {
    currentIndex.dispose();
  }
}