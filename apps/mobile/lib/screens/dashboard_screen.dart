import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../app/map_config.dart';
import '../controllers/location_draft_controller.dart';
import '../models/climate_analysis.dart';
import '../services/climate_api_service.dart';
import '../widgets/app_shell.dart';
import '../widgets/app_card.dart';
import '../widgets/status_pill.dart';
import '../widgets/location_form.dart';
import '../widgets/methodology_guide.dart';
import '../widgets/overview_card.dart';
import '../widgets/temperature_explorer.dart';
import '../widgets/precipitation_explorer.dart';
import '../widgets/geographical_explorer.dart';
import '../widgets/recent_locations.dart';

/// The main dashboard screen. Accepts an optional [ClimateApiService] so that
/// tests can inject a mock without making real HTTP calls.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.service,
    this.mapConfiguration = MapTileConfiguration.environment,
    this.mapTileProviderFactory,
  });

  // Exposed for injection in tests; null means use the default constructor.
  final ClimateApiService? service;
  final MapTileConfiguration mapConfiguration;
  final MapTileProviderFactory? mapTileProviderFactory;

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

  // The editor moves between destinations without recreating its controllers.
  final _locationFormKey = GlobalKey();
  final _mapSession = MapExplorerSession();
  late final LocationDraftController _locationDraft;
  final _recentLocations = <AnalyzedLocation>[];

  @override
  void initState() {
    super.initState();
    _locationDraft = LocationDraftController(
      latitude: _lat,
      longitude: _lon,
      startYear: _startYear,
      endYear: _endYear,
    );
    _service = widget.service ?? ClimateApiService();
    _analyze();
  }

  @override
  void dispose() {
    _locationDraft.dispose();
    if (widget.service == null) {
      _service.close();
    }
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_loading) return;
    final query = (
      latitude: _lat,
      longitude: _lon,
      startYear: _startYear,
      endYear: _endYear,
    );
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final result = await _service.fetchAnalysis(
        latitude: query.latitude,
        longitude: query.longitude,
        startYear: query.startYear,
        endYear: query.endYear,
      );
      if (mounted) {
        setState(() {
          _data = result;
          _loading = false;
          _recentLocations.removeWhere(
            (entry) =>
                entry.latitude == query.latitude &&
                (entry.longitude == query.longitude ||
                    (entry.longitude.abs() == 180 &&
                        query.longitude.abs() == 180)) &&
                entry.startYear == query.startYear &&
                entry.endYear == query.endYear,
          );
          _recentLocations.insert(0, query);
          if (_recentLocations.length > 5) _recentLocations.removeLast();
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
      child: _selectedIndex == 0
          ? OverviewCard(
              analysis: _data,
              recentLocations: RecentLocations(
                entries: List.unmodifiable(_recentLocations),
                onSelected: (entry) => _locationDraft.restoreAnalyzedLocation(
                  latitude: entry.latitude,
                  longitude: entry.longitude,
                  startYear: entry.startYear,
                  endYear: entry.endYear,
                ),
              ),
              geographicalExplorer: GeographicalExplorer(
                session: _mapSession,
                draftController: _locationDraft,
                configuration: widget.mapConfiguration,
                tileProviderFactory: widget.mapTileProviderFactory,
              ),
              explorer: _locationForm(),
              status: _loading || _error != null || _data == null
                  ? _body()
                  : null,
              onTemperature: () => setState(() => _selectedIndex = 1),
              onPrecipitation: () => setState(() => _selectedIndex = 2),
            )
          : _selectedIndex == 1
          ? TemperatureExplorer(
              analysis: _data,
              explorer: _locationForm(),
              status: _loading || _error != null || _data == null
                  ? _body()
                  : null,
            )
          : _selectedIndex == 2
          ? PrecipitationExplorer(
              analysis: _data,
              explorer: _locationForm(),
              status: _loading || _error != null || _data == null
                  ? _body()
                  : null,
            )
          : MethodologyGuide(
              analysis: _data,
              explorer: _locationForm(),
              status: _loading || _error != null || _data == null
                  ? _body()
                  : null,
            ),
    );
  }

  Widget _locationForm() => LocationForm(
    key: _locationFormKey,
    draftController: _locationDraft,
    onAnalyze: _onAnalyze,
    initialLat: _lat,
    initialLon: _lon,
    initialStartYear: _startYear,
    initialEndYear: _endYear,
    loading: _loading,
    compactMode: true,
    editLabel: 'Edit location',
  );

  // ── Shared body ─────────────────────────────────────────────────────────────

  Widget _body() {
    if (_loading) return _loadingState();
    if (_error != null) return _errorState(_error!);
    if (_data == null) return _emptyState();

    return const SizedBox.shrink();
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
}
