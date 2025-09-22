import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../services/user_repository.dart';

class UsageView extends StatefulWidget {
  final AuthController auth;
  const UsageView({super.key, required this.auth});

  @override
  State<UsageView> createState() => _UsageViewState();
}

class _UsageViewState extends State<UsageView> {
  late Future<UserUsageResult> _future;
  final _repo = UserRepository();

  @override
  void initState() {
    super.initState();
    final email = widget.auth.user?.email ?? '';
    _future = _repo.getUsageByEmail(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F6),
      appBar: AppBar(
        title: const Text('Thống kê sử dụng'),
        backgroundColor: Colors.white,
        elevation: .5,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: FutureBuilder<UserUsageResult>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (snap.hasError) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lỗi: ${snap.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => setState(() {
                          final email = widget.auth.user?.email ?? '';
                          _future = _repo.getUsageByEmail(email);
                        }),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  );
                }
                final data = snap.data!;
                final total = data.credit == 0 ? 1.0 : data.credit;
                final used = data.creditUsed.clamp(0, total);
                final percent = (used / total).clamp(0.0, 1.0);
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thống kê sử dụng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tổng quan số tiền sử dụng',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            minHeight: 10,
                            value: percent,
                            backgroundColor: const Color(0xFFE6E7F6),
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF5358FF),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${data.creditUsed} / ${data.credit} Credit',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
