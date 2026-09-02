---
name: "web-map-builder"
description: "Interactive web maps — Leaflet, MapLibre GL JS, Mapbox GL JS; standalone HTML, React map components, dashboards, PWAs. Owns render thresholds, tile/basemap sources, cartographic design. Triggers: web map, tile layer, popup, marker, choropleth, heatmap, clustering, vector tiles, PMTiles, GeoJSON on map, basemap, color ramp, legend, label placement, bilingual/RTL/Hebrew map, map embed."
---

# Web Map Builder

Single source of truth for **render thresholds, tile/basemap sources, and cartographic design**.
No other skill restates those numbers. Spatial technique → `geospatial-analysis`; pre-publish QA and
Pages deployment → `github-portfolio-deploy`; delivery format → `apex-geoai-style`.

## Library Selection

| Requirement | Use | Why |
|---|---|---|
| Standalone map, no build step | Leaflet + CDN | Zero config, small, large plugin ecosystem |
| Vector tiles, 3D, terrain | MapLibre GL JS | Open source, style spec |
| Mapbox Studio styles / geocoding | Mapbox GL JS | Token required; verify current license terms |
| React app | `react-leaflet` | Native React lifecycle integration |
| 10k+ features | MapLibre GL JS + vector tiles | Canvas/WebGL, no DOM node per feature |

Verify current versions before pinning. Never assume one from memory.

## Render Thresholds (Authoritative)

| Features | Strategy |
|---|---|
| < 500 | GeoJSON on Leaflet, default SVG renderer |
| 500 – 5,000 | `L.geoJSON` + `pointToLayer` → `L.circleMarker` (no DOM icons) |
| 5,000 – 50,000 | Canvas renderer (`preferCanvas: true`) or clustering |
| 50,000+ | Vector tiles — MapLibre GL JS or PMTiles |

- Raster/imagery: tile layers (XYZ/TMS/WMTS). Never full images client-side.
- GeoJSON > 1 MB: serve gzip/brotli, simplify **at the source** (`ST_SimplifyPreserveTopology`, or
  `turf.simplify` in the build step). Shipping 8 MB to simplify in the browser wastes the transfer
  you were trying to save.

## Delivery Target Decides CDN Strategy

| Target | Scripts | Stylesheets |
|---|---|---|
| GitHub Pages / own hosting | any CDN | any CDN |
| **Claude Artifact** | cdnjs, jsdelivr, cdn.tailwindcss.com, code.jquery.com **only** | **inline only** — `fonts.googleapis.com` is the sole external origin |

`unpkg.com` and `esm.sh` are CSP-blocked in Artifacts and fail **silently** — blank map, no console
error the user will see. In an Artifact, load Leaflet's JS from cdnjs and paste its CSS inline.

## Standalone HTML Map

```html
<!DOCTYPE html>
<html lang="he" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.css" />
    <!-- Social/OG meta and the full pre-publish checklist: github-portfolio-deploy -->
</head>
<body>
    <div id="map" style="height:100vh;width:100%"></div>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.js"></script>
    <script>
        const map = L.map('map').setView([31.8, 34.65], 12);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(map);
    </script>
</body>
</html>
```

## React Component Map

```jsx
import { MapContainer, TileLayer, GeoJSON } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';

export default function MapView({ data, locale = 'he' }) {
    const isRTL = ['he', 'ar'].includes(locale);
    return (
        <MapContainer center={[31.8, 34.65]} zoom={12} style={{ height: '100vh' }}>
            <TileLayer
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                attribution="© OpenStreetMap contributors"
            />
            {data && (
                <GeoJSON
                    data={data}
                    onEachFeature={(feature, layer) => {
                        layer.bindPopup(
                            `<div dir="${isRTL ? 'rtl' : 'ltr'}">${feature.properties.name}</div>`
                        );
                    }}
                />
            )}
        </MapContainer>
    );
}
```

## Cartographic Design

Inspect the data distribution before choosing a scale.

- **Ramps**: perceptually uniform sequential (viridis, plasma, cividis); diverging (RdYlBu, BrBG)
  centred on a meaningful breakpoint. Never rainbow/jet — non-uniform luminance invents visual
  breaks that are not in the data.
