import 'package:flutter_test/flutter_test.dart';
import 'package:hisab_master/models/transaction.dart';

void main() {
  test('TransactionModel map round-trip', () {
    final t = TransactionModel(
      id: 'x1',
      amount: 125.5,
      type: TransactionType.expense,
      category: 'Food',
      dateTime: DateTime(2026, 3, 14, 9, 30),
      note: 'lunch',
    );
    final back = TransactionModel.fromMap('x1', t.toMap());
    expect(back.amount, 125.5);
    expect(back.type, TransactionType.expense);
    expect(back.category, 'Food');
    expect(back.dateTime, DateTime(2026, 3, 14, 9, 30));
    expect(back.note, 'lunch');
  });

  test('categories defined for both types', () {
    expect(kCategories[TransactionType.income], isNotEmpty);
    expect(kCategories[TransactionType.expense], isNotEmpty);
    expect(kCategories[TransactionType.expense]!.contains('Food'), isTrue);
  });
}
