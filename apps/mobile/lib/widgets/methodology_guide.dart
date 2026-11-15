import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../models/climate_analysis.dart';
import 'methodology_panel.dart';
import 'observatory_layout.dart';

/// Page context for the scientific guide; request state stays in DashboardScreen.
class MethodologyGuide extends StatelessWidget {
  const MethodologyGuide({
    super.key,
    required this.analysis,
    required this.explorer,
    this.status,
  });

  final ClimateAnalysis? analysis;
  final Widget explorer;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    final data = analysis;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObservatoryHero(
          eyebrow: 'Scientific field guide',
          title: 'How the analysis works',
          description: 'From monthly observations to trend estimates, uncertainty and interpretation.',
          compact: MediaQuery.sizeOf(context).width < AppBreakpoints.expanded,
          actions: explorer,
        ),
        ?status,
        if (data != null)
          MethodologyPanel(
            methodology: data.methodology,
            dataset: data.dataset,
            temperature: data.temperature,
            precipitation: data.precipitation,
          ),
      ],
    );
  }
}
