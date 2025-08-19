import 'package:flutter/material.dart';
import '../../settings/settings_view.dart';


class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});


  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const ListTile(
              leading: CircleAvatar(child: Icon(Icons.flutter_dash)),
              title: Text('My Starter UI'),
              subtitle: Text('hello@your.app'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('dashboard'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('settings'),
              onTap: () => Navigator.pushNamed(context, SettingsView.route),
            ),
            const AboutListTile(
              icon: Icon(Icons.info_outline),
              applicationName: 'My Starter UI',
              applicationVersion: '1.0.0',
            ),
          ],
        ),
      ),
    );
  }
}