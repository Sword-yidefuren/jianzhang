import '../core/dates.dart';
import '../core/money.dart';
import 'categories.dart';

class ParsedEntry {
  const ParsedEntry({
    required this.raw,
    required this.amountCents,
    required this.direction,
    required this.category,
    required this.account,
    required this.merchant,
    required this.note,
    required this.occurredAt,
    required this.categoryMatched,
  });

  final String raw;
  final int amountCents;
  final EntryDirection direction;
  final String category;
  final String account;
  final String merchant;
  final String note;
  final DateTime occurredAt;
  final bool categoryMatched;

  String get preview =>
      '${direction.label} · $category · ${Money.format(amountCents)} · $account';
}

/// 把“午饭 25 微信”这类短句解析成一条可落库的账目。
///
/// 解析器故意保持保守：没有金额就返回 null，交给详细表单，不硬猜。
class QuickParser {
  const QuickParser._();

  static ParsedEntry? parse(
    String input, {
    DateTime? now,
    String defaultAccount = '其他',
  }) {
    final current = now ?? DateTime.now();
    var text = _normalize(input);
    if (text.isEmpty) return null;

    var occurredAt = current;
    var hasExplicitDate = false;

    // 时间先剥掉，避免 12:30 被当成金额。
    final timePattern = RegExp(r'(\d{1,2}):(\d{2})');
    final timeMatch = timePattern.firstMatch(text);
    if (timeMatch != null) {
      final hour = int.tryParse(timeMatch.group(1) ?? '');
      final minute = int.tryParse(timeMatch.group(2) ?? '');
      if (hour != null && minute != null && hour < 24 && minute < 60) {
        occurredAt = DateTime(
          occurredAt.year,
          occurredAt.month,
          occurredAt.day,
          hour,
          minute,
        );
      }
      text = text.replaceRange(timeMatch.start, timeMatch.end, ' ');
    }

    DateTime? resolveMonthDay(int month, int day) {
      if (month < 1 || month > 12 || day < 1 || day > 31) return null;
      var year = current.year;
      var candidate = DateTime(year, month, day);
      // 12 月记账、1 月补记时，未写年份应落到上一年。
      if (candidate.isAfter(current.add(const Duration(days: 1)))) {
        year -= 1;
        candidate = DateTime(year, month, day);
      }
      return candidate;
    }

    // 相对日期。
    const relative = <String, int>{
      '大前天': 3,
      '前天': 2,
      '昨天': 1,
      '昨日': 1,
      '今天': 0,
      '今日': 0,
      '刚才': 0,
    };
    for (final entry in relative.entries) {
      if (text.contains(entry.key)) {
        if (entry.value == 0) {
          // 今天/刚才：保留前面已经解析出的时间。
          occurredAt = DateTime(
            current.year,
            current.month,
            current.day,
            occurredAt.hour,
            occurredAt.minute,
          );
        } else {
          final date = dateOnly(current).subtract(Duration(days: entry.value));
          occurredAt = DateTime(date.year, date.month, date.day, 12);
        }
        text = text.replaceFirst(entry.key, ' ');
        hasExplicitDate = true;
        break;
      }
    }

    // 2026-11-03 / 2026年11月3日。
    if (!hasExplicitDate) {
      final full = RegExp(r'(\d{4})[年./-](\d{1,2})[月./-](\d{1,2})[日号]?')
          .firstMatch(text);
      if (full != null) {
        final year = int.parse(full.group(1)!);
        final month = int.parse(full.group(2)!);
        final day = int.parse(full.group(3)!);
        if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
          occurredAt = DateTime(year, month, day, 12);
          hasExplicitDate = true;
          text = text.replaceRange(full.start, full.end, ' ');
        }
      }
    }

    // 11月3日。
    if (!hasExplicitDate) {
      final monthDay = RegExp(r'(\d{1,2})月(\d{1,2})[日号]').firstMatch(text);
      if (monthDay != null) {
        final date = resolveMonthDay(
          int.parse(monthDay.group(1)!),
          int.parse(monthDay.group(2)!),
        );
        if (date != null) {
          occurredAt = DateTime(date.year, date.month, date.day, 12);
          hasExplicitDate = true;
          text = text.replaceRange(monthDay.start, monthDay.end, ' ');
        }
      }
    }

