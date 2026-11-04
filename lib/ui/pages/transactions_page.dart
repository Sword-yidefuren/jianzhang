import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/ledger_entry.dart';
import '../../domain/categories.dart';
import '../../state/ledger_controller.dart';
import '../pages/import_page.dart';
import '../sheets/entry_sheet.dart';
import '../theme.dart';
import '../widgets/components.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key, required this.controller});

  final LedgerController controller;

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late final TextEditingController _searchController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.controller.search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      widget.controller.setSearch(value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    widget.controller.setSearch('');
    setState(() {});
  }

  Future<void> _openImport() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ImportPage(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final groups = _groupEntries(controller.monthEntries);
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 600 ? 20.0 : 36.0;

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 12),
                child: Column(
                  children: [
                    PageHeader(
                      kicker: 'Transactions',
                      title: '明细',
                      subtitle: controller.isCurrentMonth
                          ? '本月共 ${controller.summary.count} 笔'
                          : '${monthLabel(controller.selectedMonth)} 的账目',
                      trailing: OutlinedButton.icon(
                        onPressed: _openImport,
                        icon: const Icon(
                          Icons.file_download_outlined,
                          size: 16,
                        ),
                        label: const Text('导入'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        MonthSwitcher(
                          month: controller.selectedMonth,
                          current: controller.isCurrentMonth,
                          compact: true,
                          onPrevious: () => controller.shiftMonth(-1),
                          onNext: () => controller.shiftMonth(1),
                          onCurrent: () => controller.goToMonth(DateTime.now()),
                        ),
                        const Spacer(),
                        Text(
                          '${controller.monthEntries.length} 笔',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.faint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '搜商家、备注、分类或账户',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 19,
                          color: AppColors.faint,
                        ),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _clearSearch,
                                icon: const Icon(Icons.close_rounded, size: 17),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _FilterChip(
                          label: '全部',
                          selected: controller.filter == null,
                          onTap: () => controller.setFilter(null),
                        ),
                        const SizedBox(width: 7),
                        _FilterChip(
                          label: '支出',
                          selected: controller.filter == EntryDirection.expense,
                          onTap: () =>
                              controller.setFilter(EntryDirection.expense),
                        ),
                        const SizedBox(width: 7),
                        _FilterChip(
                          label: '收入',
                          selected: controller.filter == EntryDirection.income,
                          onTap: () =>
                              controller.setFilter(EntryDirection.income),
                        ),
                        const Spacer(),
                        if (controller.search.isNotEmpty ||
                            controller.filter != null)
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              controller.clearFilters();
                              setState(() {});
                            },
                            child: const Text('清空筛选'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: groups.isEmpty
                    ? EmptyState(
                        icon: Icons.receipt_long_rounded,
                        title:
                            controller.search.isNotEmpty ||
                                controller.filter != null
                            ? '没有匹配的账目'
                            : '这个月还没有账目',
                        message:
                            controller.search.isNotEmpty ||
                                controller.filter != null
                            ? '换个关键词，或清空筛选试试。'
                            : '用一句话记一笔，或导入微信/支付宝账单。',
                        action: OutlinedButton.icon(
                          onPressed: _openImport,
                          icon: const Icon(
                            Icons.file_download_outlined,
                            size: 16,
                          ),
                          label: const Text('导入账单'),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          4,
                          horizontal,
                          36,
                        ),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return _DayGroupCard(
                            group: group,
                            controller: controller,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_DayGroup> _groupEntries(List<LedgerEntry> entries) {
    final groups = <_DayGroup>[];
    for (final entry in entries) {
      final day = dateOnly(entry.occurredAt);
      if (groups.isEmpty || !isSameDay(groups.last.date, day)) {
        groups.add(_DayGroup(date: day, entries: [entry]));
      } else {
        groups.last.entries.add(entry);
      }
    }
    return groups;
  }
}

class _DayGroup {
  _DayGroup({required this.date, required this.entries});

  final DateTime date;
  final List<LedgerEntry> entries;

  int get netCents => entries.fold(
    0,
    (sum, entry) =>
        sum +
        (entry.direction == EntryDirection.income
            ? entry.amountCents
            : -entry.amountCents),
  );
}

class _DayGroupCard extends StatelessWidget {
  const _DayGroupCard({required this.group, required this.controller});

  final _DayGroup group;
  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    final net = group.netCents;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Row(
              children: [
                Text(
                  dayLabel(group.date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  '${group.entries.length} 笔',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.faint,
                  ),
                ),
                const Spacer(),
                Text(
                  '${net >= 0 ? '+' : '-'}${Money.format(net.abs())}',
                  style: AppTheme.numeric(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: net >= 0 ? AppColors.income : AppColors.muted,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < group.entries.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 52),
                  Dismissible(
                    key: ValueKey('entry-${group.entries[i].id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 18),
                      decoration: BoxDecoration(
                        color: AppColors.expense,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    confirmDismiss: (_) => showConfirmDialog(
                      context,
                      title: '删除这笔账？',
                      message: '删除后无法恢复，统计会立即更新。',
                      confirmLabel: '删除',
                      destructive: true,
                    ),
                    onDismissed: (_) =>
                        controller.deleteEntry(group.entries[i].id!),
                    child: EntryTile(
                      entry: group.entries[i],
                      dense: true,
                      onTap: () => showEntryEditor(
                        context,
                        controller,
                        entry: group.entries[i],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? AppColors.ink : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
