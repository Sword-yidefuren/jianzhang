import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:jianzhang/domain/bill_importer.dart';
import 'package:jianzhang/domain/categories.dart';

const wechatCsv = '''
微信支付账单明细
微信昵称：[Sword]
起始时间：[2026-10-01 00:00:00] 终止时间：[2026-10-31 23:59:59]
导出类型：[全部]
导出时间：[2026-11-01 10:00:00]

微信支付账单明细列表
交易时间,交易类型,交易对方,商品,收/支,金额(元),支付方式,当前状态,交易单号,商户单号,备注
2026-10-01 08:15:00,商户消费,肯德基,早餐,支出,¥18.00,零钱,支付成功,4200001,M001,/
2026-10-02 09:00:00,转账,张三,转账,收入,¥200.00,零钱,已收钱,4200002,M002,还款
2026-10-03 12:00:00,商户消费,滴滴出行,打车,支出,¥35.50,零钱,支付成功,4200003,M003,/
2026-10-04 12:00:00,商户消费,某店,商品,不计收支,¥0.00,零钱,支付成功,4200004,M004,/
''';

const alipayCsv = '''
支付宝交易记录明细查询
账号:[xxx]
起始日期:[2026-10-01 00:00:00]    终止日期:[2026-10-31 23:59:59]
---------------------------------交易记录明细列表------------------------------------
交易号,商家订单号,交易创建时间,付款时间,最近修改时间,交易来源地,类型,交易对方,商品名称,金额（元）,收/支,交易状态,服务费（元）,成功退款（元）,备注,资金状态
2026100122001,SHOP1,2026-10-01 12:30:00,2026-10-01 12:30:00,2026-10-01 12:30:00,其他,即时到账交易,淘宝商家,日用品,68.00,支出,交易成功,0.00,0.00,,已支出
2026100222002,SHOP2,2026-10-02 08:00:00,2026-10-02 08:00:00,2026-10-02 08:00:00,其他,转账,公司,工资,12000.00,收入,交易成功,0.00,0.00,9月工资,已收入
''';

