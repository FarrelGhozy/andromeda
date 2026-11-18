import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// Banner penanda mode mock di homepage.
/// Data yang tampil adalah data contoh lokal, bukan data kebun.
class MockBanner extends StatelessWidget {
  const MockBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isMockMode) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: colors.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            color: colors.onTertiaryContainer,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'MODE MOCK — data contoh, bukan data kebun',
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
