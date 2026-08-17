import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../models/journal_entry.dart';
import '../providers/journal_provider.dart';

/// Form tambah/edit catatan jurnal.
/// Dipanggil tanpa argumen (tambah baru) atau dengan `JournalEntry` (edit).
class JournalEditScreen extends StatefulWidget {
  const JournalEditScreen({super.key});

  @override
  State<JournalEditScreen> createState() => _JournalEditScreenState();
}

class _JournalEditScreenState extends State<JournalEditScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = 'penyiraman';
  String? _editId; // null = tambah baru
  bool _argsLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute.of() membutuhkan inherited widget — aman di sini,
    // bukan di initState (Flutter runtime error jika dipanggil di initState).
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is JournalEntry) {
      _editId = args.id;
      _date = args.date;
      _category = args.category;
      _titleController.text = args.title;
      _contentController.text = args.content;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Judul tidak boleh kosong'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    final provider = context.read<JournalProvider>();
    final entry = JournalEntry(
      id: _editId,
      date: _date,
      category: _category,
      title: title,
      content: content,
    );
    if (_editId == null) {
      await provider.addEntry(entry);
    } else {
      await provider.updateEntry(entry);
    }
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _delete() async {
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
    if (confirmed != true || _editId == null) return;
    await context.read<JournalProvider>().deleteEntry(_editId!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editId == null ? 'Tambah Catatan' : 'Edit Catatan'),
        actions: [
          if (_editId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus',
              onPressed: _delete,
            ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Simpan',
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tanggal
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Tanggal'),
            trailing: Text(
              '${_date.day}/${_date.month}/${_date.year}',
              style: theme.textTheme.titleSmall,
            ),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          // Kategori
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(
              labelText: 'Kategori',
              border: OutlineInputBorder(),
            ),
            items: JournalProvider.categories
                .map((c) => DropdownMenuItem(
                      value: c.value,
                      child: Text(c.label),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'lainnya'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Judul *',
              hintText: 'Contoh: Siram pagi petak 1-3',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Isi catatan',
              hintText: 'Tulis detail kegiatan atau pengamatan...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan Catatan'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
