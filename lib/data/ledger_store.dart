import 'package:sqlite3/sqlite3.dart';

import '../core/dates.dart';
import '../domain/categories.dart';
import 'ledger_entry.dart';

class ImportWriteResult {
  const ImportWriteResult({required this.inserted, required this.duplicates});

  final int inserted;
  final int duplicates;
}

class LedgerStore {
  LedgerStore._(this._db, {required this.databasePath}) {
    _db.execute('PRAGMA busy_timeout = 5000;');
    _migrate();
  }

  factory LedgerStore.open(String path) {
    final db = sqlite3.open(path);
    try {
      db.execute('PRAGMA journal_mode = WAL;');
    } on SqliteException {
      // 某些文件系统不支持 WAL，退回默认日志模式即可。
    }
    return LedgerStore._(db, databasePath: path);
  }

  factory LedgerStore.inMemory() {
    final db = sqlite3.openInMemory();
    return LedgerStore._(db, databasePath: ':memory:');
  }

  final Database _db;
  final String databasePath;

  void _migrate() {
    final version =
        _db.select('PRAGMA user_version;').first.columnAt(0) as int? ?? 0;
    if (version < 1) {
      _db.execute('''
        CREATE TABLE IF NOT EXISTS entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          occurred_at TEXT NOT NULL,
          direction INTEGER NOT NULL,
          amount_cents INTEGER NOT NULL,
          category TEXT NOT NULL,
          account TEXT NOT NULL,
          merchant TEXT NOT NULL DEFAULT '',
          note TEXT NOT NULL DEFAULT '',
          source TEXT NOT NULL DEFAULT 'manual',
          external_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
      _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_entries_occurred '
        'ON entries(occurred_at);',
      );
      _db.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_entries_external
        ON entries(source, external_id)
        WHERE external_id IS NOT NULL AND external_id <> '';
      ''');
      _db.execute('PRAGMA user_version = 1;');
    }
  }

