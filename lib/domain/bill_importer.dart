import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:gbk_codec/gbk_codec.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../data/ledger_entry.dart';
import 'categories.dart';

enum BillSource { wechat, alipay }

extension BillSourceX on BillSource {
  String get id => this == BillSource.wechat ? 'wechat' : 'alipay';
  String get label => this == BillSource.wechat ? '微信支付' : '支付宝';
  String get account => this == BillSource.wechat ? '微信' : '支付宝';
}

class BillImportException implements Exception {
  const BillImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BillParseResult {
  const BillParseResult({
    required this.fileName,
    required this.source,
    required this.entries,
    required this.totalRows,
    required this.skippedRows,
  });

  final String fileName;
  final BillSource source;
  final List<LedgerEntry> entries;
  final int totalRows;
  final int skippedRows;

  int get importableCount => entries.length;
  int get expenseCents => entries
      .where((entry) => entry.direction == EntryDirection.expense)
      .fold(0, (sum, entry) => sum + entry.amountCents);
  int get incomeCents => entries
      .where((entry) => entry.direction == EntryDirection.income)
      .fold(0, (sum, entry) => sum + entry.amountCents);
}

/// 只解析官方账单导出的 CSV，不联网、不落原文件。
class BillImporter {
  const BillImporter._();

  static BillParseResult parseBytes(
    Uint8List bytes, {
    required String fileName,
    DateTime? now,
  }) {
    if (bytes.isEmpty) {
      throw const BillImportException('文件是空的');
    }
    final text = _decode(bytes);
    final source = _detectSource(text);
    final header = _findHeader(text, source);
    if (header == null) {
      throw const BillImportException('找不到账单表头，请确认是微信/支付宝导出的 CSV');
    }

    final lines = text.split(RegExp(r'\r?\n'));
    final section = lines.sublist(header.lineIndex).join('\n');
    final rows = Csv(
      fieldDelimiter: ',',
      autoDetect: false,
      skipEmptyLines: true,
    ).decode(section);
    if (rows.length < 2) {
      throw const BillImportException('账单里没有可读取的交易行');
    }

    final headers = rows.first
        .map((cell) => _normalizeHeader(cell.toString()))
        .toList();
    final index = _ColumnIndex(headers, source);
    if (!index.isUsable) {
      throw BillImportException('账单缺少必要列：${index.missing.join('、')}');
    }

    final timestamp = now ?? DateTime.now();
    final entries = <LedgerEntry>[];
    var totalRows = 0;
    var skippedRows = 0;

    for (final row in rows.skip(1)) {
      final cells = row.map((cell) => cell.toString().trim()).toList();
      if (cells.length <= index.time) continue;
      final occurredAt = parseBillDate(cells[index.time]);
      if (occurredAt == null) continue;
      totalRows++;

      final direction = _parseDirection(index.value(cells, index.direction));
      final amount = Money.tryParseToCents(index.value(cells, index.amount));
      if (direction == null || amount == null || amount <= 0) {
        skippedRows++;
        continue;
      }

      final status = index.value(cells, index.status);
      if (_isClosedStatus(status)) {
        skippedRows++;
        continue;
      }

      final merchant = index.value(cells, index.merchant);
      final product = index.value(cells, index.product);
      final type = index.value(cells, index.type);
      final remark = index.value(cells, index.remark);
      final externalRaw = index.value(cells, index.externalId);
      final externalId = externalRaw.isEmpty
          ? _fallbackExternalId(source, occurredAt, amount, merchant, product)
          : externalRaw;

      final category = classifyCategory(
        '$merchant $product $type $remark',
        direction,
      );
      final noteParts = <String>[
        if (product.isNotEmpty && product != '/') product,
        if (remark.isNotEmpty && remark != '/') remark,
      ];

      entries.add(
        LedgerEntry(
          occurredAt: occurredAt,
          direction: direction,
          amountCents: amount,
          category: category.name,
          account: source.account,
          merchant: merchant == '/' ? '' : merchant,
          note: noteParts.join(' · '),
          source: source.id,
          externalId: externalId,
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      );
    }

    return BillParseResult(
      fileName: fileName,
      source: source,
      entries: entries,
      totalRows: totalRows,
      skippedRows: skippedRows,
    );
  }

  static String _decode(Uint8List bytes) {
    var data = bytes;
    if (data.length >= 3 &&
        data[0] == 0xEF &&
        data[1] == 0xBB &&
        data[2] == 0xBF) {
      data = data.sublist(3);
    }
    try {
      final text = utf8.decode(data);
      if (!text.contains('\uFFFD')) return text;
    } on FormatException {
      // 继续尝试 GBK。
    }
    try {
      final text = gbk_bytes.decode(data);
      if (text.contains('\uFFFD')) {
        throw const BillImportException('账单编码无法识别，请导出 CSV 后重试');
      }
      return text;
    } catch (_) {
      throw const BillImportException('账单编码无法识别，请导出 CSV 后重试');
    }
  }

  static BillSource _detectSource(String text) {
    final head = text.length > 4000 ? text.substring(0, 4000) : text;
    final wechatScore = [
      '微信支付账单',
      '微信昵称',
      '微信支付',
      '商户单号',
    ].where(head.contains).length;
    final alipayScore = [
      '支付宝',
      '交易创建时间',
      '商家订单号',
      '支付宝交易记录',
    ].where(head.contains).length;
    if (wechatScore == 0 && alipayScore == 0) {
      throw const BillImportException('认不出这是微信还是支付宝的账单');
    }
    return wechatScore >= alipayScore ? BillSource.wechat : BillSource.alipay;
  }

  static _HeaderLocation? _findHeader(String text, BillSource source) {
    final lines = text.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final normalized = _normalizeHeader(lines[i]);
      final hasTime =
          normalized.contains('交易时间') ||
          normalized.contains('交易创建时间') ||
          normalized.contains('付款时间');
      final hasAmount =
          normalized.contains('金额(元)') || normalized.contains('金额');
      final hasDirection = normalized.contains('收/支');
      if (hasTime && hasAmount && hasDirection) {
        return _HeaderLocation(i);
      }
    }
    return null;
  }

