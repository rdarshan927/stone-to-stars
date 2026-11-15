/// Build-time raster provider settings. Client-side map keys are public tokens.
class MapTileConfiguration {
  const MapTileConfiguration({
    this.apiKey = '',
    this.style = '',
    this.customUrl = '',
    this.providerLabel = '',
    this.providerUrl = '',
    this.termsConfirmed = false,
    this.usesOpenStreetMap = true,
  });

  static const environment = MapTileConfiguration(
    apiKey: String.fromEnvironment('MAPTILER_API_KEY'),
    style: String.fromEnvironment('MAPTILER_STYLE'),
    customUrl: String.fromEnvironment('MAP_TILE_URL'),
    providerLabel: String.fromEnvironment('MAP_ATTRIBUTION_LABEL'),
    providerUrl: String.fromEnvironment('MAP_ATTRIBUTION_URL'),
    termsConfirmed: bool.fromEnvironment('MAP_PROVIDER_TERMS_CONFIRMED'),
    usesOpenStreetMap: bool.fromEnvironment('MAP_USES_OSM', defaultValue: true),
  );

  final String apiKey;
  final String style;
  final String customUrl;
  final String providerLabel;
  final String providerUrl;
  final bool termsConfirmed;
  final bool usesOpenStreetMap;

  bool get isMapTiler =>
      customUrl.isEmpty || Uri.tryParse(customUrl)?.host == 'api.maptiler.com';
  String get attributionLabel => isMapTiler ? '© MapTiler' : providerLabel;
  String get attributionUrl =>
      isMapTiler ? 'https://www.maptiler.com/copyright/' : providerUrl;

  String get urlTemplate => customUrl.isEmpty
      ? 'https://api.maptiler.com/maps/${Uri.encodeComponent(style)}/256/{z}/{x}/{y}.png?key=${Uri.encodeComponent(apiKey)}'
      : customUrl;

  bool get isConfigured {
    if (!termsConfirmed) return false;
    if (customUrl.isEmpty && (apiKey.trim().isEmpty || style.trim().isEmpty)) {
      return false;
    }
    final uri = Uri.tryParse(urlTemplate);
    final credit = Uri.tryParse(attributionUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        !uri.host.endsWith('tile.openstreetmap.org') &&
        ['{z}', '{x}', '{y}'].every(urlTemplate.contains) &&
        attributionLabel.trim().isNotEmpty &&
        credit != null &&
        credit.scheme == 'https' &&
        credit.host.isNotEmpty;
  }
}
