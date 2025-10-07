import 'dart:async';
import 'package:flutter/material.dart';
import 'admin_table_scaffold.dart';
import '../services/admin_repository.dart';
import '../models/admin_user.dart';

class AdminAccountsView extends StatefulWidget {
  const AdminAccountsView({super.key});

  @override
  State<AdminAccountsView> createState() => _AdminAccountsViewState();
}

class _AdminAccountsViewState extends State<AdminAccountsView> {
  final _repo = AdminRepository();
  final _columns = const [
    'Tên',
    'Email',
    'Số điện thoại',
    'Loại tài khoản',
    'Trạng thái',
    'Ngày tạo',
  ];

  List<AdminUser> _items = const [];
  bool _loading = true;
  String? _error;
  int _page = 1;
  int _limit = 10;
  int _total = 0;
  String _keyword = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _repo.listUsers(
        page: _page,
        limit: _limit,
        keyword: _keyword,
      );
      setState(() {
        _items = res.items;
        _total = res.total;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _onEdit(int rowIndex) async {
    if (rowIndex < 0 || rowIndex >= _items.length) return;
    final user = _items[rowIndex];
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _EditUserDialog(user: user),
    );
    if (result == null) return;

    double _parseD(String? s, double fallback) =>
        s != null && s.trim().isNotEmpty
        ? (double.tryParse(s.trim()) ?? fallback)
        : fallback;

    final name = result['name']?.trim().isNotEmpty == true
        ? result['name']!.trim()
        : user.name;
    final email = result['email']?.trim().isNotEmpty == true
        ? result['email']!.trim()
        : user.email;
    final role = result['role']?.trim().isNotEmpty == true
        ? result['role']!.trim()
        : user.role;
    final credit = _parseD(result['credits'], user.credit);

    try {
      setState(() => _loading = true);
      final updatedFromServer = await _repo.updateUser(
        id: user.id,
        name: name,
        email: email,
        credit: credit,
        role: role,
      );
      setState(() {
        _items[rowIndex] = updatedFromServer;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cập nhật thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<List<String>> get _tableData => _items
      .map(
        (u) => [
          u.name,
          u.email,
          u.phone,
          u.role,
          (u.active ?? false) ? '1' : '0',
          u.createdAt,
        ],
      )
      .toList();

  void _toggleActive(int rowIndex, bool v) {
    if (rowIndex < 0 || rowIndex >= _items.length) return;
    final user = _items[rowIndex];
    setState(
      () => _items[rowIndex] = AdminUser(
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        verified: user.verified,
        createdAt: user.createdAt,
        credit: user.credit,
        creditUsed: user.creditUsed,
        active: v,
      ),
    );
    () async {
      try {
        await _repo.updateUserActive(id: user.id, active: v);
        if (!mounted) return;
        final msg = v ? 'Đã kích hoạt user' : 'Đã vô hiệu hóa user';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      msg,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
      } catch (e) {
        if (!mounted) return;
        setState(() => _items[rowIndex] = user);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cập nhật active thất bại: $e')));
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[Admin] Quản lý tài khoản')),
      body: Column(
        children: [
          // thanh tìm kiếm + page size
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên hoặc email...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      suffixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        _keyword = v.trim();
                        _page = 1;
                        _load();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _limit,
                  items: const [10, 20, 50]
                      .map(
                        (v) => DropdownMenuItem<int>(
                          value: v,
                          child: Text(v.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    _limit = v;
                    _page = 1;
                    _load();
                  },
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: AdminTableScaffold(
              columns: _columns,
              data: _tableData,
              showSearch: false,
              showPagination: false,
              cellMaxWidth: 160,
              centerColumns: const {4},
              cellBuilder: (rowIndex, colIndex, value) {
                // Active switch column
                if (colIndex == 4) {
                  final isActive = (rowIndex >= 0 && rowIndex < _items.length)
                      ? (_items[rowIndex].active ?? false)
                      : false;
                  return Switch.adaptive(
                    value: isActive,
                    onChanged: (v) => _toggleActive(rowIndex, v),
                  );
                }
                return null;
              },
              actionsBuilder: (row) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Sửa',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _onEdit(row),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Xoá vĩnh viễn',
                    icon: const Icon(Icons.delete_forever_outlined),
                    onPressed: () async {
                      final user = _items[row];
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Xoá tài khoản'),
                          content: Text(
                            'Bạn có chắc muốn xoá vĩnh viễn "${user.name}"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Huỷ'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Xoá'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      try {
                        setState(() => _loading = true);
                        await _repo.hardDeleteUser(user.id);
                        setState(() {
                          _items.removeAt(row);
                          _total = (_total - 1).clamp(0, 1 << 31);
                        });
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã xoá tài khoản')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Xoá thất bại: $e')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          _remotePagination(),
        ],
      ),
    );
  }

  Widget _remotePagination() {
    final totalPages = (_total / _limit).ceil().clamp(1, 9999);
    _page = _page.clamp(1, totalPages);
    List<Widget> buttons = [];
    buttons.add(
      ElevatedButton(
        onPressed: _page > 1
            ? () {
                setState(() {
                  _page--;
                });
                _load();
              }
            : null,
        child: const Text('Prev'),
      ),
    );

    final maxPagesToShow = 7;
    List<int> pages;
    if (totalPages <= maxPagesToShow) {
      pages = List.generate(totalPages, (i) => i + 1);
    } else {
      pages = <int>{
        1,
        totalPages,
        _page,
        _page - 1,
        _page + 1,
        2,
        totalPages - 1,
      }.where((p) => p >= 1 && p <= totalPages).toList()..sort();
    }
    int? last;
    for (final p in pages) {
      if (last != null && p - last > 1) {
        buttons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...'),
          ),
        );
      }
      final isActive = p == _page;
      buttons.add(
        isActive
            ? FilledButton(onPressed: () {}, child: Text(p.toString()))
            : OutlinedButton(
                onPressed: () {
                  setState(() {
                    _page = p;
                  });
                  _load();
                },
                child: Text(p.toString()),
              ),
      );
      last = p;
    }

    buttons.add(
      ElevatedButton(
        onPressed: _page < totalPages
            ? () {
                setState(() {
                  _page++;
                });
                _load();
              }
            : null,
        child: const Text('Next'),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Trang '
            '$_page'
            '/$totalPages',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          ...buttons,
        ],
      ),
    );
  }
}

// ====== Edit Dialog ======
class _EditUserDialog extends StatefulWidget {
  final AdminUser user;
  const _EditUserDialog({required this.user});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _roleCtrl;
  late final TextEditingController _creditsCtrl; // optional
  late final TextEditingController _creditsUsedCtrl; // optional

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.name);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _roleCtrl = TextEditingController(text: widget.user.role);
    _creditsCtrl = TextEditingController(text: _fmt(widget.user.credit));
    _creditsUsedCtrl = TextEditingController(
      text: _fmt(widget.user.creditUsed),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _roleCtrl.dispose();
    _creditsCtrl.dispose();
    _creditsUsedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _field('Tên', _nameCtrl)),
                  const SizedBox(width: 16),
                  Expanded(child: _field('Email', _emailCtrl)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _field('Số credits', _creditsCtrl, number: true),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _field(
                      'Số credit đã sử dụng',
                      _creditsUsedCtrl,
                      number: true,
                      enabled: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _field('Role', _roleCtrl))]),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Huỷ'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      // Return edited values; credits fields are currently informational
                      Navigator.pop(context, {
                        'name': _nameCtrl.text.trim(),
                        'email': _emailCtrl.text.trim(),
                        'role': _roleCtrl.text.trim(),
                        'credits': _creditsCtrl.text.trim(),
                        'creditsUsed': _creditsUsedCtrl.text.trim(),
                      });
                    },
                    child: const Text('Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    bool number = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        TextField(
          controller: ctrl,
          enabled: enabled,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(double v) {
    // up to 6 decimals, trim trailing zeros
    String s = v.toStringAsFixed(6);
    if (!s.contains('.')) return s;
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }
}
