/// Artikel Pustaka Pengetahuan Petani (Fase 2).
/// Dibundel di asset app (`assets/data/tips_petani.json`) — bisa dibaca
/// offline, diperbarui tiap rilis.
class ArticleSection {
  final String heading;
  final String body;

  ArticleSection({required this.heading, required this.body});

  factory ArticleSection.fromJson(Map<String, dynamic> json) => ArticleSection(
        heading: json['heading'] ?? '',
        body: json['body'] ?? '',
      );
}

class JournalArticle {
  final String id;
  final String category; // penyiraman | pemupukan | hama | perawatan | lainnya
  final String title;
  final String summary;
  final List<ArticleSection> sections;

  JournalArticle({
    required this.id,
    required this.category,
    required this.title,
    required this.summary,
    required this.sections,
  });

  factory JournalArticle.fromJson(Map<String, dynamic> json) =>
      JournalArticle(
        id: json['id'] ?? '',
        category: json['category'] ?? 'lainnya',
        title: json['title'] ?? '',
        summary: json['summary'] ?? '',
        sections: (json['sections'] as List? ?? [])
            .map((s) => ArticleSection.fromJson(Map<String, dynamic>.from(s)))
            .toList(),
      );
}
