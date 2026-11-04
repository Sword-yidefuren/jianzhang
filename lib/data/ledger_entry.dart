import '../domain/categories.dart';

class LedgerEntry {
  const LedgerEntry({
    this.id,
    required this.occurredAt,
    required this.direction,
    required this.amountCents,
    required this.category,
    required this.account,
    this.merchant = '',
    this.note = '',
    this.source = 'manual',
    this.externalId,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final DateTime occurredAt;
  final EntryDirection direction;
  final int amountCents;
  final String category;
  final String account;
  final String merchant;
  final String note;
  final String source;
  final String? externalId;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get title {
    if (merchant.trim().isNotEmpty) return merchant.trim();
    if (note.trim().isNotEmpty) return note.trim();
    return category;
  }

  String get subtitle {
    final parts = <String>[];
    if (merchant.trim().isNotEmpty && note.trim().isNotEmpty) {
      parts.add(note.trim());
    }
    if (account.trim().isNotEmpty) parts.add(account.trim());
    return parts.join(' · ');
  }

  bool get isImported => source == 'wechat' || source == 'alipay';

  String get sourceLabel {
    switch (source) {
      case 'wechat':
        return '微信导入';
      case 'alipay':
        return '支付宝导入';
      default:
        return '手动';
    }
  }

  LedgerEntry copyWith({
    int? id,
    DateTime? occurredAt,
    EntryDirection? direction,
    int? amountCents,
    String? category,
    String? account,
    String? merchant,
    String? note,
    String? source,
    String? externalId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LedgerEntry(
      id: id ?? this.id,
      occurredAt: occurredAt ?? this.occurredAt,
      direction: direction ?? this.direction,
      amountCents: amountCents ?? this.amountCents,
      category: category ?? this.category,
      account: account ?? this.account,
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class LedgerSummary {
  const LedgerSummary({
    required this.expenseCents,
    required this.incomeCents,
    required this.count,
  });

  final int expenseCents;
  final int incomeCents;
  final int count;

  int get netCents => incomeCents - expenseCents;
}

class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.amountCents,
    required this.count,
  });

  final String category;
  final int amountCents;
  final int count;
}

class MonthTotal {
  const MonthTotal({
    required this.month,
    required this.expenseCents,
    required this.incomeCents,
  });

  final DateTime month;
  final int expenseCents;
  final int incomeCents;
}
