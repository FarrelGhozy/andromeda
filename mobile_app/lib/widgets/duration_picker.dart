import 'package:flutter/material.dart';

class DurationPicker extends StatelessWidget {
  final ValueChanged<int> onSelected;

  const DurationPicker({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final durations = [15, 30, 60, 120];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Durasi Buka Valve:',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: durations.map((d) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton(
                  onPressed: () => onSelected(d),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    '${d}s',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
