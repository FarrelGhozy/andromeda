import 'package:flutter/material.dart';
import '../config/theme_config.dart';
import '../models/journal_article.dart';

/// Halaman baca artikel Pustaka Pengetahuan (Fase 2).
/// Konten dari asset bundled — berfungsi penuh tanpa internet.
class JournalArticleScreen extends StatelessWidget {
  final JournalArticle article;

  const JournalArticleScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Pustaka')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ArticleCategory.label(article.category),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.accentOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(article.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            article.summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 32),
          for (final section in article.sections) ...[
            Text(section.heading, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(section.body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Label kategori artikel Pustaka (murni konstanta, tanpa dependensi provider).
/// Catatan: kategori artikel beda dari kategori catatan jurnal
/// ('hama'/'perawatan' untuk artikel; 'hama-penyakit' untuk catatan).
class ArticleCategory {
  static String label(String value) {
    const map = {
      'penyiraman': '💧 Penyiraman',
      'pemupukan': '🌱 Pemupukan',
      'hama': '🐛 Hama & Penyakit',
      'perawatan': '🛠️ Perawatan',
      'lainnya': '📝 Lainnya',
    };
    return map[value] ?? '📝 Lainnya';
  }
}
