# Eclipse Photography Tool — Coding Guidelines

## Architecture
- **Single-file UI**: All simulation rendering is in `Sources/EclipseApp/UI/MainUI.swift`
- **Build system**: `build.sh` compiles with `swiftc` directly (no Xcode project)
- **Target**: macOS 11+, x86_64, AppKit + MapKit + CoreLocation
- **Assets**: PNG images in `Resources/` → copied to `.app/Contents/Resources/`

## Eclipse Simulation Physics

### Progress Timeline (0.0 → 1.0)
| Progress | Event |
|----------|-------|
| 0.00 | Pre-eclipse |
| 0.10 | **C1** — First Contact |
| 0.10–0.39 | Partial phases (moon gradually covers sun) |
| 0.39 | **C2** — Second Contact (totality begins) |
| 0.393 | Diamond Ring (entry) |
| 0.397 | Baily's Beads (entry) |
| 0.405 | Corona visible / Totality |
| 0.50 | **MAX** — Greatest Eclipse |
| 0.595 | Corona fading / Totality |
| 0.603 | Baily's Beads (exit) |
| 0.607 | Diamond Ring (exit) |
| 0.61 | **C3** — Third Contact (totality ends) |
| 0.61–0.90 | Partial phases (moon uncovering) |
| 0.90 | **C4** — Fourth Contact (last contact) |
| 1.00 | Post-eclipse |

### Correct Event Sequence at C2/C3
```
C2 → Diamond Ring → Baily's Beads → Totality/Corona → Greatest Eclipse → Totality/Corona → Baily's Beads → Diamond Ring → C3
```
**CRITICAL**: Diamond Ring and Baily's Beads ONLY occur at the edges of totality (near C2 and C3). They NEVER appear between totality and greatest eclipse.

### Rendering Layers (draw order)
1. **Sky** — darkens with coverage
2. **Stars** — emerge during totality
3. **Sun** — orange gradient with limb darkening (fades at totality)
4. **Corona** — ONLY when `overlap > 0.999` (true totality). Never during partial phases.
5. **Moon disc** — black silhouette (earthshine during deep totality)
6. **Chromosphere** — thin pink arc near C2/C3 only
7. **Baily's Beads** — bright golden pearls on moon's sun-facing limb, positioned using lunar limb profile valleys
8. **Diamond Ring** — large brilliant flare with bloom, elongated core, and starburst spikes

### Key Physics Rules
- **Corona visibility**: `overlap > 0.999` — corona is ONLY visible during true totality
- **Baily's Beads**: Appear at lunar limb valleys (negative offsets in limb profile), on the **sun-facing side** of the moon
- **Diamond Ring**: Large warm flare (not a dot), with bloom extending 2× sun radius, 6-point starburst
- **Moon trajectory**: Smoothstep easing, moon centered over sun at C2 (progress 0.39) and C3 (0.61)
- **Overlap calculation**: Geometric circle-circle intersection area

## Lunar Limb Profile
- 72 samples at 5° intervals around the moon's limb
- Negative values = valleys (where Baily's beads form)
- Positive values = mountains
- Future: integrate Kaguya/Herald data via Radiant Drift API (`https://api.radiantdrift.com/lunar-limb/`)
- API returns 0.2° resolution data from Kaguya spacecraft measurements

## Asset Loading
- Searches: `.app/Contents/Resources/`, `Bundle.main.resourcePath`, dev paths
- Required PNGs: `Sun.png`, `Moon.png`, `Corona.png`, `CoronaLayer.png`, `Totality.png`
- Sun image blended at 30% over procedural orange gradient
- Corona photo overlay at 35% opacity during totality

## UI Components
- `EclipseAnimationView` — main simulation canvas with `draw()` override
- `ContactTimesListView` — scrollable list with second-by-second highlight
- `ContactTicksView` — tick marks under scrub slider (C1/C2/mid/C3/C4)
- Speed controls: ¼×, 1×, 2×, 4× with visual highlight
- Animation stops at progress 1.0 (no looping), play button restarts

## Build & Run
```bash
bash build.sh
```
Compiles all Swift files, copies assets, generates Info.plist, launches `.app` bundle.
