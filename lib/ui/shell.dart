import 'package:flutter/material.dart';

import '../state/ledger_controller.dart';
import 'pages/home_page.dart';
import 'pages/savings_page.dart';
import 'pages/settings_page.dart';
import 'pages/stats_page.dart';
import 'sheets/quick_record_sheet.dart';
import 'theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final LedgerController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  List<Widget> _buildPages() => [
    HomePage(
      controller: widget.controller,
      onOpenSavings: () => setState(() => _index = 2),
    ),
    StatsPage(controller: widget.controller),
    SavingsPage(controller: widget.controller),
    SettingsPage(controller: widget.controller),
  ];

  void _openNewEntry() {
    showQuickRecordSheet(context, widget.controller);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 920;
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final body = IndexedStack(index: _index, children: _buildPages());
        if (!wide) {
          return Scaffold(
            body: body,
            floatingActionButton: FloatingActionButton(
              onPressed: _openNewEntry,
              backgroundColor: AppColors.ink,
              foregroundColor: const Color(0xFFF7F2E7),
              elevation: 0,
              shape: const CircleBorder(),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: BottomAppBar(
              color: AppColors.paper,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: const CircularNotchedRectangle(),
              notchMargin: 6,
              padding: EdgeInsets.zero,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 64,
                  child: Row(
                    children: [
                      Expanded(
                        child: _BottomTab(
                          icon: Icons.edit_note_rounded,
                          label: '记账',
                          selected: _index == 0,
                          onTap: () => setState(() => _index = 0),
                        ),
                      ),
                      Expanded(
                        child: _BottomTab(
                          icon: Icons.insights_rounded,
                          label: '统计',
                          selected: _index == 1,
                          onTap: () => setState(() => _index = 1),
                        ),
                      ),
                      const SizedBox(width: 76),
                      Expanded(
                        child: _BottomTab(
                          icon: Icons.savings_rounded,
                          label: '存钱',
                          selected: _index == 2,
                          onTap: () => setState(() => _index = 2),
                        ),
                      ),
                      Expanded(
                        child: _BottomTab(
                          icon: Icons.settings_rounded,
                          label: '设置',
                          selected: _index == 3,
                          onTap: () => setState(() => _index = 3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              _Sidebar(
                index: _index,
                controller: widget.controller,
                onSelected: (value) => setState(() => _index = value),
                onNewEntry: _openNewEntry,
              ),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ink : AppColors.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.controller,
    required this.onSelected,
    required this.onNewEntry,
  });

  final int index;
  final LedgerController controller;
  final ValueChanged<int> onSelected;
  final VoidCallback onNewEntry;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.edit_note_rounded, '记账'),
      (Icons.insights_rounded, '统计'),
      (Icons.savings_rounded, '存钱'),
      (Icons.settings_rounded, '设置'),
    ];
    return Container(
      width: 224,
      decoration: const BoxDecoration(
        color: AppColors.paperDeep,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Text(
                      '简',
                      style: TextStyle(
                        color: Color(0xFFF7F2E7),
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '简账',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        'LOCAL LEDGER',
                        style: TextStyle(
                          fontSize: 8.5,
                          letterSpacing: 1.7,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 34),
              for (var i = 0; i < items.length; i++) ...[
                _NavItem(
                  icon: items[i].$1,
                  label: items[i].$2,
                  selected: index == i,
                  onTap: () => onSelected(i),
                ),
                const SizedBox(height: 4),
              ],
              const Spacer(),
              InkWell(
                onTap: onNewEntry,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: Color(0xFFF7F2E7),
                      ),
                      SizedBox(width: 5),
                      Text(
                        '记一笔',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF7F2E7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          size: 13,
                          color: AppColors.faint,
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          '本地存储',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${controller.totalCount} 笔',
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.faint,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '数据只在这台设备上，不上传、不联网。',
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.45,
                        color: AppColors.faint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected ? AppColors.line : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.accent : AppColors.muted,
            ),
            const SizedBox(width: 11),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppColors.ink : AppColors.muted,
              ),
            ),
            if (selected) ...[
              const Spacer(),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
