import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import '../services/climate_api_service.dart';
import '../widgets/annual_chart.dart';
import '../widgets/app_shell.dart';
import '../widgets/app_card.dart';
import '../widgets/status_pill.dart';
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
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
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
    if (_loading) return;
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

  Widget _loadingState() => _stateCard(
    title: 'Fetching climate data from NASA POWER…',
    children: [
      const CircularProgressIndicator(semanticsLabel: 'Analysis in progress'),
      const SizedBox(height: AppSpacing.lg),
      Text(
        'Waiting for climate observations and analysis. This may take a little while.',
        style: AppText.bodySmall,
      ),
    ],
  );

  Widget _errorState(ApiException err) {
    final (label, guidance, icon) = switch (err.kind) {
      ApiErrorKind.connection => (
        'Connection unavailable',
        'Check your connection and that the climate service is available, then retry.',
        Icons.cloud_off,
      ),
      ApiErrorKind.timeout => (
        'Request timed out',
        'The service did not respond in time. You can retry this analysis.',
        Icons.timer_outlined,
      ),
      ApiErrorKind.http => (
        'Service error',
        'The climate service could not complete this request. Review the details below before retrying.',
        Icons.cloud_off,
      ),
      ApiErrorKind.invalidResponse => (
        'Unexpected response',
        'The service response could not be read as climate analysis. You can retry the request.',
        Icons.info_outline,
      ),
    };
    return _stateCard(
      title: 'Failed to load data',
      children: [
        StatusPill(label: label, color: AppColors.danger, icon: icon),
        const SizedBox(height: AppSpacing.md),
        Text(guidance, style: AppText.body),
        const SizedBox(height: AppSpacing.sm),
        Text(err.message, style: AppText.bodySmall),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton.icon(
          onPressed: _analyze,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _emptyState() => _stateCard(
    title: 'Ready to explore',
    children: [
      const StatusPill(
        label: 'No analysis yet',
        color: AppColors.textSecondary,
        icon: Icons.info_outline,
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        'Enter a location and press Analyze to begin.',
        style: AppText.bodySmall,
      ),
    ],
  );

  Widget _stateCard({required String title, required List<Widget> children}) =>
      Semantics(
        liveRegion: true,
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: AppText.title)),
              const SizedBox(height: AppSpacing.lg),
              ...children,
            ],
          ),
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
