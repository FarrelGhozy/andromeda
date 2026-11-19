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
class _EntriesTab extends StatefulWidget {
  const _EntriesTab();

  @override
  State<_EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends State<_EntriesTab> {
  String? _selectedCategory; // null = semua

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allEntries = context.watch<JournalProvider>().entries;

    if (allEntries.isEmpty) {
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

    final entries = _selectedCategory == null
        ? allEntries
        : allEntries.where((e) => e.category == _selectedCategory).toList();

    // Kelompokkan per tanggal (desc).
    final grouped = <DateTime, List<JournalEntry>>{};
    for (final e in entries) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      grouped.putIfAbsent(day, () => []).add(e);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // Filter chip horizontal
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: const Text('Semua'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                ),
              ),
              for (final cat in JournalProvider.categories)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat.label),
                    selected: _selectedCategory == cat.value,
                    onSelected: (_) => setState(() {
                      _selectedCategory =
                          _selectedCategory == cat.value ? null : cat.value;
                    }),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_alt_off_outlined,
                          size: 48, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text('Tidak ada catatan di kategori ini',
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _selectedCategory = null),
                        child: const Text('Tampilkan Semua'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
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
                      for (final entry in grouped[day]!)
                        _EntryCard(entry: entry),
                    ],
                  ],
                ),
        ),
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

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus catatan?'),
        content: const Text('Catatan ini akan dihapus permanen dari HP.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final provider = context.read<JournalProvider>();
    await provider.deleteEntry(entry.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Catatan berhasil dihapus'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ));
  }

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
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 20,
                        color: theme.colorScheme.onSurfaceVariant),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (action) {
                      if (action == 'edit') {
                        HapticFeedback.lightImpact();
                        Navigator.pushNamed(context, AppRoutes.journalEdit,
                            arguments: entry);
                      } else if (action == 'delete') {
                        HapticFeedback.lightImpact();
                        _delete(context);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Catatan'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 18, color: AppColors.danger),
                            SizedBox(width: 8),
                            Text('Hapus Catatan',
                                style: TextStyle(color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  ),
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
