import 'package:flutter/material.dart';
import 'admin_table_scaffold.dart';

class AdminMessagesView extends StatelessWidget {
  const AdminMessagesView({super.key});

  @override
  Widget build(BuildContext context) {
    final columns = [
      'Người dùng',
      'Bot',
      'Tin nhắn cuối',
      'Ngày tạo',
    ];
    final data = List<List<String>>.generate(32, (i) => [
          'user$i@example.com',
          'Bot #${i % 5}',
          'Tin nhắn cuối số $i',
          '12/06/2025 12:5${i % 10}:03',
        ]);

    return Scaffold(
      appBar: AppBar(title: const Text('[Admin] Quản lý tin nhắn')),
      body: AdminTableScaffold(
        columns: columns,
        data: data,
        actionsBuilder: (row) => Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.open_in_new),
            SizedBox(width: 8),
            Icon(Icons.delete_outline),
          ],
        ),
      ),
    );
  }
}
