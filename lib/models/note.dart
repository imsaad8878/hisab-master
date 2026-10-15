class NoteModel {
  const NoteModel({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory NoteModel.fromMap(String id, Map<String, dynamic> m) => NoteModel(
        id: id,
        title: m['title'] as String? ?? '',
        body: m['body'] as String? ?? '',
        updatedAt:
            DateTime.tryParse(m['updatedAt'] as String? ?? '') ??
                DateTime.now(),
      );
}
