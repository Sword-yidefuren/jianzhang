import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../state/ledger_controller.dart';
import '../theme.dart';
import '../widgets/components.dart';

class SavingsPage extends StatelessWidget {
  const SavingsPage({super.key, required this.controller});

  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    final month = controller.currentMonth;
    final monthNet = controller.currentMonthNetCents;
    final yearNet = controller.currentYearNetCents;
    return PageScrollBody(
      children: [
        const PageHeader(
          kicker: 'Savings',
          title: '存钱',
          subtitle: '把每个月的结余，变成看得见的目标。',
        ),
        const SizedBox(height: 24),
        _SloganCard(
          slogan: controller.savingsSlogan,
          onTap: () => _editSlogan(context),
        ),
        const SizedBox(height: 16),
        _SavingsHero(
          label: '${month.year}年${month.month}月已存',
          caption: '本月收入减去支出后的结余',
          amountCents: monthNet,
          goalCents: controller.monthGoalCents,
          onEdit: () => _editGoal(context, isYear: false),
        ),
        const SizedBox(height: 16),
        _SavingsHero(
          label: '${month.year}年已存',
          caption: '今年累计收入减去支出',
          amountCents: yearNet,
          goalCents: controller.yearGoalCents,
          onEdit: () => _editGoal(context, isYear: true),
          compact: true,
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '存钱目标',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    controller.monthGoalCents == 0 &&
                            controller.yearGoalCents == 0
                        ? '还没有设置'
                        : '点数字修改',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _GoalRow(
                label: '本月目标',
                subtitle: monthLabel(month),
                cents: controller.monthGoalCents,
                onTap: () => _editGoal(context, isYear: false),
              ),
              const Divider(height: 22),
              _GoalRow(
                label: '全年目标',
                subtitle: '${month.year}年',
                cents: controller.yearGoalCents,
                onTap: () => _editGoal(context, isYear: true),
              ),
              const SizedBox(height: 8),
              const Text(
                '存钱数字就是首页的结余，不会另外复制一笔账。',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.55,
                  color: AppColors.faint,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editSlogan(BuildContext context) async {
    final text = TextEditingController(text: controller.savingsSlogan);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('给存钱一个理由'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '存钱口号',
            hintText: '例如：存够钱买手机',
          ),
        ),
        actions: [
          if (controller.savingsSlogan.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('清除'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(text.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value == null) return;
    controller.setSavingsSlogan(value);
  }

  Future<void> _editGoal(BuildContext context, {required bool isYear}) async {
    final current = isYear
        ? controller.yearGoalCents
        : controller.monthGoalCents;
    final text = TextEditingController(
      text: current > 0 ? Money.inputValue(current) : '',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isYear ? '设置全年存钱目标' : '设置本月存钱目标'),
        content: TextField(
          controller: text,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '¥ ',
            labelText: '目标金额',
            hintText: '例如 3000',
          ),
        ),
        actions: [
          if (current > 0)
            TextButton(
              onPressed: () => Navigator.of(context).pop(0),
              child: const Text('清除'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final raw = text.text.trim();
              if (raw.isEmpty) {
                Navigator.of(context).pop(0);
                return;
              }
              final cents = Money.tryParseToCents(raw);
              if (cents != null && cents > 0) {
                Navigator.of(context).pop(cents);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    text.dispose();
    if (value == null) return;
    if (isYear) {
      controller.setYearGoal(value);
    } else {
      controller.setMonthGoal(value);
    }
  }
}

class _SloganCard extends StatelessWidget {
  const _SloganCard({required this.slogan, required this.onTap});

  final String slogan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasSlogan = slogan.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined, size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasSlogan ? slogan : '给存钱一个理由，比如：存够钱买手机',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: hasSlogan ? 15 : 11.5,
                  fontWeight: hasSlogan ? FontWeight.w600 : FontWeight.w500,
                  height: 1.45,
                  color: hasSlogan ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              hasSlogan ? Icons.edit_outlined : Icons.add_rounded,
              size: 17,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsHero extends StatelessWidget {
  const _SavingsHero({
    required this.label,
    required this.caption,
    required this.amountCents,
    required this.goalCents,
    required this.onEdit,
    this.compact = false,
  });

  final String label;
  final String caption;
  final int amountCents;
  final int goalCents;
  final VoidCallback onEdit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hasGoal = goalCents > 0;
    final met = hasGoal && amountCents >= goalCents;
    final color = amountCents < 0 || (hasGoal && !met)
        ? AppColors.expense
        : AppColors.income;
    final gap = goalCents - amountCents;
    final progress = !hasGoal
        ? 0.0
        : (amountCents / goalCents).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: EdgeInsets.all(compact ? 20 : 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(hasGoal ? '修改目标' : '设置目标'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(amountCents),
              style: AppTheme.numeric(
                size: compact ? 38 : 52,
                color: color,
                letterSpacing: -1.8,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            style: const TextStyle(fontSize: 10.5, color: AppColors.faint),
          ),
          if (hasGoal) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: progress,
                backgroundColor: AppColors.paperDeep,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              met
                  ? '已经超过目标 ${Money.format(-gap)}'
                  : '离目标还差 ${Money.format(gap)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              '设一个目标，存钱才有方向。',
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.label,
    required this.subtitle,
    required this.cents,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final int cents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.faint,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              cents > 0 ? Money.format(cents) : '未设置',
              style: AppTheme.numeric(
                size: 16,
                color: cents > 0 ? AppColors.ink : AppColors.faint,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.faint,
            ),
          ],
        ),
      ),
    );
  }
}
