import 'dart:async';
import 'package:flutter/material.dart';
import 'admin_table_scaffold.dart';
import '../services/admin_repository.dart';
import '../models/admin_message.dart';

class AdminMessagesView extends StatefulWidget {
  const AdminMessagesView({super.key});

  @override
  State<AdminMessagesView> createState() => _AdminMessagesViewState();
}

class _AdminMessagesViewState extends State<AdminMessagesView> {
  final _repo = AdminRepository();
  final _columns = const [
    'Người dùng',
    'Bot',
    'Mô hình',
    'User nói',
    'Bot trả lời',
    'Credit dùng',
    'Ngày tạo',
  ];

  List<AdminMessage> _items = const [];
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
      final res = await _repo.listMessages(
        page: _page,
        limit: _limit,
        search: _keyword,
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

  List<List<String>> get _tableData => _items
      .map(
        (m) => [
          m.userName,
          m.botName,
          (m.models ?? ''),
          m.contentUser,
          m.contentBot,
          _fmtCredit(m.creditCost),
          m.createdAt != null ? _fmtDateTime(m.createdAt!) : '-',
        ],
      )
      .toList();

  String _fmtDateTime(DateTime dt) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  String _fmtCredit(double v) {
    // Show up to 6 decimals, trim trailing zeros
    String s = v.toStringAsFixed(6);
    if (!s.contains('.')) return s;
    // Trim trailing zeros after decimal
    s = s.replaceFirst(RegExp(r'0+$'), '');
    // If ends with '.', remove it
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[Admin] Quản lý tin nhắn')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên user hoặc bot...',
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
              actionsBuilder: (row) => IconButton(
                tooltip: 'Xem chi tiết',
                icon: const Icon(Icons.open_in_new),
                onPressed: () {
                  final m = _items[row];
                  showDialog(
                    context: context,
                    builder: (_) => _MessageDetailDialog(message: m),
                  );
                },
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

class _MessageDetailDialog extends StatelessWidget {
  final AdminMessage message;
  const _MessageDetailDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.8;
    final maxW = MediaQuery.of(context).size.width * 0.9;
    final isWide = maxW >= 800;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: SizedBox(
          height: maxH,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tin nhắn của ${message.userName} với ${message.botName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (message.createdAt != null)
                  Text(
                    _fmt(message.createdAt!),
                    style: const TextStyle(color: Colors.black54),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _readonlyField(
                                'Tin nhắn người dùng',
                                message.contentUser,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _readonlyField(
                                'Tin nhắn bot',
                                message.contentBot,
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _readonlyField(
                                'Tin nhắn người dùng',
                                message.contentUser,
                              ),
                              const SizedBox(height: 12),
                              _readonlyField(
                                'Tin nhắn bot',
                                message.contentBot,
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Đóng'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _readonlyField(String label, String value) {
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
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: SelectableText(
              value.isEmpty ? '(trống)' : value,
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }
}
