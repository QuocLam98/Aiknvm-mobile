import 'package:flutter/material.dart';
import 'package:aiknvm/models/feature.dart';


class FeatureCard extends StatelessWidget {
  final Feature feature;
  final VoidCallback? onTap;
  const FeatureCard({super.key, required this.feature, this.onTap});


  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap ?? () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tapped ${feature.label}')),
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(feature.icon, size: 36),
              const SizedBox(height: 8),
              Text(feature.label),
            ],
          ),
        ),
      ),
    );
  }
}