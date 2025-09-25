import 'package:flutter/material.dart';

class AdminTableScaffold extends StatefulWidget {
  final List<String>
  columns; // without index column, actions added automatically at end if actionsBuilder!=null
  final List<List<String>>
  data; // each row: list of cell strings for the columns
  final String searchHint;
  final Widget Function(int rowIndex)? actionsBuilder;
  final bool showSearch;
  final bool showPagination;
  final double? cellMaxWidth; // constrain cell width to enable ellipsis

  const AdminTableScaffold({
    super.key,
    required this.columns,
    required this.data,
    this.searchHint = 'Tìm theo tên hoặc email...',
    this.actionsBuilder,
    this.showSearch = true,
    this.showPagination = true,
    this.cellMaxWidth = 240,
  });

  @override
  State<AdminTableScaffold> createState() => _AdminTableScaffoldState();
}

class _AdminTableScaffoldState extends State<AdminTableScaffold> {
  final _searchCtrl = TextEditingController();
  int _page = 1;
  int _perPage = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<int> get _filteredIndexList {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = <int>[];
    for (var i = 0; i < widget.data.length; i++) {
      final row = widget.data[i];
      if (!widget.showSearch || q.isEmpty) {
        list.add(i);
      } else {
        final hit = row.any((c) => c.toLowerCase().contains(q));
        if (hit) list.add(i);
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredIndexList;
    final total = filtered.length;
    final totalPages = (total / _perPage).ceil().clamp(1, 9999);
    _page = _page.clamp(1, totalPages);
    int startIndex = 0;
    List<int> pageIndexes;
    if (widget.showPagination) {
      startIndex = (_page - 1) * _perPage;
      final end = (startIndex + _perPage).clamp(0, total);
      pageIndexes = filtered.sublist(startIndex, end);
    } else {
      pageIndexes = filtered;
    }

    final hasActions = widget.actionsBuilder != null;

    return Column(
      children: [
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (_) => setState(() => _page = 1),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 900),
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 24,
                  headingRowHeight: 46,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 56,
                  columns: [
                    const DataColumn(label: Text('#')),
                    ...widget.columns.map((c) => DataColumn(label: Text(c))),
                    if (hasActions)
                      const DataColumn(label: SizedBox(width: 80)),
                  ],
                  rows: [
                    for (int i = 0; i < pageIndexes.length; i++)
                      _buildRow(
                        index: startIndex + i + 1,
                        rowIndex: pageIndexes[i],
                        hasActions: hasActions,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.showPagination) _pagination(totalPages),
      ],
    );
  }

  DataRow _buildRow({
    required int index,
    required int rowIndex,
    required bool hasActions,
  }) {
    final row = widget.data[rowIndex];
    final cells = <DataCell>[];
    cells.add(DataCell(Text(index.toString())));
    for (final c in row) {
      final child = Text(
        c,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        softWrap: false,
      );
      if (widget.cellMaxWidth != null) {
        cells.add(DataCell(SizedBox(width: widget.cellMaxWidth, child: child)));
      } else {
        cells.add(DataCell(child));
      }
    }
    if (hasActions) {
      cells.add(
        DataCell(
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [widget.actionsBuilder!(rowIndex)],
          ),
        ),
      );
    }
    return DataRow(cells: cells);
  }

  Widget _pagination(int totalPages) {
    List<Widget> buttons = [];
    buttons.add(
      _pagerButton(
        'Prev',
        enabled: _page > 1,
        onTap: () => setState(() => _page--),
      ),
    );

    final maxPagesToShow = 7;
    if (totalPages <= maxPagesToShow) {
      for (int p = 1; p <= totalPages; p++) {
        buttons.add(_pagerNumber(p));
      }
    } else {
      // simple compact pages with ellipsis
      final pages = <int>{
        1,
        totalPages,
        _page,
        _page - 1,
        _page + 1,
        2,
        totalPages - 1,
      }.where((p) => p >= 1 && p <= totalPages).toList()..sort();
      int? last;
      for (final p in pages) {
        if (last != null && p - last > 1) {
          buttons.add(_ellipsis());
        }
        buttons.add(_pagerNumber(p));
        last = p;
      }
    }

    buttons.add(
      _pagerButton(
        'Next',
        enabled: _page < totalPages,
        onTap: () => setState(() => _page++),
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
          const SizedBox(width: 12),
          _pageSizeDropdown(),
        ],
      ),
    );
  }

  Widget _pagerButton(
    String label, {
    required bool enabled,
    required VoidCallback onTap,
  }) => ElevatedButton(onPressed: enabled ? onTap : null, child: Text(label));

  Widget _pagerNumber(int p) {
    final isActive = p == _page;
    if (isActive) {
      return FilledButton(onPressed: () {}, child: Text(p.toString()));
    }
    return OutlinedButton(
      onPressed: () => setState(() => _page = p),
      child: Text(p.toString()),
    );
  }

  Widget _ellipsis() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
    child: Text('...'),
  );

  Widget _pageSizeDropdown() {
    return DropdownButton<int>(
      value: _perPage,
      items: const [10, 20, 50]
          .map(
            (v) => DropdownMenuItem<int>(value: v, child: Text(v.toString())),
          )
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          _perPage = v;
          _page = 1;
        });
      },
    );
  }
}
