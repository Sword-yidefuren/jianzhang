import 'package:flutter_test/flutter_test.dart';
import 'package:jianzhang/core/money.dart';
import 'package:jianzhang/domain/categories.dart';
import 'package:jianzhang/domain/quick_parser.dart';

void main() {
  final now = DateTime(2026, 11, 4, 19, 40);

  ParsedEntry parse(String input) {
    final result = QuickParser.parse(input, now: now);
    expect(result, isNotNull, reason: '应该能解析：$input');
    return result!;
  }

  group('金额', () {
    test('整数与小数', () {
      expect(Money.tryParseToCents('25'), 2500);
      expect(Money.tryParseToCents('25.5'), 2550);
      expect(Money.tryParseToCents('¥1,280.08'), 128008);
      expect(Money.tryParseToCents('12元'), 1200);
      expect(Money.tryParseToCents('abc'), isNull);
    });

    test('格式化', () {
      expect(Money.format(2500), '¥25');
      expect(Money.format(2550), '¥25.50');
      expect(Money.format(128008), '¥1,280.08');
      expect(Money.format(-1200), '-¥12');
    });
  });

  group('一句话解析', () {
    test('午饭 25', () {
      final entry = parse('午饭 25');
      expect(entry.amountCents, 2500);
      expect(entry.direction, EntryDirection.expense);
      expect(entry.category, '餐饮');
      expect(entry.account, '其他');
      expect(entry.merchant, '午饭');
    });

    test('打车 18.5 支付宝', () {
      final entry = parse('打车 18.5 支付宝');
      expect(entry.amountCents, 1850);
      expect(entry.direction, EntryDirection.expense);
      expect(entry.category, '交通');
      expect(entry.account, '支付宝');
    });

    test('昨天 超市 128 微信', () {
      final entry = parse('昨天 超市 128 微信');
      expect(entry.occurredAt, DateTime(2026, 11, 3, 12));
      expect(entry.category, '购物');
      expect(entry.account, '微信');
    });

    test('工资 12000', () {
      final entry = parse('工资 12000');
      expect(entry.direction, EntryDirection.income);
      expect(entry.category, '工资');
      expect(entry.amountCents, 1200000);
    });

    test('收到退款 99', () {
      final entry = parse('收到退款 99');
      expect(entry.direction, EntryDirection.income);
      expect(entry.category, '退款');
    });

    test('发红包 200 是支出，收红包 200 是收入', () {
      final sent = parse('发红包 200');
      expect(sent.direction, EntryDirection.expense);
      expect(sent.category, '人情');

      final received = parse('收红包 200');
      expect(received.direction, EntryDirection.income);
      expect(received.category, '红包');
    });

    test('11月3日 房租 2800', () {
      final entry = parse('11月3日 房租 2800');
      expect(entry.occurredAt, DateTime(2026, 11, 3, 12));
      expect(entry.category, '居住');
    });

    test('显式正负号', () {
      expect(parse('+200 红包').direction, EntryDirection.income);
      expect(parse('-35 咖啡').direction, EntryDirection.expense);
    });

    test('请客 300 现金', () {
      final entry = parse('请客 300 现金');
      expect(entry.category, '人情');
      expect(entry.account, '现金');
    });

    test('常见分类', () {
      expect(parse('星巴克 32').category, '餐饮');
      expect(parse('加油 300').category, '交通');
      expect(parse('话费 100').category, '通讯');
      expect(parse('医院 200').category, '医疗');
      expect(parse('电影 45').category, '娱乐');
      expect(parse('买书 50').category, '学习');
      expect(parse('基金收益 88').direction, EntryDirection.income);
      expect(parse('基金收益 88').category, '理财');
    });

    test('跳过人数，取真正的金额', () {
      final entry = parse('3个人午饭75');
      expect(entry.amountCents, 7500);
      expect(entry.category, '餐饮');
    });

    test('带时间', () {
      final entry = parse('今天 12:30 午饭 25');
      expect(entry.occurredAt, DateTime(2026, 11, 4, 12, 30));
    });

    test('没有金额返回 null', () {
      expect(QuickParser.parse('今天心情不错', now: now), isNull);
    });

    test('全角数字', () {
      final entry = parse('午饭 ２５');
      expect(entry.amountCents, 2500);
    });
  });
}
