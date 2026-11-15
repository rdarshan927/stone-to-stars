import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../controllers/location_draft_controller.dart';

String _formatSummaryCoord(double v, String pos, String neg) =>
    '${v.abs().toStringAsFixed(2)}°${v >= 0 ? pos : neg}';

/// Coordinate + year input controls.
///
/// Shows four text fields (Latitude, Longitude, Start Year, End Year)
/// and an Analyze button. Calls [onAnalyze] when the user submits valid values.
///
/// When [compactMode] is `true` (used on the Overview tab):
/// - On phone viewports (`< AppBreakpoints.medium`), renders a compact summary
///   line showing coordinates and analysis period with an `Edit` action that
///   expands the full form.
/// - On tablet and desktop viewports (`>= AppBreakpoints.medium`), renders a
///   compact form that wraps when available space is limited.
/// When [compactMode] is `false` (default), renders the full two-row form.
class LocationForm extends StatefulWidget {
  const LocationForm({
    super.key,
    required this.onAnalyze,
    this.initialLat = 7.3,
    this.initialLon = 81.8,
    this.initialStartYear = 1981,
    this.initialEndYear = 2025,
    this.loading = false,
    this.compactMode = false,
    this.editLabel = 'Edit',
    this.draftController,
  });

  final void Function(double lat, double lon, int start, int end) onAnalyze;
  final double initialLat;
  final double initialLon;
  final int initialStartYear;
  final int initialEndYear;
  final bool loading;
  final bool compactMode;
  final String editLabel;
  final LocationDraftController? draftController;

  @override
  State<LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends State<LocationForm> {
  final _formKey = GlobalKey<FormState>();
  late LocationDraftController _draft;
  bool _ownsDraft = false;
  TextEditingController get _lat => _draft.latitude;
  TextEditingController get _lon => _draft.longitude;
  TextEditingController get _start => _draft.startYear;
  TextEditingController get _end => _draft.endYear;

  /// Whether the phone summary bar on Overview has been expanded by the user.
  bool _expandedOnPhone = false;

  @override
  void initState() {
    super.initState();
    _attachDraft();
  }

  void _attachDraft() {
    _ownsDraft = widget.draftController == null;
    _draft =
        widget.draftController ??
        LocationDraftController(
          latitude: widget.initialLat,
          longitude: widget.initialLon,
          startYear: widget.initialStartYear,
          endYear: widget.initialEndYear,
        );
    _draft.addListener(_draftChanged);
  }

  void _draftChanged() => setState(() {});

  /// P0-4: Keep controllers in sync when the parent commits new query
  /// parameters. Only updates a controller if the corresponding prop has
  /// actually changed, so user-entered text is never overwritten mid-edit
  /// unless the parent explicitly advances to a new value.
  @override
  void didUpdateWidget(LocationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draftController != widget.draftController) {
      _draft.removeListener(_draftChanged);
      if (_ownsDraft) _draft.dispose();
      _attachDraft();
    }
    // Shared drafts are never overwritten by submitted-query props.
    if (widget.draftController != null) return;
    if (oldWidget.initialLat != widget.initialLat) {
      _lat.text = '${widget.initialLat}';
    }
    if (oldWidget.initialLon != widget.initialLon) {
      _lon.text = '${widget.initialLon}';
    }
    if (oldWidget.initialStartYear != widget.initialStartYear) {
      _start.text = '${widget.initialStartYear}';
    }
    if (oldWidget.initialEndYear != widget.initialEndYear) {
      _end.text = '${widget.initialEndYear}';
    }
  }

