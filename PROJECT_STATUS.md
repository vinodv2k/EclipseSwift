# Eclipse Photography Tool — Project Status

## Last Updated: April 20, 2026

## What's Working
- ✅ Photorealistic eclipse simulation with real image assets
- ✅ Deep orange sun with limb darkening
- ✅ Smooth moon trajectory with smoothstep easing
- ✅ Corona: asymmetric streamers + photo overlay, only during true totality (overlap > 99.9%)
- ✅ Diamond ring: large warm flare with bloom (2× sun radius), elongated core, 6-point starburst
- ✅ Baily's beads: golden pearls positioned on moon's sun-facing limb using lunar limb profile
- ✅ Chromosphere: subtle pink partial arc near C2/C3
- ✅ Earthshine on moon during deep totality
- ✅ Background stars during totality
- ✅ Scrub slider with C1/C2/mid/C3/C4 tick marks
- ✅ Contact times list with second-by-second highlighting
- ✅ Correct event sequence: C2 → DR → Beads → Totality/Corona → Max → Corona → Beads → DR → C3
- ✅ Speed controls (¼×, 1×, 2×, 4×)
- ✅ Animation stops at end (no looping), restart via play button
- ✅ Annular eclipse ring-of-fire mode

## Known Issues / TODO
- [ ] Lunar limb profile uses synthetic data (72 samples). Integrate real Kaguya/Herald data via Radiant Drift API for accurate bead placement
- [ ] Fine-tune corona streamer shapes for more natural asymmetry
- [ ] Baily's beads could use more variation in size/brightness based on real limb data
- [ ] Diamond ring exit (C3 side) could be tuned independently from entry
- [ ] Consider adding prominence detail during chromosphere flash
- [ ] QA edge cases at extreme slider positions

## Key Files
| File | Purpose |
|------|---------|
| `Sources/EclipseApp/UI/MainUI.swift` | All UI + simulation rendering (~2700 lines) |
| `Sources/EclipseApp/Eclipse/EclipseEngine.swift` | Eclipse calculations |
| `Sources/EclipseApp/Eclipse/EclipseMapView.swift` | Map view |
| `Sources/EclipseApp/Camera/` | Camera SDK bridges |
| `build.sh` | Build & launch script |
| `Resources/*.png` | Real photographic assets |
| `CODING_GUIDELINES.md` | Physics rules & architecture |

## Lunar Limb Profile Integration (Next Step)
- API: `GET https://api.radiantdrift.com/lunar-limb/[DATE_TIME]?obs=[LAT,LNG]`
- Returns arc-second offsets at 0.2° intervals (1800 data points)
- Negative offsets = valleys = where Baily's beads appear
- Data from Kaguya spacecraft, curated by David Herald
- Pro plan required for API access
- Libration range: l ±9.0°, b ±1.6°
