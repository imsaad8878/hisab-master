import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/category_repository.dart';
import '../models/category_tag.dart';
import 'auth_providers.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final repo = CategoryRepository();
  repo.initLocal();
  return repo;
});

/// Custom (user-created) categories only — defaults are separate.
final customCategoriesProvider = StreamProvider<List<CategoryTag>>((ref) {
  final uid = ref.watch(dataUidProvider);
  if (uid == 'signed_out') return Stream.value(const []);
  return ref.watch(categoryRepositoryProvider).watchCategories(uid);
});
