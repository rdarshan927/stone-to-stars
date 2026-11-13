import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../models/climate_analysis.dart';
import '../services/climate_api_service.dart';
import '../widgets/annual_chart.dart';
import '../widgets/location_form.dart';
import '../widgets/methodology_panel.dart';
import '../widgets/overview_card.dart';
import '../widgets/trend_card.dart';

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
  static const double _kDesktopBreakpoint = 900;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _kDesktopBreakpoint;
        return isDesktop ? _desktopLayout() : _mobileLayout();
      },
    );
  }

  // ── Desktop layout ──────────────────────────────────────────────────────────

  Widget _desktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.thermostat_outlined),
                selectedIcon: Icon(Icons.thermostat),
                label: Text('Temperature'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.water_drop_outlined),
                selectedIcon: Icon(Icons.water_drop),
                label: Text('Precipitation'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.science_outlined),
                selectedIcon: Icon(Icons.science),
                label: Text('Methodology'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Location form always visible at top on desktop.
                  LocationForm(
                    onAnalyze: _onAnalyze,
                    initialLat: _lat,
                    initialLon: _lon,
                    initialStartYear: _startYear,
                    initialEndYear: _endYear,
                    loading: _loading,
                  ),
                  const SizedBox(height: 20),
                  _body(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile layout ───────────────────────────────────────────────────────────

  Widget _mobileLayout() {
    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.thermostat_outlined),
            selectedIcon: Icon(Icons.thermostat),
            label: 'Temperature',
          ),
          NavigationDestination(
            icon: Icon(Icons.water_drop_outlined),
            selectedIcon: Icon(Icons.water_drop),
            label: 'Precipitation',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science),
            label: 'Methodology',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            LocationForm(
              onAnalyze: _onAnalyze,
              initialLat: _lat,
              initialLon: _lon,
              initialStartYear: _startYear,
              initialEndYear: _endYear,
              loading: _loading,
            ),
            const SizedBox(height: 16),
            _body(),
          ],
        ),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.blue,
            foregroundColor: Colors.white,
          ),
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

  Widget _temperatureSection(ClimateAnalysis d) {
    final t = d.temperature;
    return Column(
      children: [
        AnnualChart(
          series: t.series,
          seriesUnits: t.seriesUnits,
          seriesColor: AppColors.cyan,
          title: 'Annual Mean Temperature',
          trend: t.trend,
        ),
        const SizedBox(height: 16),
        TrendCard(title: 'Annual Temperature Trend', trend: t.trend),
        const SizedBox(height: 16),
        _seasonalSummary('Seasonal Temperature Trend', t.seasonal),
        if (t.excludedYears.isNotEmpty) ...[
          const SizedBox(height: 16),
          _excludedYearsCard(t.excludedYears),
        ],
      ],
    );
  }

  Widget _precipitationSection(ClimateAnalysis d) {
    final p = d.precipitation;
    return Column(
      children: [
        AnnualChart(
          series: p.series,
          seriesUnits: p.seriesUnits,
          seriesColor: AppColors.orange,
          title: 'Annual Precipitation Total',
          trend: p.trend,
        ),
        const SizedBox(height: 16),
        TrendCard(title: 'Annual Precipitation Trend', trend: p.trend),
        const SizedBox(height: 16),
        _seasonalSummary('Seasonal Precipitation Trend', p.seasonal),
        if (p.excludedYears.isNotEmpty) ...[
          const SizedBox(height: 16),
          _excludedYearsCard(p.excludedYears),
        ],
      ],
    );
  }

  Widget _methodologySection(ClimateAnalysis d) =>
      MethodologyPanel(methodology: d.methodology);

  Widget _seasonalSummary(String title, SeasonalTrend s) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (!s.hasResult)
            Text(
              'Insufficient data for seasonal trend analysis.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            )
          else ...[
            if (s.direction != null)
              _pill(
                s.direction![0].toUpperCase() + s.direction!.substring(1),
                s.direction == 'increasing' ? AppColors.cyan : AppColors.orange,
              ),
            const SizedBox(height: 8),
            if (s.senSlopePerDecade != null)
              Text(
                'Sen\'s slope: ${s.senSlopePerDecade!.toStringAsFixed(4)} ${s.slopeUnitsPerDecade}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            if (s.pValue != null)
              Text(
                'p-value: ${s.pValue!.toStringAsFixed(4)} — '
                '${(s.significant ?? false) ? 'Significant' : 'Not significant'}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ],
      ),
    );
  }

  Widget _excludedYearsCard(List<ExcludedYear> excluded) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Excluded Years (incomplete data)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: excluded
                .map(
                  (e) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger.withAlpha(80)),
                    ),
                    child: Text(
                      '${e.year} (${e.validMonths}/12)',
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: AppColors.danger),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
