import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/loan.dart';
import '../models/transaction.dart';

final _bdt = NumberFormat.currency(locale: 'en_BD', symbol: '৳', decimalDigits: 0);

Future<void> shareTransactionsPdf(
    List<TransactionModel> list, String title) async {
  final doc = pw.Document();
  final sorted = [...list]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  final income =
      sorted.where((t) => t.type == TransactionType.income).fold<double>(0, (s, t) => s + t.amount);
  final expense =
      sorted.where((t) => t.type == TransactionType.expense).fold<double>(0, (s, t) => s + t.amount);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Hisab Master', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
              pw.Text(DateFormat('d MMM yyyy').format(DateTime.now())),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          color: PdfColors.grey100,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _stat('Income', income, PdfColors.green700),
              _stat('Expense', expense, PdfColors.red700),
              _stat('Balance', income - expense, PdfColors.blue800),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          headers: ['Date', 'Type', 'Category', 'Party', 'Note', 'Amount'],
          data: [
            for (final t in sorted)
              [
                DateFormat('d MMM').format(t.dateTime),
                t.type == TransactionType.income ? 'In' : 'Out',
                t.category,
                t.party ?? '',
                t.note,
                '${t.type == TransactionType.income ? '+' : '-'}${_bdt.format(t.amount)}',
              ],
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text('$title • ${sorted.length} entries',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ],
    ),
  );
  final bytes = await doc.save();
  await Share.shareXFiles(
    [XFile.fromData(bytes, name: 'hisab_master_report.pdf', mimeType: 'application/pdf')],
    text: 'Hisab Master report',
  );
}

pw.Widget _stat(String label, double value, PdfColor color) => pw.Column(
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 2),
        pw.Text(_bdt.format(value),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: color)),
      ],
    );

String buildCsv(List<TransactionModel> list) {
  final sorted = [...list]..sort((a, b) => b.dateTime.compareTo(a.dateTime));
  final buf = StringBuffer('Date,Type,Category,Party,Note,Amount\n');
  for (final t in sorted) {
    final note = t.note.replaceAll('"', "'").replaceAll(',', ' ');
    final party = (t.party ?? '').replaceAll('"', "'").replaceAll(',', ' ');
    buf.writeln(
        '"${DateFormat('yyyy-MM-dd HH:mm').format(t.dateTime)}","${t.type.name}","${t.category}","$party","$note",${t.type == TransactionType.income ? '' : '-'}${t.amount.toStringAsFixed(0)}');
  }
  return buf.toString();
}

Future<void> shareTransactionsCsv(List<TransactionModel> list) async {
  final bytes = Uint8List.fromList(utf8.encode(buildCsv(list)));
  await Share.shareXFiles([
    XFile.fromData(bytes, name: 'hisab_master_transactions.csv', mimeType: 'text/csv'),
  ]);
}

String buildBackupJson({
  required List<TransactionModel> transactions,
  required List<LoanRecord> loans,
  required List<RecurringRule> recurring,
  required Map<String, dynamic> profile,
}) {
  return jsonEncode({
    'app': 'hisab_master',
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'profile': profile,
    'transactions': [
      for (final t in transactions) {'id': t.id, ...t.toMap()},
    ],
    'loans': [
      for (final l in loans) {'id': l.id, ...l.toMap()},
    ],
    'recurring': [
      for (final r in recurring) {'id': r.id, ...r.toMap()},
    ],
  });
}

Future<void> shareBackupFile(String jsonText) async {
  final bytes = Uint8List.fromList(utf8.encode(jsonText));
  await Share.shareXFiles([
    XFile.fromData(bytes, name: 'hisab_master_backup.json', mimeType: 'application/json'),
  ]);
}
