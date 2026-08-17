import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/journal_entry.dart';
import '../models/journal_article.dart';
import '../services/local_store.dart';

/// State fitur Jurnal & Pengetahuan (Fase 2):
/// - Catatan kegiatan petani (CRUD, tersimpan lokal)
/// - Pustaka artikel bundled (asset JSON, offline-friendly)
class JournalProvider extends ChangeNotifier {
  final LocalStore _store;

  List<JournalEntry> _entries = [];
  List<JournalArticle> _articles = [];
  bool _loaded = false;

  List<JournalEntry> get entries {
    final sorted = List<JournalEntry>.of(_entries);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }
  List<JournalArticle> get articles => _articles;
  bool get loaded => _loaded;

  JournalProvider(this._store);

  /// Muat catatan dari SharedPreferences + artikel dari asset.
  Future<void> init() async {
    // Catatan lokal
    final raw = await _store.getJson(LocalStore.journalEntriesKey);
    if (raw is List) {
      _entries = raw
          .map((e) => JournalEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    // Artikel bundled (asset)
    try {
      final jsonText =
          await rootBundle.loadString('assets/data/tips_petani.json');
      final list = jsonDecode(jsonText) as List;
      _articles = list
          .map((a) => JournalArticle.fromJson(Map<String, dynamic>.from(a)))
          .toList();
    } catch (_) {
      _articles = [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() =>
      _store.setJson(LocalStore.journalEntriesKey, _entries.map((e) => e.toJson()).toList());

  /// Tambah catatan baru.
  Future<void> addEntry(JournalEntry entry) async {
    _entries.add(entry);
    await _persist();
    notifyListeners();
  }

  /// Perbarui catatan yang sudah ada (berdasarkan id).
  Future<void> updateEntry(JournalEntry entry) async {
    final i = _entries.indexWhere((e) => e.id == entry.id);
    if (i < 0) return;
    _entries[i] = entry;
    await _persist();
    notifyListeners();
  }

  /// Hapus catatan.
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await _persist();
    notifyListeners();
  }

  /// Kategori untuk dropdown form & filter (urutan tampilan).
  static const List<({String value, String label, IconData icon})> categories = [
    (value: 'penyiraman', label: '💧 Penyiraman', icon: Icons.water_drop_outlined),
    (value: 'pemupukan', label: '🌱 Pemupukan', icon: Icons.grass),
    (value: 'hama-penyakit', label: '🐛 Hama & Penyakit', icon: Icons.pest_control_outlined),
    (value: 'panen', label: '🌾 Panen', icon: Icons.shopping_basket_outlined),
    (value: 'lainnya', label: '📝 Lainnya', icon: Icons.notes),
  ];

  static String categoryLabel(String value) {
    for (final c in categories) {
      if (c.value == value) return c.label;
    }
    return '📝 Lainnya';
  }
}
