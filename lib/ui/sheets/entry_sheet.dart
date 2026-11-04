import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/dates.dart';
import '../../core/money.dart';
import '../../data/ledger_entry.dart';
import '../../domain/categories.dart';
import '../../state/ledger_controller.dart';
import '../theme.dart';
import '../widgets/components.dart';

Future<void> showEntryEditor(
  BuildContext context,
  LedgerController controller, {
  LedgerEntry? entry,
  String? initialText,
}) async {
  final wide = MediaQuery.sizeOf(context).width >= 760;
  if (wide) {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 760),
          child: EntryForm(
            controller: controller,
            entry: entry,
            initialText: initialText,
          ),
        ),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: EntryForm(
          controller: controller,
          entry: entry,
          initialText: initialText,
        ),
      ),
    ),
  );
}

class EntryForm extends StatefulWidget {
  const EntryForm({
    super.key,
    required this.controller,
    this.entry,
    this.initialText,
  });

  final LedgerController controller;
  final LedgerEntry? entry;
  final String? initialText;

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  late EntryDirection _direction;
  late String _category;
  late String _account;
  late DateTime _date;
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;
  final _amountFocus = FocusNode();
  final _merchantFocus = FocusNode();
  String? _amountError;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _direction = entry?.direction ?? EntryDirection.expense;
    _category =
        entry?.category ??
        (entry?.direction == EntryDirection.income ? '工资' : '餐饮');
    _account = entry?.account ?? '微信';
    _date = entry?.occurredAt ?? DateTime.now();
    _amountController = TextEditingController(
      text: entry == null ? '' : Money.inputValue(entry.amountCents),
    );
    _merchantController = TextEditingController(
      text: entry?.merchant ?? widget.initialText ?? '',
    );
    _noteController = TextEditingController(text: entry?.note ?? '');
    if (!_validCategory(_category, _direction)) {
      _category = _poolFor(_direction).first.name;
    }
    if (entry == null && widget.initialText == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    _amountFocus.dispose();
    _merchantFocus.dispose();
    super.dispose();
  }

  List<Category> _poolFor(EntryDirection direction) =>
      direction == EntryDirection.expense
      ? expenseCategories
      : incomeCategories;

  bool _validCategory(String name, EntryDirection direction) =>
      _poolFor(direction).any((category) => category.name == name);

  void _setDirection(EntryDirection direction) {
    if (_direction == direction) return;
    setState(() {
      _direction = direction;
      if (!_validCategory(_category, direction)) {
        _category = _poolFor(direction).first.name;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  void _save() {
    final cents = Money.tryParseToCents(_amountController.text);
    if (cents == null || cents <= 0) {
      setState(() => _amountError = '请输入大于 0 的金额');
      _amountFocus.requestFocus();
      return;
    }
    if (_editing) {
      widget.controller.updateEntry(
        widget.entry!.copyWith(
          occurredAt: _date,
          direction: _direction,
          amountCents: cents,
          category: _category,
          account: _account,
          merchant: _merchantController.text.trim(),
          note: _noteController.text.trim(),
        ),
      );
    } else {
      widget.controller.addManual(
        occurredAt: _date,
        direction: _direction,
        amountCents: cents,
        category: _category,
        account: _account,
        merchant: _merchantController.text,
        note: _noteController.text,
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除这笔账？',
      message: '删除后无法恢复，统计会立即更新。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    widget.controller.deleteEntry(widget.entry!.id!);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _direction == EntryDirection.expense;
    final accent = isExpense ? AppColors.expense : AppColors.income;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lineStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editing ? '编辑账目' : '记一笔',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _editing ? '改完直接保存' : '金额、分类、日期都可以改',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                10,
                24,
                20 + (bottomInset > 0 ? 0 : 8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DirectionToggle(value: _direction, onChanged: _setDirection),
                  const SizedBox(height: 24),
                  const Text(
                    '金额',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '¥',
                        style: AppTheme.numeric(
                          size: 30,
                          color: accent,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          focusNode: _amountFocus,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                            LengthLimitingTextInputFormatter(12),
                          ],
                          style: AppTheme.numeric(size: 38, color: accent),
                          decoration: const InputDecoration(
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w600,
                              color: AppColors.faint,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (_) {
                            if (_amountError != null) {
                              setState(() => _amountError = null);
                            }
                          },
                          onSubmitted: (_) => _save(),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  if (_amountError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _amountError!,
                      style: const TextStyle(
                        color: AppColors.expense,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    '分类',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _CategoryGrid(
                    categories: _poolFor(_direction),
                    selected: _category,
                    accent: accent,
                    onSelected: (name) => setState(() => _category = name),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '账户',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final account in const [
                        '微信',
                        '支付宝',
                        '银行卡',
                        '现金',
                        '其他',
                      ])
                        _ChoicePill(
                          label: account,
                          selected: _account == account,
                          accent: accent,
                          onTap: () => setState(() => _account = account),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F5EE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${fullDayLabel(_date)}  ${timeLabel(_date)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.faint,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _merchantController,
                    focusNode: _merchantFocus,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '商家 / 用途',
                      hintText: '例如：午饭、滴滴、房租',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    minLines: 1,
                    decoration: const InputDecoration(
                      labelText: '备注（可选）',
                      hintText: '补充一点信息',
                    ),
                  ),
                  if (_editing) ...[
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _delete,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('删除这笔账'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.expense,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              16 + (bottomInset > 0 ? bottomInset : 0),
            ),
            decoration: const BoxDecoration(
              color: AppColors.card,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size(0, 52),
                ),
                child: Text(_editing ? '保存修改' : '记下 ${_direction.label}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionToggle extends StatelessWidget {
  const _DirectionToggle({required this.value, required this.onChanged});

  final EntryDirection value;
  final ValueChanged<EntryDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.paperDeep,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final direction in EntryDirection.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(direction),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: value == direction
                        ? AppColors.card
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: value == direction
                        ? const [
                            BoxShadow(
                              color: Color(0x0F201C14),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        direction == EntryDirection.expense
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 15,
                        color: value == direction
                            ? (direction == EntryDirection.expense
                                  ? AppColors.expense
                                  : AppColors.income)
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        direction.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: value == direction
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: value == direction
                              ? AppColors.ink
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.accent,
    required this.onSelected,
  });

  final List<Category> categories;
  final String selected;
  final Color accent;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 360 ? 3 : 4;
        final spacing = 8.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final category in categories)
              SizedBox(
                width: width,
                child: InkWell(
                  onTap: () => onSelected(category.name),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected == category.name
                          ? accent.withValues(alpha: 0.1)
                          : const Color(0xFFF8F5EE),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected == category.name
                            ? accent.withValues(alpha: 0.55)
                            : AppColors.line,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          category.icon,
                          size: 18,
                          color: selected == category.name
                              ? accent
                              : category.color,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected == category.name
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected == category.name
                                ? accent
                                : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.6) : AppColors.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? accent : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
