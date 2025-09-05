import 'package:flutter/material.dart';

class AdminProductsView extends StatelessWidget {
  const AdminProductsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[Admin] Quản lý sản phẩm bán ra')),
      body: const Center(child: Text('Nội dung Quản lý sản phẩm bán ra')),
    );
  }
}

