---
name: "geospatial-analysis"
description: "Spatial technique owner: CRS/EPSG/SRID, reprojection, ITM/WGS84/UTM, geometry validity (ST_MakeValid, shapely), predicates, spatial joins, buffers, nearest-neighbour/kNN, indexing (R-tree/GiST/k-d tree), PostGIS, GeoPandas, DuckDB Spatial, rasters, zonal stats, resampling, COG/STAC/GeoParquet/FlatGeobuf/Zarr, GeoAI pipelines (spatial CV, leakage, tiling/chipping, segmentation, detection). Rendering → web-map-builder; delivery format → apex-geoai-style."
---

# Geospatial Analysis

Canonical owner of spatial correctness. Cited by `apex-geoai-style` and `web-map-builder`; neither
restates these rules.

| Concern | Owner |
|---|---|
| CRS, geometry validity, spatial ops, raster, GeoAI pipelines | this skill |
| Render thresholds, tile sources, cartography, RTL map UI | `web-map-builder` |
| Response format, code completeness, non-spatial architecture | `apex-geoai-style` |
| Pre-publish QA, GitHub Pages | `github-portfolio-deploy` |

## CRS Discipline

**Every dataset carries a CRS or it is unusable.** A CRS-less frame is a bug, not a default.

- Geographic (EPSG:4326) is angular. Metric ops — buffer, length, area, distance, centroid on
  large extents — are **invalid** in it. Project first, measure, project back if needed.
- Pick the metric CRS by extent: local projected CRS for a country/region, UTM zone for a swath,
  equal-area (Mollweide, Albers) for area statistics, `EPSG:3857` **only** for tile alignment —
  never for measurement (Mercator area error scales as `sec²φ`).
- Israel context: `EPSG:2039` (ITM, Israeli TM Grid) for metric work; `EPSG:4326` for interchange.
  ITM↔WGS84 is a **datum transformation** (Clarke 1880 → GRS80/WGS84), not an affine reprojection —
  a library without the grid shift silently lands ~100–200 m off.
- Reproject with a transformer, not per-point trig. Cache it: `pyproj.Transformer` construction is
  the expensive part.

```python
import geopandas as gpd

ITM = 2039  # Israeli TM Grid — metric, valid for buffer/area/length


def buffer_meters(gdf: gpd.GeoDataFrame, meters: float) -> gpd.GeoDataFrame:
    """Buffer in metres regardless of input CRS, returning the original CRS.

    Buffering in EPSG:4326 treats the distance as degrees; at Israel's latitude
    one degree of longitude is ~93 km, so the result is wrong by ~5 orders of
    magnitude and anisotropic (longitude compresses by cos(lat), latitude does not).
    """
    if gdf.crs is None:
        raise ValueError("CRS is undefined; refusing to guess")
    original = gdf.crs
    out = gdf.to_crs(ITM)
    out["geometry"] = out.geometry.buffer(meters)
    return out.to_crs(original)
```

## Geometry Validity

Validity precedes every predicate. An invalid geometry makes `intersects`, `within`, and `area`
undefined — engines do not raise, they return plausible garbage.

- OGC simple-features invalidity: self-intersection, unclosed rings, interior rings outside the
  exterior, repeated vertices, zero-area slivers.
- Repair with `ST_MakeValid` (PostGIS) or `shapely.make_valid` — **not** `buffer(0)`, which silently
  drops rings and collapses bowties. Measured on the bowtie
  `Polygon([(0,0),(2,2),(2,0),(0,2),(0,0)])` under Shapely 2.1.2: `make_valid` → MultiPolygon,
  area 2.0; `buffer(0)` → Polygon, area 1.0. Half the area gone, no warning.
- `make_valid` can change geometry type (Polygon → GeometryCollection). Filter back to the expected
  type explicitly rather than letting the collection propagate into a join.
- Exterior rings CCW, interiors CW (RFC 7946 requires this for GeoJSON; many writers ignore it and
  some consumers wind-order-cull).

```python
from shapely import make_valid
from shapely.geometry.base import BaseGeometry


def repair(geom: BaseGeometry, keep: str = "Polygon") -> BaseGeometry | None:
    """Repair an invalid geometry, keeping only parts of the expected type.

    make_valid may return a GeometryCollection mixing lines and points with the
    polygons; passing that downstream corrupts area sums and join cardinality.
    """
    if geom is None or geom.is_empty:
        return None
    fixed = make_valid(geom)
    if fixed.geom_type == keep:
        return fixed
    parts = [g for g in getattr(fixed, "geoms", []) if g.geom_type == keep]
    if not parts:
        return None
    if len(parts) == 1:
        return parts[0]
    from shapely.geometry import MultiPolygon
    return MultiPolygon(parts)
```

## Predicates, Joins, Indexing

- Predicate semantics differ at the boundary: `within` excludes boundary-only contact, `intersects`
  includes it, `touches` requires boundary contact with disjoint interiors. Choosing by vibe
  produces off-by-one feature counts that survive review.
