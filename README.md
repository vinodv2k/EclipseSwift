# 🌑 EclipseSwift — Eclipse Photography Tool

A macOS astronomy tool for planning and executing solar eclipse photography.  
Built with **Swift + AppKit + MapKit**, compiled directly with `swiftc` (no Xcode required).

> **GitHub**: https://github.com/vinodv2k/EclipseSwift  
> **Platform**: macOS 11+ · x86_64 · AppKit + MapKit + CoreLocation

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🗺 **Interactive Eclipse Map** | Computed eclipse paths for 2024–2034 overlaid on MapKit |
| ⏱ **Contact Time Calculator** | Besselian-elements math gives C1/C2/C3/C4 for any lat/lon |
| 🎞 **Eclipse Simulation** | Full animated totality sequence with corona, Baily's Beads, Diamond Ring |
| 📷 **Camera Control** | Sony SDK + gPhoto2 camera detection, live view, exposure control |
| 📜 **Script Generator** | Auto-generate timed shoot sequences from contact times |
| 🌑 **Multi-Eclipse Support** | 2024 Apr 8 → 2034 Mar 20 (11 total + annular + hybrid) |

---

## 🚀 Build & Run

```bash
bash build.sh
```

Compiles all Swift sources, copies `Resources/` assets, generates `Info.plist`,
and launches the `.app` bundle automatically.

---

## 🏗 Architecture

```
Sources/EclipseApp/
├── UI/
│   └── MainUI.swift          ← Entire UI: window, sidebar, tabs, simulation (2955 lines)
├── Eclipse/
│   ├── EclipseEngine.swift   ← Besselian math, contact times, path computation
│   └── EclipseMapView.swift  ← MapKit overlay rendering
├── Camera/
│   ├── CameraManager.swift   ← Sony SDK + gPhoto2 abstraction
│   ├── GPhoto2Bridge.swift   ← gPhoto2 CLI bridge
│   └── SonyCameraSDKBridge.swift ← Sony CRSDK bridge
└── Script/
    └── ScriptEngine.swift    ← Photography script generation + execution
```

---

## 🔭 Calculation Architecture (Mermaid)

### End-to-End Data & Computation Flow

```mermaid
flowchart TD
    NASA["🌐 NASA GSFC\nFive Millennium Canon\nVSOP87 / ELP2000-82"]
    CSV["📄 SonyCRSDK\nBesselian CSVs\n/data/besselian/*.csv"]
    BE["📐 BesselianElements\nstruct in EclipseEngine\n• x,y,d,μ polynomials\n• l1, l2, tanF1, tanF2\n• t0 (TDT hours), ΔT (s)"]
    NASA -->|verbatim values| BE
    CSV  -->|cross-verified| BE

    subgraph EclipseEngine["EclipseEngine.swift — EclipseCalculationEngine"]
        direction TB
        BE --> CP["computePath(for:)\nFundamental-plane → Geodetic\n① Horner poly eval\n② x²+y² < 1 guard\n③ ζ = √(1−x²−y²)\n④ sinφ' = y·cosD + ζ·sinD\n⑤ H = atan2(x, ζ·cosD − y·sinD)\n⑥ φ_geod = atan(tanφ'/(1−f)²)\n⑦ λ_east = H − μ\n⑧ wKm = 2|l2−ζ·tanF2|·R/ζ"]
        BE --> CT["computeContactTimes(\n  elements, lat, lon)\n• Geocentric observer coords\n• Scan ±4h @10s steps → C1,C4\n• Refine with l2 sign change → C2,C3\n• Fallback: ground-distance\n  for high-γ eclipses"]
        CT --> CTOUT["ContactTimes\n• c1/c2/c3/c4: Date?\n• max: Date?\n• magnitude: Double\n• durationTotalitySeconds"]
    end

    CP --> EP["EclipsePath\n• centerLine [(lat,lon)]\n• northLimit / southLimit\n• widthKm (median)"]

    subgraph EclipseMapView["EclipseMapView.swift"]
        EP --> PATHS["eclipsePaths dict\n[String: EclipsePath]\n(lazy computed)"]
        PATHS --> DRAW["drawPath()\n• Center line (dashed red)\n• North/South edge polylines\n• Filled umbral band polygon\n• Greatest eclipse pin"]
    end

    CTOUT --> SIM

    subgraph MainUI["MainUI.swift — UI Layer"]
        SIM["EclipseAnimationView\ndraw() @ 60fps\n• Sky darkening\n• Stars\n• Sun gradient\n• Corona (overlap>0.999)\n• Moon silhouette\n• Chromosphere\n• Baily's Beads\n• Diamond Ring"]
        TICKS["ContactTicksView\nC1/C2/mid/C3/C4\ntick marks on scrub bar"]
        LIST["ContactTimesListView\nSecond-by-second\nlive highlight"]
        STATE["SharedEclipseState\n• selectedEclipse\n• contactTimes\n• userLat/Lon\n• progress (0→1)"]
        STATE --> SIM
        STATE --> TICKS
        STATE --> LIST
    end

    CTOUT --> STATE

    subgraph ScriptEngine["ScriptEngine.swift"]
        SG["ScriptGenerator\ngenerate(contacts:config:)\n→ [ScriptCommand]"]
        SE["ScriptExecutor\nrun(script:)\n• Timer-based dispatch\n• executeCommand()"]
        SG --> SE
    end

    CTOUT --> SG

    subgraph CameraLayer["Camera Layer"]
        CM["CameraManager\n(ObservableObject)\n• detectCameras()\n• connect(to:)\n• applyExposure()\n• singleShot() / burst()\n• startLiveView()"]
        GP["GPhoto2Bridge\ngphoto2 CLI subprocess"]
        SONY["SonyCameraSDKBridge\nSONY CRSDK C++ bridge"]
        CM --> GP
        CM --> SONY
    end

    SE --> CM
```

