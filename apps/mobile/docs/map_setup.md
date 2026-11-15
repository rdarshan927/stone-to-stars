# Geographical explorer: raster provider setup

The map starts closed and is unavailable until a provider is configured. Manual
coordinates and NASA POWER analysis work independently of the basemap. Opening,
closing, selecting a point, panning, zooming and recentering do not submit climate
requests. Analyze retains its existing validation and explicit submission behavior.

## MapTiler

Create your own MapTiler Cloud account and select a plan and raster style that
permit your intended use. Confirm the style's full data credits and branding
requirements before enabling it. No live credentials or style entitlement have
been supplied or verified for this project.

Example, after checking your chosen style and plan:

```sh
flutter run -d chrome \
  --dart-define=MAPTILER_API_KEY=YOUR_PUBLIC_MAP_TOKEN \
  --dart-define=MAPTILER_STYLE=YOUR_APPROVED_DARK_STYLE_ID \
  --dart-define=MAP_PROVIDER_TERMS_CONFIRMED=true
```

The URL uses MapTiler's 256px XYZ raster endpoint. Keep real credentials out of
source control. Build-time values embedded in Web and Android clients are not
secrets. Use separate keys for development, Web production and Android; restrict
Web origins and native application User-Agent (`flutter_map (stone-to-stars)`),
and configure account quotas/alerts. Check actual outgoing headers before
restricting a native key. Tile traffic is billed per request for this client.

The map includes linked MapTiler and OpenStreetMap credits plus MapTiler's official
logo. The logo was retrieved from https://api.maptiler.com/resources/logo.svg and
converted, without changing its artwork, to a local 240px-wide PNG. Its use here
is provider attribution, not application branding. These credits are not a claim
that an unverified account/style is compliant; additional style-specific credits
must be checked before use.

Sources:
- https://docs.maptiler.com/guides/map-design/attribution/add-attribution/
- https://docs.maptiler.com/guides/developer/credentials/api-key/
- https://www.maptiler.com/cloud/pricing/

## Another raster provider

Set `MAP_TILE_URL` to an HTTPS XYZ template containing `{z}`, `{x}`, `{y}`,
`MAP_ATTRIBUTION_LABEL` to its credit text, `MAP_ATTRIBUTION_URL` to its HTTPS
license/credit page, and `MAP_PROVIDER_TERMS_CONFIRMED=true` after checking access
and licensing. `MAP_USES_OSM` defaults to true, preserving OpenStreetMap credits;
set it to false only for a provider that does not use OSM. MapTiler URLs always
retain MapTiler branding. Providers with additional logo/credit requirements
need those requirements implemented before enabling them.

Public `tile.openstreetmap.org` URLs are deliberately rejected. There is no
fallback provider, tile proxy, offline download or automatic climate retry.

## Interaction and failures

Drag/pinch/double-click the map or use keyboard-operable zoom and recenter
controls. Focused maps support arrow-key panning. Ordinary wheel scrolling is
left to the page. Recenter restores the world view, not a selected analysis point.

Tap/click to select draft coordinates, or activate **Use map centre** with the
keyboard. The marker and manual latitude/longitude fields share one editable
draft, separate from submitted analysis parameters. Map selection preserves both
year fields. Incomplete/invalid manual text is retained and hides the marker.
Valid manual changes update the marker and bring it into view if needed. Manual
polar latitudes remain valid for analysis; latitudes outside ±85.05112878° cannot
be displayed by this Web Mercator basemap and are explained without clamping.
Only map-generated longitudes are normalized into [-180, 180).

The marker identifies draft coordinates, not a weather station or the boundary
of a NASA POWER grid cell. Existing results retain their submitted location until
the next analysis; selecting a new point does not relabel or replace them. Drafts
and the marker survive destination changes, editor collapse and resizing.

Camera values survive closing the explorer and changing destinations. Hidden
maps unmount and dispose their tile provider. Browser/native caching can reduce
repeat transfers, but offline availability is not guaranteed. Native tile cache
uses a 50 MiB soft limit; no climate data is cached by the map.

Overview's Recent Locations list retains at most five successful submitted
coordinate/year queries in memory, newest first. Valid responses with insufficient
observations count as successful analyses; errors and timeouts do not add entries.
Repeated successful queries move to the top. The two antimeridian representations
(180° and -180°) deduplicate when latitude and years match, while retaining the
latest submitted value. Selecting history restores all four draft fields without
submitting or replacing displayed results. Analyze still requests fresh results;
this is not a result cache. History clears when the app session ends.

Tile failures display a separate message and an explicit retry action that
recreates the tile layer/provider while retaining the camera. It can recover from
transient failures; invalid keys, missing style access or quota exhaustion still
require provider/account correction. Search, geolocation and
regional analysis are not implemented.
