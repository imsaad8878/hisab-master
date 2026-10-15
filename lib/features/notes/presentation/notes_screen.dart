import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/note_repository.dart';
import '../../../models/note.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/note_providers.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(notesProvider).valueOrNull ?? const [];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Note')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.edit_note),
        label: const Text('New note'),
      ),
      body: notes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sticky_note_2_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text('কোনো note নেই',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text(
                      'মনে মনে কিছু লিখে রাখো —\nকাজের কথা, তালিকা, আইডিয়া যা ইচ্ছে',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: notes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final n = notes[i];
                return Dismissible(
                  key: ValueKey(n.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete note?'),
                        content: Text(n.title.isEmpty
                            ? 'Untitled note'
                            : '"${n.title}" delete hobe.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor:
                                      theme.colorScheme.error),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref
                          .read(noteRepositoryProvider)
                          .deleteNote(ref.read(dataUidProvider), n.id);
                    }
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.delete_outline,
                        color: theme.colorScheme.onErrorContainer),
                  ),
                  child: Card(
                    child: ListTile(
                      onTap: () => _openEditor(context, ref, existing: n),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.sticky_note_2_outlined,
                            color: Colors.orange, size: 20),
                      ),
                      title: Text(
                        n.title.isEmpty ? 'Untitled' : n.title,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (n.body.isNotEmpty)
                            n.body.replaceAll('\n', ' • '),
                          DateFormat('d MMM yyyy • h:mm a')
                              .format(n.updatedAt),
                        ].join('\n'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                    ),
                  ),
                );
              },
            ),
    );
  }

  static Future<void> _openEditor(BuildContext context, WidgetRef ref,
      {NoteModel? existing}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                existing == null ? 'নতুন Note' : 'Note সম্পাদনা',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: existing == null,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
                decoration:
                    const InputDecoration(labelText: 'Title (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bodyCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 8,
                minLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Write here…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  final body = bodyCtrl.text.trim();
                  if (title.isEmpty && body.isEmpty) {
                    Navigator.pop(ctx);
                    return;
                  }
                  await ref.read(noteRepositoryProvider).saveNote(
                        ref.read(dataUidProvider),
                        NoteModel(
                          id: existing?.id ?? NoteRepository.newId(),
                          title: title,
                          body: body,
                          updatedAt: DateTime.now(),
                        ),
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
