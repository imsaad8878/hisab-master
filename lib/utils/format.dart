import 'package:intl/intl.dart';

class Format {
  Format._();

  static final NumberFormat _tk = NumberFormat.decimalPattern('en');

  static String tk(num amount) {
    final sign = amount < 0 ? '-' : '';
    return '$sign৳ ${_tk.format(amount.abs().round())}';
  }

  static String compactTk(num amount) {
    final a = amount.abs();
    if (a >= 10000000) return '${(a / 10000000).toStringAsFixed(1)}Cr';
    if (a >= 100000) return '${(a / 100000).toStringAsFixed(1)}L';
    if (a >= 1000) return '${(a / 1000).toStringAsFixed(1)}k';
    return _tk.format(a.round());
  }

  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);

  static String time(DateTime d) => DateFormat('h:mm a').format(d);

  static String dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(d);
  }
}