---

### Contact Time Computation Detail

```mermaid
flowchart LR
    OBS["Observer\nlat, lon (°)"]
    BE2["BesselianElements\nt0, x,y,d,μ,l1,l2\ntanF1, tanF2, ΔT"]

    OBS --> GEO["Geocentric correction\nu = atan(0.99664719·tan(φ))\nρ·sinφ' , ρ·cosφ'"]
    BE2 --> GEO

    GEO --> SCAN["Coarse scan ±4h\nstep = 10 s\n→ tStart (C1), tEnd (C4)\n→ tMax (greatest)"]

    SCAN --> MAG["magnitude(at:t)\n• eval x,y,d,μ @ t\n• h = μ_rad + lon_rad − ΔT_rad\n• ξ = ρcosφ·sin(h)\n• η = ρsinφ·cosD − ρcosφ·cos(h)·sinD\n• ζ = ρsinφ·sinD + ρcosφ·cos(h)·cosD\n• dist = √((x−ξ)²+(y−η)²)\n• l1' = l1 − ζ·tanF1\n• mag = (l1'−dist) / (2·l1')"]

    MAG --> REFINE["Fine scan tStart→tEnd\n3600 steps\nl2(t) sign change → C2, C3\nl2' = l2 − ζ·tanF2"]

    REFINE --> FALLBACK{"l2 sign change\nfound?"}
    FALLBACK -->|Yes| OUT
    FALLBACK -->|No, high-γ| GD["Ground-distance fallback\n• Find closest center-line pt\n• If within ½-width × 1.5\n• Estimate C2/C3 from\n  path-depth fraction"]
    GD --> OUT["ContactTimes\nC1 · C2 · max · C3 · C4"]
```

---

### Eclipse Simulation Progress Timeline

```mermaid
timeline
    title Eclipse Progress (0.0 → 1.0)
    section Pre-Eclipse
        0.00 : Clear sky, full sun
    section Partial (ingress)
        0.10 : C1 — First Contact
        0.10–0.39 : Moon covers sun gradually
    section Totality begins
        0.390 : C2 — Second Contact
        0.393 : Diamond Ring (entry)
        0.397 : Baily's Beads (entry)
        0.405 : Corona visible — totality
    section Greatest Eclipse
        0.500 : MAX — Greatest Eclipse
    section Totality ends
        0.595 : Corona fading
        0.603 : Baily's Beads (exit)
        0.607 : Diamond Ring (exit)
        0.610 : C3 — Third Contact
    section Partial (egress)
        0.61–0.90 : Moon uncovers sun
        0.900 : C4 — Fourth Contact
    section Post-Eclipse
        1.00 : Full sun restored
```

---

### Rendering Layer Order (EclipseAnimationView)

