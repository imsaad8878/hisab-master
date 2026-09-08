import '../../models/transaction.dart';

class CategoryTag {
  const CategoryTag({required this.name, required this.type});

  final String name;

  /// 'income' or 'expense'
  final String type;

  Map<String, dynamic> toMap() => {'name': name, 'type': type};

  factory CategoryTag.fromMap(Map<String, dynamic> m) => CategoryTag(
        name: m['name'] as String? ?? '',
        type: m['type'] as String? ?? 'expense',
      );
}

const Map<String, List<String>> kCategoriesByTypeName = {
  'expense': [
    'Food',
    'Transport',
    'Rent',
    'Shopping',
    'Bills',
    'Health',
    'Education',
    'Entertainment',
    'Other',
  ],
  'income': [
    'Salary',
    'Business',
    'Freelance',
    'Gift',
    'Investment',
    'Other',
  ],
};

bool isDefaultCategory(String name) => kCategories.values
    .any((list) => list.any((c) => c.toLowerCase() == name.toLowerCase()));
