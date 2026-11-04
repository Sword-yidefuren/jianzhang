import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/ledger_controller.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

class JianzhangApp extends StatelessWidget {
  const JianzhangApp({super.key, required this.controller});

  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '简账',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppShell(controller: controller),
    );
  }
}
