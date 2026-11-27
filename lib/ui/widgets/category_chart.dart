import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/ledger_entry.dart';
import '../../domain/categories.dart';
import '../theme.dart';

class CategoryDonut extends StatelessWidget {
  const CategoryDonut({
    super.key,
    required this.totals,
    required this.totalCents,
    required this.direction,
    this.size = 150,
  });

  final List<CategoryTotal> totals;
  final int totalCents;
  final EntryDirection direction;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(totals: totals, totalCents: totalCents),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                direction == EntryDirection.expense ? '支出' : '收入',
                style: const TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                Money.format(totalCents),
                style: AppTheme.numeric(
                  size: size < 130 ? 18 : 20,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.totals, required this.totalCents});

  final List<CategoryTotal> totals;
  final int totalCents;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.width * 0.105;
    final radius = (size.width - stroke) / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.paperDeep
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, track);

    if (totalCents <= 0 || totals.isEmpty) return;
    final gap = totals.length > 1 ? 0.035 : 0.0;
    var start = -math.pi / 2;
    for (final item in totals) {
      final sweep = item.amountCents / totalCents * math.pi * 2;
      if (sweep <= 0) continue;
      final category = categoryFor(item.category, EntryDirection.expense);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = category.color;
      final effectiveSweep = math.max(sweep - gap, 0.006);
      canvas.drawArc(rect, start + gap / 2, effectiveSweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.totalCents != totalCents || oldDelegate.totals != totals;
}

class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({
    super.key,
    required this.totals,
    required this.totalCents,
    required this.direction,
    this.maxRows = 5,
  });

  final List<CategoryTotal> totals;
  final int totalCents;
  final EntryDirection direction;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 520;
        final donut = CategoryDonut(
          totals: totals,
          totalCents: totalCents,
          direction: direction,
        );
        final list = _CategoryList(
          totals: totals,
          totalCents: totalCents,
          direction: direction,
          maxRows: maxRows,
        );
        if (!wide) {
          return Column(children: [donut, const SizedBox(height: 20), list]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            donut,
            const SizedBox(width: 28),
            Expanded(child: list),
          ],
        );
      },
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.totals,
    required this.totalCents,
    required this.direction,
    required this.maxRows,
  });

  final List<CategoryTotal> totals;
  final int totalCents;
  final EntryDirection direction;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Text(
          '这个月还没有账目',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }
    final rows = totals.take(maxRows).toList();
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          _CategoryRow(
            total: rows[i],
            totalCents: totalCents,
            direction: direction,
          ),
        ],
        if (totals.length > maxRows)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Text(
                  '另有 ${totals.length - maxRows} 个分类',
                  style: const TextStyle(fontSize: 11, color: AppColors.faint),
                ),
                const Spacer(),
                Text(
                  Money.format(
                    totals
                        .skip(maxRows)
                        .fold(0, (sum, item) => sum + item.amountCents),
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.faint,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.total,
    required this.totalCents,
    required this.direction,
  });

  final CategoryTotal total;
  final int totalCents;
  final EntryDirection direction;

  @override
  Widget build(BuildContext context) {
    final category = categoryFor(total.category, direction);
    final percent = totalCents <= 0 ? 0.0 : total.amountCents / totalCents;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: category.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        total.category,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${(percent * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.faint,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 3,
                    backgroundColor: AppColors.paperDeep,
                    valueColor: AlwaysStoppedAnimation(category.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            Money.format(total.amountCents),
            style: AppTheme.numeric(
              size: 12.5,
              weight: FontWeight.w600,
              color: AppColors.ink,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