  int insert(LedgerEntry entry) {
    _db.execute(
      '''
      INSERT INTO entries (
        occurred_at, direction, amount_cents, category, account,
        merchant, note, source, external_id, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        entry.occurredAt.toIso8601String(),
        entry.direction.storageValue,
        entry.amountCents,
        entry.category,
        entry.account,
        entry.merchant,
        entry.note,
        entry.source,
        entry.externalId,
        entry.createdAt.toIso8601String(),
        entry.updatedAt.toIso8601String(),
      ],
    );
    return _db.lastInsertRowId;
  }

  void update(LedgerEntry entry) {
    final id = entry.id;
    if (id == null) throw ArgumentError('更新账目时必须带 id');
    _db.execute(
      '''
      UPDATE entries SET
        occurred_at = ?, direction = ?, amount_cents = ?, category = ?,
        account = ?, merchant = ?, note = ?, updated_at = ?
      WHERE id = ?;
      ''',
      [
        entry.occurredAt.toIso8601String(),
        entry.direction.storageValue,
        entry.amountCents,
        entry.category,
        entry.account,
        entry.merchant,
        entry.note,
        entry.updatedAt.toIso8601String(),
        id,
      ],
    );
  }

  void delete(int id) {
    _db.execute('DELETE FROM entries WHERE id = ?;', [id]);
  }

  ImportWriteResult insertImported(List<LedgerEntry> entries, String source) {
    if (entries.isEmpty) {
      return const ImportWriteResult(inserted: 0, duplicates: 0);
    }
    final existing = <String>{};
    final rows = _db.select(
      'SELECT external_id FROM entries '
      'WHERE source = ? AND external_id IS NOT NULL;',
      [source],
    );
    for (final row in rows) {
      final value = row['external_id'] as String?;
      if (value != null && value.isNotEmpty) existing.add(value);
    }

    var inserted = 0;
    var duplicates = 0;
    _db.execute('BEGIN IMMEDIATE;');
    try {
      for (final entry in entries) {
        final externalId = entry.externalId?.trim();
        if (externalId == null || externalId.isEmpty) continue;
        if (!existing.add(externalId)) {
          duplicates++;
          continue;
        }
        insert(entry.copyWith(source: source, externalId: externalId));
        inserted++;
      }
      _db.execute('COMMIT;');
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
    return ImportWriteResult(inserted: inserted, duplicates: duplicates);
  }

  List<LedgerEntry> entriesForMonth(
    DateTime month, {
    EntryDirection? direction,
    String query = '',
  }) {
    final start = monthStart(month);
    final end = addMonths(start, 1);
    final clauses = <String>['occurred_at >= ?', 'occurred_at < ?'];
    final params = <Object?>[start.toIso8601String(), end.toIso8601String()];

    if (direction != null) {
      clauses.add('direction = ?');
      params.add(direction.storageValue);
    }
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      final like = '%$trimmed%';
      clauses.add(
        '(merchant LIKE ? OR note LIKE ? OR category LIKE ? OR account LIKE ?)',
      );
      params.addAll([like, like, like, like]);
    }
    params.add(500);

    final rows = _db.select(
      'SELECT * FROM entries WHERE ${clauses.join(' AND ')} '
      'ORDER BY occurred_at DESC, id DESC LIMIT ?;',
      params,
    );
    return rows.map(_fromRow).toList();
  }

  List<LedgerEntry> recent({int limit = 6}) {
    final rows = _db.select(
      'SELECT * FROM entries ORDER BY occurred_at DESC, id DESC LIMIT ?;',
      [limit],
    );
    return rows.map(_fromRow).toList();
  }

  List<LedgerEntry> allEntries() {
    final rows = _db.select(
      'SELECT * FROM entries ORDER BY occurred_at ASC, id ASC;',
    );
    return rows.map(_fromRow).toList();
  }

  LedgerEntry? byId(int id) {
    final rows = _db.select('SELECT * FROM entries WHERE id = ?;', [id]);
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  LedgerSummary summaryForMonth(DateTime month) {
    final start = monthStart(month);
    final end = addMonths(start, 1);
    final row = _db
        .select(
          '''
      SELECT
        COALESCE(SUM(CASE WHEN direction = 0 THEN amount_cents ELSE 0 END), 0)
          AS expense,
        COALESCE(SUM(CASE WHEN direction = 1 THEN amount_cents ELSE 0 END), 0)
          AS income,
        COUNT(*) AS count
      FROM entries WHERE occurred_at >= ? AND occurred_at < ?;
      ''',
          [start.toIso8601String(), end.toIso8601String()],
        )
        .first;
    return LedgerSummary(
      expenseCents: row['expense'] as int,
      incomeCents: row['income'] as int,
      count: row['count'] as int,
    );
  }

  List<CategoryTotal> categoryTotals(DateTime month, EntryDirection direction) {
    final start = monthStart(month);
    final end = addMonths(start, 1);
    final rows = _db.select(
      '''
      SELECT category, SUM(amount_cents) AS amount, COUNT(*) AS count
      FROM entries
      WHERE occurred_at >= ? AND occurred_at < ? AND direction = ?
      GROUP BY category
      ORDER BY amount DESC, category ASC;
      ''',
      [start.toIso8601String(), end.toIso8601String(), direction.storageValue],
    );
    return rows
        .map(
          (row) => CategoryTotal(
            category: row['category'] as String,
            amountCents: row['amount'] as int,
            count: row['count'] as int,
          ),
        )
        .toList();
  }

  List<MonthTotal> monthlyTotals(DateTime endMonth, {int count = 6}) {
    final result = <MonthTotal>[];
    for (var offset = count - 1; offset >= 0; offset--) {
      final month = addMonths(monthStart(endMonth), -offset);
      final summary = summaryForMonth(month);
      result.add(
        MonthTotal(
          month: month,
          expenseCents: summary.expenseCents,
          incomeCents: summary.incomeCents,
        ),
      );
    }
    return result;
  }

  int totalCount() {
    final row = _db.select('SELECT COUNT(*) AS count FROM entries;').first;
    return row['count'] as int;
  }

  void deleteAll() {
    _db.execute('DELETE FROM entries;');
  }

  void close() {
    _db.dispose();
  }

  LedgerEntry _fromRow(Row row) {
    final external = row['external_id'] as String?;
    return LedgerEntry(
      id: row['id'] as int,
      occurredAt: DateTime.parse(row['occurred_at'] as String),
      direction: EntryDirectionX.fromStorage(row['direction'] as int),
      amountCents: row['amount_cents'] as int,
      category: row['category'] as String,
      account: row['account'] as String,
      merchant: (row['merchant'] as String?) ?? '',
      note: (row['note'] as String?) ?? '',
      source: (row['source'] as String?) ?? 'manual',
      externalId: external == null || external.isEmpty ? null : external,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
