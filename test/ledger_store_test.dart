import 'package:flutter_test/flutter_test.dart';
import 'package:jianzhang/data/ledger_entry.dart';
import 'package:jianzhang/data/ledger_store.dart';
import 'package:jianzhang/domain/categories.dart';

void main() {
  late LedgerStore store;
  final fixedNow = DateTime(2026, 11, 4, 20);

  setUp(() {
    store = LedgerStore.inMemory();
  });

  tearDown(() {
    store.close();
  });

  LedgerEntry entry({
    required DateTime at,
    required int cents,
    required EntryDirection direction,
    String category = '餐饮',
    String account = '微信',
    String merchant = '午饭',
  }) {
    return LedgerEntry(
      occurredAt: at,
      direction: direction,
      amountCents: cents,
      category: category,
      account: account,
      merchant: merchant,
      createdAt: fixedNow,
      updatedAt: fixedNow,
    );
  }

  test('插入、汇总、分类统计', () {
    store.insert(
      entry(
        at: DateTime(2026, 11, 1, 12),
        cents: 2500,
        direction: EntryDirection.expense,
      ),
    );
    store.insert(
      entry(
        at: DateTime(2026, 11, 2, 12),
        cents: 8000,
        direction: EntryDirection.expense,
        category: '交通',
        merchant: '打车',
      ),
    );
    store.insert(
      entry(
        at: DateTime(2026, 11, 3, 12),
        cents: 1200000,
        direction: EntryDirection.income,
        category: '工资',
        merchant: '工资',
      ),
    );
    store.insert(
      entry(
        at: DateTime(2026, 10, 30, 12),
        cents: 9900,
        direction: EntryDirection.expense,
      ),
    );

    final summary = store.summaryForMonth(DateTime(2026, 11));
    expect(summary.expenseCents, 10500);
    expect(summary.incomeCents, 1200000);
    expect(summary.count, 3);

    final categories = store.categoryTotals(
      DateTime(2026, 11),
      EntryDirection.expense,
    );
    expect(categories.first.category, '交通');
    expect(categories.first.amountCents, 8000);

    final monthEntries = store.entriesForMonth(DateTime(2026, 11));
    expect(monthEntries.length, 3);
    expect(monthEntries.first.occurredAt.day, 3);

    final searched = store.entriesForMonth(DateTime(2026, 11), query: '打车');
    expect(searched.length, 1);
  });

  test('导入去重', () {
    final rows = [
      entry(
        at: DateTime(2026, 10, 1, 8),
        cents: 1800,
        direction: EntryDirection.expense,
        account: '微信',
        merchant: '肯德基',
      ).copyWith(source: 'wechat', externalId: '4200001'),
      entry(
        at: DateTime(2026, 10, 2, 9),
        cents: 20000,
        direction: EntryDirection.income,
        category: '其他',
        account: '微信',
        merchant: '张三',
      ).copyWith(source: 'wechat', externalId: '4200002'),
    ];

    final first = store.insertImported(rows, 'wechat');
    expect(first.inserted, 2);
    expect(first.duplicates, 0);

    final second = store.insertImported(rows, 'wechat');
    expect(second.inserted, 0);
    expect(second.duplicates, 2);
    expect(store.totalCount(), 2);
  });

  test('编辑与删除', () {
    final id = store.insert(
      entry(
        at: DateTime(2026, 11, 1, 12),
        cents: 2500,
        direction: EntryDirection.expense,
      ),
    );
    final saved = store.byId(id)!;
    store.update(
      saved.copyWith(
        amountCents: 3000,
        category: '购物',
        account: '支付宝',
        updatedAt: fixedNow,
      ),
    );
    final updated = store.byId(id)!;
    expect(updated.amountCents, 3000);
    expect(updated.category, '购物');

    store.delete(id);
    expect(store.byId(id), isNull);
  });

  test('近六个月趋势', () {
    store.insert(
      entry(
        at: DateTime(2026, 11, 1, 12),
        cents: 2500,
        direction: EntryDirection.expense,
      ),
    );
    final totals = store.monthlyTotals(DateTime(2026, 11));
    expect(totals.length, 6);
    expect(totals.first.month, DateTime(2026, 6));
    expect(totals.last.month, DateTime(2026, 11));
    expect(totals.last.expenseCents, 2500);
  });
}
