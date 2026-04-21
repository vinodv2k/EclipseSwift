# Eclipse Photography Tool — AI Prompt Context & Session Instructions

## Purpose
This file provides persistent context for AI coding sessions working on the
Eclipse Photography Tool. **Read this file at the start of every session.**

## Repository
**GitHub**: https://github.com/vinodv2k/EclipseSwift
**Local**:  `/Users/jai/Documents/Eclipse/EclipseApp`
**Remote**: `origin → https://github.com/vinodv2k/EclipseSwift.git`

---

## 1. Always Reference SonyCRSDK

The canonical reference implementation for all eclipse math is:

```
/Users/jai/Documents/Eclipse/SonyCRSDK/
```

Key files to consult:
| File | Purpose |
|------|---------|
| `src/eclipse/services/solar/EclipseCalculationService.cpp` | Besselian → contact times, observer coordinates, magnitude |
| `src/eclipse/services/solar/BesselianService.cpp` | CSV loading, element validation |
| `src/eclipse/data/besselian/*.csv` | Authoritative Besselian element data for each eclipse |
| `src/eclipse/services/dto/BesselianDataDTO.h` | Data structure definitions |
| `src/eclipse/services/solar/SolarFramingPlacementCalculator.cpp` | Photography framing math |

**Rule**: Before changing any eclipse math formula, cross-check against the
equivalent code in `EclipseCalculationService.cpp`. The sign convention
`lon_east = H − μ` (not `μ − H`) has been verified against SonyCRSDK.

---

## 2. Project Structure

```
/Users/jai/Documents/Eclipse/EclipseApp/
├── Sources/EclipseApp/
│   ├── Eclipse/
│   │   ├── EclipseEngine.swift      ← All Besselian math, contact times, path computation
│   │   └── EclipseMapView.swift     ← MapKit rendering, eclipse path display
│   ├── UI/
│   │   ├── MainUI.swift             ← Single-file simulation + main UI (AppKit)
│   │   └── AppEntry.swift           ← App entry point
│   ├── Camera/
│   │   ├── CameraManager.swift
│   │   ├── GPhoto2Bridge.swift
│   │   └── SonyCameraSDKBridge.swift
│   └── Script/
│       └── ScriptEngine.swift
├── Resources/                       ← PNG assets (Sun, Moon, Corona, etc.)
├── build.sh                         ← Build + launch script (swiftc, no Xcode)
├── CODING_GUIDELINES.md             ← Physics rules, rendering layers, timeline
└── CONTEXT.md                       ← THIS FILE
```

Build command: `bash build.sh`  
Target: macOS 11+, x86_64, AppKit + MapKit + CoreLocation

---

## 3. Eclipse Math Key Facts

### Sign Conventions (verified against SonyCRSDK)
```
h      = muRad + lonEastRad − deltaTRad        // local hour angle
xi     = rhoCos · sin(h)
eta    = rhoSin · cos(d) − rhoCos · cos(h) · sin(d)
zeta   = rhoSin · sin(d) + rhoCos · cos(h) · cos(d)
lonEast = H_deg − mu_deg                        // NOT mu − H
```

### Path Computation (computePath in EclipseEngine.swift)
1. Evaluate Besselian polynomials via Horner's method
2. Check `x²+y² < 1` (shadow strikes Earth)
3. ζ = √(1 − x² − y²)
4. `sinφ' = y·cos(d) + ζ·sin(d)` → geocentric latitude
5. `H = atan2(x, ζ·cos(d) − y·sin(d))` → local hour angle (degrees)
6. `φ = atan(tan(φ')/(1−f)²)` → geodetic latitude (WGS-84)
7. `λ = H − μ` → east longitude
8. Width: `wKm = 2·|l2 − ζ·tanF2|·6378.137 / ζ`

### ΔT Corrections
Each eclipse has a `deltaT` (seconds, TDT−UT) stored in `besselianData`.
Applied as: `deltaTRad = deltaT × 2π / 86400`

---

## 4. Besselian Data Sources

| Eclipse | Source | deltaT (s) |
|---------|--------|-----------|
| 2024-04-08 | NASA GSFC / SonyCRSDK CSV | 74.0 |
| 2026-08-12 | NASA GSFC / SonyCRSDK CSV | 75.4 |
| 2027-08-02 | NASA GSFC / SonyCRSDK CSV | 76.0 |
| 2028-07-22 | NASA GSFC | 76.6 |
| 2030-06-01 | NASA GSFC | 77.8 |
| 2030-11-25 | NASA GSFC | 78.1 |
| 2031-05-21 | NASA GSFC | 78.5 |
| 2031-11-14 | NASA GSFC | 78.8 |
| 2032-05-09 | NASA GSFC | 79.1 |
| 2033-03-30 | NASA GSFC | 79.7 |
| 2034-03-20 | NASA GSFC | 80.4 |

NASA source: https://eclipse.gsfc.nasa.gov/SEsearch/SEdata.php?Ecl=YYYYMMDD

---

## 5. Completed Work (as of 2026-04-21)

- ✅ Replaced all hardcoded eclipse path tables with Besselian-computed paths
- ✅ Fixed longitude formula bug (`lon = H − mu`, was backwards)
- ✅ Added ΔT correction to all hour angle calculations
- ✅ Verified all Besselian elements against NASA/SonyCRSDK for 2024–2031
- ✅ Added Besselian elements for 2032, 2033, 2034 eclipses
- ✅ Median path width for robustness at high-latitude path extremes
- ✅ Perpendicular offset geometry clamped at high latitudes (cos lat ≥ 0.10)
- ✅ ContactTimes: Besselian l2 scan + ground-distance fallback for high-gamma eclipses
- ✅ App builds and launches (`bash build.sh`)

---

## 6. Known Edge Cases & Gotchas

- **High-gamma eclipses** (|γ| > 0.9, e.g. 2033 γ=0.978): path is short and
  near a pole; the l2 check may find no totality for some observer locations.
  The ground-distance fallback in `computeContactTimes` handles this.
- **Annular eclipses**: l2 > 0 throughout; C2/C3 use l2p sign change still works.
- **Hybrid eclipses** (2031-11-14): narrow path (38 km), γ ≈ 0; standard
  Besselian math applies, but totality duration is very sensitive to observer position.
- **Antarctica eclipses** (2029-01-26): This is actually a **partial** eclipse
  globally (|γ| > 1 for central); no umbral path exists. No Besselian entry.
- **Path longitude wrap**: Always normalise `lon` with `while lon > 180 { lon -= 360 }`.

---

## 7. Remaining / Future Work

- [ ] Visual validation: compare rendered paths against NASA GIF maps
- [ ] Add lunar limb profile data from Kaguya/Herald via Radiant Drift API
- [ ] SonyCRSDK camera integration: trigger scripts at C1/C2/C3/C4
- [ ] Export photography sequence to SCRIPT file
- [ ] Add 2035–2040 eclipses as Besselian data becomes available
