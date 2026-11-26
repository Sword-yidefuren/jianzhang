import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/ledger_entry.dart';
import '../../domain/categories.dart';
import '../../state/ledger_controller.dart';
import 'import_page.dart';
import '../sheets/entry_sheet.dart';
import '../theme.dart';
import '../widgets/components.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onOpenSavings,
  });

  final LedgerController controller;
  final VoidCallback onOpenSavings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
          child: ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 26, horizontal, 96),
            children: [
              PageHeader(
                kicker: 'Jianzhang',
                title: '记账',
                subtitle: controller.isCurrentMonth
                    ? '本月共 ${controller.summary.count} 笔'
                    : '${monthLabel(controller.selectedMonth)} 的账目',
                trailing: OutlinedButton.icon(
                  onPressed: _openImport,
                  icon: const Icon(Icons.file_download_outlined, size: 16),
                  label: const Text('导入'),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    controller.isCurrentMonth ? '本月概览' : '月度概览',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: AppColors.muted,
                    ),
                  ),
                  const Spacer(),
                  MonthSwitcher(
                    month: controller.selectedMonth,
                    current: controller.isCurrentMonth,
                    onPrevious: () => controller.shiftMonth(-1),
                    onNext: () => controller.shiftMonth(1),
                    onCurrent: () => controller.goToMonth(DateTime.now()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                controller: controller,
                onOpenSavings: widget.onOpenSavings,
              ),
              const SizedBox(height: 22),
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
                    onTap: () => controller.setFilter(EntryDirection.expense),
                  ),
                  const SizedBox(width: 7),
                  _FilterChip(
                    label: '收入',
                    selected: controller.filter == EntryDirection.income,
                    onTap: () => controller.setFilter(EntryDirection.income),
                  ),
                  const Spacer(),
                  if (controller.search.isNotEmpty || controller.filter != null)
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        controller.clearFilters();
                        setState(() {});
                      },
                      child: const Text('清空筛选'),
                    )
                  else
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
              if (groups.isEmpty)
                EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title:
                      controller.search.isNotEmpty || controller.filter != null
                      ? '没有匹配的账目'
                      : '这个月还没有账目',
                  message:
                      controller.search.isNotEmpty || controller.filter != null
                      ? '换个关键词，或清空筛选试试。'
                      : '用下面的加号记一笔，或导入微信/支付宝账单。',
                  action: OutlinedButton.icon(
                    onPressed: _openImport,
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: const Text('导入账单'),
                  ),
                )
              else
                for (final group in groups) ...[
                  _DayGroupCard(group: group, controller: controller),
                  const SizedBox(height: 4),
                ],
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller, required this.onOpenSavings});

  final LedgerController controller;
  final VoidCallback onOpenSavings;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final hasData = summary.count > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A201C14),
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '本月支出',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFB9B5AA),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  hasData ? '${summary.count} 笔' : '还没开始',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFDCD7CB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(summary.expenseCents),
              style: AppTheme.numeric(
                size: 54,
                color: const Color(0xFFF7F2E7),
                letterSpacing: -2.2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasData ? _summaryHint(summary) : '从下面的加号开始，今天记一笔。',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFFAAA69B),
              height: 1.5,
            ),
          ),
          if (controller.isCurrentMonth) ...[
            const SizedBox(height: 10),
            _SavingsLine(controller: controller, onTap: onOpenSavings),
          ],
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.11)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: '本月收入',
                  value: Money.format(summary.incomeCents),
                ),
              ),
              Expanded(
                child: _HeroMetric(
                  label: '结余',
                  value: Money.format(summary.netCents),
                  color: summary.netCents >= 0
                      ? const Color(0xFFF7F2E7)
                      : const Color(0xFFAAA69B),
                ),
              ),
              Expanded(
                child: _HeroMetric(
                  label: '日均支出',
                  value: Money.format(_dailyAverage(summary, controller)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _dailyAverage(LedgerSummary summary, LedgerController controller) {
    final month = controller.selectedMonth;
    final now = DateTime.now();
    final days = isSameMonth(month, now) ? now.day : daysInMonth(month);
    if (days <= 0) return 0;
    return (summary.expenseCents / days).round();
  }

  String _summaryHint(LedgerSummary summary) {
    if (summary.expenseCents == 0) return '这个月只有收入，账本很轻。';
    final top = controller.expenseCategoryTotals.isEmpty
        ? null
        : controller.expenseCategoryTotals.first;
    if (top == null) return '每一笔都算数。';
    final percent = (top.amountCents / summary.expenseCents * 100).round();
    return '最大头是${top.category}，占本月支出的 $percent%。';
  }
}

class _SavingsLine extends StatelessWidget {
  const _SavingsLine({required this.controller, required this.onTap});

  final LedgerController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final goal = controller.monthGoalCents;
    final net = controller.summary.netCents;
    if (goal <= 0) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '还没有存钱目标，去存钱页设一个 →',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFFDCD7CB),
              height: 1.4,
            ),
          ),
        ),
      );
    }
    final met = net >= goal;
    final color = net > 0
        ? const Color(0xFFF7F2E7)
        : net < 0
        ? const Color(0xFFAAA69B)
        : const Color(0xFFAAA69B);
    final gap = goal - net;
    final saved = net < 0
        ? '本月结余 ${Money.format(net)}'
        : '本月已存 ${Money.format(net)}';
    final comparison = met
        ? '超过目标 ${Money.format(-gap)}'
        : '离目标还差 ${Money.format(gap)}';
    final progress = (net / goal).clamp(0.0, 1.0).toDouble();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$saved，$comparison',
              style: TextStyle(fontSize: 11, color: color, height: 1.4),
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 3,
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    this.color = const Color(0xFFF7F2E7),
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            color: Color(0xFF8F8B81),
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppTheme.numeric(
              size: 16,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
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
      padding: const EdgeInsets.only(bottom: 12),
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
