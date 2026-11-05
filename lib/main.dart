import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'app.dart';
import 'data/ledger_entry.dart';
import 'data/ledger_store.dart';
import 'domain/categories.dart';
import 'state/ledger_controller.dart';
import 'ui/theme.dart';

const _databaseOverride = String.fromEnvironment('JIANZHANG_DB_PATH');
const _seedDemo = bool.fromEnvironment('JIANZHANG_SEED_DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.card,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  Object? lastError;
  StackTrace? lastStack;
  for (final path in await _databasePaths()) {
    try {
      File(path).parent.createSync(recursive: true);
      final store = LedgerStore.open(path);
      if (_seedDemo && store.totalCount() == 0) {
        _insertDemoEntries(store, DateTime.now());
      }
      runApp(JianzhangApp(controller: LedgerController(store)));
      return;
    } catch (error, stack) {
      lastError = error;
      lastStack = stack;
      if (!_isAccessFailure(error)) break;
    }
  }

  final error = lastError ?? StateError('没有可用的数据目录');
  try {
    final file = File(
      p.join(Directory.systemTemp.path, 'jianzhang-startup-error.txt'),
    );
    file.writeAsStringSync('$error\n\n${lastStack ?? ''}');
  } catch (_) {
    // Nothing else we can do if even the temp directory is unavailable.
  }
  runApp(_StartupErrorApp(error: error));
}

Future<List<String>> _databasePaths() async {
  if (_databaseOverride.isNotEmpty) return [_databaseOverride];

  final paths = <String>[];
  try {
    final support = await getApplicationSupportDirectory();
    paths.add(p.join(support.path, 'jianzhang.sqlite'));
  } catch (_) {
    // Fall through to the portable locations below.
  }
  if (Platform.isWindows) {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    paths.add(p.join(exeDir, 'data', 'jianzhang.sqlite'));
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      paths.add(p.join(localAppData, 'Sword', 'jianzhang', 'jianzhang.sqlite'));
    }
  }
  paths.add(p.join(Directory.systemTemp.path, 'jianzhang', 'jianzhang.sqlite'));
  return paths;
}

bool _isAccessFailure(Object error) {
  if (error is FileSystemException) return true;
  if (error is SqliteException) {
    final code = error.resultCode;
    return code == 5 || code == 8 || code == 14;
  }
  return false;
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storage_rounded,
                    size: 40,
                    color: AppColors.expense,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '账本打不开',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '请确认应用数据目录可写，然后重新打开。',
                    style: TextStyle(fontSize: 11, color: AppColors.faint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Development-only sample data used to preview the UI with a realistic month.
void _insertDemoEntries(LedgerStore store, DateTime now) {
  final stamp = now;
  void add({
    required DateTime at,
    required EntryDirection direction,
    required int cents,
    required String category,
    required String account,
    String merchant = '',
    String note = '',
    String source = 'manual',
  }) {
    store.insert(
      LedgerEntry(
        occurredAt: at,
        direction: direction,
        amountCents: cents,
        category: category,
        account: account,
        merchant: merchant,
        note: note,
        source: source,
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
  }

  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);

  add(
    at: thisMonth.add(const Duration(hours: 9)),
    direction: EntryDirection.income,
    cents: 1200000,
    category: '工资',
    account: '银行卡',
    note: '本月工资',
  );
  add(
    at: thisMonth.add(const Duration(hours: 10)),
    direction: EntryDirection.expense,
    cents: 320000,
    category: '居住',
    account: '银行卡',
    note: '房租',
  );
  add(
    at: thisMonth.add(const Duration(days: 1, hours: 12, minutes: 20)),
    direction: EntryDirection.expense,
    cents: 3250,
    category: '餐饮',
    account: '微信',
    merchant: '老乡鸡',
    note: '午饭',
    source: 'wechat',
  );
  add(
    at: thisMonth.add(const Duration(days: 2, hours: 9, minutes: 10)),
    direction: EntryDirection.expense,
    cents: 1800,
    category: '餐饮',
    account: '支付宝',
    merchant: 'Manner',
    note: '咖啡',
    source: 'alipay',
  );
  add(
    at: thisMonth.add(const Duration(days: 3, hours: 8, minutes: 45)),
    direction: EntryDirection.expense,
    cents: 600,
    category: '交通',
    account: '支付宝',
    merchant: '地铁',
    source: 'alipay',
  );
  add(
    at: thisMonth.add(const Duration(days: 3, hours: 19, minutes: 5)),
    direction: EntryDirection.expense,
    cents: 12860,
    category: '购物',
    account: '微信',
    merchant: '盒马',
    note: '日用品',
    source: 'wechat',
  );
  add(
    at: thisMonth.add(const Duration(days: 3, hours: 21)),
    direction: EntryDirection.income,
    cents: 20000,
    category: '人情',
    account: '微信',
    note: '红包',
    source: 'wechat',
  );

  add(
    at: lastMonth.add(const Duration(days: 4, hours: 10)),
    direction: EntryDirection.expense,
    cents: 280000,
    category: '居住',
    account: '银行卡',
    note: '房租',
  );
  add(
    at: lastMonth.add(const Duration(days: 7, hours: 18, minutes: 30)),
    direction: EntryDirection.expense,
    cents: 42000,
    category: '餐饮',
    account: '微信',
    merchant: '朋友聚餐',
    source: 'wechat',
  );
  add(
    at: lastMonth.add(const Duration(days: 11, hours: 22)),
    direction: EntryDirection.expense,
    cents: 8900,
    category: '交通',
    account: '支付宝',
    merchant: '滴滴',
    source: 'alipay',
  );
  add(
    at: lastMonth.add(const Duration(days: 17, hours: 15)),
    direction: EntryDirection.income,
    cents: 50000,
    category: '兼职',
    account: '支付宝',
    note: '稿费',
    source: 'alipay',
  );
  add(
    at: lastMonth.add(const Duration(days: 21, hours: 16)),
    direction: EntryDirection.expense,
    cents: 39900,
    category: '购物',
    account: '支付宝',
    merchant: '运动鞋',
    source: 'alipay',
  );
}
