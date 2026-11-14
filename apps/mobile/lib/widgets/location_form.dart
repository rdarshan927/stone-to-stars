import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';

/// Coordinate + year input controls.
///
/// Shows four text fields (Latitude, Longitude, Start Year, End Year)
/// and an Analyze button. Calls [onAnalyze] when the user submits valid values.
class LocationForm extends StatefulWidget {
  const LocationForm({
    super.key,
    required this.onAnalyze,
    this.initialLat = 7.3,
    this.initialLon = 81.8,
    this.initialStartYear = 1981,
    this.initialEndYear = 2025,
    this.loading = false,
  });

  final void Function(double lat, double lon, int start, int end) onAnalyze;
  final double initialLat;
  final double initialLon;
  final int initialStartYear;
  final int initialEndYear;
  final bool loading;

  @override
  State<LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends State<LocationForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lat;
  late final TextEditingController _lon;
  late final TextEditingController _start;
  late final TextEditingController _end;

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
    widget.onAnalyze(lat, lon, start, end);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            Text(
              'Location & Period',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
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
            ElevatedButton.icon(
              onPressed: widget.loading ? null : _submit,
              icon: widget.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search, size: 18),
              label: Text(widget.loading ? 'Analyzing…' : 'Analyze'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
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
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
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
    return null;
  }

  String? _validateEnd(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    if (n == null) return 'Enter a year';
    final start = int.tryParse(_start.text.trim()) ?? 1981;
    if (n <= start) return '> start year';
    return null;
  }
}
