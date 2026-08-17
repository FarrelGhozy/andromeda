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

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'],
        date: DateTime.parse(json['date']),
        category: json['category'] ?? 'lainnya',
        title: json['title'] ?? '',
        content: json['content'] ?? '',
        createdAt: DateTime.parse(json['created_at']),
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
