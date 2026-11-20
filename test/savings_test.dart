import 'package:flutter_test/flutter_test.dart';
import 'package:jianzhang/data/ledger_store.dart';
import 'package:jianzhang/domain/categories.dart';
import 'package:jianzhang/state/ledger_controller.dart';

void main() {
  test('固定月收入自动生成，重复开启不重复入账', () {
    final store = LedgerStore.inMemory();
    final controller = LedgerController(store, now: DateTime(2026, 11, 5, 12));

    expect(controller.salaryEnabled, isFalse);
    controller.saveSalarySettings(enabled: true, cents: 1200000);
    expect(controller.salaryEnabled, isTrue);
    expect(controller.salaryCents, 1200000);
    expect(controller.summary.incomeCents, 1200000);

    final november = store.entryByExternal(
      'auto_salary',
      'auto-salary:2026-11',
    );
    expect(november, isNotNull);
    expect(november!.amountCents, 1200000);
    expect(november.direction, EntryDirection.income);
    expect(november.category, '工资');

    controller.saveSalarySettings(enabled: true, cents: 1200000);
    expect(
      store.allEntries().where((entry) => entry.source == 'auto_salary').length,
      1,
    );

    final december = LedgerController(store, now: DateTime(2026, 12, 5, 12));
    expect(december.summary.incomeCents, 1200000);
    expect(
      store.entryByExternal('auto_salary', 'auto-salary:2026-12'),
      isNotNull,
    );
    expect(
      store.allEntries().where((entry) => entry.source == 'auto_salary').length,
      2,
    );

    december.saveSalarySettings(enabled: false, cents: 1200000);
    expect(december.salaryEnabled, isFalse);
    expect(
      store.allEntries().where((entry) => entry.source == 'auto_salary').length,
      2,
    );
  });

  test('存钱目标与口号写入设置并在新控制器中恢复', () {
    final store = LedgerStore.inMemory();
    final controller = LedgerController(store, now: DateTime(2026, 11, 5, 12));
    controller.setMonthGoal(500000);
    controller.setYearGoal(6000000);
    controller.setSavingsSlogan('存够钱买手机');

    expect(controller.monthGoalCents, 500000);
    expect(controller.yearGoalCents, 6000000);
    expect(controller.savingsSlogan, '存够钱买手机');

    final restored = LedgerController(store, now: DateTime(2026, 11, 5, 12));
    expect(restored.monthGoalCents, 500000);
    expect(restored.yearGoalCents, 6000000);
    expect(restored.savingsSlogan, '存够钱买手机');
  });
}
