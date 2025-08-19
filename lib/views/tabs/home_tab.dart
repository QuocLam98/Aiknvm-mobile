import 'package:flutter/material.dart';
import '../../models/feature.dart';
import '../dashboard/widgets/feature_card.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});


  @override
  Widget build(BuildContext context) {
    const items = [
      Feature(icon: Icons.qr_code_scanner, label: 'Scan'),
      Feature(icon: Icons.map, label: 'Map'),
      Feature(icon: Icons.chat_bubble, label: 'Chat'),
      Feature(icon: Icons.analytics, label: 'Reports'),
      Feature(icon: Icons.settings, label: 'settings'),
      Feature(icon: Icons.help_outline, label: 'Help'),
    ];


    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: items.map((e) => FeatureCard(feature: e)).toList(),
      ),
    );
  }
}