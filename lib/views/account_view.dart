import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../services/auth_repository.dart';

class AccountView extends StatefulWidget {
  final AuthController auth;
  const AccountView({super.key, required this.auth});

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _avatarUrl;
  bool _loading = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _prefillFromAuth();
    _loadProfile();
  }

  void _prefillFromAuth() {
    _emailCtrl.text = widget.auth.user?.email ?? '';
    // Nếu sau khi tải profile có phone/avt sẽ cập nhật tiếp
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = AuthRepository();
      final uid = widget.auth.user?.id ?? '';
      final u = await repo.getProfileById(uid);
      if (!mounted) return;
      _emailCtrl.text = u.email;
      _phoneCtrl.text = u.phone ?? '';
      _avatarUrl = u.avatarUrl;
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = 'Vui lòng nhập số điện thoại');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = AuthRepository();
      final uid = widget.auth.user?.id ?? '';
      await repo.updatePhoneById(userId: uid, phone: phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu số điện thoại')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản của bạn'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFFEFF3F8),
                    backgroundImage: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: (_avatarUrl == null || _avatarUrl!.isEmpty)
                        ? Icon(Icons.person, size: 44, color: Colors.grey.shade600)
                        : null,
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Email của bạn'),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailCtrl,
                  enabled: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Số điện thoại'),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Lưu lại'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