- Always index before joining: GiST in PostGIS, `sindex` in GeoPandas. Every engine's spatial join
  is filter-then-refine — the index is the filter; without it the refine step runs O(n·m).
- Distance queries: `ST_DWithin(a, b, d)` is index-assisted; `ST_Distance(a, b) < d` is not. Same
  result, different complexity class.
- **Join before buffer.** Buffering the larger table first materialises n polygons to discard most
  of them.
- Floating-point coordinates make coincident boundaries non-coincident. Snap-round to a tolerance
  matched to source precision before topology work; do not chase the last ULP.
- Dissolve/union at scale: `ST_Union` on a grouped set beats iterative pairwise union (cascaded
  internally); iterating in Python is the classic accidental O(n²).

## Raster

- Resampling by variable type: **nearest** for categorical (land cover, class masks — anything else
  invents classes that do not exist), bilinear/cubic for continuous, **average** when downsampling
  continuous data for statistics.
- Align grids before algebra. Differing origin, pixel size, or CRS between two rasters means the
  arithmetic is comparing unrelated ground positions.
- Read windowed, never whole-array, on anything that does not comfortably fit memory. COG plus
  windowed range reads is the reason COG exists.
- Zonal stats: rasterize zones once to the raster grid rather than looping polygons; `exactextract`
  for area-weighted boundary pixels when partial coverage matters.
- NoData is not zero. Mask it before `mean`, `sum`, or normalisation, or the sentinel value
  (often `-9999`) enters the statistic.

## GeoAI Pipelines

The failure mode specific to this domain is **spatial leakage**, and it inflates validation metrics
without touching training loss.

- **Why random k-fold lies.** Tobler's law means nearby samples are correlated. A random split puts
  a sample's neighbours in both train and test, so the model can interpolate rather than
  generalise. Reported accuracy then measures memorised local texture. The gap widens with the
  autocorrelation range of the target — check it with a variogram or Moran's *I* before choosing a
  split.
- **Fix:** spatial cross-validation — block/grid folds, or `GroupKFold` grouped by an administrative
  or cluster ID. Buffer a dead zone between folds at least as wide as the autocorrelation range,
  and drop samples inside it.
- **Tiling/chipping:** overlap tiles by the receptive field (or ≥ the largest object) so objects on
  seams are learnable; deduplicate predictions on overlap by NMS or by keeping only the chip-centre
  region. Assign whole tiles to folds — never individual pixels from a shared tile.
- **Label alignment:** rasterize labels with the *same* transform, grid, and CRS as the imagery.
  A half-pixel offset is invisible in a preview and caps achievable IoU.
- **Class imbalance:** rare positives (buildings after a disaster, illegal dumping) need
  loss-level handling — focal or Dice loss, positive-anchor oversampling — not accuracy as a
  metric. Report per-class IoU/F1 and PR-AUC; overall accuracy is meaningless at 1% prevalence.
- **Normalisation statistics** come from the training folds only. Computing band means over the
  full dataset leaks test distribution into training.
- **Inference geography:** a model trained on one sensor, season, or region does not transfer
  silently. State the training domain with the metric, and evaluate on a spatially disjoint
  hold-out region, not a random subset.

## Formats

| Format | Use when |
|---|---|
| **COG** | Raster on object storage; windowed/overview reads without a server |
| **STAC** | Cataloguing and discovering raster/scene collections |
| **GeoParquet** | Columnar vector at analytic scale; predicate/column pushdown, DuckDB/Arrow |
| **FlatGeobuf** | Streamable vector with a spatial index; bbox reads over HTTP range |
| **PMTiles** | Single-file tile archive served statically |
| **Zarr** | Chunked N-dimensional arrays; time-series and multi-band cubes |
| **Shapefile** | Only when a consumer forces it — 2 GB cap, 10-char fields, no true NULL, multi-file |

## Anti-Patterns to Flag

- **Buffer/area/length in EPSG:4326** — degrees are not metres; error is latitude-dependent.
- **`buffer(0)` as a validity fix** — silently deletes rings.
- **`centroid` as a representative point** — a centroid may fall outside a concave or multipart
  polygon. Use `ST_PointOnSurface` / `representative_point()` when the point must lie inside.
- **Nearest-neighbour on unprojected coordinates** — a k-d tree on lat/lon treats degrees as
  isotropic; ranking is wrong away from the equator and broken across the antimeridian.
- **Silent CRS coercion on join** — GeoPandas raises, PostGIS does not if SRIDs are both 0. Assert
  CRS equality before the join.
- **Random k-fold on spatial samples** — see above; the reported metric is not generalisation.
- **Reprojecting a raster to compare, then reporting metric error in the source CRS** — pick one
  metric CRS for the whole comparison.
- **Trusting `.shp` field names after a write** — DBF truncates to 10 characters and will collide.
