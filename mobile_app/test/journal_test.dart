import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:andromeda/models/journal_entry.dart';
import 'package:andromeda/providers/journal_provider.dart';
import 'package:andromeda/routes.dart';
import 'package:andromeda/screens/journal_edit_screen.dart';
import 'package:andromeda/screens/journal_screen.dart';
import 'package:andromeda/services/local_store.dart';

/// Fake LocalStore untuk pengujian in-memory tanpa SharedPreferences nyata.
class FakeLocalStore extends LocalStore {
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> setJson(String key, dynamic value) async {
    _storage[key] = value;
  }

  @override
  Future<dynamic> getJson(String key) async {
    return _storage[key];
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }
}

void main() {
  group('JournalEntry Model', () {
    test('fromJson membaca semua kolom dengan benar', () {
      final now = DateTime(2026, 11, 19, 10, 0, 0);
      final json = {
        'id': 'entry-123',
        'date': now.toIso8601String(),
        'category': 'penyiraman',
        'title': 'Siram petak 1',
        'content': 'Tanah mulai kering di petak 1',
        'created_at': now.toIso8601String(),
      };

      final entry = JournalEntry.fromJson(json);

      expect(entry.id, 'entry-123');
      expect(entry.date, now);
      expect(entry.category, 'penyiraman');
      expect(entry.title, 'Siram petak 1');
      expect(entry.content, 'Tanah mulai kering di petak 1');
      expect(entry.createdAt, now);
    });

    test('fromJson defensif terhadap id int atau kolom tanggal null/rusak', () {
      final json = {
        'id': 99999, // numeric id dari data lama
        'date': 'bukan-tanggal-valid',
        'category': null,
        'title': null,
        'content': null,
        'created_at': null,
      };

      final entry = JournalEntry.fromJson(json);

      expect(entry.id, '99999');
      expect(entry.category, 'lainnya');
      expect(entry.title, '');
      expect(entry.content, '');
      expect(entry.date, isA<DateTime>());
      expect(entry.createdAt, isA<DateTime>());
    });

    test('toJson memformat entri dengan benar', () {
      final date = DateTime(2026, 11, 19);
      final created = DateTime(2026, 11, 19, 8, 30);
      final entry = JournalEntry(
        id: 'test-id',
        date: date,
        category: 'pemupukan',
        title: 'Pupuk NPK',
        content: 'Dosis 5 gram per tanaman',
        createdAt: created,
      );

      final json = entry.toJson();

      expect(json['id'], 'test-id');
      expect(json['date'], date.toIso8601String());
      expect(json['category'], 'pemupukan');
      expect(json['title'], 'Pupuk NPK');
      expect(json['content'], 'Dosis 5 gram per tanaman');
      expect(json['created_at'], created.toIso8601String());
    });

    test('copyWith memperbarui nilai dan mempertahankan field yang tidak diubah', () {
      final original = JournalEntry(
        id: 'orig-id',
        date: DateTime(2026, 11, 10),
        category: 'hama-penyakit',
        title: 'Semprot hama',
        content: 'Pakai pestisida nabati',
        createdAt: DateTime(2026, 11, 10, 7, 0),
      );

      final updated = original.copyWith(
        title: 'Semprot kutu daun',
        content: 'Pakai ekstrak daun tembakau',
      );

      expect(updated.id, 'orig-id');
      expect(updated.date, original.date);
      expect(updated.category, original.category);
      expect(updated.title, 'Semprot kutu daun');
      expect(updated.content, 'Pakai ekstrak daun tembakau');
      expect(updated.createdAt, original.createdAt);
    });
  });

  group('JournalProvider CRUD & Sorting', () {
    late FakeLocalStore fakeStore;
    late JournalProvider provider;

    setUp(() {
      fakeStore = FakeLocalStore();
      provider = JournalProvider(fakeStore);
    });

    test('addEntry menambahkan entri dan menyimpannya di storage', () async {
      await provider.init(loadArticles: false);
      expect(provider.entries, isEmpty);

      final entry = JournalEntry(
        id: '1',
        date: DateTime(2026, 11, 19),
        category: 'penyiraman',
        title: 'Penyiraman pagi',
        content: 'Petak 1 dan 2',
      );

      await provider.addEntry(entry);

      expect(provider.entries.length, 1);
      expect(provider.entries.first.title, 'Penyiraman pagi');

      // Validasi storage
      final stored = await fakeStore.getJson(LocalStore.journalEntriesKey);
      expect(stored, isA<List>());
      expect((stored as List).length, 1);
      expect(stored.first['title'], 'Penyiraman pagi');
    });

    test('updateEntry memperbarui entri yang ada tanpa membuat duplikat', () async {
      await provider.init(loadArticles: false);
      final entry = JournalEntry(
        id: 'edit-1',
        date: DateTime(2026, 11, 19),
        category: 'penyiraman',
        title: 'Penyiraman awal',
        content: 'Isi awal',
      );
      await provider.addEntry(entry);
      expect(provider.entries.length, 1);

      final updated = entry.copyWith(
        title: 'Penyiraman sore (diperbarui)',
        content: 'Isi diperbarui',
      );
      await provider.updateEntry(updated);

      expect(provider.entries.length, 1); // Tidak ada duplikat!
      expect(provider.entries.first.title, 'Penyiraman sore (diperbarui)');
      expect(provider.entries.first.content, 'Isi diperbarui');

      final stored = await fakeStore.getJson(LocalStore.journalEntriesKey) as List;
      expect(stored.length, 1);
      expect(stored.first['title'], 'Penyiraman sore (diperbarui)');
    });

    test('deleteEntry menghapus entri berdasarkan ID', () async {
      await provider.init(loadArticles: false);
      final e1 = JournalEntry(
        id: 'del-1',
        date: DateTime(2026, 11, 19),
        category: 'panen',
        title: 'Panen cabai',
        content: '10 kg',
      );
      final e2 = JournalEntry(
        id: 'del-2',
        date: DateTime(2026, 11, 19),
        category: 'pemupukan',
        title: 'Pupuk kandang',
        content: 'Petak 3',
      );
      await provider.addEntry(e1);
      await provider.addEntry(e2);
      expect(provider.entries.length, 2);

      await provider.deleteEntry('del-1');

      expect(provider.entries.length, 1);
      expect(provider.entries.first.id, 'del-2');

      final stored = await fakeStore.getJson(LocalStore.journalEntriesKey) as List;
      expect(stored.length, 1);
      expect(stored.first['id'], 'del-2');
    });

    test('entries terurut stabil: tanggal desc, lalu createdAt desc', () async {
      await provider.init(loadArticles: false);

      final day1 = DateTime(2026, 11, 18);
      final day2 = DateTime(2026, 11, 19);

      // Entri hari sama beda createdAt
      final eOldDate = JournalEntry(
        id: 'old-day',
        date: day1,
        category: 'lainnya',
        title: 'Kemarin',
        content: '',
        createdAt: DateTime(2026, 11, 18, 10, 0),
      );
      final eTodayMorning = JournalEntry(
        id: 'today-morning',
        date: day2,
        category: 'penyiraman',
        title: 'Hari ini pagi',
        content: '',
        createdAt: DateTime(2026, 11, 19, 7, 0),
      );
      final eTodayAfternoon = JournalEntry(
        id: 'today-afternoon',
        date: day2,
        category: 'panen',
        title: 'Hari ini sore',
        content: '',
        createdAt: DateTime(2026, 11, 19, 16, 0),
      );

      // Masukkan acak
      await provider.addEntry(eOldDate);
      await provider.addEntry(eTodayMorning);
      await provider.addEntry(eTodayAfternoon);

      final result = provider.entries;
      expect(result.length, 3);
      // Hari ini sore harus pertama (tanggal sama, createdAt lebih baru)
      expect(result[0].id, 'today-afternoon');
      // Hari ini pagi kedua
      expect(result[1].id, 'today-morning');
      // Kemarin terakhir
      expect(result[2].id, 'old-day');
    });

    test('categoryLabel mengembalikan label yang sesuai dan fallback ke lainnya', () {
      expect(JournalProvider.categoryLabel('penyiraman'), '💧 Penyiraman');
      expect(JournalProvider.categoryLabel('pemupukan'), '🌱 Pemupukan');
      expect(JournalProvider.categoryLabel('hama-penyakit'), '🐛 Hama & Penyakit');
      expect(JournalProvider.categoryLabel('panen'), '🌾 Panen');
      expect(JournalProvider.categoryLabel('lainnya'), '📝 Lainnya');
      expect(JournalProvider.categoryLabel('tidak-dikenal'), '📝 Lainnya');
    });
  });

  group('Routes & Journal Navigation Passing Arguments', () {
    test('onGenerateRoute journalEdit mengoper arguments ke JournalEditScreen', () {
      final testEntry = JournalEntry(
        id: 'route-test-1',
        date: DateTime(2026, 11, 19),
        category: 'panen',
        title: 'Panen Tomat',
        content: 'Hasil melimpah',
      );

      final route = AppRoutes.onGenerateRoute(
        RouteSettings(name: AppRoutes.journalEdit, arguments: testEntry),
      ) as MaterialPageRoute;

      expect(route.settings.name, AppRoutes.journalEdit);
      expect(route.settings.arguments, testEntry);

      final widget = route.builder(const _TestDummyContext()) as JournalEditScreen;
      expect(widget.entry, testEntry);
    });

    test('onGenerateRoute journalEdit tanpa argumen menghasilkan JournalEditScreen mode tambah baru', () {
      final route = AppRoutes.onGenerateRoute(
        const RouteSettings(name: AppRoutes.journalEdit),
      ) as MaterialPageRoute;

      final widget = route.builder(const _TestDummyContext()) as JournalEditScreen;
      expect(widget.entry, isNull);
    });
  });

  group('JournalEditScreen Widget Tests', () {
    late FakeLocalStore fakeStore;
    late JournalProvider provider;

    setUp(() {
      fakeStore = FakeLocalStore();
      provider = JournalProvider(fakeStore);
    });

    testWidgets('Mode Tambah Baru: judul form Tambah Catatan & tombol Hapus tidak tampil', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: JournalEditScreen(),
          ),
        ),
      );

      expect(find.text('Tambah Catatan'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('Simpan Catatan'), findsOneWidget);
    });

    testWidgets('Mode Edit: judul Edit Catatan, field terisi, tombol Hapus & Simpan Perubahan tampil', (tester) async {
      final entry = JournalEntry(
        id: 'widget-edit-1',
        date: DateTime(2026, 11, 19),
        category: 'pemupukan',
        title: 'Pemupukan Jagung',
        content: 'Pakai Urea',
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: JournalEditScreen(entry: entry),
          ),
        ),
      );

      expect(find.text('Edit Catatan'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('Simpan Perubahan'), findsOneWidget);
      expect(find.text('Pemupukan Jagung'), findsOneWidget);
      expect(find.text('Pakai Urea'), findsOneWidget);
    });

    testWidgets('JournalScreen menampilkan daftar, filter chip, dan menu aksi', (tester) async {
      await provider.init(loadArticles: false);
      await provider.addEntry(JournalEntry(
        id: 'entry-filter-1',
        date: DateTime(2026, 11, 19),
        category: 'penyiraman',
        title: 'Siram Pagi',
        content: 'Petak 1',
      ));
      await provider.addEntry(JournalEntry(
        id: 'entry-filter-2',
        date: DateTime(2026, 11, 19),
        category: 'pemupukan',
        title: 'Pupuk Kompos',
        content: 'Petak 2',
      ));

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: Scaffold(
              body: JournalScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Kedua entri tampil
      expect(find.text('Siram Pagi'), findsOneWidget);
      expect(find.text('Pupuk Kompos'), findsOneWidget);

      // Filter chip ada
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('💧 Penyiraman'), findsAtLeast(1));

      // Menu aksi titik tiga ada
      expect(find.byIcon(Icons.more_vert), findsNWidgets(2));
    });
  });
}

class _TestDummyContext implements BuildContext {
  const _TestDummyContext();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
