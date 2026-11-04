import 'dart:convert';
import 'dart:typed_data';

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
}
