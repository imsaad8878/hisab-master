import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../providers/transaction_providers.dart';
import '../../utils/format.dart';

/// Keeps the Android home-screen widget in sync with the latest balance.
/// Called from the home screen whenever totals change.
void registerHomeWidgetUpdates(WidgetRef ref) {
  ref.listen(totalsProvider, (previous, next) {
    _push(next.balance, next.monthExpense);
  });
  final totals = ref.read(totalsProvider);
  _push(totals.balance, totals.monthExpense);
}

Future<void> _push(double balance, double monthExpense) async {
  try {
    await HomeWidget.saveWidgetData<String>('balance', Format.tk(balance));
    await HomeWidget.saveWidgetData<String>(
        'monthExpense', 'This month: ${Format.tk(monthExpense)}');
    await HomeWidget.updateWidget(name: 'HisabWidgetProvider');
  } catch (_) {
    // Widget updates must never break the main app.
  }
}
