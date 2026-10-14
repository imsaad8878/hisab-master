class LoanRecord {
  const LoanRecord({
    required this.id,
    required this.person,
    required this.amount,
    required this.given,
    this.date,
    this.note = '',
    this.settled = false,
  });

  final String id;
  final String person;
  final double amount;

  /// true = you gave money (they owe you); false = you took money.
  final bool given;
  final DateTime? date;
  final String note;
  final bool settled;

  Map<String, dynamic> toMap() => {
        'person': person,
        'amount': amount,
        'given': given,
        'date': (date ?? DateTime.now()).toIso8601String(),
        'note': note,
        'settled': settled,
      };

  factory LoanRecord.fromMap(String id, Map<String, dynamic> m) => LoanRecord(
        id: id,
        person: m['person'] as String? ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        given: m['given'] as bool? ?? true,
        date: DateTime.tryParse(m['date'] as String? ?? ''),
        note: m['note'] as String? ?? '',
        settled: m['settled'] as bool? ?? false,
      );
}

class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.dayOfMonth,
    this.note = '',
  });

  final String id;
  final double amount;

  /// 'income' or 'expense'
  final String type;
  final String category;
  final int dayOfMonth;
  final String note;

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'type': type,
        'category': category,
        'dayOfMonth': dayOfMonth,
        'note': note,
      };

  factory RecurringRule.fromMap(String id, Map<String, dynamic> m) =>
      RecurringRule(
        id: id,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        type: m['type'] as String? ?? 'expense',
        category: m['category'] as String? ?? 'Other',
        dayOfMonth: ((m['dayOfMonth'] as num?)?.toInt() ?? 1).clamp(1, 28),
        note: m['note'] as String? ?? '',
      );
}