- **Classification**: natural breaks, quantile, equal interval, and standard deviation produce
  different maps from identical data. Pick deliberately and state why.
- **Basemap**: light (CartoDB Positron) under dense overlays; satellite for land-cover context;
  dark for point density and heatmaps.
- **Typography**: `Noto Sans`; `Rubik` for Hebrew. Hierarchy by size and weight, not more colours.
  Halo labels over imagery.
- **Label placement**: first-class — collision detection, priority ranking, halo for legibility.
- **Legend**: compact, off the data, using the map's own symbols. Drop a redundant "Legend" title.
- **Hierarchy**: data > labels > basemap. A basemap competing with the data is the wrong basemap.

## RTL & Bilingual

- `<html lang="he" dir="rtl">` at document level.
- Popup/tooltip content wrapped in `<div dir="rtl">` for Hebrew/Arabic.
- Unicode bidi marks (`&rlm;` RLM, `&lrm;` LRM) when mixing scripts inline.
- Controls right-side in RTL: `L.control.zoom({ position: 'topright' })`.
- Font stack: `'Rubik', 'Noto Sans Hebrew', 'Noto Sans Arabic', sans-serif`.

## Interaction Patterns

### URL State

```javascript
// Shareable filter state
const params = new URLSearchParams(window.location.search);
const filterType = params.get('type') || 'all';

function updateURL(key, value) {
    params.set(key, value);
    history.replaceState(null, '', `?${params.toString()}`);
}
```

### Navigation Deep Links (canonical — `github-portfolio-deploy` defers here)

```javascript
/**
 * Build navigation deep links for a destination.
 * @param {number} lat - WGS84 latitude
 * @param {number} lng - WGS84 longitude
 * @param {string} [name] - Human-readable label (optional)
 */
function navigationLinks(lat, lng, name = '') {
    const label = encodeURIComponent(name);
    return {
        waze: `https://waze.com/ul?ll=${lat},${lng}&navigate=yes`,
        // destination accepts EITHER "lat,lng" OR a place name — not both.
        // destination_place_id requires a real Google Place ID (ChIJ...); passing an
        // encoded name there is silently ignored or breaks the link.
        google: `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}`,
        // daddr drives the route; q only labels the pin.
        apple: `https://maps.apple.com/?daddr=${lat},${lng}${label ? `&q=${label}` : ''}`,
    };
}
```

### Responsive

```css
/* 44px, not Leaflet's 26px default: apex-geoai-style mandates >= 44px touch targets */
.leaflet-control-zoom a { width: 44px; height: 44px; line-height: 44px; font-size: 20px; }

@media (max-width: 768px) {
    #sidebar { position: fixed; bottom: 0; width: 100%; height: 40vh; z-index: 1000; }
    #map { height: 60vh; }
}
@media (min-width: 769px) {
    #sidebar { width: 320px; height: 100vh; }
    #map { margin-left: 320px; height: 100vh; }
}
```

## Tile & Basemap Options

| Provider | URL | Notes |
|---|---|---|
| OSM | `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png` | Free; tile usage policy allows low-traffic demos only. Verify current policy before shipping. |
| CartoDB Light | `https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png` | Clean under overlays. Attribution required. |
| CartoDB Dark | `https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png` | Attribution required. |
| Esri World Imagery | `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}` | Note `{z}/{y}/{x}` order. Verify current Esri terms. |
| MapTiler | API key | Vector tiles; Hebrew label support. |

Never state a provider's licensing terms from memory.

## Anti-Patterns to Flag

- **DOM markers past the CircleMarker threshold** — thousands of DOM nodes; move down the ladder.
- **`unpkg.com` in an Artifact** — CSP-blocked, fails silently. See the CDN table.
- **Mapbox GL JS license assumptions** — v2+ changed terms. Verify; MapLibre GL JS is the fork.
- **Hardcoded API keys in public repos** — env vars, or restrict the key to a domain.
- **Missing attribution** — OSM, CartoDB, Esri, Mapbox all require it.
- **`setView` without a bounds check** — unknown extent → `fitBounds()` on the GeoJSON layer.
- **Rainbow ramps on sequential data** — perceptually non-uniform.
