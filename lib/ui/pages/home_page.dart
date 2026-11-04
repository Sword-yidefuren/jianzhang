import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/ledger_entry.dart';
import '../../domain/categories.dart';
import '../../state/ledger_controller.dart';
import '../sheets/entry_sheet.dart';
import '../theme.dart';
import '../widgets/category_chart.dart';
import '../widgets/components.dart';
import '../widgets/quick_entry.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onOpenTransactions,
  });

  final LedgerController controller;
  final VoidCallback onOpenTransactions;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    return PageScrollBody(
      children: [
        const PageHeader(
          kicker: 'Jianzhang',
          title: '记账',
          subtitle: '打开就能记，月底自然清楚。',
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text(
              '本月概览',
              style: TextStyle(
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
        _SummaryCard(controller: controller),
        const SizedBox(height: 16),
        QuickEntry(controller: controller),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(
                title: '花在哪里',
                trailing: controller.expenseCategoryTotals.isEmpty
                    ? null
                    : '${controller.expenseCategoryTotals.length} 个分类',
              ),
              const SizedBox(height: 18),
              CategoryBreakdown(
                totals: controller.expenseCategoryTotals,
                totalCents: summary.expenseCents,
                direction: EntryDirection.expense,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Column(
            children: [
              _SectionHeader(
                title: '最近账目',
                trailing: controller.recentEntries.isEmpty ? null : '全部',
                onTrailingTap: onOpenTransactions,
              ),
              const SizedBox(height: 6),
              if (controller.recentEntries.isEmpty)
                const EmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: '还没有账目',
                  message: '在上面的输入框说一句“午饭 25”，就记好了。',
                  compact: true,
                )
              else
                for (var i = 0; i < controller.recentEntries.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  EntryTile(
                    entry: controller.recentEntries[i],
                    showDate: true,
                    onTap: () => showEntryEditor(
                      context,
                      controller,
                      entry: controller.recentEntries[i],
                    ),
                  ),
                ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            '本地 SQLite · 无账号 · 无云同步',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.8,
              color: AppColors.faint,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final LedgerController controller;

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
            hasData ? _summaryHint(summary) : '从下面一句话开始，今天记一笔。',
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFFAAA69B),
              height: 1.5,
            ),
          ),
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
                      ? const Color(0xFFD7E4DB)
                      : const Color(0xFFF0C9B9),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          InkWell(
            onTap: onTrailingTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 11,
                      color: onTrailingTap == null
                          ? AppColors.faint
                          : AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (onTrailingTap != null) ...[
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: AppColors.muted,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
