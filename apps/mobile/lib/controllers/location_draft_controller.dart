import 'package:flutter/widgets.dart';

/// Raw editable form values, independent of submitted queries and API results.
class LocationDraftController extends ChangeNotifier {
  LocationDraftController({
    double latitude = 7.3,
    double longitude = 81.8,
    int startYear = 1981,
    int endYear = 2025,
  }) : latitude = TextEditingController(text: '$latitude'),
       longitude = TextEditingController(text: '$longitude'),
       startYear = TextEditingController(text: '$startYear'),
       endYear = TextEditingController(text: '$endYear') {
    for (final controller in _controllers) {
      controller.addListener(_changed);
    }
  }

  final TextEditingController latitude;
  final TextEditingController longitude;
  final TextEditingController startYear;
  final TextEditingController endYear;
  bool _updating = false;

  List<TextEditingController> get _controllers => [
    latitude,
    longitude,
    startYear,
    endYear,
  ];

  ({double latitude, double longitude})? get coordinates {
    final lat = double.tryParse(latitude.text.trim());
    final lon = double.tryParse(longitude.text.trim());
    if (latitudeError(latitude.text) != null ||
        longitudeError(longitude.text) != null) {
      return null;
    }
    return (latitude: lat!, longitude: lon!);
  }

  static String? latitudeError(String? text) => _coordinateError(text, 90);
  static String? longitudeError(String? text) => _coordinateError(text, 180);

  static String? _coordinateError(String? text, int limit) {
    final value = double.tryParse(text?.trim() ?? '');
    if (value == null || !value.isFinite) return 'Enter a number';
    if (value < -limit || value > limit) return '−$limit to $limit';
    return null;
  }

  /// Normalize only map-generated longitudes. Manual out-of-range text remains
  /// invalid, rather than being silently rewritten while the user types.
  bool selectMapPoint(double lat, double lon) {
    if (!lat.isFinite || !lon.isFinite || lat < -90 || lat > 90) return false;
    final normalized = lon >= -180 && lon < 180
        ? lon
        : ((lon + 180) % 360) - 180;
    _updating = true;
    latitude.text = '${lat == 0 ? 0.0 : lat}';
    longitude.text = '${normalized == 0 ? 0.0 : normalized}';
    _updating = false;
    notifyListeners();
    return true;
  }

  void _changed() {
    if (!_updating) notifyListeners();
  }

  /// Restore a successful query verbatim, including valid manual polar points.
  /// No normalization or analysis is performed when selecting history.
  void restoreAnalyzedLocation({
    required double latitude,
    required double longitude,
    required int startYear,
    required int endYear,
  }) {
    _updating = true;
    this.latitude.text = '$latitude';
    this.longitude.text = '$longitude';
    this.startYear.text = '$startYear';
    this.endYear.text = '$endYear';
    _updating = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_changed);
      controller.dispose();
    }
    super.dispose();
  }
}