```mermaid
flowchart TB
    P["progress (0→1)\nfrom SharedEclipseState"]
    P --> L1["① Sky\ndarkens with coverage fraction"]
    L1 --> L2["② Stars\nemerge when overlap > 0.7"]
    L2 --> L3["③ Sun disc\norange gradient + limb darkening\nfades at totality"]
    L3 --> L4["④ Corona\nONLY when overlap > 0.999\nphoto overlay at 35% opacity"]
    L4 --> L5["⑤ Moon silhouette\nblack disc\nearthshine glow in deep totality"]
    L5 --> L6["⑥ Chromosphere\nthin pink arc\nnear C2 and C3 only"]
    L6 --> L7["⑦ Baily's Beads\ngolden pearls at limb valleys\nsun-facing side only"]
    L7 --> L8["⑧ Diamond Ring\nlarge warm flare\nbloom 2× sun radius\n6-point starburst"]
```

---

## 📐 Key Formulas

### Fundamental-Plane → Geodetic (Espenak/Meeus)

```
ζ         = √(1 − x² − y²)
sin(φ')   = y·cos(D) + ζ·sin(D)          // geocentric latitude
H         = atan2(x,  ζ·cos(D) − y·sin(D))  // local hour angle (deg)
φ_geod    = atan(tan(φ') / (1−f)²)        // WGS-84 geodetic latitude
λ_east    = H − μ                          // east longitude (NOT μ − H)
w_km      = 2 · |l₂ − ζ·tanF₂| · 6378.137 / ζ
```

### Observer Magnitude

```
h      = μ_rad + λ_east_rad − ΔT·2π/86400
ξ      = ρ_cos · sin(h)
η      = ρ_sin·cos(D) − ρ_cos·cos(h)·sin(D)
ζ_obs  = ρ_sin·sin(D) + ρ_cos·cos(h)·cos(D)
dist   = √((x−ξ)² + (y−η)²)
l₁'    = l₁ − ζ_obs·tanF₁
mag    = (l₁' − dist) / (2·l₁')          // 0 = no eclipse, 1 = total
```

> Sign convention verified against `SonyCRSDK/src/eclipse/services/solar/EclipseCalculationService.cpp`

---

## 🗂 Eclipse Database (2024–2034)

| Date | Type | Greatest Eclipse | Max Duration | Width |
|------|------|-----------------|-------------|-------|
| 2024-04-08 | Total | 25.3°N 104.1°W | 4m 28s | 198 km |
| 2026-08-12 | Total | 65.2°N 25.2°W | 2m 18s | 294 km |
| 2027-08-02 | Total | 25.5°N 33.2°E | 6m 23s | 258 km |
| 2028-07-22 | Total | 15.6°S 126.7°E | 5m 10s | 230 km |
| 2029-01-26 | Partial | — | — | — |
| 2030-06-01 | Annular | 56.5°N 80.1°E | 5m 21s | 250 km |
| 2030-11-25 | Total | 43.6°S 71.2°E | 3m 44s | 169 km |
| 2031-05-21 | Annular | 8.9°N 71.7°E | 5m 26s | 152 km |
| 2031-11-14 | Hybrid | 0.6°S 137.6°W | 1m 08s | 38 km |
| 2032-05-09 | Annular | 51.3°S 7.1°W | 0m 22s | 44 km |
| 2033-03-30 | Total | 71.3°N 155.8°W | 2m 37s | 781 km |
| 2034-03-20 | Total | 16.1°N 22.2°E | 4m 09s | 159 km |

All Besselian elements sourced verbatim from **NASA GSFC Five Millennium Canon**
(Fred Espenak, VSOP87/ELP2000-82) and cross-verified against SonyCRSDK CSV data.

---

## 📚 References

- [NASA Five Millennium Canon of Solar Eclipses](https://eclipse.gsfc.nasa.gov/SEpubs/5MCSE.html)
- [NASA Solar Eclipse Search Engine](https://eclipse.gsfc.nasa.gov/SEsearch/SEsearch.php)
- [Meeus, *Astronomical Algorithms* 2nd ed., Ch. 54–55](https://www.willbell.com/math/mc1.htm)
- [Espenak — Besselian Elements](https://eclipse.gsfc.nasa.gov/SEcat5/beselm.html)
- SonyCRSDK `EclipseCalculationService.cpp` (internal reference implementation)

---

## 📄 License

Private repository — © 2026 vinodv2k. All rights reserved.
