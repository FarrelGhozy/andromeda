import 'package:flutter/material.dart';

class DurationPicker extends StatelessWidget {
  final int selectedDuration;
  final ValueChanged<int> onSelected;

  const DurationPicker({
    super.key,
    required this.selectedDuration,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durations = [0, 15, 30, 60, 120];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Durasi Buka Valve:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              _labelFor(selectedDuration),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: durations.map((d) {
            final isSelected = selectedDuration == d;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(_labelFor(d)),
                  selected: isSelected,
                  onSelected: (_) => onSelected(d),
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : null,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _labelFor(int duration) {
    if (duration == 0) return '∞';
    return '${duration}s';
  }
}
