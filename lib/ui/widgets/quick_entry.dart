import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../domain/categories.dart';
import '../../domain/quick_parser.dart';
import '../../state/ledger_controller.dart';
import '../sheets/entry_sheet.dart';
import '../theme.dart';
import 'components.dart';

class QuickEntry extends StatefulWidget {
  const QuickEntry({super.key, required this.controller});

  final LedgerController controller;

  @override
  State<QuickEntry> createState() => _QuickEntryState();
}

class _QuickEntryState extends State<QuickEntry> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  ParsedEntry? _parsed;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _parsed = QuickParser.parse(value, defaultAccount: '微信');
    });
  }

  void _submit() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      _focusNode.requestFocus();
      return;
    }
    final parsed = _parsed;
    if (parsed == null) {
      showEntryEditor(context, widget.controller, initialText: text);
      return;
    }
    final id = widget.controller.addParsed(parsed);
    _textController.clear();
    setState(() => _parsed = null);
    _focusNode.requestFocus();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '已记下 ${parsed.direction.label} ${Money.format(parsed.amountCents)} · ${parsed.category}',
        ),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => widget.controller.deleteEntry(id),
        ),
      ),
    );
  }

  void _useExample(String text) {
    _textController.text = text;
    _textController.selection = TextSelection.collapsed(offset: text.length);
    _onChanged(text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    return SectionCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                '一句话记账',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Text(
                _textController.text.isEmpty ? '试试直接说' : '回车保存',
                style: const TextStyle(fontSize: 10.5, color: AppColors.faint),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5EE),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? AppColors.accent.withValues(alpha: 0.6)
                    : AppColors.line,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                    ),
                    decoration: const InputDecoration(
                      hintText: '例如：午饭 25 微信',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.faint,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                      isDense: true,
                    ),
                    onChanged: _onChanged,
                    onSubmitted: (_) => _submit(),
                    onTap: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: IconButton.filled(
                    onPressed: _submit,
                    style: IconButton.styleFrom(
                      backgroundColor: _textController.text.trim().isEmpty
                          ? AppColors.paperDeep
                          : AppColors.ink,
                      foregroundColor: _textController.text.trim().isEmpty
                          ? AppColors.faint
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 19),
                    tooltip: '记下',
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: parsed == null
                ? _Examples(onTap: _useExample)
                : _Preview(parsed: parsed),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 12,
                color: AppColors.faint,
              ),
              const SizedBox(width: 5),
              const Expanded(
                child: Text(
                  '只在这台设备解析，不联网',
                  style: TextStyle(fontSize: 10.5, color: AppColors.faint),
                ),
              ),
              TextButton.icon(
                onPressed: () => showEntryEditor(context, widget.controller),
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('详细记一笔'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 30),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.parsed});

  final ParsedEntry parsed;

  @override
  Widget build(BuildContext context) {
    final isExpense = parsed.direction == EntryDirection.expense;
    final color = isExpense ? AppColors.expense : AppColors.income;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
            SoftTag(
              label: parsed.direction.label,
              color: color,
              background: color.withValues(alpha: 0.12),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                '${parsed.category}  ·  ${parsed.account}  ·  ${dayLabel(parsed.occurredAt)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ),
            const Spacer(),
            Text(
              Money.format(parsed.amountCents),
              style: AppTheme.numeric(
                size: 17,
                color: color,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Examples extends StatelessWidget {
  const _Examples({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    const examples = ['午饭 25', '打车 18.5 支付宝', '工资 12000', '昨天 超市 128 微信'];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final example in examples)
            InkWell(
              onTap: () => onTap(example),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  example,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