  @override
  void dispose() {
    _draft.removeListener(_draftChanged);
    if (_ownsDraft) _draft.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final lat = double.parse(_lat.text.trim());
    final lon = double.parse(_lon.text.trim());
    final start = int.parse(_start.text.trim());
    final end = int.parse(_end.text.trim());
    if (_expandedOnPhone) {
      setState(() => _expandedOnPhone = false);
    }
    widget.onAnalyze(lat, lon, start, end);
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < AppBreakpoints.medium;
    final Widget editor;
    if (widget.compactMode && isPhone && !_expandedOnPhone) {
      editor = _buildPhoneCollapsedSummary(context);
    } else if (widget.compactMode && !isPhone) {
      editor = _buildHorizontalCompactForm(context);
    } else {
      editor = _buildFullForm(
        context,
        showCollapseAction: widget.compactMode && isPhone && _expandedOnPhone,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        editor,
        if (widget.draftController != null && _hasDraftChanges) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Editing a draft. Last submitted query: '
            '${_formatSummaryCoord(widget.initialLat, 'N', 'S')}, '
            '${_formatSummaryCoord(widget.initialLon, 'E', 'W')} · '
            '${widget.initialStartYear}–${widget.initialEndYear}.',
            key: const ValueKey('submitted_location_context'),
            style: AppText.bodySmall,
          ),
        ],
      ],
    );
  }

  bool get _hasDraftChanges {
    final point = _draft.coordinates;
    return point == null ||
        point.latitude != widget.initialLat ||
        point.longitude != widget.initialLon ||
        int.tryParse(_start.text.trim()) != widget.initialStartYear ||
        int.tryParse(_end.text.trim()) != widget.initialEndYear;
  }

  Widget _buildPhoneCollapsedSummary(BuildContext context) {
    final point = _draft.coordinates;
    final coordText = point == null
        ? 'Incomplete or invalid coordinates'
        : '${_formatSummaryCoord(point.latitude, 'N', 'S')}, '
              '${_formatSummaryCoord(point.longitude, 'E', 'W')}';
    final periodText = '${_start.text}–${_end.text}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgAll,
        border: const Border.fromBorderSide(AppBorders.subtle),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 16, color: AppColors.cyan),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Location & Period',
                  style: AppText.label.copyWith(fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  '$coordText  ·  $periodText${_hasDraftChanges ? ' · Draft, not analyzed' : ''}',
                  style: AppText.numeric.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (widget.loading) ...[
            const SizedBox(width: AppSpacing.sm),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: TextButton.icon(
              onPressed: () => setState(() => _expandedOnPhone = true),
              icon: const Icon(Icons.tune, size: 16, color: AppColors.cyan),
              label: Text(
                widget.editLabel,
                style: AppText.label.copyWith(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                minimumSize: const Size(
                  kMinInteractiveDimension,
                  kMinInteractiveDimension,
                ),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCompactForm(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgAll,
        border: const Border.fromBorderSide(AppBorders.subtle),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Location & Period',
              style: AppText.label.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _fieldLayout(compact: true, includeAnalyze: true),
          ],
        ),
      ),
    );
  }

  Widget _buildFullForm(
    BuildContext context, {
    required bool showCollapseAction,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.lgAll,
        border: const Border.fromBorderSide(AppBorders.subtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Location & Period',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (showCollapseAction)
                  TextButton.icon(
                    onPressed: () => setState(() => _expandedOnPhone = false),
                    icon: const Icon(
                      Icons.expand_less,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    label: Text('Collapse', style: AppText.label),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      minimumSize: const Size(
                        kMinInteractiveDimension,
                        kMinInteractiveDimension,
                      ),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _fieldLayout(compact: false, includeAnalyze: false),
            const SizedBox(height: 16),
            _analyzeButton(compact: false),
          ],
        ),
      ),
    );
  }

  Widget _fieldLayout({
    required bool compact,
    required bool includeAnalyze,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final fields = [
        _field(
          controller: _lat,
          label: 'Latitude',
          hint: '−90 to 90',
          validator: _validateLat,
          compact: compact,
        ),
        _field(
          controller: _lon,
          label: 'Longitude',
          hint: '−180 to 180',
          validator: _validateLon,
          compact: compact,
        ),
        _field(
          controller: _start,
          label: 'Start Year',
          hint: '≥ 1981',
          validator: _validateStart,
          isInt: true,
          compact: compact,
        ),
        _field(
          controller: _end,
          label: 'End Year',
          hint: '≤ 2025',
          validator: _validateEnd,
          isInt: true,
          compact: compact,
        ),
      ];
      if (compact && constraints.maxWidth >= 520 * scale) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < fields.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(flex: i < 2 ? 3 : 2, child: fields[i]),
            ],
            const SizedBox(width: AppSpacing.sm + AppSpacing.xxs),
            _analyzeButton(compact: true),
          ],
        );
      }
      final gap = compact ? AppSpacing.sm : AppSpacing.sm + AppSpacing.xxs;
      final minimumFieldWidth = (compact ? 140 : 120) * scale;
      final columns = constraints.maxWidth >= minimumFieldWidth * 2 + gap
          ? 2
          : 1;
      final fieldWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final field in fields) SizedBox(width: fieldWidth, child: field),
          if (includeAnalyze) _analyzeButton(compact: true),
        ],
      );
    },
  );

  Widget _analyzeButton({required bool compact}) {
    return ElevatedButton.icon(
      onPressed: widget.loading ? null : _submit,
      icon: widget.loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.search, size: 18),
      label: Text(widget.loading ? 'Analyzing…' : 'Analyze'),
      // Colours come from the theme (cyan fill, dark text).
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 18,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String? Function(String?) validator,
    bool isInt = false,
    bool compact = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: compact,
        contentPadding: compact
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 11)
            : null,
      ),
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(signed: true, decimal: true),
      inputFormatters: isInt ? [FilteringTextInputFormatter.digitsOnly] : null,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      onFieldSubmitted: (_) => _submit(),
    );
  }

  String? _validateLat(String? v) {
    return LocationDraftController.latitudeError(v);
  }

  String? _validateLon(String? v) {
    return LocationDraftController.longitudeError(v);
  }

  String? _validateStart(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null) return 'Enter a year';
    if (n < 1981) return '≥ 1981';
    // No upper-bound on start alone. _validateEnd checks that
    // the end year is later than the start year.
    return null;
  }

  String? _validateEnd(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null) return 'Enter a year';
    // Upper bound: NASA POWER data runs through 2025.
    if (n > 2025) return '≤ 2025';
    final start = int.tryParse(_start.text.trim());
    // start must be strictly less than end.
    if (start != null && n <= start) return '> start year';
    return null;
  }
}
