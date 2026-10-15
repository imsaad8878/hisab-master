import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/repositories/loan_repository.dart';
import '../../../data/repositories/transaction_repository.dart';
import '../../../models/category_tag.dart';
import '../../../models/loan.dart';
import '../../../models/transaction.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/category_providers.dart';
import '../../../providers/loan_providers.dart';
import '../../../providers/profile_providers.dart';
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
  final _partyCtrl = TextEditingController();
  bool _saving = false;
  String? _amountError;
  String? _photo;
  bool _recurring = false;
  int _recurringDay = DateTime.now().day.clamp(1, 28);

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
    _partyCtrl.text = widget.existing?.party ?? '';
    _photo = widget.existing?.photo;
    _recurring = widget.existing?.recurringId != null;
    if (!_categoriesFor(_type).contains(_category)) {
      _category = _categoriesFor(_type).first;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _partyCtrl.dispose();
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

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1000,
        imageQuality: 60,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 800 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo khub boro — onno akta try korun.')));
        return;
      }
      setState(() => _photo = base64Encode(bytes));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo nite parini.')));
    }
  }

  Future<void> _save() async {
    if (_saving) return; // double-tap e duplicate entry hobe na
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Ekta thik amount likhun (৳ 0 er beshi).');
      return;
    }
    // Budget warning before saving an expense that crosses the monthly limit.
    if (_type == TransactionType.expense && widget.existing == null) {
      final budget =
          (ref.read(profileDocProvider).valueOrNull?['monthlyBudget'] as num?)
                  ?.toDouble() ??
              0;
      if (budget > 0) {
        final spent = ref.read(totalsProvider).monthExpense;
        final after = spent + amount;
        if (after > budget) {
          final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 36),
              title: const Text('Budget cross hobe!'),
              content: Text(
                'Ei month budget ${Format.tk(budget)} — ekhon porjonto '
                '${Format.tk(spent)} kharcha hoyeche.\n\n'
                'Ei ${Format.tk(amount)} save korle total ${Format.tk(after)} '
                'hobe, budget er ${Format.tk(after - budget)} beshi!',
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Firo')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Thik ase, save koro')),
              ],
            ),
          );
          if (ok != true) return;
        }
      }
    }
    setState(() {
      _saving = true;
      _amountError = null;
    });
    final repo = ref.read(transactionRepositoryProvider);
    final uid = ref.read(dataUidProvider);

    String? recurringId = widget.existing?.recurringId;
    if (_recurring && widget.existing == null) {
      final rule = RecurringRule(
        id: LoanRepository.newId(),
        amount: amount,
        type: _type.name,
        category: _category,
        dayOfMonth: _recurringDay,
        note: _noteCtrl.text.trim(),
      );
      await ref.read(recurringRepositoryProvider).saveRule(uid, rule);
      recurringId = rule.id;
    } else if (!_recurring && widget.existing?.recurringId != null) {
      await ref
          .read(recurringRepositoryProvider)
          .deleteRule(uid, widget.existing!.recurringId!);
      recurringId = null;
    }

    final model = TransactionModel(
      id: widget.existing?.id ?? TransactionRepository.newId(),
      amount: amount,
      type: _type,
      category: _category,
      dateTime: _date,
      note: _noteCtrl.text.trim(),
      photo: _photo,
      recurringId: recurringId,
      party: _partyCtrl.text.trim().isEmpty ? null : _partyCtrl.text.trim(),
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    try {
      if (widget.existing == null) {
        await repo.addTransaction(uid, model);
      } else {
        await repo.updateTransaction(uid, model);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      _showResultToast(messenger, theme, model, saved: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showResultToast(messenger, theme, model, saved: false, error: e);
    }
  }

  /// Save porshesh e clear confirmation — amount, type ar category dekhay,
  /// jate buja jay entry ta add hoyeche ki na.
  void _showResultToast(ScaffoldMessengerState messenger, ThemeData theme,
      TransactionModel t,
      {required bool saved, Object? error}) {
    final isExpense = t.type == TransactionType.expense;
    final color = saved
        ? (isExpense ? const Color(0xFFC62828) : const Color(0xFF2E7D32))
        : theme.colorScheme.error;
    final text = saved
        ? '${widget.existing == null ? 'Added' : 'Updated'}: '
            '${isExpense ? 'Expense' : 'Income'} ${Format.tk(t.amount)} • ${t.category}'
        : 'Save hoy ni — ${error ?? 'unknown error'}';
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      duration: Duration(seconds: saved ? 3 : 4),
      content: Row(
        children: [
          Icon(
            saved
                ? (isExpense ? Icons.south_west : Icons.north_east)
                : Icons.error_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ));
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
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                TextInputFormatter.withFunction((old, next) {
                  if ('.'.allMatches(next.text).length > 1) return old;
                  return next;
                }),
              ],
              style: theme.textTheme.headlineSmall,
              decoration: InputDecoration(
                prefixText: '৳ ',
                labelText: 'Amount (Tk)',
                errorText: _amountError,
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
              controller: _partyCtrl,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: _type == TransactionType.expense
                    ? 'কাকে দিলাম? (optional)'
                    : 'কার কাছে পাইল? (optional)',
                helperText: 'নাম, দোকান, ব্যাক্তি — যেকোনো',
                prefixIcon: Icon(_type == TransactionType.expense
                    ? Icons.person_off_outlined
                    : Icons.person_add_alt_outlined),
              ),
            ),
            TextField(
              controller: _noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Bill photo'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_outlined, size: 18),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            if (_photo != null) ...[
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(_photo!),
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _photo = null),
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _recurring,
              onChanged: (v) => setState(() => _recurring = v),
              title: const Text('Repeat every month',
                  style: TextStyle(fontSize: 14)),
              subtitle: const Text('Rent, salary — bar bar likhte hobe na',
                  style: TextStyle(fontSize: 12)),
              secondary: const Icon(Icons.repeat),
            ),
            if (_recurring)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Text('Day: ', style: TextStyle(fontSize: 13)),
                    DropdownButton<int>(
                      value: _recurringDay,
                      items: [
                        for (var d = 1; d <= 28; d++)
                          DropdownMenuItem(value: d, child: Text('$d')),
                      ],
                      onChanged: (d) =>
                          setState(() => _recurringDay = d ?? _recurringDay),
                    ),
                    const SizedBox(width: 8),
                    Text('of every month',
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: (isExpense ? theme.colorScheme.error : Colors.green)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (isExpense ? theme.colorScheme.error : Colors.green)
                      .withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(isExpense ? Icons.south_west : Icons.north_east,
                      size: 18,
                      color:
                          isExpense ? theme.colorScheme.error : Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    '${isExpense ? 'Expense' : 'Income'}: '
                    '${Format.tk(double.tryParse(_amountCtrl.text.trim()) ?? 0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color:
                          isExpense ? theme.colorScheme.error : Colors.green,
                    ),
                  ),
                  const Spacer(),
                  Text(_category,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor:
                    isExpense ? theme.colorScheme.error : Colors.green,
                disabledBackgroundColor:
                    (isExpense ? theme.colorScheme.error : Colors.green)
                        .withValues(alpha: 0.5),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_saving
                  ? 'Saving…'
                  : widget.existing == null
                      ? 'Save'
                      : 'Update'),
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
