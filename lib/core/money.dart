/// 金额在数据库里一律存“分”，这里只负责整数与显示之间的转换。
class Money {
  const Money._();

  static int? tryParseToCents(String raw) {
    var text = raw
        .replaceAll('，', ',')
        .replaceAll('￥', '¥')
        .replaceAll(' ', '')
        .replaceAll(',', '')
        .replaceAll('元', '')
        .replaceAll('块', '')
        .replaceAll('钱', '')
        .replaceAll('¥', '');
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
    if (match == null) return null;
    final yuan = int.tryParse(match.group(1) ?? '');
    if (yuan == null) return null;
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    final cents = int.tryParse(fraction) ?? 0;
    return yuan * 100 + cents;
  }

  static String format(int cents, {bool symbol = true}) {
    final negative = cents < 0;
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fraction = abs % 100;
    final grouped = _groupDigits(yuan.toString());
    final body = fraction == 0
        ? grouped
        : '$grouped.${fraction.toString().padLeft(2, '0')}';
    return '${negative ? '-' : ''}${symbol ? '¥' : ''}$body';
  }

  static String inputValue(int cents) {
    final yuan = cents ~/ 100;
    final fraction = cents % 100;
    if (fraction == 0) return yuan.toString();
    return '$yuan.${fraction.toString().padLeft(2, '0')}';
  }

  static String _groupDigits(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
