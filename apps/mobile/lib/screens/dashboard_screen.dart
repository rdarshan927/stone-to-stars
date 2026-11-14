import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import '../services/climate_api_service.dart';
import '../widgets/annual_chart.dart';
import '../widgets/app_shell.dart';
import '../widgets/climate_trend_card.dart';
import '../widgets/excluded_years_panel.dart';
import '../widgets/seasonal_trend_card.dart';
import '../widgets/location_form.dart';
import '../widgets/methodology_panel.dart';
import '../widgets/overview_card.dart';

/// The main dashboard screen. Accepts an optional [ClimateApiService] so that
/// tests can inject a mock without making real HTTP calls.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.service});

  // Exposed for injection in tests; null means use the default constructor.
  final ClimateApiService? service;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ClimateApiService _service;

  ClimateAnalysis? _data;
  bool _loading = false;
  ApiException? _error;

  // Current query parameters (shown in the form).
  double _lat = 7.3;
  double _lon = 81.8;
  int _startYear = 1981;
  int _endYear = 2025;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ClimateApiService();
    _analyze();
  }

  @override
  void dispose() {
    if (widget.service == null) {
      _service.close();
    }
    super.dispose();
  }

  Future<void> _analyze() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.fetchAnalysis(
        latitude: _lat,
        longitude: _lon,
        startYear: _startYear,
        endYear: _endYear,
      );
      if (mounted) {
        setState(() {
          _data = result;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiException(
            ApiErrorKind.connection,
            'Unexpected error: $e',
          );
          _loading = false;
        });
      }
    }
  }

  void _onAnalyze(double lat, double lon, int start, int end) {
    setState(() {
      _lat = lat;
      _lon = lon;
      _startYear = start;
      _endYear = end;
    });
    _analyze();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      child: Column(
        children: [
          LocationForm(
            onAnalyze: _onAnalyze,
            initialLat: _lat,
            initialLon: _lon,
            initialStartYear: _startYear,
            initialEndYear: _endYear,
            loading: _loading,
            compactMode: _selectedIndex == 0,
          ),
          const SizedBox(height: AppSpacing.lg),
          _body(),
        ],
      ),
    );
  }

  // ── Shared body ─────────────────────────────────────────────────────────────

  Widget _body() {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState(_error!);
    if (_data == null) return _emptyState();

    return switch (_selectedIndex) {
      0 => _overviewSection(_data!),
      1 => _temperatureSection(_data!),
      2 => _precipitationSection(_data!),
      3 => _methodologySection(_data!),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _loadingState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(
          'Fetching climate data from NASA POWER…',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          'This may take up to 30 seconds.',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _errorState(ApiException err) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        const Icon(Icons.cloud_off, size: 48, color: AppColors.danger),
        const SizedBox(height: 16),
        Text(
          'Failed to load data',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: AppColors.danger),
        ),
        const SizedBox(height: 8),
        Text(
          err.message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _analyze,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Retry'),
          // Colours come from the theme (cyan fill, dark text).
        ),
      ],
    ),
  );

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Text(
      'Enter a location and press Analyze to begin.',
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: AppColors.textSecondary),
    ),
  );

  // ── Sections ─────────────────────────────────────────────────────────────

  Widget _overviewSection(ClimateAnalysis d) => OverviewCard(analysis: d);

  Widget _temperatureSection(ClimateAnalysis d) => _climateSection(
    d.temperature,
    variableName: 'Temperature',
    chartTitle: 'Annual Mean Temperature',
    accentColor: AppColors.cyan,
  );

  Widget _precipitationSection(ClimateAnalysis d) => _climateSection(
    d.precipitation,
    variableName: 'Precipitation',
    chartTitle: 'Annual Precipitation Total',
    accentColor: AppColors.amber,
  );

  Widget _climateSection(
    VariableAnalysis variable, {
    required String variableName,
    required String chartTitle,
    required Color accentColor,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Keep the chart full-width even when the detail cards share a row.
      AnnualChart(
        series: variable.series,
        seriesUnits: variable.seriesUnits,
        seriesColor: accentColor,
        title: chartTitle,
        trend: variable.trend,
      ),
      _methodNote(variable.method),
      const SizedBox(height: AppSpacing.lg),
      LayoutBuilder(
        builder: (context, constraints) {
          // Account for the shell's rail and padding as well as screen size.
          final twoColumns =
              MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded &&
              constraints.maxWidth >= AppBreakpoints.medium;
          final cardWidth = twoColumns
              ? (constraints.maxWidth - AppSpacing.lg) / 2
              : constraints.maxWidth;
          // Stable children preserve expanded details when the window resizes.
          return Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              SizedBox(
                width: cardWidth,
                child: ClimateTrendCard(
                  title: 'Annual $variableName Trend',
                  trend: variable.trend,
                  accentColor: accentColor,
                ),
              ),
              SizedBox(
                width: cardWidth,
                child: SeasonalTrendCard(
                  title: 'Seasonal $variableName Trend',
                  trend: variable.seasonal,
                  accentColor: accentColor,
                ),
              ),
            ],
          );
        },
      ),
      if (variable.excludedYears.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        ExcludedYearsPanel(excludedYears: variable.excludedYears),
      ],
    ],
  );

  /// Small note beneath a chart describing its annual aggregation method.
  /// Uses the `method` string provided directly by the backend — no paraphrasing.
  Widget _methodNote(String method) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.xs,
      AppSpacing.xs + AppSpacing.xxs,
      AppSpacing.xs,
      0,
    ),
    child: Text(
      method,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: AppColors.textSecondary),
    ),
  );

  Widget _methodologySection(ClimateAnalysis d) =>
      MethodologyPanel(methodology: d.methodology);
}
