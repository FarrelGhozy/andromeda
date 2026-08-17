import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../models/journal_entry.dart';
import '../providers/journal_provider.dart';
import '../routes.dart';

/// Jurnal & Pengetahuan Petani (Fase 2) — satu halaman dua tab:
/// - "Catatan Saya": log harian kegiatan (CRUD, tersimpan lokal)
/// - "Pustaka": artikel pengetahuan bundled (bahasa sederhana, offline)
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();
    if (!provider.loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Jurnal & Pengetahuan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Jurnal & Pengetahuan'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.edit_note), text: 'Catatan Saya'),
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Pustaka'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, AppRoutes.journalEdit);
          },
          icon: const Icon(Icons.add),
          label: const Text('Tambah Catatan'),
        ),
        body: const TabBarView(
          children: [
            _EntriesTab(),
            _LibraryTab(),
          ],
        ),
      ),
    );
  }
}

/// Tab Catatan Saya — daftar entri dikelompokkan per tanggal.
class _EntriesTab extends StatelessWidget {
  const _EntriesTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = context.watch<JournalProvider>().entries;

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_note, size: 72,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('Belum ada catatan', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Catat penyiraman, pemupukan, hama, dan panen '
                'untuk merencanakan perawatan tanaman',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    // Kelompokkan per tanggal (desc).
    final grouped = <DateTime, List<JournalEntry>>{};
    for (final e in entries) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      grouped.putIfAbsent(day, () => []).add(e);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      children: [
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
            child: Text(
              _formatDay(day),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          for (final entry in grouped[day]!) _EntryCard(entry: entry),
        ],
      ],
    );
  }

  static String _formatDay(DateTime t) {
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${days[t.weekday - 1]}, ${t.day} ${months[t.month - 1]} ${t.year}';
  }
}

class _EntryCard extends StatelessWidget {
  final JournalEntry entry;

  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pushNamed(context, AppRoutes.journalEdit,
              arguments: entry);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      JournalProvider.categoryLabel(entry.category),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: 18,
                      color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 6),
              Text(entry.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (entry.content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(entry.content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tab Pustaka — daftar artikel pengetahuan (bundled).
class _LibraryTab extends StatelessWidget {
  const _LibraryTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final articles = context.watch<JournalProvider>().articles;

    if (articles.isEmpty) {
      return Center(
        child: Text('Pustaka kosong',
            style: theme.textTheme.bodyMedium),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(context, AppRoutes.journalArticle,
                  arguments: article);
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.menu_book_outlined,
                        color: AppColors.accentOrange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(article.title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(article.summary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
