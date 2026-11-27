import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jianzhang/app.dart';
import 'package:jianzhang/data/ledger_store.dart';
import 'package:jianzhang/state/ledger_controller.dart';

void main() {
  testWidgets('首页能启动并打开一句话输入', (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = LedgerController(
      LedgerStore.inMemory(),
      now: DateTime(2026, 11, 4),
    );
    await tester.pumpWidget(JianzhangApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('本月概览'), findsOneWidget);
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.byKey(const Key('add-entry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-entry')));
    await tester.pumpAndSettle();
    expect(find.text('一句话记账'), findsOneWidget);
    expect(find.textContaining('例如：午饭'), findsOneWidget);
  });
}
