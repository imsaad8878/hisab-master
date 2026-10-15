import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/note_repository.dart';
import '../models/note.dart';
import 'auth_providers.dart';

final noteRepositoryProvider = Provider<NoteRepository>((ref) {
  final repo = NoteRepository();
  repo.initLocal();
  return repo;
});

final notesProvider = StreamProvider<List<NoteModel>>((ref) {
  final uid = ref.watch(dataUidProvider);
  if (uid == 'signed_out') return Stream.value(const []);
  return ref.watch(noteRepositoryProvider).watchNotes(uid);
});
