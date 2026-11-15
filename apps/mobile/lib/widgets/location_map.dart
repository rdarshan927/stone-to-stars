import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/map_config.dart';
import '../app/tokens.dart';

/// A bounded basemap. Selection changes a draft, never submits an analysis.
class LocationMap extends StatefulWidget {
  const LocationMap({
    super.key,
    required this.configuration,
    required this.initialCenter,
    required this.initialZoom,
    required this.onCameraChanged,
    this.tileProviderFactory,
    this.openLink = launchUrl,
    this.selectedPoint,
    this.onPointSelected,
  });

  final MapTileConfiguration configuration;
  final LatLng initialCenter;
  final double initialZoom;
  final void Function(LatLng center, double zoom) onCameraChanged;
  final TileProvider Function()? tileProviderFactory;
  final Future<bool> Function(Uri) openLink;
  final LatLng? selectedPoint;
  final ValueChanged<LatLng>? onPointSelected;

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  static const _mercatorLatitudeLimit = 85.05112878;
  final _controller = MapController();
  late TileProvider _provider;
  bool _ready = false;
  bool _failed = false;
  bool _readyQueued = false;
  int _attempt = 0;

  bool get _pointVisible =>
      widget.selectedPoint != null &&
      widget.selectedPoint!.latitude.abs() <= _mercatorLatitudeLimit;

