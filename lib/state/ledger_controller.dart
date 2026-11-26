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
    _loadSettings();
    _ensureAutoSalary(now ?? DateTime.now());
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
  LedgerSummary _currentSummary = const LedgerSummary(
    expenseCents: 0,
    incomeCents: 0,
    count: 0,
  );
  List<CategoryTotal> _expenseCategoryTotals = const [];
  List<CategoryTotal> _incomeCategoryTotals = const [];
  List<MonthTotal> _trend = const [];
  int _totalCount = 0;
  int _currentYearNetCents = 0;

  bool _salaryEnabled = false;
  int _salaryCents = 0;
  String? _salaryStartMonth;
  String? _salaryLastMonth;
  int _monthGoalCents = 0;
  int _yearGoalCents = 0;
  String _savingsSlogan = '';
  String _lastEntryMode = 'quick';

  DateTime get selectedMonth => _selectedMonth;
  EntryDirection? get filter => _filter;
  String get search => _search;
  List<LedgerEntry> get monthEntries => _monthEntries;
  List<LedgerEntry> get allMonthEntries => _allMonthEntries;
  List<LedgerEntry> get recentEntries => _recentEntries;
  LedgerSummary get summary => _summary;
  LedgerSummary get currentSummary => _currentSummary;
  List<CategoryTotal> get expenseCategoryTotals => _expenseCategoryTotals;
  List<CategoryTotal> get incomeCategoryTotals => _incomeCategoryTotals;
  List<CategoryTotal> categoryTotalsFor(EntryDirection direction) =>
      direction == EntryDirection.expense
      ? _expenseCategoryTotals
      : _incomeCategoryTotals;
  List<MonthTotal> get trend => _trend;
  int get totalCount => _totalCount;

  DateTime get currentMonth => monthStart(DateTime.now());
  int get currentMonthNetCents => _currentSummary.netCents;
  int get currentYearNetCents => _currentYearNetCents;
  int get monthGoalCents => _monthGoalCents;
  int get yearGoalCents => _yearGoalCents;
  String get savingsSlogan => _savingsSlogan;
  String get lastEntryMode => _lastEntryMode;
  bool get salaryEnabled => _salaryEnabled;
  int get salaryCents => _salaryCents;

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
    final now = DateTime.now();
    _currentSummary = isSameMonth(_selectedMonth, now)
        ? _summary
        : store.summaryForMonth(now);
    _currentYearNetCents = store.summaryForYear(now.year).netCents;
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

  void setMonthGoal(int cents) {
    _monthGoalCents = cents < 0 ? 0 : cents;
    store.writeSetting('savings.monthGoalCents', '$_monthGoalCents');
    notifyListeners();
  }

  void setYearGoal(int cents) {
    _yearGoalCents = cents < 0 ? 0 : cents;
    store.writeSetting('savings.yearGoalCents', '$_yearGoalCents');
    notifyListeners();
  }

  void setSavingsSlogan(String value) {
    final slogan = value.trim();
    _savingsSlogan = slogan.length > 40 ? slogan.substring(0, 40) : slogan;
    store.writeSetting('savings.slogan', _savingsSlogan);
    notifyListeners();
  }

  void setLastEntryMode(String mode) {
    if (mode != 'quick' && mode != 'detailed') return;
    _lastEntryMode = mode;
    store.writeSetting('entry.lastMode', mode);
  }

  void saveSalarySettings({required bool enabled, required int cents}) {
    final now = DateTime.now();
    final currentMonth = monthStart(now);
    _salaryEnabled = enabled;
    _salaryCents = cents < 0 ? 0 : cents;
    store.writeSetting('salary.enabled', enabled ? '1' : '0');
    store.writeSetting('salary.cents', '$_salaryCents');

    if (enabled) {
      if (_salaryStartMonth == null) {
        _salaryStartMonth = _monthKey(currentMonth);
        store.writeSetting('salary.startMonth', _salaryStartMonth!);
      }
      final key = 'auto-salary:${_monthKey(currentMonth)}';
      final existing = store.entryByExternal('auto_salary', key);
      if (existing != null && cents > 0) {
        store.update(existing.copyWith(amountCents: cents, updatedAt: now));
      }
      _ensureAutoSalary(now);
    } else {
      // 关闭后不补记停用期间的月份；已生成的收入保留。
      _salaryLastMonth = _monthKey(currentMonth);
      store.writeSetting('salary.lastMonth', _salaryLastMonth!);
    }
    refresh();
  }

  void _loadSettings() {
    _salaryEnabled = store.readSetting('salary.enabled') == '1';
    _salaryCents = int.tryParse(store.readSetting('salary.cents') ?? '') ?? 0;
    _salaryStartMonth = store.readSetting('salary.startMonth');
    _salaryLastMonth = store.readSetting('salary.lastMonth');
    _monthGoalCents =
        int.tryParse(store.readSetting('savings.monthGoalCents') ?? '') ?? 0;
    _yearGoalCents =
        int.tryParse(store.readSetting('savings.yearGoalCents') ?? '') ?? 0;
    _savingsSlogan = store.readSetting('savings.slogan') ?? '';
    _lastEntryMode = store.readSetting('entry.lastMode') ?? 'quick';
  }

  void _ensureAutoSalary(DateTime now) {
    if (!_salaryEnabled || _salaryCents <= 0) return;
    final current = monthStart(now);
    final start = _parseMonthKey(_salaryStartMonth) ?? current;
    var cursor = _salaryLastMonth == null
        ? start
        : addMonths(_parseMonthKey(_salaryLastMonth!) ?? start, 1);
    if (cursor.isBefore(start)) cursor = start;
    var generated = 0;
    while (!cursor.isAfter(current) && generated < 36) {
      final key = 'auto-salary:${_monthKey(cursor)}';
      if (store.entryByExternal('auto_salary', key) == null) {
        store.insert(
          LedgerEntry(
            occurredAt: DateTime(cursor.year, cursor.month, 1, 9),
            direction: EntryDirection.income,
            amountCents: _salaryCents,
            category: '工资',
            account: '银行卡',
            merchant: '固定收入',
            note: '每月自动计入',
            source: 'auto_salary',
            externalId: key,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      _salaryLastMonth = _monthKey(cursor);
      store.writeSetting('salary.lastMonth', _salaryLastMonth!);
      cursor = addMonths(cursor, 1);
      generated++;
    }
  }

  static DateTime? _parseMonthKey(String? value) {
    if (value == null) return null;
    final parts = value.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return DateTime(year, month);
  }

  static String _monthKey(DateTime month) =>
      '${month.year.toString().padLeft(4, '0')}-'
      '${month.month.toString().padLeft(2, '0')}';

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
