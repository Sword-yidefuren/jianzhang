import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money.dart';
import '../../domain/bill_importer.dart';
import '../../state/ledger_controller.dart';
import '../theme.dart';
import '../widgets/components.dart';

class ImportPage extends StatefulWidget {
  const ImportPage({super.key, required this.controller});

  final LedgerController controller;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final List<BillParseResult> _results = [];
  final List<String> _errors = [];
  ImportPlan? _plan;
  bool _picking = false;
  bool _importing = false;

  Future<void> _pickFiles() async {
    setState(() {
      _picking = true;
      _errors.clear();
    });
    try {
      final files = await FilePicker.pickFiles(
        dialogTitle: '选择微信 / 支付宝账单',
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt', 'xlsx'],
      );
      if (files.isEmpty) {
        if (mounted) setState(() => _picking = false);
        return;
      }
      final results = <BillParseResult>[];
      final errors = <String>[];
      for (final file in files) {
        try {
          final bytes = await file.readAsBytes();
          results.add(BillImporter.parseBytes(bytes, fileName: file.name));
        } on BillImportException catch (error) {
          errors.add('${file.name}：${error.message}');
        } on PlatformException catch (error) {
          errors.add('${file.name}：读取失败（${error.message ?? '系统限制'}）');
        } catch (error) {
          errors.add('${file.name}：读取失败（$error）');
        }
      }
      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(results);
        _errors.addAll(errors);
        _plan = _results.isEmpty
            ? null
            : widget.controller.buildImportPlan(_results);
        _picking = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errors.add('打开文件选择器失败：$error');
        _picking = false;
      });
    }
  }

  Future<void> _import() async {
    final plan = _plan;
    if (plan == null || plan.entries.isEmpty || _importing) return;
    setState(() => _importing = true);
    final result = widget.controller.importPlan(plan);
    if (!mounted) return;
    setState(() => _importing = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('新增 ${result.inserted} 笔账目。'),
            if (plan.duplicateCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('另有 ${plan.duplicateCount} 笔之前已经导入过，已自动跳过。'),
              ),
            if (plan.skippedRows > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('账单里 ${plan.skippedRows} 行不计收支或已关闭，没有导入。'),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 600 ? 20.0 : 36.0;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          '导入账单',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 36),
            children: [
              const PageHeader(
                kicker: 'Import',
                title: '把账单搬进来',
                subtitle: '支持微信支付、支付宝导出的 CSV / Excel（.xlsx）；自动分类，并按交易单号去重。',
              ),
              const SizedBox(height: 20),
              const _HowToCard(),
              const SizedBox(height: 16),
              _PickerCard(
                picking: _picking,
                hasResults: _results.isNotEmpty,
                onTap: _picking ? null : _pickFiles,
              ),
              if (_errors.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final error in _errors)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.expenseSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.expense.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 17,
                          color: AppColors.expense,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            error,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.expense,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (_results.isNotEmpty && plan != null) ...[
                const SizedBox(height: 18),
                for (final result in _results) ...[
                  _FileResultCard(result: result),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                _PlanCard(plan: plan),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: plan.entries.isEmpty || _importing
                        ? null
                        : _import,
                    icon: _importing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      plan.entries.isEmpty
                          ? '没有新账目可导入'
                          : '导入 ${plan.entries.length} 笔',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '导入后仍可在明细里修改分类或删除',
                    style: TextStyle(fontSize: 10.5, color: AppColors.faint),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              const _PrivacyNote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  const _HowToCard();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '先导出，再解压',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          const _Step(
            number: '01',
            title: '微信支付',
            detail: '我 → 服务 → 钱包 → 账单 → 常见问题 → 下载账单，选择“用于个人对账”。',
          ),
          const SizedBox(height: 12),
          const _Step(
            number: '02',
            title: '支付宝',
            detail: '我的 → 账单 → 右上角更多 → 开具交易流水证明；或在电脑端下载余额收支明细。',
          ),
          const SizedBox(height: 12),
          const _Step(
            number: '03',
            title: '解压得到 CSV 或 Excel',
            detail: '微信账单是加密 ZIP，先用邮件里的解压码在系统里解压，再来这里选 CSV 或 .xlsx。',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.line),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AppColors.muted,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'App 不保存压缩包、邮箱或解压码。选择 CSV / Excel 后只在内存里解析，不保留原文件。',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.paperDeep,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.muted,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PickerCard extends StatelessWidget {
  const _PickerCard({
    required this.picking,
    required this.hasResults,
    required this.onTap,
  });

  final bool picking;
  final bool hasResults;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.lineStrong,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: picking
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.upload_file_rounded,
                      size: 22,
                      color: AppColors.accent,
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              picking
                  ? '正在读取…'
                  : hasResults
                  ? '重新选择账单'
                  : '选择账单文件',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '支持 CSV / Excel，可一次选多个',
              style: TextStyle(fontSize: 11, color: AppColors.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileResultCard extends StatelessWidget {
  const _FileResultCard({required this.result});

  final BillParseResult result;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoftTag(
                label: result.source.label,
                color: result.source == BillSource.wechat
                    ? AppColors.income
                    : const Color(0xFF3B6F9E),
                background: result.source == BillSource.wechat
                    ? AppColors.incomeSoft
                    : const Color(0xFFE1EAF2),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${result.importableCount} 笔',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '支出 ${Money.format(result.expenseCents)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.expense,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '收入 ${Money.format(result.incomeCents)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.income),
                ),
              ),
              if (result.skippedRows > 0)
                Text(
                  '跳过 ${result.skippedRows} 行',
                  style: const TextStyle(fontSize: 11, color: AppColors.faint),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});

  final ImportPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '导入预览',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.6,
              color: Color(0xFFAAA69B),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${plan.entries.length}',
                style: AppTheme.numeric(
                  size: 34,
                  color: const Color(0xFFF7F2E7),
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text(
                  '笔可导入',
                  style: TextStyle(fontSize: 12, color: Color(0xFFDCD7CB)),
                ),
              ),
              const Spacer(),
              if (plan.duplicateCount > 0)
                Text(
                  '重复 ${plan.duplicateCount} 笔',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFE2B99F),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PlanMetric(
                  label: '支出',
                  value: Money.format(plan.expenseCents),
                  color: const Color(0xFFF0C9B9),
                ),
              ),
              Expanded(
                child: _PlanMetric(
                  label: '收入',
                  value: Money.format(plan.incomeCents),
                  color: const Color(0xFFD7E4DB),
                ),
              ),
              Expanded(
                child: _PlanMetric(
                  label: '跳过行',
                  value: '${plan.skippedRows}',
                  color: const Color(0xFFAAA69B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  const _PlanMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF8F8B81)),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppTheme.numeric(size: 14, color: color)),
        ),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: AppColors.faint),
          SizedBox(height: 6),
          Text(
            '解析和入库都在这台设备上完成',
            style: TextStyle(fontSize: 10.5, color: AppColors.faint),
          ),
        ],
      ),
    );
  }
}
