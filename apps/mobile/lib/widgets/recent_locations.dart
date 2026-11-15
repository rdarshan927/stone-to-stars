import 'package:flutter/material.dart';

import '../app/tokens.dart';
import 'app_card.dart';

typedef AnalyzedLocation = ({
  double latitude,
  double longitude,
  int startYear,
  int endYear,
});

/// Session history presentation only. Dashboard owns the successful queries.
class RecentLocations extends StatelessWidget {
  const RecentLocations({
    super.key,
    required this.entries,
    required this.onSelected,
  });

  final List<AnalyzedLocation> entries;
  final ValueChanged<AnalyzedLocation> onSelected;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Recent Locations',
                style: AppText.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'This session only. Select to fill the draft, then press Analyze.',
              style: AppText.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final entry in entries)
                  Semantics(
                    button: true,
                    label:
                        'Load recent location: latitude ${entry.latitude} degrees, longitude ${entry.longitude} degrees, ${entry.startYear} to ${entry.endYear}',
                    hint: 'Updates the draft only. Press Analyze to request climate results.',
                    onTap: () => onSelected(entry),
                    excludeSemantics: true,
                    child: TextButton(
                      onPressed: () => onSelected(entry),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        alignment: Alignment.centerLeft,
                      ),
                      child: Text(
                        '${entry.latitude.toStringAsFixed(5)}°, ${entry.longitude.toStringAsFixed(5)}° · ${entry.startYear}–${entry.endYear}',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
