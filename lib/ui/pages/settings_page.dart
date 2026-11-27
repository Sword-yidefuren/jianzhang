import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/categories.dart';
import '../../state/ledger_controller.dart';
import '../pages/import_page.dart';
import '../theme.dart';
import '../widgets/components.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.controller});

  final LedgerController controller;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _exporting = false;

  Future<void> _exportCsv() async {
    if (_exporting) return;
    final entries = widget.controller.store.allEntries();
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('还没有账目可以导出')));
      return;
    }
    setState(() => _exporting = true);
    try {
      final rows = <List<dynamic>>[
        ['日期', '类型', '分类', '金额(元)', '账户', '商家', '备注', '来源', '交易单号'],
        for (final entry in entries)
          [
            csvTimestamp(entry.occurredAt),
            entry.direction.label,
            entry.category,
            (entry.amountCents / 100).toStringAsFixed(2),
            entry.account,
            entry.merchant,
            entry.note,
            entry.sourceLabel,
            entry.externalId ?? '',
          ],
      ];
      final csvText = Csv(
        fieldDelimiter: ',',
        lineDelimiter: '\n',
        addBom: true,
      ).encode(rows);
      final bytes = Uint8List.fromList(utf8.encode(csvText));
      final uri = await FilePicker.saveFile(
        dialogTitle: '导出账目 CSV',
        fileName: '简账-${compactDate(DateTime.now())}.csv',
        bytes: bytes,
        mimeType: 'text/csv',
      );
      if (!mounted) return;
      if (uri != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已导出 ${entries.length} 笔账目')));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('导出失败：$error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '清空所有账目？',
      message: '共 ${widget.controller.totalCount} 笔，删除后无法恢复。建议先导出 CSV。',
      confirmLabel: '全部删除',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    widget.controller.clearAll();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('账本已清空')));
  }

  Future<void> _editSalary() async {
    final controller = widget.controller;
    final amount = TextEditingController(
      text: controller.salaryCents > 0
          ? Money.inputValue(controller.salaryCents)
          : '',
    );
    var enabled = controller.salaryEnabled;
    String? error;
    var resultCents = controller.salaryCents;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('固定月收入'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('每月自动计入收入')),
                  Switch(
                    value: enabled,
                    onChanged: (value) => setDialogState(() {
                      enabled = value;
                      error = null;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amount,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  prefixText: '¥ ',
                  labelText: '月收入',
                  errorText: error,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '开启后每月 1 号自动生成一笔“工资”收入；关闭后不再新增，已生成的收入不会删除。',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.55,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                if (enabled) {
                  final cents = Money.tryParseToCents(amount.text.trim());
                  if (cents == null || cents <= 0) {
                    setDialogState(() => error = '请输入大于 0 的金额');
                    return;
                  }
                  resultCents = cents;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), amount.dispose);
    if (saved != true || !mounted) return;
    controller.saveSalarySettings(enabled: enabled, cents: resultCents);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(enabled ? '固定收入已开启' : '固定收入已关闭')));
  }

  void _showSyncExplanation() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('为什么不能自动同步？'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '微信/支付宝没有开放个人流水接口，第三方 App 拿不到实时账单。',
                style: TextStyle(fontSize: 13, height: 1.65),
              ),
              SizedBox(height: 10),
              Text(
                '所以用官方导出文件导入；数据只在本机，不上传。',
                style: TextStyle(fontSize: 13, height: 1.65),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return PageScrollBody(
      children: [
        const PageHeader(
          kicker: 'Settings',
          title: '设置',
          subtitle: '账本和数据都在本机。',
        ),
        const SizedBox(height: 22),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingRow(
                icon: Icons.account_balance_wallet_outlined,
                title: '固定月收入',
                subtitle: controller.salaryEnabled
                    ? '每月 1 号自动计入 ${Money.format(controller.salaryCents)}'
                    : '未开启，收入手动记录',
                onTap: _editSalary,
              ),
              const Divider(height: 1, indent: 66),
              _SettingRow(
                icon: Icons.file_download_outlined,
                title: '导入微信 / 支付宝账单',
                subtitle: '官方 CSV / Excel，自动分类与去重',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => ImportPage(controller: controller),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 66),
              _SettingRow(
                icon: Icons.table_view_outlined,
                title: '导出账目 CSV',
                subtitle: _exporting
                    ? '正在准备文件…'
                    : '${controller.totalCount} 笔，可用 Excel 打开',
                onTap: _exporting ? null : _exportCsv,
                trailing: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              const Divider(height: 1, indent: 66),
              _SettingRow(
                icon: Icons.sync_disabled_rounded,
                title: '为什么不能实时同步？',
                subtitle: '看清楚边界，不抱错误期待',
                onTap: _showSyncExplanation,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingRow(
                icon: Icons.storage_rounded,
                title: '本地存储',
                subtitle: '${controller.totalCount} 笔，只在这台设备',
              ),
              const Divider(height: 1, indent: 66),
              _SettingRow(
                icon: Icons.delete_outline_rounded,
                title: '清空所有账目',
                subtitle: '不影响分类词典和 App 本身',
                destructive: true,
                onTap: _clearAll,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          padding: EdgeInsets.zero,
          child: _SettingRow(
            icon: Icons.info_outline_rounded,
            title: '简账 1.3.2',
            subtitle: '本地优先，不上传、不联网',
          ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text(
            'JIANZHANG · MADE FOR ONE PERSON',
            style: TextStyle(
              fontSize: 9.5,
              letterSpacing: 1.4,
              color: AppColors.faint,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.expense : AppColors.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: destructive
                    ? AppColors.expenseSoft
                    : AppColors.paperDeep,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 18,
                color: destructive ? AppColors.expense : AppColors.muted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.faint,
                      )),
          ],
        ),
      ),
    );
  }
}
