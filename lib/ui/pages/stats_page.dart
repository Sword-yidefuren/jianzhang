import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/ledger_entry.dart';
import '../../domain/categories.dart';
import '../../state/ledger_controller.dart';
import '../theme.dart';
import '../widgets/category_chart.dart';
import '../widgets/components.dart';
import '../widgets/trend_chart.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key, required this.controller});

  final LedgerController controller;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  EntryDirection _direction = EntryDirection.expense;
  bool _yearView = false;
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final summary = _yearView
        ? controller.store.summaryForYear(_year)
        : controller.summary;
    final sourceEntries = _yearView
        ? controller.store.entriesForYear(_year)
        : controller.allMonthEntries;
    final entries = sourceEntries
        .where((entry) => entry.direction == _direction)
        .toList();
    final totalCents = entries.fold(0, (sum, entry) => sum + entry.amountCents);
    final days = _yearView
        ? _yearDays
        : (controller.isCurrentMonth
              ? DateTime.now().day
              : daysInMonth(controller.selectedMonth));
    final dailyAverage = days <= 0 ? 0 : (totalCents / days).round();
    final biggest = entries.isEmpty
        ? null
        : entries.reduce((a, b) => a.amountCents >= b.amountCents ? a : b);
    final totals = _yearView
        ? controller.store.categoryTotalsForYear(_year, _direction)
        : controller.categoryTotalsFor(_direction);
    final trend = _yearView
        ? controller.store.monthlyTotalsForYear(_year)
        : controller.trend;
    final periodLabel = _yearView
        ? '$_year年'
        : monthLabel(controller.selectedMonth);

    return PageScrollBody(
      children: [
        PageHeader(
          kicker: 'Insights',
          title: '统计',
          subtitle: _yearView ? '把一年的账看清楚，不用做表格。' : '把一个月的账看清楚，不用做表格。',
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            _RangeToggle(
              yearView: _yearView,
              onChanged: (value) => setState(() {
                _yearView = value;
                if (value) _year = controller.selectedMonth.year;
              }),
            ),
            const Spacer(),
            _StatsToggle(
              value: _direction,
              onChanged: (value) => setState(() => _direction = value),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_yearView)
              _YearSwitcher(
                year: _year,
                onPrevious: () => setState(() => _year--),
                onNext: () => setState(() => _year++),
              )
            else
              MonthSwitcher(
                month: controller.selectedMonth,
                current: controller.isCurrentMonth,
                onPrevious: () => controller.shiftMonth(-1),
                onNext: () => controller.shiftMonth(1),
                onCurrent: () => controller.goToMonth(DateTime.now()),
              ),
            const Spacer(),
            Text(
              '${entries.length} 笔',
              style: const TextStyle(fontSize: 11, color: AppColors.faint),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _yearView
                              ? '$_year年${_direction.label}'
                              : '本月${_direction.label}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 1.2,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            Money.format(totalCents),
                            style: AppTheme.numeric(
                              size: 38,
                              color: _direction == EntryDirection.expense
                                  ? AppColors.expense
                                  : AppColors.income,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SoftTag(
                    label: '${entries.length} 笔',
                    color: AppColors.muted,
                    background: AppColors.paperDeep,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MetricCell(
                      label: '日均',
                      value: Money.format(dailyAverage),
                    ),
                  ),
                  Expanded(
                    child: MetricCell(
                      label: '最大单笔',
                      value: biggest == null
                          ? '—'
                          : Money.format(biggest.amountCents),
                    ),
                  ),
                  Expanded(
                    child: MetricCell(
                      label: '记账天数',
                      value: '${_activeDays(entries)} 天',
                      align: CrossAxisAlignment.end,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _yearView ? '全年趋势' : '近 6 个月',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _direction == EntryDirection.expense ? '支出趋势' : '收入趋势',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TrendChart(
                data: trend,
                direction: _direction,
                selectedMonth: _yearView
                    ? DateTime(
                        _year,
                        _year == DateTime.now().year
                            ? DateTime.now().month
                            : 12,
                      )
                    : controller.selectedMonth,
                onMonthTap: (month) {
                  controller.goToMonth(month);
                  setState(() => _yearView = false);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _yearView
                        ? '$_year年${_direction.label}分类'
                        : '${_direction.label}分类',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '占 ${_direction.label}比例',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CategoryBreakdown(
                totals: totals,
                totalCents: _direction == EntryDirection.expense
                    ? summary.expenseCents
                    : summary.incomeCents,
                direction: _direction,
                maxRows: 8,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            '$periodLabel · 共 ${summary.count} 笔账',
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.faint,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }

  int get _yearDays {
    final now = DateTime.now();
    final start = DateTime(_year);
    if (_year == now.year) {
      return now.difference(start).inDays + 1;
    }
    return DateTime(_year + 1).difference(start).inDays;
  }

  int _activeDays(List<LedgerEntry> entries) {
    final days = <int>{};
    for (final entry in entries) {
      days.add(
        DateTime(
          entry.occurredAt.year,
          entry.occurredAt.month,
          entry.occurredAt.day,
        ).millisecondsSinceEpoch,
      );
    }
    return days.length;
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.yearView, required this.onChanged});

  final bool yearView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.paperDeep,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RangeItem(
            label: '月',
            selected: !yearView,
            onTap: () => onChanged(false),
          ),
          _RangeItem(
            label: '年',
            selected: yearView,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _RangeItem extends StatelessWidget {
  const _RangeItem({
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
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x0D201C14),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.ink : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _YearSwitcher extends StatelessWidget {
  const _YearSwitcher({
    required this.year,
    required this.onPrevious,
    required this.onNext,
  });

  final int year;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _YearArrow(icon: Icons.chevron_left_rounded, onTap: onPrevious),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$year年',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _YearArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _YearArrow extends StatelessWidget {
  const _YearArrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: 28,
        height: 30,
        child: Icon(icon, size: 18, color: AppColors.muted),
      ),
    );
  }
}

class _StatsToggle extends StatelessWidget {
  const _StatsToggle({required this.value, required this.onChanged});

  final EntryDirection value;
  final ValueChanged<EntryDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.paperDeep,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final direction in EntryDirection.values)
            InkWell(
              onTap: () => onChanged(direction),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: value == direction
                      ? AppColors.card
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: value == direction
                      ? const [
                          BoxShadow(
                            color: Color(0x0D201C14),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  direction.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: value == direction
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: value == direction
                        ? (direction == EntryDirection.expense
                              ? AppColors.expense
                              : AppColors.income)
                        : AppColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