  static String _normalizeHeader(String value) => value
      .replaceAll('\uFEFF', '')
      .replaceAll('（', '(')
      .replaceAll('）', ')')
      .replaceAll(' ', '')
      .replaceAll('\t', '')
      .trim();

  static EntryDirection? _parseDirection(String value) {
    if (value == '收入') return EntryDirection.income;
    if (value == '支出') return EntryDirection.expense;
    return null;
  }

  static bool _isClosedStatus(String status) =>
      status.contains('交易关闭') ||
      status.contains('已关闭') ||
      status.contains('等待付款') ||
      status.contains('待付款');

  static String _fallbackExternalId(
    BillSource source,
    DateTime time,
    int amount,
    String merchant,
    String product,
  ) => '${source.id}:${time.toIso8601String()}:$amount:$merchant:$product';
}

class _HeaderLocation {
  const _HeaderLocation(this.lineIndex);

  final int lineIndex;
}

class _ColumnIndex {
  _ColumnIndex(List<String> headers, BillSource source) {
    time = _find(headers, ['交易时间', '交易创建时间', '付款时间']);
    direction = _find(headers, ['收/支', '收支']);
    amount = _find(headers, ['金额(元)', '金额']);
    merchant = _find(headers, ['交易对方', '对方']);
    product = source == BillSource.wechat
        ? _find(headers, ['商品', '商品名称'])
        : _find(headers, ['商品名称', '商品']);
    externalId = source == BillSource.wechat
        ? _find(headers, ['交易单号'])
        : _find(headers, ['交易号']);
    status = _find(headers, ['当前状态', '交易状态']);
    type = _find(headers, ['交易类型', '类型']);
    remark = _find(headers, ['备注']);
  }

  late final int time;
  late final int direction;
  late final int amount;
  late final int merchant;
  late final int product;
  late final int externalId;
  late final int status;
  late final int type;
  late final int remark;

  bool get isUsable =>
      time >= 0 && direction >= 0 && amount >= 0 && externalId >= 0;

  List<String> get missing => [
    if (time < 0) '交易时间',
    if (direction < 0) '收/支',
    if (amount < 0) '金额',
    if (externalId < 0) '交易单号',
  ];

  String value(List<String> cells, int index) {
    if (index < 0 || index >= cells.length) return '';
    return cells[index].trim();
  }

  static int _find(List<String> headers, List<String> aliases) {
    for (final alias in aliases) {
      final index = headers.indexOf(alias);
      if (index >= 0) return index;
    }
    for (var i = 0; i < headers.length; i++) {
      if (aliases.any((alias) => headers[i].contains(alias))) return i;
    }
    return -1;
  }
}