    // 11-3 / 11/3。
    if (!hasExplicitDate) {
      final short = RegExp(r'(?<!\d)(\d{1,2})[-/](\d{1,2})(?!\d)')
          .firstMatch(text);
      if (short != null) {
        final date = resolveMonthDay(
          int.parse(short.group(1)!),
          int.parse(short.group(2)!),
        );
        if (date != null) {
          occurredAt = DateTime(date.year, date.month, date.day, 12);
          hasExplicitDate = true;
          text = text.replaceRange(short.start, short.end, ' ');
        }
      }
    }

    // 3号：本月；若日期还没到，按上个月算。
    if (!hasExplicitDate) {
      final dayOnly = RegExp(r'(?<!\d)(\d{1,2})[日号]').firstMatch(text);
      if (dayOnly != null) {
        final day = int.parse(dayOnly.group(1)!);
        if (day >= 1 && day <= 31) {
          var month = current.month;
          var year = current.year;
          if (day > current.day) {
            month -= 1;
            if (month == 0) {
              month = 12;
              year -= 1;
            }
          }
          occurredAt = DateTime(year, month, day, 12);
          hasExplicitDate = true;
          text = text.replaceRange(dayOnly.start, dayOnly.end, ' ');
        }
      }
    }

    // 周一 / 上周五。
    if (!hasExplicitDate) {
      final weekday = RegExp(r'(上上周|上周|本周|这周)?(?:周|星期)([一二三四五六日天])')
          .firstMatch(text);
      if (weekday != null) {
        const map = <String, int>{
          '一': 1,
          '二': 2,
          '三': 3,
          '四': 4,
          '五': 5,
          '六': 6,
          '日': 7,
          '天': 7,
        };
        final prefix = weekday.group(1) ?? '';
        final target = map[weekday.group(2)] ?? current.weekday;
        var delta = current.weekday - target;
        if (delta < 0) delta += 7;
        if (prefix == '上周') delta += 7;
        if (prefix == '上上周') delta += 14;
        final date = dateOnly(current).subtract(Duration(days: delta));
        occurredAt = DateTime(date.year, date.month, date.day, 12);
        hasExplicitDate = true;
        text = text.replaceRange(weekday.start, weekday.end, ' ');
      }
    }

    final accountMatch = _extractAccount(text);
    final account =
        accountMatch?.account ??
        (defaultAccount.trim().isEmpty ? '其他' : defaultAccount);
    if (accountMatch != null) {
      text = text.replaceRange(accountMatch.start, accountMatch.end, ' ');
    }

    final amount = _extractAmount(text);
    if (amount == null || amount.cents <= 0) return null;
    text = text.replaceRange(amount.start, amount.end, ' ');

    final direction =
        amount.explicitDirection ??
        inferDirection('${text.trim()} ${input.trim()}');

    final note = _cleanNote(text);
    final merchant = note.isEmpty ? _defaultMerchant(direction, input) : note;
    final category = classifyCategory(
      '$note ${_stripAmountWords(input)}',
      direction,
    );

    if (hasExplicitDate && occurredAt.hour == 0 && occurredAt.minute == 0) {
      occurredAt = DateTime(
        occurredAt.year,
        occurredAt.month,
        occurredAt.day,
        12,
      );
    }

