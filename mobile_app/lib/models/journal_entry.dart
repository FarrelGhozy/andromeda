/// Entri catatan kegiatan petani (Fase 2 — Jurnal).
/// 100% tersimpan lokal di SharedPreferences via LocalStore.
class JournalEntry {
  final String id;
  final DateTime date; // tanggal kejadian (bisa berbeda dari waktu dibuat)
  final String category; // penyiraman | pemupukan | hama-penyakit | panen | lainnya
  final String title;
  final String content;
  final DateTime createdAt;

  JournalEntry({
    String? id,
    required this.date,
    required this.category,
    required this.title,
    required this.content,
    DateTime? createdAt,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  JournalEntry copyWith({
    String? id,
    DateTime? date,
    String? category,
    String? title,
    String? content,
    DateTime? createdAt,
  }) =>
      JournalEntry(
        id: id ?? this.id,
        date: date ?? this.date,
        category: category ?? this.category,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
      );

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id']?.toString(),
        date: json['date'] != null
            ? (DateTime.tryParse(json['date'].toString()) ?? DateTime.now())
            : DateTime.now(),
        category: json['category']?.toString() ?? 'lainnya',
        title: json['title']?.toString() ?? '',
        content: json['content']?.toString() ?? '',
        createdAt: json['created_at'] != null
            ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'category': category,
        'title': title,
        'content': content,
        'created_at': createdAt.toIso8601String(),
      };
}
