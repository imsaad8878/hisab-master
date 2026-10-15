import 'package:flutter/material.dart';

enum TransactionType { income, expense }

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.category,
    required this.dateTime,
    this.note = '',
    this.photo,
    this.recurringId,
    this.party,
  });

  final String id;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime dateTime;
  final String note;

  /// Base64-compressed bill photo (optional).
  final String? photo;

  /// Id of the recurring rule that generated this entry (optional).
  final String? recurringId;

  /// Person or business this money went to / came from
  /// (e.g. "Rahim", "Bkash", "Boss"). Optional.
  final String? party;

  TransactionModel copyWith({
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? dateTime,
    String? note,
    String? photo,
    String? recurringId,
    String? party,
  }) {
    return TransactionModel(
      id: id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      dateTime: dateTime ?? this.dateTime,
      note: note ?? this.note,
      photo: photo ?? this.photo,
      recurringId: recurringId ?? this.recurringId,
      party: party ?? this.party,
    );
  }

  Map<String, dynamic> toMap() => {
        'amount': amount,
        'type': type.name,
        'category': category,
        'dateTime': dateTime.toIso8601String(),
        'note': note,
        if (photo != null && photo!.isNotEmpty) 'photo': photo,
        if (recurringId != null) 'recurringId': recurringId,
        if (party != null && party!.isNotEmpty) 'party': party,
      };

  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) {
    return TransactionModel(
      id: id,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: map['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      category: map['category'] as String? ?? 'Other',
      dateTime:
          DateTime.tryParse(map['dateTime'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String? ?? '',
      photo: map['photo'] as String?,
      recurringId: map['recurringId'] as String?,
      party: map['party'] as String?,
    );
  }
}

const Map<TransactionType, List<String>> kCategories = {
  TransactionType.expense: [
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
  TransactionType.income: [
    'Salary',
    'Business',
    'Freelance',
    'Gift',
    'Investment',
    'Other',
  ],
};

IconData categoryIcon(String category) {
  switch (category) {
    case 'Food':
      return Icons.restaurant;
    case 'Transport':
      return Icons.directions_bus;
    case 'Rent':
      return Icons.home_work;
    case 'Shopping':
      return Icons.shopping_bag;
    case 'Bills':
      return Icons.receipt_long;
    case 'Health':
      return Icons.medical_services;
    case 'Education':
      return Icons.school;
    case 'Entertainment':
      return Icons.sports_esports;
    case 'Salary':
      return Icons.payments;
    case 'Business':
      return Icons.storefront;
    case 'Freelance':
      return Icons.laptop;
    case 'Gift':
      return Icons.card_giftcard;
    case 'Investment':
      return Icons.trending_up;
    default:
      return Icons.category;
  }
}
