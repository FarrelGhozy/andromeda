import 'package:flutter/material.dart';

/// Banner peringatan offline di homepage.
/// Menampilkan kapan data terakhir disimpan (dari snapshot cache) supaya
/// petani tahu bahwa data bukan realtime.
class OfflineBanner extends StatelessWidget {
  final DateTime? cachedAt;

  const OfflineBanner({super.key, this.cachedAt});

  static String formatSavedTime(DateTime t) {
    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${days[t.weekday - 1]}, ${t.day} ${months[t.month - 1]} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final cached = cachedAt;
    final timeText =
        cached != null ? ' — data tersimpan ${formatSavedTime(cached)}' : '';
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: colors.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: colors.onTertiaryContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline$timeText',
              style: TextStyle(
                color: colors.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
