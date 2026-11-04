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

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final summary = controller.summary;
    final entries = controller.allMonthEntries
        .where((entry) => entry.direction == _direction)
        .toList();
    final totalCents = entries.fold(0, (sum, entry) => sum + entry.amountCents);
    final days = controller.isCurrentMonth
        ? DateTime.now().day
        : daysInMonth(controller.selectedMonth);
    final dailyAverage = days <= 0 ? 0 : (totalCents / days).round();
    final biggest = entries.isEmpty
        ? null
        : entries.reduce((a, b) => a.amountCents >= b.amountCents ? a : b);
    final totals = controller.categoryTotalsFor(_direction);

    return PageScrollBody(
      children: [
        PageHeader(kicker: 'Insights', title: '统计', subtitle: '把一个月看清楚，不用做表格。'),
        const SizedBox(height: 18),
        Row(
          children: [
            MonthSwitcher(
              month: controller.selectedMonth,
              current: controller.isCurrentMonth,
              onPrevious: () => controller.shiftMonth(-1),
              onNext: () => controller.shiftMonth(1),
              onCurrent: () => controller.goToMonth(DateTime.now()),
            ),
            const Spacer(),
            _StatsToggle(
              value: _direction,
              onChanged: (value) => setState(() => _direction = value),
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
                          _direction == EntryDirection.expense
                              ? '本月支出'
                              : '本月收入',
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
                  const Text(
                    '近 6 个月',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
                data: controller.trend,
                direction: _direction,
                selectedMonth: controller.selectedMonth,
                onMonthTap: controller.goToMonth,
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
                    _direction == EntryDirection.expense ? '支出分类' : '收入分类',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '占 ${_direction == EntryDirection.expense ? '支出' : '收入'}比例',
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
            '${monthLabel(controller.selectedMonth)} · 共 ${summary.count} 笔账',
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
