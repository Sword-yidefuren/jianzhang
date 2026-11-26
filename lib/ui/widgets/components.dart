import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/ledger_entry.dart';
import '../../domain/categories.dart';
import '../theme.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.color = AppColors.card,
    this.onTap,
    this.borderColor = AppColors.line,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A201C14),
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: content,
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.kicker,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String kicker;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kicker.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing!],
      ],
    );
  }
}

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    this.onCurrent,
    this.current = true,
    this.compact = false,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onCurrent;
  final bool current;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(
          icon: Icons.chevron_left_rounded,
          onPressed: onPrevious,
          tooltip: '上个月',
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
          child: Text(
            monthLabel(month),
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        _ArrowButton(
          icon: Icons.chevron_right_rounded,
          onPressed: onNext,
          tooltip: '下个月',
        ),
        if (!current && onCurrent != null) ...[
          const SizedBox(width: 6),
          TextButton(onPressed: onCurrent, child: const Text('回到本月')),
        ],
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(10),
            color: AppColors.card,
          ),
          child: Icon(icon, size: 18, color: AppColors.ink),
        ),
      ),
    );
  }
}

class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    this.onTap,
    this.showDate = false,
    this.dense = false,
  });

  final LedgerEntry entry;
  final VoidCallback? onTap;
  final bool showDate;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final category = categoryFor(entry.category, entry.direction);
    final isExpense = entry.direction == EntryDirection.expense;
    final subtitleParts = <String>[
      if (showDate) dayLabel(entry.occurredAt),
      if (entry.subtitle.isNotEmpty) entry.subtitle,
      if (entry.isImported) entry.sourceLabel,
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 2 : 4,
          vertical: dense ? 9 : 11,
        ),
        child: Row(
          children: [
            Container(
              width: dense ? 38 : 42,
              height: dense ? 38 : 42,
              decoration: BoxDecoration(
                color: category.monoColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                category.icon,
                size: dense ? 19 : 21,
                color: category.monoColor,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: dense ? 13.5 : 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitleParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? '-' : '+'}${Money.format(entry.amountCents)}',
                  style: AppTheme.numeric(
                    size: dense ? 14.5 : 15.5,
                    weight: FontWeight.w600,
                    color: isExpense ? AppColors.expense : AppColors.income,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.category,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryMark extends StatelessWidget {
  const CategoryMark({
    super.key,
    required this.category,
    this.size = 38,
    this.soft = true,
  });

  final Category category;
  final double size;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: soft
            ? category.monoColor.withValues(alpha: 0.13)
            : category.monoColor,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(
        category.icon,
        size: size * 0.47,
        color: soft ? category.monoColor : Colors.white,
      ),
    );
  }
}

class SoftTag extends StatelessWidget {
  const SoftTag({
    super.key,
    required this.label,
    this.color = AppColors.accent,
    this.background = AppColors.accentSoft,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
          height: 1.1,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 20 : 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.paperDeep,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 24, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.muted,
                    height: 1.55,
                  ),
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '确定',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.expense)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class PageScrollBody extends StatelessWidget {
  const PageScrollBody({
    super.key,
    required this.children,
    this.padding,
    this.maxWidth = 760,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 600 ? 20.0 : 36.0;
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding:
                padding ?? EdgeInsets.fromLTRB(horizontal, 26, horizontal, 36),
            children: children,
          ),
        ),
      ),
    );
  }
}
