import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

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
///   compact single-row horizontal form.
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
  });

  final void Function(double lat, double lon, int start, int end) onAnalyze;
  final double initialLat;
  final double initialLon;
  final int initialStartYear;
  final int initialEndYear;
  final bool loading;
  final bool compactMode;

  @override
  State<LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends State<LocationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lat;
  late final TextEditingController _lon;
  late final TextEditingController _start;
  late final TextEditingController _end;

  /// Whether the phone summary bar on Overview has been expanded by the user.
  bool _expandedOnPhone = false;

  @override
  void initState() {
    super.initState();
    _lat = TextEditingController(text: '${widget.initialLat}');
    _lon = TextEditingController(text: '${widget.initialLon}');
    _start = TextEditingController(text: '${widget.initialStartYear}');
    _end = TextEditingController(text: '${widget.initialEndYear}');
  }

  /// P0-4: Keep controllers in sync when the parent commits new query
  /// parameters. Only updates a controller if the corresponding prop has
  /// actually changed, so user-entered text is never overwritten mid-edit
  /// unless the parent explicitly advances to a new value.
  @override
  void didUpdateWidget(LocationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    _lat.dispose();
    _lon.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  void _submit() {
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

    if (widget.compactMode && isPhone && !_expandedOnPhone) {
      return _buildPhoneCollapsedSummary(context);
    }

    if (widget.compactMode && !isPhone) {
      return _buildHorizontalCompactForm(context);
    }

    return _buildFullForm(
      context,
      showCollapseAction: widget.compactMode && isPhone && _expandedOnPhone,
    );
  }

  Widget _buildPhoneCollapsedSummary(BuildContext context) {
    final coordText =
        '${_formatSummaryCoord(widget.initialLat, 'N', 'S')}, '
        '${_formatSummaryCoord(widget.initialLon, 'E', 'W')}';
    final periodText = '${widget.initialStartYear}–${widget.initialEndYear}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
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
                  '$coordText  ·  $periodText',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          TextButton.icon(
            onPressed: () => setState(() => _expandedOnPhone = true),
            icon: const Icon(Icons.tune, size: 16, color: AppColors.cyan),
            label: Text(
              'Edit',
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
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _field(
                    controller: _lat,
                    label: 'Latitude',
                    hint: '−90 to 90',
                    validator: _validateLat,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _field(
                    controller: _lon,
                    label: 'Longitude',
                    hint: '−180 to 180',
                    validator: _validateLon,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _field(
                    controller: _start,
                    label: 'Start Year',
                    hint: '≥ 1981',
                    validator: _validateStart,
                    isInt: true,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: _field(
                    controller: _end,
                    label: 'End Year',
                    hint: '≤ 2025',
                    validator: _validateEnd,
                    isInt: true,
                    compact: true,
                  ),
                ),
                const SizedBox(width: 10),
                _analyzeButton(compact: true),
              ],
            ),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
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
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    controller: _lat,
                    label: 'Latitude',
                    hint: '−90 to 90',
                    validator: _validateLat,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    controller: _lon,
                    label: 'Longitude',
                    hint: '−180 to 180',
                    validator: _validateLon,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _field(
                    controller: _start,
                    label: 'Start Year',
                    hint: '≥ 1981',
                    validator: _validateStart,
                    isInt: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    controller: _end,
                    label: 'End Year',
                    hint: '≤ 2025',
                    validator: _validateEnd,
                    isInt: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _analyzeButton(compact: false),
          ],
        ),
      ),
    );
  }

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
    final d = double.tryParse(v?.trim() ?? '');
    if (d == null) return 'Enter a number';
    if (d < -90 || d > 90) return '−90 to 90';
    return null;
  }

  String? _validateLon(String? v) {
    final d = double.tryParse(v?.trim() ?? '');
    if (d == null) return 'Enter a number';
    if (d < -180 || d > 180) return '−180 to 180';
    return null;
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
