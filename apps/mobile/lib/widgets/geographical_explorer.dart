import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app/map_config.dart';
import '../app/tokens.dart';
import '../controllers/location_draft_controller.dart';
import 'app_card.dart';
import 'location_map.dart';

typedef MapTileProviderFactory = TileProvider Function();

/// View state only: unrelated to form drafts, submitted queries or results.
/// Retaining values lets a hidden map unmount without continuing tile requests.
class MapExplorerSession {
  bool expanded = false;
  LatLng center = const LatLng(20, 0);
  double zoom = 2;
}

class GeographicalExplorer extends StatefulWidget {
  const GeographicalExplorer({
    super.key,
    required this.session,
    this.configuration = MapTileConfiguration.environment,
    this.tileProviderFactory,
    this.draftController,
  });

  final MapExplorerSession session;
  final MapTileConfiguration configuration;
  final MapTileProviderFactory? tileProviderFactory;
  final LocationDraftController? draftController;

  @override
  State<GeographicalExplorer> createState() => _GeographicalExplorerState();
}

class _GeographicalExplorerState extends State<GeographicalExplorer> {
  @override
  void initState() {
    super.initState();
    widget.draftController?.addListener(_draftChanged);
  }

  @override
  void didUpdateWidget(GeographicalExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draftController != widget.draftController) {
      oldWidget.draftController?.removeListener(_draftChanged);
      widget.draftController?.addListener(_draftChanged);
    }
  }

  @override
  void dispose() {
    widget.draftController?.removeListener(_draftChanged);
    super.dispose();
  }

  void _draftChanged() => setState(() {});

  LatLng? get _selectedPoint {
    final point = widget.draftController?.coordinates;
    return point == null ? null : LatLng(point.latitude, point.longitude);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Semantics(
              expanded: widget.session.expanded,
              child: TextButton.icon(
                key: const ValueKey('map_explorer_toggle'),
                onPressed: () => setState(
                  () => widget.session.expanded = !widget.session.expanded,
                ),
                icon: const Icon(Icons.public, color: AppColors.cyan),
                label: Text(
                  widget.session.expanded ? 'Close map' : 'Explore on map',
                ),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ),
          ),
          if (widget.session.expanded) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.draftController == null
                  ? 'Pan and zoom to explore geography. Use the location form to analyze coordinates.'
                  : 'Tap or click to choose draft coordinates, then press Analyze in the location form. NASA POWER provides gridded climate estimates; the marker is not a weather station or a grid-cell boundary.',
              style: AppText.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (!widget.configuration.isConfigured)
              Semantics(
                liveRegion: true,
                child: Text(
                  'Map unavailable: a tile provider has not been configured and confirmed. Manual location entry and climate analysis remain available.',
                  key: const ValueKey('map_unconfigured'),
                  style: AppText.body,
                ),
              )
            else
              LocationMap(
                configuration: widget.configuration,
                tileProviderFactory: widget.tileProviderFactory,
                initialCenter: widget.session.center,
                initialZoom: widget.session.zoom,
                selectedPoint: _selectedPoint,
                onPointSelected: widget.draftController == null
                    ? null
                    : (point) => widget.draftController!.selectMapPoint(
                        point.latitude,
                        point.longitude,
                      ),
                onCameraChanged: (center, zoom) {
                  widget.session.center = center;
                  widget.session.zoom = zoom;
                },
              ),
          ],
        ],
      ),
    ),
  );
}
