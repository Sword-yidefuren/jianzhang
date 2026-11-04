import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../data/ledger_entry.dart';
import '../data/ledger_store.dart';
import '../domain/bill_importer.dart';
import '../domain/categories.dart';
import '../domain/quick_parser.dart';

class ImportPlan {
  const ImportPlan({
    required this.results,
    required this.entries,
    required this.duplicateCount,
  });

  final List<BillParseResult> results;
  final List<LedgerEntry> entries;
  final int duplicateCount;

  int get expenseCents => entries
      .where((entry) => entry.direction == EntryDirection.expense)
      .fold(0, (sum, entry) => sum + entry.amountCents);

  int get incomeCents => entries
      .where((entry) => entry.direction == EntryDirection.income)
      .fold(0, (sum, entry) => sum + entry.amountCents);

  int get skippedRows =>
      results.fold(0, (sum, result) => sum + result.skippedRows);
}

class LedgerController extends ChangeNotifier {
  LedgerController(this.store, {DateTime? now})
    : _selectedMonth = monthStart(now ?? DateTime.now()) {
    refresh();
  }

  final LedgerStore store;

  DateTime _selectedMonth;
  EntryDirection? _filter;
  String _search = '';

  List<LedgerEntry> _monthEntries = const [];
  List<LedgerEntry> _allMonthEntries = const [];
  List<LedgerEntry> _recentEntries = const [];
  LedgerSummary _summary = const LedgerSummary(
    expenseCents: 0,
    incomeCents: 0,
    count: 0,
  );
  List<CategoryTotal> _expenseCategoryTotals = const [];
  List<CategoryTotal> _incomeCategoryTotals = const [];
  List<MonthTotal> _trend = const [];
  int _totalCount = 0;

  DateTime get selectedMonth => _selectedMonth;
  EntryDirection? get filter => _filter;
  String get search => _search;
  List<LedgerEntry> get monthEntries => _monthEntries;
  List<LedgerEntry> get allMonthEntries => _allMonthEntries;
  List<LedgerEntry> get recentEntries => _recentEntries;
  LedgerSummary get summary => _summary;
  List<CategoryTotal> get expenseCategoryTotals => _expenseCategoryTotals;
  List<CategoryTotal> get incomeCategoryTotals => _incomeCategoryTotals;
  List<CategoryTotal> categoryTotalsFor(EntryDirection direction) =>
      direction == EntryDirection.expense
      ? _expenseCategoryTotals
      : _incomeCategoryTotals;
  List<MonthTotal> get trend => _trend;
  int get totalCount => _totalCount;

  bool get isCurrentMonth => isSameMonth(_selectedMonth, DateTime.now());

  void refresh() {
    _allMonthEntries = store.entriesForMonth(_selectedMonth);
    _monthEntries = (_filter == null && _search.trim().isEmpty)
        ? _allMonthEntries
        : store.entriesForMonth(
            _selectedMonth,
            direction: _filter,
            query: _search,
          );
    _recentEntries = store.recent(limit: 5);
    _summary = store.summaryForMonth(_selectedMonth);
    _expenseCategoryTotals = store.categoryTotals(
      _selectedMonth,
      EntryDirection.expense,
    );
    _incomeCategoryTotals = store.categoryTotals(
      _selectedMonth,
      EntryDirection.income,
    );
    _trend = store.monthlyTotals(_selectedMonth);
    _totalCount = store.totalCount();
    notifyListeners();
  }

  void shiftMonth(int delta) {
    _selectedMonth = addMonths(_selectedMonth, delta);
    refresh();
  }

  void goToMonth(DateTime month) {
    _selectedMonth = monthStart(month);
    refresh();
  }

  void setFilter(EntryDirection? direction) {
    if (_filter == direction) return;
    _filter = direction;
    refresh();
  }

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    refresh();
  }

  void clearFilters() {
    _filter = null;
    _search = '';
    refresh();
  }

  int addParsed(ParsedEntry parsed) {
    final now = DateTime.now();
    final entry = LedgerEntry(
      occurredAt: parsed.occurredAt,
      direction: parsed.direction,
      amountCents: parsed.amountCents,
      category: parsed.category,
      account: parsed.account,
      merchant: parsed.merchant,
      note: parsed.note,
      source: 'manual',
      createdAt: now,
      updatedAt: now,
    );
    final id = store.insert(entry);
    if (!isSameMonth(parsed.occurredAt, _selectedMonth)) {
      _selectedMonth = monthStart(parsed.occurredAt);
    }
    refresh();
    return id;
  }

  int addManual({
    required DateTime occurredAt,
    required EntryDirection direction,
    required int amountCents,
    required String category,
    required String account,
    String merchant = '',
    String note = '',
  }) {
    final now = DateTime.now();
    final id = store.insert(
      LedgerEntry(
        occurredAt: occurredAt,
        direction: direction,
        amountCents: amountCents,
        category: category,
        account: account,
        merchant: merchant.trim(),
        note: note.trim(),
        source: 'manual',
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (!isSameMonth(occurredAt, _selectedMonth)) {
      _selectedMonth = monthStart(occurredAt);
    }
    refresh();
    return id;
  }

  void updateEntry(LedgerEntry entry) {
    store.update(entry.copyWith(updatedAt: DateTime.now()));
    refresh();
  }

  void deleteEntry(int id) {
    store.delete(id);
    refresh();
  }

  ImportPlan buildImportPlan(List<BillParseResult> results) {
    final existing = store.externalKeys();
    final seen = <String>{};
    final entries = <LedgerEntry>[];
    var duplicates = 0;
    for (final result in results) {
      for (final entry in result.entries) {
        final key = '${entry.source}|${entry.externalId}';
        if (existing.contains(key) || !seen.add(key)) {
          duplicates++;
        } else {
          entries.add(entry);
        }
      }
    }
    return ImportPlan(
      results: results,
      entries: entries,
      duplicateCount: duplicates,
    );
  }

  ImportWriteResult importPlan(ImportPlan plan) {
    final grouped = <String, List<LedgerEntry>>{};
    for (final entry in plan.entries) {
      grouped.putIfAbsent(entry.source, () => []).add(entry);
    }
    var inserted = 0;
    var duplicates = 0;
    for (final item in grouped.entries) {
      final result = store.insertImported(item.value, item.key);
      inserted += result.inserted;
      duplicates += result.duplicates;
    }
    refresh();
    return ImportWriteResult(inserted: inserted, duplicates: duplicates);
  }

  void clearAll() {
    store.deleteAll();
    refresh();
  }

  @override
  void dispose() {
    store.close();
    super.dispose();
  }
}
