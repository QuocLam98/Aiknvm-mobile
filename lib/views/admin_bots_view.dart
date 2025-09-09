import 'package:flutter/material.dart';
import 'admin_table_scaffold.dart';

class AdminBotsView extends StatelessWidget {
  const AdminBotsView({super.key});

  @override
  Widget build(BuildContext context) {
    final columns = [
      'Tên bot',
      'Mô tả',
      'Trạng thái',
      'Ngày tạo',
    ];
    final data = List<List<String>>.generate(18, (i) => [
          'Bot #$i',
          'Mô tả bot $i',
          (i % 2 == 0) ? 'Kích hoạt' : 'Ẩn',
          '21/08/2025 10:5${i % 10}:52',
        ]);

    return Scaffold(
      appBar: AppBar(title: const Text('[Admin] Quản lý bot AI')),
      body: AdminTableScaffold(
        columns: columns,
        data: data,
        actionsBuilder: (row) => Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.edit_outlined),
            SizedBox(width: 8),
            Icon(Icons.delete_outline),
          ],
        ),
      ),
    );
  }
}
