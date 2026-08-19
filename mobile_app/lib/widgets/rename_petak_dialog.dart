import 'package:flutter/material.dart';
import '../config/theme_config.dart';

/// Dialog ganti nama petak (custom sesuai tanaman di lahan).
/// Dipakai bersama dari grid petak & dashboard.
///
/// `onRename` dipanggil saat user menekan Simpan; return `true` jika
/// tersimpan di server. Dialog menutup dirinya sendiri hanya jika sukses.
Future<bool> showRenamePetakDialog(
  BuildContext context, {
  required String deviceId,
  required String currentName,
  required Future<bool> Function(String newName) onRename,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder:
        (_) => _RenamePetakDialog(
          deviceId: deviceId,
          currentName: currentName,
          onRename: onRename,
        ),
  );
  return saved ?? false;
}

/// Saran tanaman umum — tap chip langsung mengisi kolom nama.
const List<String> _plantSuggestions = [
  'Padi',
  'Cabai Rawit',
  'Cabai Merah',
  'Kangkung',
  'Tomat',
  'Bawang Merah',
  'Bawang Putih',
  'Jagung',
  'Terong',
  'Bayam',
  'Kacang Panjang',
  'Wortel',
  'Mentimun',
  'Selada',
];

class _RenamePetakDialog extends StatefulWidget {
  final String deviceId;
  final String currentName;
  final Future<bool> Function(String newName) onRename;

  const _RenamePetakDialog({
    required this.deviceId,
    required this.currentName,
    required this.onRename,
  });

  @override
  State<_RenamePetakDialog> createState() => _RenamePetakDialogState();
}

class _RenamePetakDialogState extends State<_RenamePetakDialog> {
  static const int _maxLength = 40;

  late final TextEditingController _controller;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Nama petak tidak boleh kosong');
      return;
    }
    if (name.length > _maxLength) {
      setState(() => _errorText = 'Maksimal $_maxLength karakter');
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    final ok = await widget.onRename(name);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Gagal mengubah nama petak — periksa koneksi'),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 3),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      title: Row(
        children: [
          Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Ganti Nama Petak',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.deviceId.toUpperCase().replaceAll('-', ' ')} — '
              'sesuaikan dengan tanaman di lahan ini',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: _maxLength,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nama petak',
                hintText: 'mis. Cabai Rawit',
                prefixIcon: const Icon(Icons.spa_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                errorText: _errorText,
              ),
              onSubmitted: (_) => _saving ? null : _save(),
            ),
            const SizedBox(height: 8),
            Text(
              'Saran tanaman:',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _plantSuggestions.map((plant) {
                    final selected = _controller.text.trim() == plant;
                    return ChoiceChip(
                      label: Text(plant),
                      selected: selected,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => _controller.text = plant,
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon:
              _saving
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.check, size: 18),
          label: const Text('Simpan'),
        ),
      ],
    );
  }
}
