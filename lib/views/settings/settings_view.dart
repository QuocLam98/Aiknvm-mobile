
import 'package:flutter/material.dart';


class SettingsView extends StatelessWidget {
  static const route = '/settings';
  const SettingsView({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('settings')),
      body: ListView(
        children: const [
          ListTile(leading: Icon(Icons.color_lens), title: Text('Theme')),
          ListTile(leading: Icon(Icons.notifications), title: Text('Notifications')),
        ],
      ),
    );
  }
}