  @override
  void didUpdateWidget(LocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pointVisible &&
        widget.selectedPoint != oldWidget.selectedPoint &&
        !_controller.camera.visibleBounds.contains(widget.selectedPoint!)) {
      // Keep valid manual edits visible without moving the camera on each key
      // when the point is already in view. Polar coordinates are never clamped.
      _controller.move(widget.selectedPoint!, _controller.camera.zoom);
    }
  }

  TileProvider _newProvider() =>
      widget.tileProviderFactory?.call() ??
      NetworkTileProvider(
        cachingProvider: kIsWeb
            ? null
            : BuiltInMapCachingProvider.getOrCreateInstance(
                maxCacheSize: 50 * 1024 * 1024,
              ),
      );

  @override
  void initState() {
    super.initState();
    _provider = _newProvider();
  }

  @override
  void dispose() {
    _controller.dispose();
    // TileLayer owns and disposes its provider, including on retry.
    super.dispose();
  }

  void _tileReady(int attempt) {
    if (_ready || _readyQueued) return;
    _readyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && attempt == _attempt) setState(() => _ready = true);
    });
  }

  void _tileFailed(int attempt) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && attempt == _attempt && !_failed) {
        setState(() => _failed = true);
      }
    });
  }

  void _retry() => setState(() {
    _attempt++;
    _ready = false;
    _failed = false;
    _readyQueued = false;
    _provider = _newProvider();
  });

  void _zoom(double delta) {
    final camera = _controller.camera;
    _controller.move(camera.center, (camera.zoom + delta).clamp(1, 16));
  }

  Future<void> _open(String url) async {
    var opened = false;
    try {
      opened = await widget.openLink(Uri.parse(url));
    } catch (_) {
      // Attribution failures must not affect the map or climate service.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not open the attribution link.')),
      );
    }
  }

  Widget _credit(String label, String url, {Widget? child}) => TextButton(
    onPressed: () => _open(url),
    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    child: child ?? Text(label, style: AppText.bodySmall),
  );

  @override
  Widget build(BuildContext context) {
    final attempt = _attempt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            IconButton.outlined(
              tooltip: 'Zoom in map',
              onPressed: () => _zoom(1),
              icon: const Icon(Icons.add),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
            IconButton.outlined(
              tooltip: 'Zoom out map',
              onPressed: () => _zoom(-1),
              icon: const Icon(Icons.remove),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            ),
            TextButton.icon(
              onPressed: () => _controller.move(const LatLng(20, 0), 2),
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Recenter view'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
            if (widget.onPointSelected != null)
              TextButton.icon(
                onPressed: () =>
                    widget.onPointSelected!(_controller.camera.center),
                icon: const Icon(Icons.place_outlined),
                label: const Text('Use map centre'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (widget.onPointSelected != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              widget.selectedPoint == null
                  ? 'Draft coordinates are incomplete or invalid. Enter valid coordinates or select a map point.'
                  : 'Draft location: ${widget.selectedPoint!.latitude.toStringAsFixed(5)}°, ${widget.selectedPoint!.longitude.toStringAsFixed(5)}°. Press Analyze to request climate results.${_pointVisible ? '' : ' This latitude is outside the map’s visible range; manual analysis remains available.'}',
              key: const ValueKey('map_draft_location'),
              style: AppText.bodySmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        LayoutBuilder(
          builder: (context, constraints) => ClipRRect(
            borderRadius: AppRadii.smAll,
            child: SizedBox(
              key: const ValueKey('map_canvas'),
              height: MediaQuery.sizeOf(context).height < 500
                  ? 200
                  : constraints.maxWidth < 600
                  ? 240
                  : 340,
              child: Semantics(
                label: widget.onPointSelected == null
                    ? 'Geographical basemap. Drag to pan, pinch or double tap to zoom. When focused, use arrow keys to pan.'
                    : 'Geographical basemap. Tap to select draft coordinates. Drag to pan, pinch or double tap to zoom. Use arrow keys to pan when focused, then activate Use map centre to select.',
                child: FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: widget.initialCenter,
                    initialZoom: widget.initialZoom,
                    minZoom: 1,
                    maxZoom: 16,
                    onTap: widget.onPointSelected == null
                        ? null
                        : (_, point) => widget.onPointSelected!(point),
                    backgroundColor: AppColors.background,
                    interactionOptions: InteractionOptions(
                      keyboardOptions: const KeyboardOptions(autofocus: false),
                      // Page wheel scrolling remains available over the map.
                      flags:
                          InteractiveFlag.all &
                          ~InteractiveFlag.rotate &
                          ~InteractiveFlag.scrollWheelZoom,
                      cursorKeyboardRotationOptions:
                          CursorKeyboardRotationOptions.disabled(),
                    ),
                    onPositionChanged: (camera, _) =>
                        widget.onCameraChanged(camera.center, camera.zoom),
                  ),
                  children: [
                    TileLayer(
                      key: ValueKey(_attempt),
                      urlTemplate: widget.configuration.urlTemplate,
                      tileProvider: _provider,
                      userAgentPackageName: 'stone-to-stars',
                      maxNativeZoom: 16,
                      panBuffer: 0,
                      keepBuffer: 1,
                      tileDisplay: const TileDisplay.instantaneous(),
                      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                      errorTileCallback: (_, _, _) => _tileFailed(attempt),
                      tileBuilder: (context, tileWidget, tile) {
                        if (tile.imageInfo != null) _tileReady(attempt);
                        return tileWidget;
                      },
                    ),
                    if (_pointVisible)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.selectedPoint!,
                            width: 40,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: const IgnorePointer(
                              child: ExcludeSemantics(
                                child: Icon(
                                  Icons.location_on,
                                  key: ValueKey('draft_location_marker'),
                                  color: AppColors.cyan,
                                  size: 40,
                                  shadows: [
                                    Shadow(
                                      color: AppColors.background,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          child: Text(
            _failed
                ? 'Some map tiles could not load. Check your connection, provider access or quota. Climate analysis is unaffected.'
                : _ready
                ? 'Basemap for geographical context; not NASA POWER observations.'
                : 'Loading map tiles…',
            key: const ValueKey('map_status'),
            style: AppText.bodySmall,
          ),
        ),
        if (_failed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry map tiles'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ),
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.configuration.isMapTiler)
              _credit(
                'MapTiler website',
                'https://www.maptiler.com/',
                child: Image.asset(
                  'assets/maps/maptiler-logo.png',
                  width: 100,
                  semanticLabel: 'MapTiler website',
                ),
              ),
            _credit(
              widget.configuration.attributionLabel,
              widget.configuration.attributionUrl,
            ),
            if (widget.configuration.isMapTiler ||
                widget.configuration.usesOpenStreetMap)
              _credit(
                '© OpenStreetMap contributors',
                'https://www.openstreetmap.org/copyright',
              ),
          ],
        ),
      ],
    );
  }
}
