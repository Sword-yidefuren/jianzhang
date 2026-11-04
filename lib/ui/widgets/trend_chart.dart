import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/ledger_entry.dart';
import '../../domain/categories.dart';
import '../theme.dart';

class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.data,
    required this.direction,
    required this.selectedMonth,
    this.height = 190,
    this.onMonthTap,
  });

  final List<MonthTotal> data;
  final EntryDirection direction;
  final DateTime selectedMonth;
  final double height;
  final ValueChanged<DateTime>? onMonthTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: onMonthTap == null
                ? null
                : (details) {
                    final width = constraints.maxWidth;
                    final slot = width / math.max(data.length, 1);
                    final index = (details.localPosition.dx / slot)
                        .floor()
                        .clamp(0, data.length - 1);
                    onMonthTap!(data[index].month);
                  },
            child: CustomPaint(
              size: Size(constraints.maxWidth, height),
              painter: _TrendPainter(
                data: data,
                direction: direction,
                selectedMonth: selectedMonth,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.data,
    required this.direction,
    required this.selectedMonth,
  });

  final List<MonthTotal> data;
  final EntryDirection direction;
  final DateTime selectedMonth;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final values = data
        .map(
          (item) => direction == EntryDirection.expense
              ? item.expenseCents
              : item.incomeCents,
        )
        .toList();
    final maxValue = values.reduce(math.max);
    final chartTop = 24.0;
    final chartBottom = size.height - 30;
    final chartHeight = chartBottom - chartTop;
    final slot = size.width / data.length;

    final gridPaint = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = chartTop + chartHeight * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final activeColor = direction == EntryDirection.expense
        ? AppColors.expense
        : AppColors.income;

    for (var i = 0; i < data.length; i++) {
      final isSelected =
          data[i].month.year == selectedMonth.year &&
          data[i].month.month == selectedMonth.month;
      final ratio = maxValue == 0 ? 0.0 : values[i] / maxValue;
      final barWidth = math.min(slot * 0.42, 34.0);
      final left = slot * i + (slot - barWidth) / 2;
      final barHeight = math
          .max(chartHeight * ratio, values[i] > 0 ? 4.0 : 2.0)
          .toDouble();
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(left, chartBottom - barHeight, barWidth, barHeight),
        topLeft: const Radius.circular(7),
        topRight: const Radius.circular(7),
        bottomLeft: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      );
      final paint = Paint()
        ..color = isSelected
            ? activeColor
            : activeColor.withValues(alpha: values[i] == 0 ? 0.12 : 0.28);
      canvas.drawRRect(rect, paint);

      if (isSelected && values[i] > 0) {
        _paintText(
          canvas,
          Money.format(values[i]),
          Offset(left + barWidth / 2, chartBottom - barHeight - 20),
          const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          align: TextAlign.center,
        );
      }

      _paintText(
        canvas,
        '${data[i].month.month}月',
        Offset(slot * i + slot / 2, chartBottom + 9),
        TextStyle(
          fontSize: 10.5,
          color: isSelected ? AppColors.ink : AppColors.faint,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        align: TextAlign.center,
      );
    }
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset anchor,
    TextStyle style, {
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: ui.TextDirection.ltr,
      textAlign: align,
    )..layout();
    final dx = align == TextAlign.center
        ? anchor.dx - painter.width / 2
        : anchor.dx;
    painter.paint(canvas, Offset(dx, anchor.dy));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.direction != direction ||
      oldDelegate.selectedMonth != selectedMonth;
}

class MetricCell extends StatelessWidget {
  const MetricCell({
    super.key,
    required this.label,
    required this.value,
    this.color = AppColors.ink,
    this.align = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final Color color;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            letterSpacing: 0.6,
            color: AppColors.faint,
          ),
        ),
        const SizedBox(height: 6),
        Text(value, style: AppTheme.numeric(size: 18, color: color)),
      ],
    );
  }
}
