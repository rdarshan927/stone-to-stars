import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/climate_analysis.dart';
import 'app_card.dart';
import 'status_pill.dart';

/// Displays only the exclusion fields exposed by the frontend model.
class ExcludedYearsPanel extends StatelessWidget {
  const ExcludedYearsPanel({super.key, required this.excludedYears});

  final List<ExcludedYear> excludedYears;

  @override
  Widget build(BuildContext context) {
    if (excludedYears.isEmpty) return const SizedBox.shrink();

    return AppCard.callout(
      accent: AppColors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Excluded years', style: AppText.subtitle),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Annual analysis requires 12 valid months per year. '
            'These years have incomplete monthly data.',
            style: AppText.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final year in excludedYears)
                StatusPill(
                  label: '${year.year} · ${year.validMonths}/12 valid months',
                  color: AppColors.amber,
                  icon: Icons.info_outline,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
