import 'dart:async';
import 'package:flutter/material.dart';
import 'admin_table_scaffold.dart';
import '../services/payment_repository.dart';

class AdminPaymentsView extends StatefulWidget {
  const AdminPaymentsView({super.key});

  @override
  State<AdminPaymentsView> createState() => _AdminPaymentsViewState();
}

class _AdminPaymentsViewState extends State<AdminPaymentsView> {
  final _repo = PaymentRepository();
  final _columns = const ['Email', 'Số tiền', 'Ngày tạo'];

  List<PaymentRecord> _items = const [];
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
      final res = await _repo.listPayments(
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
      if (mounted) setState(() => _loading = false);
    }
  }

  List<List<String>> get _tableData =>
      _items.map((p) => [p.email, p.amountRaw, _fmtDate(p.createdAt)]).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('[Admin] Quản lý thanh toán')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Tìm theo email hoặc mã...',
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
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Làm mới',
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
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
              showPagination: false, // dùng phân trang remote dưới
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
                setState(() => _page--);
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
      buttons.add(
        OutlinedButton(
          onPressed: () {
            setState(() => _page = p);
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
                setState(() => _page++);
                _load();
              }
            : null,
        child: const Text('Next'),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      alignment: Alignment.centerLeft,
      child: Wrap(spacing: 6, children: buttons),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
  String _two(int v) => v < 10 ? '0$v' : '$v';
  // No currency formatting now because backend already returns string
}
