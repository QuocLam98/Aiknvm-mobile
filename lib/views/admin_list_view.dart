import 'package:flutter/material.dart';

class AdminListView extends StatelessWidget {
  const AdminListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trang quản trị')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Card(
          //   child: ListTile(
          //     leading: const Icon(Icons.people_alt_outlined),
          //     title: const Text('Quản lý người dùng'),
          //     trailing: const Icon(Icons.chevron_right),
          //     onTap: () => Navigator.pushNamed(context, '/admin/users'),
          //   ),
          // ),
          // const SizedBox(height: 8),
          // Card(
          //   child: ListTile(
          //     leading: const Icon(Icons.tune_outlined),
          //     title: const Text('Cấu hình hệ thống'),
          //     trailing: const Icon(Icons.chevron_right),
          //     onTap: () => Navigator.pushNamed(context, '/admin/config'),
          //   ),
          // ),
          // const SizedBox(height: 8),
          // [Admin] Quản lý tài khoản
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('[Admin] Quản lý tài khoản'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/admin/accounts'),
            ),
          ),
          const SizedBox(height: 8),
          // [Admin] Quản lý bot AI
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('[Admin] Quản lý bot AI'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/admin/bots'),
            ),
          ),
          const SizedBox(height: 8),
          // [Admin] Quản lý tin nhắn
          Card(
            child: ListTile(
              leading: const Icon(Icons.list_alt_outlined),
              title: const Text('[Admin] Quản lý tin nhắn'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/admin/messages'),
            ),
          ),
          const SizedBox(height: 8),
          // [Admin] Quản lý thanh toán
          Card(
            child: ListTile(
              leading: const Icon(Icons.credit_card_outlined),
              title: const Text('[Admin] Quản lý thanh toán'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/admin/payments'),
            ),
          ),
          const SizedBox(height: 8),
          // [Admin] Quản lý sản phẩm bán ra
          Card(
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('[Admin] Quản lý sản phẩm bán ra'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/admin/products'),
            ),
          ),
        ],
      ),
    );
  }
}
