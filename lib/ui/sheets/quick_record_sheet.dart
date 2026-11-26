import 'package:flutter/material.dart';

import '../../state/ledger_controller.dart';
import '../theme.dart';
import '../widgets/quick_entry.dart';
import 'entry_sheet.dart';

Future<void> showQuickRecordSheet(
  BuildContext context,
  LedgerController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _QuickRecordSheet(controller: controller),
  );
}

class _QuickRecordSheet extends StatefulWidget {
  const _QuickRecordSheet({required this.controller});

  final LedgerController controller;

  @override
  State<_QuickRecordSheet> createState() => _QuickRecordSheetState();
}

class _QuickRecordSheetState extends State<_QuickRecordSheet> {
  late String _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.controller.lastEntryMode;
  }

  void _setMode(String mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    widget.controller.setLastEntryMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final height = (MediaQuery.sizeOf(context).height * 0.9 - insets).clamp(
      340.0,
      900.0,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lineStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 10, 8),
              child: Row(
                children: [
                  const Text(
                    '记一笔',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.paperDeep,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeTab(
                        label: '简单记',
                        selected: _mode == 'quick',
                        onTap: () => _setMode('quick'),
                      ),
                    ),
                    Expanded(
                      child: _ModeTab(
                        label: '详细记',
                        selected: _mode == 'detailed',
                        onTap: () => _setMode('detailed'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _mode == 'quick'
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
                      child: QuickEntry(
                        controller: widget.controller,
                        autofocus: true,
                        showDetailedAction: false,
                        onSaved: () => Navigator.of(context).pop(),
                      ),
                    )
                  : EntryForm(
                      controller: widget.controller,
                      embedded: true,
                      onSaved: () => Navigator.of(context).pop(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x0D201C14),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.ink : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