    return ParsedEntry(
      raw: input.trim(),
      amountCents: amount.cents,
      direction: direction,
      category: category.name,
      account: account,
      merchant: merchant,
      note: '',
      occurredAt: occurredAt,
      categoryMatched: category.name != '其他',
    );
  }

  static String _normalize(String input) {
    var text = input.trim();
    const fullWidthDigits = '０１２３４５６７８９';
    for (var i = 0; i < fullWidthDigits.length; i++) {
      text = text.replaceAll(fullWidthDigits[i], '$i');
    }
    return text
        .replaceAll('．', '.')
        .replaceAll('＋', '+')
        .replaceAll('－', '-')
        .replaceAll('￥', '¥')
        .replaceAll('，', ',')
        .replaceAll(RegExp(r'[。！!？?；;]+$'), '')
        .trim();
  }

  static _AccountMatch? _extractAccount(String text) {
    const rules = <(String, List<String>)>[
      ('微信', ['微信支付', '微信', '零钱']),
      ('支付宝', ['支付宝', '花呗', '余额宝']),
      (
        '银行卡',
        [
          '招商银行',
          '工商银行',
          '建设银行',
          '农业银行',
          '中国银行',
          '银行卡',
          '信用卡',
          '储蓄卡',
          '招行',
          '工行',
          '建行',
          '农行',
          '中行',
        ],
      ),
      ('现金', ['现金']),
    ];
    for (final rule in rules) {
      for (final keyword in rule.$2) {
        final index = text.indexOf(keyword);
        if (index >= 0) {
          return _AccountMatch(
            account: rule.$1,
            start: index,
            end: index + keyword.length,
          );
        }
      }
    }
    return null;
  }

  static _AmountMatch? _extractAmount(String text) {
    final pattern = RegExp(
      r'([+\-]?)\s*(?:[¥￥]\s*)?(\d+(?:\.\d{1,2})?)\s*(元|块钱|块|人民币|rmb)?',
      caseSensitive: false,
    );
    final matches = <_AmountCandidate>[];
    for (final match in pattern.allMatches(text)) {
      final raw = match.group(0) ?? '';
      final cents = Money.tryParseToCents(match.group(2) ?? '');
      if (cents == null || cents <= 0) continue;

      final after = text.substring(match.end).trimLeft();
      if (RegExp(r'^(个|人|杯|份|次|天|年|月|日|号|点|折|%|％)').hasMatch(after)) {
        continue;
      }
      final before = match.start == 0 ? '' : text[match.start - 1];
      if (RegExp(r'[\d.]').hasMatch(before)) continue;

      var score = 0;
      if (match.group(3) != null || raw.contains('¥')) score += 100;
      if ((match.group(2) ?? '').contains('.')) score += 15;
      if ((match.group(1) ?? '').isNotEmpty) score += 5;
      matches.add(
        _AmountCandidate(
          start: match.start,
          end: match.end,
          cents: cents,
          score: score,
          sign: match.group(1) ?? '',
        ),
      );
    }
    if (matches.isEmpty) return null;
    matches.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.cents.compareTo(a.cents);
    });
    final best = matches.first;
    return _AmountMatch(
      start: best.start,
      end: best.end,
      cents: best.cents,
      explicitDirection: best.sign == '+'
          ? EntryDirection.income
          : best.sign == '-'
          ? EntryDirection.expense
          : null,
    );
  }

  static String _cleanNote(String text) {
    var note = text
        .replaceAll(RegExp(r'[¥￥]'), ' ')
        .replaceAll(RegExp(r'(花了|付了|付款|支付|收到|收入|支出|消费|记一笔|记账|一笔|通过|用了)'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[，,、:：\-+]+|[，,、:：\-+]+$'), '')
        .trim();
    return note;
  }

  static String _stripAmountWords(String text) => text
      .replaceAll(RegExp(r'[¥￥]'), ' ')
      .replaceAll(RegExp(r'\d+(?:\.\d{1,2})?'), ' ')
      .replaceAll(RegExp(r'(元|块钱|块|人民币|rmb)', caseSensitive: false), ' ')
      .trim();

  static String _defaultMerchant(EntryDirection direction, String input) {
    final category = classifyCategory(_stripAmountWords(input), direction);
    return category.name;
  }
}

class _AccountMatch {
  const _AccountMatch({
    required this.account,
    required this.start,
    required this.end,
  });

  final String account;
  final int start;
  final int end;
}

class _AmountMatch {
  const _AmountMatch({
    required this.start,
    required this.end,
    required this.cents,
    required this.explicitDirection,
  });

  final int start;
  final int end;
  final int cents;
  final EntryDirection? explicitDirection;
}

class _AmountCandidate {
  const _AmountCandidate({
    required this.start,
    required this.end,
    required this.cents,
    required this.score,
    required this.sign,
  });

  final int start;
  final int end;
  final int cents;
  final int score;
  final String sign;
}
