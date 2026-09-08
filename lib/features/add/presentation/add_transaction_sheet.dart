import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/transaction_repository.dart';
import '../../../models/category_tag.dart';
import '../../../models/transaction.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/category_providers.dart';
import '../../../providers/transaction_providers.dart';
import '../../../utils/format.dart';

Future<void> showAddTransactionSheet(BuildContext context,
    {TransactionModel? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _AddTransactionForm(existing: existing),
    ),
  );
}

/// Default categories are built-in; this also merges user's custom ones.
class _AddTransactionForm extends ConsumerStatefulWidget {
  const _AddTransactionForm({this.existing});

  final TransactionModel? existing;

  @override
  ConsumerState<_AddTransactionForm> createState() => _AddTransactionFormState();
}

class _AddTransactionFormState extends ConsumerState<_AddTransactionForm> {
  late TransactionType _type =
      widget.existing?.type ?? TransactionType.expense;
  late String _category = widget.existing?.category ?? 'Food';
  late DateTime _date = widget.existing?.dateTime ?? DateTime.now();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  List<String> _categoriesFor(TransactionType t) {
    final customs =
        ref.read(customCategoriesProvider).valueOrNull ?? const <CategoryTag>[];
    final def = kCategories[t]!;
    final extra = customs
        .where((c) =>
            c.type == t.name &&
            !def.any((d) => d.toLowerCase() == c.name.toLowerCase()))
        .map((c) => c.name);
    return [...def, ...extra];
  }

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.existing == null
        ? ''
        : widget.existing!.amount
            .toStringAsFixed(widget.existing!.amount % 1 == 0 ? 0 : 2);
    _noteCtrl.text = widget.existing?.note ?? '';
    if (!_categoriesFor(_type).contains(_category)) {
      _category = _categoriesFor(_type).first;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _setType(TransactionType t) {
    setState(() {
      _type = t;
      if (!_categoriesFor(t).contains(_category)) {
        _category = _categoriesFor(t).first;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked != null) {
      setState(() {
        _date =
            DateTime(_date.year, _date.month, _date.day, picked.hour, picked.minute);
      });
    }
  }

  Future<void> _addNewCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New ${_type == TransactionType.expense ? 'expense' : 'income'} '
            'category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Coffee, Mosque, Tuition…',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Add')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    final err =
        await ref.read(categoryRepositoryProvider).addCategory(
              ref.read(dataUidProvider),
              name,
              _type.name,
            );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    setState(() => _category = name.trim());
  }

  Future<void> _maybeDeleteCategory(String c) async {
    if (isDefaultCategory(c)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default category delete kora jabe na.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$c" category?'),
        content: const Text('Transactions already using it will keep the name.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(categoryRepositoryProvider).deleteCategory(
          ref.read(dataUidProvider), CategoryTag(name: c, type: _type.name));
      if (_category == c) setState(() => _category = _categoriesFor(_type).first);
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ekta thik amount likhun.')),
      );
      return;
    }
    final repo = ref.read(transactionRepositoryProvider);
    final uid = ref.read(dataUidProvider);
    final model = TransactionModel(
      id: widget.existing?.id ?? TransactionRepository.newId(),
      amount: amount,
      type: _type,
      category: _category,
      dateTime: _date,
      note: _noteCtrl.text.trim(),
    );
    if (widget.existing == null) {
      await repo.addTransaction(uid, model);
    } else {
      await repo.updateTransaction(uid, model);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = _type == TransactionType.expense;
    ref.watch(customCategoriesProvider);
    final categories = _categoriesFor(_type);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null
                  ? 'Add transaction'
                  : 'Edit transaction',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Money Out'),
                  icon: Icon(Icons.trending_down),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Money In'),
                  icon: Icon(Icons.trending_up),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => _setType(s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              autofocus: widget.existing == null,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: theme.textTheme.headlineSmall,
              decoration: InputDecoration(
                prefixText: '৳ ',
                labelText: 'Amount (Tk)',
                prefixIcon: Icon(isExpense ? Icons.south_west : Icons.north_east,
                    color: isExpense ? theme.colorScheme.error : Colors.green),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Category', style: theme.textTheme.titleSmall),
                Text('long-press to delete custom',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CategoryChip(
                        category: c,
                        selected: _category == c,
                        onTap: () => setState(() => _category = c),
                        onLongPress: () => _maybeDeleteCategory(c),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _AddCategoryChip(onTap: _addNewCategory),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(
                  '${Format.date(_date)}  •  ${Format.time(_date)}',
                  style: const TextStyle(fontSize: 14),
                ),
                trailing:
                    TextButton(onPressed: _pickDate, child: const Text('Date')),
                onTap: _pickTime,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.check),
              label: Text(widget.existing == null ? 'Save' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final String category;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final custom = !isDefaultCategory(category);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 78,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.black12,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(categoryIcon(category),
                size: 22,
                color: custom && !selected
                    ? theme.colorScheme.secondary
                    : null),
            const SizedBox(height: 4),
            Text(category,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.bold : null),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _AddCategoryChip extends StatelessWidget {
  const _AddCategoryChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 78,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 22, color: Colors.grey.shade600),
            const SizedBox(height: 4),
            Text('New',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
