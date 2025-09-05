import 'package:flutter/material.dart';
import 'admin_table_scaffold.dart';

class AdminPaymentsView extends StatelessWidget {
  const AdminPaymentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final columns = [
      'Mã giao dịch',
      'Khách hàng',
      'Số tiền',
      'Trạng thái',
      'Ngày tạo',
    ];
    final data = List<List<String>>.generate(22, (i) => [
          'TX-${1000 + i}',
          'user$i@example.com',
          '${(i + 1) * 10000}đ',
          (i % 3 == 0) ? 'Thành công' : 'Đang xử lý',
          '10/06/2025 12:3${i % 10}:39',
        ]);

    return Scaffold(
      appBar: AppBar(title: const Text('[Admin] Quản lý thanh toán')),
      body: AdminTableScaffold(
        columns: columns,
        data: data,
        actionsBuilder: (row) => Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.receipt_long_outlined),
          ],
        ),
      ),
    );
  }
}
