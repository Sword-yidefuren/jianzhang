import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianzhang/app.dart';
import 'package:jianzhang/data/ledger_entry.dart';
import 'package:jianzhang/data/ledger_store.dart';
import 'package:jianzhang/domain/categories.dart';
import 'package:jianzhang/state/ledger_controller.dart';
import 'package:jianzhang/ui/widgets/quick_entry.dart';

LedgerController _controller({bool withData = true}) {
  final store = LedgerStore.inMemory();
  final now = DateTime(2026, 11, 5, 12);
  if (withData) {
    final items = [
      ('餐饮', 3250, EntryDirection.expense, '微信', '老乡鸡', '午饭'),
      ('居住', 320000, EntryDirection.expense, '银行卡', '', '房租'),
      ('工资', 1200000, EntryDirection.income, '银行卡', '', '工资'),
      ('购物', 12860, EntryDirection.expense, '微信', '盒马', '日用品'),
    ];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      store.insert(
        LedgerEntry(
          occurredAt: now.subtract(Duration(days: i)),
          direction: item.$3,
          amountCents: item.$2,
          category: item.$1,
          account: item.$4,
          merchant: item.$5,
          note: item.$6,
          source: 'manual',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }
  return LedgerController(store, now: now);
}

Future<void> _pumpApp(
  WidgetTester tester,
  LedgerController controller, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(JianzhangApp(controller: controller));
  await tester.pumpAndSettle();
}

void _expectNoLayoutError(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('桌面端四个页面都能切换且不溢出', (tester) async {
    final controller = _controller();
    await _pumpApp(tester, controller, size: const Size(1280, 820));

    expect(find.text('本月概览'), findsOneWidget);
    expect(find.textContaining('最大头是居住'), findsOneWidget);
    _expectNoLayoutError(tester);

    await tester.tap(find.text('统计').first);
    await tester.pumpAndSettle();
    expect(find.text('INSIGHTS'), findsOneWidget);
    _expectNoLayoutError(tester);

    await tester.tap(find.text('存钱').first);
    await tester.pumpAndSettle();
    expect(find.text('SAVINGS'), findsOneWidget);
    _expectNoLayoutError(tester);

    await tester.tap(find.text('设置').first);
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    _expectNoLayoutError(tester);
  });

  testWidgets('手机端四个页面和中间加号都在且不溢出', (tester) async {
    final controller = _controller();
    await _pumpApp(tester, controller, size: const Size(430, 900));

    expect(find.text('本月概览'), findsOneWidget);
    expect(find.byKey(const Key('add-entry')), findsOneWidget);
    _expectNoLayoutError(tester);

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    expect(find.text('INSIGHTS'), findsOneWidget);
    _expectNoLayoutError(tester);

    await tester.tap(find.text('存钱'));
    await tester.pumpAndSettle();
    expect(find.text('SAVINGS'), findsOneWidget);
    _expectNoLayoutError(tester);

    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('SETTINGS'), findsOneWidget);
    _expectNoLayoutError(tester);
  });

  testWidgets('首页显示存钱目标进度，存钱页可查看目标', (tester) async {
    final controller = _controller();
    controller.setMonthGoal(1000000);
    controller.setSavingsSlogan('存够钱买手机');
    await _pumpApp(tester, controller, size: const Size(430, 900));

    expect(find.textContaining('离目标还差'), findsOneWidget);
    _expectNoLayoutError(tester);

    await tester.tap(find.text('存钱'));
    await tester.pumpAndSettle();
    expect(find.text('SAVINGS'), findsOneWidget);
    expect(find.text('存够钱买手机'), findsOneWidget);
    expect(find.text('存钱目标'), findsOneWidget);
    expect(find.text('本月目标'), findsOneWidget);
    _expectNoLayoutError(tester);
  });

  testWidgets('加号打开面板，一句话记账直接入账', (tester) async {
    final controller = _controller(withData: false);
    await _pumpApp(tester, controller, size: const Size(430, 900));

    await tester.tap(find.byKey(const Key('add-entry')));
    await tester.pumpAndSettle();
    expect(find.text('记一笔'), findsOneWidget);
    expect(find.text('简单记'), findsOneWidget);
    expect(find.text('详细记'), findsOneWidget);

    final entryField = find.descendant(
      of: find.byType(QuickEntry),
      matching: find.byType(TextField),
    );
    await tester.enterText(entryField, '午饭 25 微信');
    await tester.pumpAndSettle();
    expect(find.textContaining('餐饮'), findsWidgets);

    await tester.tap(find.byTooltip('记下'));
    await tester.pumpAndSettle();

    expect(controller.totalCount, 1);
    final entry = controller.recentEntries.first;
    expect(entry.amountCents, 2500);
    expect(entry.category, '餐饮');
    expect(entry.account, '微信');
    expect(find.textContaining('已记下'), findsOneWidget);
    _expectNoLayoutError(tester);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('已记下'), findsNothing);
  });

  testWidgets('详细面板可以切换，并记住上次模式', (tester) async {
    final controller = _controller(withData: false);
    await _pumpApp(tester, controller, size: const Size(430, 900));

    await tester.tap(find.byKey(const Key('add-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('详细记'));
    await tester.pumpAndSettle();
    expect(find.text('记下 支出'), findsOneWidget);
    expect(controller.lastEntryMode, 'detailed');
    _expectNoLayoutError(tester);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-entry')));
    await tester.pumpAndSettle();
    expect(find.text('记下 支出'), findsOneWidget);
    expect(find.text('详细记'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    _expectNoLayoutError(tester);
  });

  testWidgets('统计页可以切到年度视图', (tester) async {
    final controller = _controller();
    await _pumpApp(tester, controller, size: const Size(430, 900));

    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('年'));
    await tester.pumpAndSettle();
    expect(find.text('全年趋势'), findsOneWidget);
    expect(find.textContaining('年支出'), findsWidgets);
    _expectNoLayoutError(tester);
  });
}