void main() {
  test('微信账单：定位表头、跳过不计收支、按关键词分类', () {
    final result = BillImporter.parseBytes(
      Uint8List.fromList(utf8.encode(wechatCsv)),
      fileName: '微信支付账单.csv',
      now: DateTime(2026, 11, 4, 20),
    );
    expect(result.source, BillSource.wechat);
    expect(result.totalRows, 4);
    expect(result.importableCount, 3);
    expect(result.skippedRows, 1);
    expect(result.entries.first.category, '餐饮');
    expect(result.entries[1].direction, EntryDirection.income);
    expect(result.entries[1].amountCents, 20000);
    expect(result.entries[2].category, '交通');
    expect(result.expenseCents, 5350);
    expect(result.incomeCents, 20000);
  });

  test('支付宝账单：UTF-8 与列映射', () {
    final result = BillImporter.parseBytes(
      Uint8List.fromList(utf8.encode(alipayCsv)),
      fileName: '支付宝账单.csv',
    );
    expect(result.source, BillSource.alipay);
    expect(result.importableCount, 2);
    expect(result.entries.first.account, '支付宝');
    expect(result.entries.first.category, '购物');
    expect(result.entries[1].category, '工资');
    expect(result.entries[1].externalId, '2026100222002');
  });

  test('支付宝旧账单 GBK 编码', () {
    final bytes = Uint8List.fromList(gbk_bytes.encode(alipayCsv));
    final result = BillImporter.parseBytes(bytes, fileName: '支付宝账单-gbk.csv');
    expect(result.source, BillSource.alipay);
    expect(result.importableCount, 2);
    expect(result.entries.first.merchant, '淘宝商家');
  });

  test('缺少表头时报错', () {
    expect(
      () => BillImporter.parseBytes(
        Uint8List.fromList(utf8.encode('姓名,金额\n张三,20')),
        fileName: 'unknown.csv',
      ),
      throwsA(isA<BillImportException>()),
    );
  });

  test('同一账单的交易单号稳定', () {
    final a = BillImporter.parseBytes(
      Uint8List.fromList(utf8.encode(wechatCsv)),
      fileName: 'a.csv',
    );
    final b = BillImporter.parseBytes(
      Uint8List.fromList(utf8.encode(wechatCsv)),
      fileName: 'b.csv',
    );
    expect(
      a.entries.map((e) => e.externalId).toList(),
      b.entries.map((e) => e.externalId).toList(),
    );
  });

  test('微信 xlsx：共享字符串、说明行、Excel 日期序列', () {
    final bytes = _xlsx(
      shared: _wechatShared,
      rows:
          '''
<row r="1"><c r="A1" t="s"><v>0</v></c></row>
<row r="2"><c r="A2" t="s"><v>1</v></c></row>
<row r="3">
  ${_shared('A3', 2)}${_shared('B3', 3)}${_shared('C3', 4)}${_shared('D3', 5)}
  ${_shared('E3', 6)}${_shared('F3', 7)}${_shared('G3', 8)}${_shared('H3', 9)}
  ${_shared('I3', 10)}${_shared('J3', 11)}${_shared('K3', 12)}
</row>
<row r="4">
  <c r="A4"><v>46296.5</v></c>${_shared('B4', 13)}${_shared('C4', 14)}
  ${_shared('D4', 15)}${_shared('E4', 16)}<c r="F4"><v>18</v></c>
  ${_shared('G4', 17)}${_shared('H4', 18)}${_shared('I4', 19)}
  ${_shared('J4', 20)}${_shared('K4', 21)}
</row>
<row r="5">
  ${_shared('A5', 33)}${_shared('B5', 22)}${_shared('C5', 23)}
  ${_shared('D5', 24)}${_shared('E5', 25)}<c r="F5"><v>200</v></c>
  ${_shared('G5', 17)}${_shared('H5', 26)}${_shared('I5', 27)}
  ${_shared('J5', 28)}${_shared('K5', 24)}
</row>
<row r="6">
  ${_shared('A6', 34)}${_shared('B6', 13)}${_shared('C6', 30)}
  ${_shared('D6', 31)}${_shared('E6', 29)}<c r="F6"><v>0</v></c>
  ${_shared('G6', 17)}${_shared('H6', 18)}${_shared('I6', 32)}
  ${_shared('J6', 20)}${_shared('K6', 21)}
</row>
''',
    );
    final result = BillImporter.parseBytes(
      bytes,
      fileName: '微信支付账单.xlsx',
      now: DateTime(2026, 11, 4, 20),
    );
    expect(result.source, BillSource.wechat);
    expect(result.totalRows, 3);
    expect(result.importableCount, 2);
    expect(result.skippedRows, 1);
    expect(result.entries.first.amountCents, 1800);
    expect(result.entries.first.occurredAt, DateTime(2026, 10, 1, 12));
    expect(result.entries.first.category, '餐饮');
    expect(result.entries[1].direction, EntryDirection.income);
    expect(result.entries[1].amountCents, 20000);
  });

  test('支付宝 xlsx：无标题行、内联字符串', () {
    final bytes = _xlsx(
      rows:
          '''
<row r="1">
  ${_inline('A1', '交易号')}${_inline('B1', '商家订单号')}
  ${_inline('C1', '交易创建时间')}${_inline('D1', '付款时间')}
  ${_inline('E1', '最近修改时间')}${_inline('F1', '交易来源地')}
  ${_inline('G1', '类型')}${_inline('H1', '交易对方')}
  ${_inline('I1', '商品名称')}${_inline('J1', '金额(元)')}
  ${_inline('K1', '收/支')}${_inline('L1', '交易状态')}
  ${_inline('M1', '服务费(元)')}${_inline('N1', '成功退款(元)')}
  ${_inline('O1', '备注')}${_inline('P1', '资金状态')}
</row>
<row r="2">
  ${_inline('A2', '2026100122001')}${_inline('B2', 'SHOP1')}
  ${_inline('C2', '2026-10-01 12:30:00')}${_inline('D2', '2026-10-01 12:30:00')}
  ${_inline('E2', '2026-10-01 12:30:00')}${_inline('F2', '其他')}
  ${_inline('G2', '即时到账交易')}${_inline('H2', '淘宝商家')}
  ${_inline('I2', '日用品')}<c r="J2"><v>68</v></c>
  ${_inline('K2', '支出')}${_inline('L2', '交易成功')}
  ${_inline('M2', '0')}${_inline('N2', '0')}
  ${_inline('O2', '')}${_inline('P2', '已支出')}
</row>
''',
    );
    final result = BillImporter.parseBytes(bytes, fileName: '账单.xlsx');
    expect(result.source, BillSource.alipay);
    expect(result.importableCount, 1);
    expect(result.entries.single.merchant, '淘宝商家');
    expect(result.entries.single.category, '购物');
    expect(result.entries.single.externalId, '2026100122001');
    expect(result.expenseCents, 6800);
  });

  test('真实 Excel 文件：共享字符串、样式和日期格式', () {
    final bytes = File('test/fixtures/wechat_sample.xlsx').readAsBytesSync();
    final result = BillImporter.parseBytes(
      bytes,
      fileName: 'wechat_sample.xlsx',
    );
    expect(result.source, BillSource.wechat);
    expect(result.importableCount, 3);
    expect(result.entries.first.occurredAt, DateTime(2026, 10, 1, 8, 15));
    expect(result.entries.first.amountCents, 1800);
    expect(result.entries.first.category, '餐饮');
    expect(result.entries[1].category, '工资');
    expect(result.entries[2].category, '交通');
  });
}

const _wechatShared = [
  '微信支付账单明细',
  '微信昵称：[Sword]',
  '交易时间',
  '交易类型',
  '交易对方',
  '商品',
  '收/支',
  '金额(元)',
  '支付方式',
  '当前状态',
  '交易单号',
  '商户单号',
  '备注',
  '商户消费',
  '肯德基',
  '早餐',
  '支出',
  '零钱',
  '支付成功',
  '4200001',
  'M001',
  '/',
  '转账',
  '张三',
  '还款',
  '收入',
  '已收钱',
  '4200002',
  'M002',
  '不计收支',
  '某店',
  '商品',
  '4200004',
  '2026-10-02 09:00:00',
  '2026-10-03 12:00:00',
];

String _shared(String ref, int index) => '<c r="$ref" t="s"><v>$index</v></c>';

String _inline(String ref, String value) =>
    '<c r="$ref" t="inlineStr"><is><t>${_escape(value)}</t></is></c>';

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

Uint8List _xlsx({required String rows, List<String> shared = const []}) {
  final sharedXml = shared.isEmpty
      ? ''
      : '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'count="${shared.length}" uniqueCount="${shared.length}">'
            '${shared.map((value) => '<si><t>${_escape(value)}</t></si>').join()}'
            '</sst>';
  final files = {
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '</Types>',
    'xl/workbook.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="账单" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
        'Target="worksheets/sheet1.xml"/></Relationships>',
    'xl/worksheets/sheet1.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData>$rows</sheetData></worksheet>',
    if (sharedXml.isNotEmpty) 'xl/sharedStrings.xml': sharedXml,
  };
  final archive = Archive();
  files.forEach((name, content) {
    archive.addFile(ArchiveFile.string(name, content));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
