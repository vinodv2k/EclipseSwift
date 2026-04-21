import Foundation

// MARK: - Eclipse Data Types

struct EclipseEvent: Identifiable {
    let id: UUID
    let date: String          // "2026-08-12"
    let type: EclipseType
    let greatestEclipseLat: Double
    let greatestEclipseLon: Double
    let durationSeconds: Int  // totality/annularity max duration
    let description: String   // Short description for UI

    enum EclipseType: String {
        case total   = "Total Solar"
        case annular = "Annular Solar"
        case hybrid  = "Hybrid Solar"
        case partial = "Partial Solar"
        case lunar   = "Lunar"
    }
}

struct ContactTimes {
    var c1: Date?
    var c2: Date?
    var max: Date?
    var c3: Date?
    var c4: Date?
    var magnitude: Double = 0
    var durationTotalitySeconds: Double = 0

    var totalityDuration: TimeInterval? {
        guard let c2 = c2, let c3 = c3 else { return nil }
        let d = c3.timeIntervalSince(c2)
        return d > 0 ? d : nil
    }
}

// MARK: - Besselian Eclipse Engine

final class EclipseCalculationEngine {

    // MARK: - Besselian Element Model

    struct BesselianElements {
        let date: String
        let t0: Double          // Reference time (hours UT)
        let x:  [Double]        // X Bessel coordinate coefficients [a0,a1,a2,a3]
        let y:  [Double]        // Y Bessel coordinate coefficients
        let d:  [Double]        // Sun declination coefficients (degrees)
        let m:  [Double]        // Greenwich hour angle coefficients (degrees)
        let l1: [Double]        // Penumbral radius coefficients
        let l2: [Double]        // Umbral radius coefficients (negative = total)
        let tanF1: Double       // Penumbral cone half-angle tan
        let tanF2: Double       // Umbral cone half-angle tan
        let mu0: Double         // Greenwich hour angle at t0 (degrees)
        let deltaT: Double      // ΔT in seconds (TDT − UT); from NASA table

        /// Convenience init for callers that haven't set deltaT yet
        init(date: String, t0: Double,
             x: [Double], y: [Double], d: [Double], m: [Double],
             l1: [Double], l2: [Double],
             tanF1: Double, tanF2: Double, mu0: Double, deltaT: Double = 0.0) {
            self.date   = date;   self.t0    = t0
            self.x      = x;      self.y     = y
            self.d      = d;      self.m     = m
            self.l1     = l1;     self.l2    = l2
            self.tanF1  = tanF1;  self.tanF2 = tanF2
            self.mu0    = mu0;    self.deltaT = deltaT
        }
    }

    // MARK: - Compute Contact Times (full Besselian method)

    static func computeContactTimes(
        elements: BesselianElements,
        latitude:  Double,
        longitude: Double
    ) -> ContactTimes {
        var result = ContactTimes()

        let latRad  = latitude  * .pi / 180.0
        let lonRad  = longitude * .pi / 180.0
        // Geocentric correction (WGS-84 ellipsoid)
        let u       = atan(0.99664719 * tan(latRad))
        let rhoSin  = 0.99664719 * sin(u) + (0.0 / 6378140.0) * sin(latRad)
        let rhoCos  = cos(u)              + (0.0 / 6378140.0) * cos(latRad)

        // Scan ±4 hours around t0 in 10-second steps for high accuracy
        let nSteps = 2880
        let step   = 8.0 / Double(nSteps)  // hours
        var prevMag: Double = -1.0
        var tStart: Double?; var tEnd: Double?
        var tMax:   Double?; var maxMag: Double = 0.0

        for i in 0...nSteps {
            let t   = elements.t0 - 4.0 + Double(i) * step
            let mag = self.magnitude(at: t, elements: elements, rhoSin: rhoSin, rhoCos: rhoCos, lonRad: lonRad)
            if mag > 0 && prevMag <= 0 { tStart = t }
            if mag <= 0 && prevMag > 0 { tEnd   = t }
            if mag > maxMag { maxMag = mag; tMax = t }
            prevMag = mag
        }

        guard let ts = tStart, let te = tEnd, let tm = tMax else { return result }

        result.c1  = hourToDate(baseDate: elements.date, hour: ts)
        result.c4  = hourToDate(baseDate: elements.date, hour: te)
        result.max = hourToDate(baseDate: elements.date, hour: tm)
        result.magnitude = maxMag

        // Refine totality using ground-distance from center line
        // For high-gamma eclipses, the fundamental-plane l2 check underestimates
        // the shadow extent due to oblique projection on the curved Earth.
        // We use the path width from EclipseMapView data as a more reliable check.
        var tC2: Double?; var tC3: Double?

        // First try: fundamental-plane Besselian check (works for moderate gamma)
        var prevL2: Double = 1.0
        let refinedSteps = 3600
        for i in 0...refinedSteps {
            let t  = ts + Double(i) * (te - ts) / Double(refinedSteps)
            let l2 = l2Value(at: t, elements: elements, rhoSin: rhoSin, rhoCos: rhoCos, lonRad: lonRad)
            if l2 < 0 && prevL2 >= 0 { tC2 = t }
            if l2 >= 0 && prevL2 < 0 { tC3 = t }
            prevL2 = l2
        }

        // If Besselian check found no totality, try ground-distance method
        // using the actual path coordinates and width.
        // Near the edges of the path (low sun altitude), the shadow is highly
        // elongated, so we use 1.5× the nominal half-width to account for
        // oblique projection and interpolation gaps in the center-line data.
        if tC2 == nil, let pathData = eclipsePaths[elements.date] {
            let halfWidthDeg = (pathData.widthKm / 2.0) / 111.0 * 1.5
            // Find closest center-line point using interpolation between consecutive points
            var minDist = Double.greatestFiniteMagnitude
            let pts = pathData.centerLine
            for i in 0..<pts.count {
                // Check direct distance to this point
                let dlat = latitude - pts[i].lat
                let dlon = (longitude - pts[i].lon) * cos(latitude * .pi / 180.0)
                let dist = sqrt(dlat * dlat + dlon * dlon)
                if dist < minDist { minDist = dist }
                // Also check distance to segment between consecutive points
                if i + 1 < pts.count {
                    let segDist = distToSegment(px: latitude, py: longitude * cos(latitude * .pi / 180.0),
                        ax: pts[i].lat, ay: pts[i].lon * cos(latitude * .pi / 180.0),
                        bx: pts[i+1].lat, by: pts[i+1].lon * cos(latitude * .pi / 180.0))
                    if segDist < minDist { minDist = segDist }
                }
            }
            // If within path half-width, estimate C2/C3 from magnitude peak
            if minDist < halfWidthDeg {
                let peakWidth = halfWidthDeg - minDist  // how deep inside the path
                let fraction = peakWidth / halfWidthDeg
                // Estimate totality duration as fraction of max (max ~2m18s for 2026)
                let estDurationHr = fraction * Double(eclipseEvents(for: elements.date)?.durationSeconds ?? 120) / 3600.0
                tC2 = tm - estDurationHr / 2.0
                tC3 = tm + estDurationHr / 2.0
            }
        }
        if let c2 = tC2 { result.c2 = hourToDate(baseDate: elements.date, hour: c2) }
        if let c3 = tC3 { result.c3 = hourToDate(baseDate: elements.date, hour: c3) }
        if let c2 = tC2, let c3 = tC3 { result.durationTotalitySeconds = (c3 - c2) * 3600.0 }

        return result
    }

    // MARK: - Internal helpers

    /// Compute observer coordinates in the fundamental plane and return
    /// magnitude of eclipse (0 = no eclipse, >0 = partial or total).
    ///
    /// Sign convention (cross-verified against SonyCRSDK EclipseCalculationService.cpp):
    ///   obsvconst1 = −lon_east_rad   (west positive internally)
    ///   h = mu_rad − obsvconst1 = mu_rad + lon_east_rad
    ///   xi   = rho_cos · sin(h)
    ///   eta  = rho_sin · cos(d) − rho_cos · cos(h) · sin(d)
    ///   zeta = rho_sin · sin(d) + rho_cos · cos(h) · cos(d)
    ///   Also: ΔT correction applied as deltaT_rad = deltaT_sec * 2π / 86400
    private static func magnitude(
        at t: Double, elements: BesselianElements,
        rhoSin: Double, rhoCos: Double, lonRad: Double
    ) -> Double {
        let dt  = t - elements.t0
        let x   = poly(elements.x, dt)
        let y   = poly(elements.y, dt)
        let d   = poly(elements.d, dt) * .pi / 180.0
        var mu  = poly(elements.m, dt)
        mu = mu - 360.0 * floor(mu / 360.0)
        let muRad = mu * .pi / 180.0
        let l1  = poly(elements.l1, dt)

        // ΔT correction: Earth's rotation offset between TDT and UT
        // (mu polynomial is in TDT; observer longitude is UT-based)
        let deltaTRad = elements.deltaT * 2.0 * .pi / 86400.0

        // Local hour angle h = mu + lon_east − deltaT_rotation_correction
        // Matches: h = mu_rad - obsvconst1 - deltaT/13713  in SonyCRSDK
        let h = muRad + lonRad - deltaTRad

        let xi   = rhoCos * sin(h)
        let eta  = rhoSin * cos(d) - rhoCos * cos(h) * sin(d)
        let zeta = rhoSin * sin(d) + rhoCos * cos(h) * cos(d)
        let dx = x - xi; let dy = y - eta
        let dist = sqrt(dx*dx + dy*dy)

        let l1p  = l1 - zeta * elements.tanF1
        return dist >= l1p ? 0.0 : (l1p - dist) / (l1p * 2.0)
    }

    private static func l2Value(
        at t: Double, elements: BesselianElements,
        rhoSin: Double, rhoCos: Double, lonRad: Double
    ) -> Double {
        let dt  = t - elements.t0
        let x   = poly(elements.x, dt)
        let y   = poly(elements.y, dt)
        let d   = poly(elements.d, dt) * .pi / 180.0
        var mu  = poly(elements.m, dt)
        mu = mu - 360.0 * floor(mu / 360.0)
        let muRad = mu * .pi / 180.0
        let l2  = poly(elements.l2, dt)

        let deltaTRad = elements.deltaT * 2.0 * .pi / 86400.0
        let h = muRad + lonRad - deltaTRad

        let xi   = rhoCos * sin(h)
        let eta  = rhoSin * cos(d) - rhoCos * cos(h) * sin(d)
        let zeta = rhoSin * sin(d) + rhoCos * cos(h) * cos(d)
        let l2p  = l2 - zeta * elements.tanF2

        let dx = x - xi; let dy = y - eta
        return sqrt(dx*dx + dy*dy) - abs(l2p)
    }

    static func poly(_ c: [Double], _ t: Double) -> Double {
        var r = 0.0; var p = 1.0
        for ci in c { r += ci * p; p *= t }
        return r
    }

    /// Look up the eclipse event for a given date string
    static func eclipseEvents(for date: String) -> EclipseEvent? {
        return upcomingEclipses.first { $0.date == date }
    }

    /// Distance from point (px,py) to line segment (ax,ay)-(bx,by)
    private static func distToSegment(px: Double, py: Double, ax: Double, ay: Double, bx: Double, by: Double) -> Double {
        let dx = bx - ax; let dy = by - ay
        let lenSq = dx * dx + dy * dy
        guard lenSq > 0 else { return sqrt((px-ax)*(px-ax)+(py-ay)*(py-ay)) }
        let t = max(0, min(1, ((px-ax)*dx + (py-ay)*dy) / lenSq))
        let projX = ax + t * dx; let projY = ay + t * dy
        return sqrt((px-projX)*(px-projX) + (py-projY)*(py-projY))
    }

    static func hourToDate(baseDate: String, hour: Double) -> Date? {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        guard let base = df.date(from: baseDate) else { return nil }
        return base.addingTimeInterval(hour * 3600.0)
    }

    // MARK: - Eclipse Database (NASA Five Millennium Canon / Fred Espenak VSOP87/ELP2000-82)

    static let upcomingEclipses: [EclipseEvent] = [
        EclipseEvent(id: UUID(), date: "2024-04-08", type: .total,
                     greatestEclipseLat:  25.3, greatestEclipseLon: -104.1,
                     durationSeconds: 268,
                     description: "Mexico → Texas → Ohio → New England"),
        EclipseEvent(id: UUID(), date: "2026-08-12", type: .total,
                     greatestEclipseLat:  65.2, greatestEclipseLon:  -25.2,
                     durationSeconds: 138,
                     description: "Arctic → Iceland → N. Spain"),
        EclipseEvent(id: UUID(), date: "2027-08-02", type: .total,
                     greatestEclipseLat:  25.5, greatestEclipseLon:   33.2,
                     durationSeconds: 383,
                     description: "Morocco → Egypt → Saudi Arabia → Indian Ocean"),
        EclipseEvent(id: UUID(), date: "2028-07-22", type: .total,
                     greatestEclipseLat: -15.6, greatestEclipseLon:  126.7,
                     durationSeconds: 310,
                     description: "Indian Ocean → Australia → New Zealand"),
        EclipseEvent(id: UUID(), date: "2029-01-26", type: .partial,
                     greatestEclipseLat: -70.2, greatestEclipseLon:  -22.8,
                     durationSeconds: 0,
                     description: "Partial — Antarctica/Southern Ocean (no central path)"),
        EclipseEvent(id: UUID(), date: "2030-06-01", type: .annular,
                     greatestEclipseLat:  56.5, greatestEclipseLon:   80.1,
                     durationSeconds: 321,
                     description: "Algeria → Greece → Turkey → W Siberia → China → Japan"),
        EclipseEvent(id: UUID(), date: "2030-11-25", type: .total,
                     greatestEclipseLat: -43.6, greatestEclipseLon:   71.2,
                     durationSeconds: 224,
                     description: "S. Atlantic → S. Africa → S. Indian Ocean → SW Australia"),
        EclipseEvent(id: UUID(), date: "2031-05-21", type: .annular,
                     greatestEclipseLat:   8.9, greatestEclipseLon:   71.7,
                     durationSeconds: 326,
                     description: "S. Africa → Indian Ocean → India → Malaysia/Borneo"),
        EclipseEvent(id: UUID(), date: "2031-11-14", type: .hybrid,
                     greatestEclipseLat:  -0.6, greatestEclipseLon: -137.6,
                     durationSeconds: 68,
                     description: "Central Pacific → Central America"),
        EclipseEvent(id: UUID(), date: "2032-05-09", type: .annular,
                     greatestEclipseLat: -51.3, greatestEclipseLon:   -7.1,
                     durationSeconds: 22,
                     description: "Near Antarctica → S. Atlantic"),
        EclipseEvent(id: UUID(), date: "2033-03-30", type: .total,
                     greatestEclipseLat:  71.3, greatestEclipseLon: -155.8,
                     durationSeconds: 157,
                     description: "NE Siberia → Alaska → Arctic Ocean"),
        EclipseEvent(id: UUID(), date: "2034-03-20", type: .total,
                     greatestEclipseLat:  16.1, greatestEclipseLon:   22.2,
                     durationSeconds: 249,
                     description: "Nigeria → Sudan → Egypt → Saudi Arabia → India"),
    ]

    // MARK: - Real Besselian Elements
    // Source: NASA GSFC "Solar Eclipse Search Engine" (Fred Espenak, VSOP87/ELP2000-82)
    // https://eclipse.gsfc.nasa.gov/SEsearch/SEdata.php?Ecl=YYYYMMDD
    // All values taken verbatim from the NASA tables; t0 is in TDT decimal hours.
    // Row order: [a0, a1, a2, a3] where a(t) = a0 + a1·Δt + a2·Δt² + a3·Δt³, Δt = t − t0 (hours).

    static let besselianData: [String: BesselianElements] = [

        // 2024 Apr 8 — Total, max 4m28s, path width 197.5 km
        // Greatest eclipse: 18:17:15 UT, lat 25.3°N, lon 104.1°W
        "2024-04-08": BesselianElements(
            date: "2024-04-08", t0: 18.0,
            x:  [-0.3182440,  0.5117116,  0.0000326, -0.0000084],
            y:  [ 0.2197640,  0.2709589, -0.0000595, -0.0000047],
            d:  [ 7.5862002,  0.0148440, -0.0000020,  0.0000000],
            m:  [89.5912170, 15.0040800,  0.0000000,  0.0000000],
            l1: [ 0.5358140,  0.0000618, -0.0000128,  0.0000000],
            l2: [-0.0102720,  0.0000615, -0.0000127,  0.0000000],
            tanF1: 0.0046683, tanF2: 0.0046450, mu0: 89.5912170, deltaT: 74.0),

        // 2026 Aug 12 — Total, max 2m18s, path width 293.9 km
        // Greatest eclipse: 17:45:51 UT, lat 65.2°N, lon 25.2°W
        "2026-08-12": BesselianElements(
            date: "2026-08-12", t0: 18.0,
            x:  [ 0.4755140,  0.5189249, -0.0000773, -0.0000080],
            y:  [ 0.7711830, -0.2301680, -0.0001246,  0.0000038],
            d:  [14.7966700, -0.0120650, -0.0000030,  0.0000000],
            m:  [88.7477870, 15.0030900,  0.0000000,  0.0000000],
            l1: [ 0.5379550,  0.0000939, -0.0000121,  0.0000000],
            l2: [-0.0081420,  0.0000935, -0.0000121,  0.0000000],
            tanF1: 0.0046141, tanF2: 0.0045911, mu0: 88.7477870, deltaT: 75.4),

        // 2027 Aug 02 — Total, max 6m23s, path width 257.7 km
        // Greatest eclipse: 10:06:34 UT, lat 25.5°N, lon 33.2°E
        "2027-08-02": BesselianElements(
            date: "2027-08-02", t0: 10.0,
            x:  [-0.0197720,  0.5447123, -0.0000446, -0.0000092],
            y:  [ 0.1600610, -0.2111582, -0.0001217,  0.0000038],
            d:  [17.7624702, -0.0101810, -0.0000040,  0.0000000],
            m:  [328.422546, 15.0021000,  0.0000000,  0.0000000],
            l1: [ 0.5305960,  0.0000138, -0.0000128,  0.0000000],
            l2: [-0.0154640,  0.0000137, -0.0000128,  0.0000000],
            tanF1: 0.0046064, tanF2: 0.0045834, mu0: 328.422546, deltaT: 76.0),

        // 2028 Jul 22 — Total, max 5m10s, path width 230.2 km
        // Greatest eclipse: 02:55:23 UT, lat 15.6°S, lon 126.7°E
        "2028-07-22": BesselianElements(
            date: "2028-07-22", t0: 3.0,
            x:  [-0.1544090,  0.5449892, -0.0000214, -0.0000087],
            y:  [-0.5864240, -0.1746085, -0.0001021,  0.0000030],
            d:  [20.1823101, -0.0079740, -0.0000050,  0.0000000],
            m:  [223.378677, 15.0010200,  0.0000000,  0.0000000],
            l1: [ 0.5352370, -0.0000859, -0.0000123,  0.0000000],
            l2: [-0.0108460, -0.0000854, -0.0000122,  0.0000000],
            tanF1: 0.0046016, tanF2: 0.0045786, mu0: 223.378677, deltaT: 76.6),

        // 2030 Jun 01 — Annular, max 5m21s, path width 249.6 km
        // Greatest eclipse: 06:27:55 UT, lat 56.5°N, lon 80.1°E
        "2030-06-01": BesselianElements(
            date: "2030-06-01", t0: 6.0,
            x:  [-0.2693910,  0.5056371,  0.0000182, -0.0000057],
            y:  [ 0.5519770,  0.0210150, -0.0001586, -0.0000002],
            d:  [22.0613003,  0.0055810, -0.0000050,  0.0000000],
            m:  [270.539825, 14.9997000,  0.0000000,  0.0000000],
            l1: [ 0.5661500, -0.0000130, -0.0000097,  0.0000000],
            l2: [ 0.0199120, -0.0000129, -0.0000097,  0.0000000],
            tanF1: 0.0046120, tanF2: 0.0045890, mu0: 270.539825, deltaT: 77.8),

        // 2030 Nov 25 — Total, max 3m44s, path width 169.3 km
        // Greatest eclipse: 06:50:19 UT, lat 43.6°S, lon 71.2°E
        "2030-11-25": BesselianElements(
            date: "2030-11-25", t0: 7.0,
            x:  [ 0.0441500,  0.5787798,  0.0000177, -0.0000098],
            y:  [-0.3926600, -0.0551891,  0.0001744,  0.0000008],
            d:  [-20.760999, -0.0079890,  0.0000050,  0.0000000],
            m:  [288.274597, 14.9983600,  0.0000000,  0.0000000],
            l1: [ 0.5382130, -0.0000379, -0.0000130,  0.0000000],
            l2: [-0.0078850, -0.0000377, -0.0000130,  0.0000000],
            tanF1: 0.0047361, tanF2: 0.0047125, mu0: 288.274597, deltaT: 78.1),

        // 2031 May 21 — Annular, max 5m26s, path width 152.2 km
        // Greatest eclipse: 07:14:45 UT, lat 8.9°N, lon 71.7°E
        "2031-05-21": BesselianElements(
            date: "2031-05-21", t0: 7.0,
            x:  [-0.1147810,  0.5112392,  0.0000072, -0.0000060],
            y:  [-0.2112480,  0.0579330, -0.0001182, -0.0000006],
            d:  [20.1591492,  0.0083390, -0.0000050,  0.0000000],
            m:  [285.851135, 15.0006200,  0.0000000,  0.0000000],
            l1: [ 0.5624050,  0.0000806, -0.0000100,  0.0000000],
            l2: [ 0.0161860,  0.0000802, -0.0000100,  0.0000000],
            tanF1: 0.0046208, tanF2: 0.0045978, mu0: 285.851135, deltaT: 78.5),

        // 2031 Nov 14 — Hybrid, max 1m08s, path width 38.3 km
        // Greatest eclipse: 21:06:12 UT, lat 0.6°S, lon 137.6°W
        "2031-11-14": BesselianElements(
            date: "2031-11-14", t0: 21.0,
            x:  [-0.0198690,  0.5509440,  0.0000366, -0.0000082],
            y:  [ 0.3149710, -0.0890652,  0.0001046,  0.0000012],
            d:  [-18.336809, -0.0105340,  0.0000040,  0.0000000],
            m:  [138.893982, 14.9997600,  0.0000000,  0.0000000],
            l1: [ 0.5477740, -0.0001068, -0.0000120,  0.0000000],
            l2: [ 0.0016280, -0.0001063, -0.0000119,  0.0000000],
            tanF1: 0.0047260, tanF2: 0.0047025, mu0: 138.893982, deltaT: 78.8),

        // 2032 May 09 — Annular, max 0m22s, path width 43.7 km  (|γ|=0.9375, near Antarctica)
        // Greatest eclipse: 13:25:23 UT, lat 51.3°S, lon 7.1°W
        // Source: NASA GSFC https://eclipse.gsfc.nasa.gov/SEsearch/SEdata.php?Ecl=20320509
        "2032-05-09": BesselianElements(
            date: "2032-05-09", t0: 13.0,
            x:  [-0.0743600,  0.5359546,  0.0000052, -0.0000074],
            y:  [-0.9654510,  0.0954058, -0.0000702, -0.0000013],
            d:  [17.5929108,  0.0106940, -0.0000040,  0.0000000],
            m:  [15.8891000, 15.0017400,  0.0000000,  0.0000000],
            l1: [ 0.5488530,  0.0001272, -0.0000112,  0.0000000],
            l2: [ 0.0027020,  0.0001266, -0.0000112,  0.0000000],
            tanF1: 0.0046310, tanF2: 0.0046079, mu0: 15.8891000, deltaT: 79.1),

        // 2033 Mar 30 — Total, max 2m37s, path width 781.1 km  (|γ|=0.9778, Alaska/Arctic)
        // Greatest eclipse: 18:01:16 UT, lat 71.3°N, lon 155.8°W
        // Source: NASA GSFC https://eclipse.gsfc.nasa.gov/SEsearch/SEdata.php?Ecl=20330330
        "2033-03-30": BesselianElements(
            date: "2033-03-30", t0: 18.0,
            x:  [-0.3188510,  0.5554244,  0.0000227, -0.0000094],
            y:  [ 0.9246670,  0.1756610, -0.0000801, -0.0000029],
            d:  [ 4.0936799,  0.0157190, -0.0000010,  0.0000000],
            m:  [88.9280780, 15.0044500,  0.0000000,  0.0000000],
            l1: [ 0.5349430,  0.0000276, -0.0000129,  0.0000000],
            l2: [-0.0111390,  0.0000275, -0.0000129,  0.0000000],
            tanF1: 0.0046807, tanF2: 0.0046574, mu0: 88.9280780, deltaT: 79.7),

        // 2034 Mar 20 — Total, max 4m09s, path width 159.1 km
        // Greatest eclipse: 10:17:25 UT, lat 16.1°N, lon 22.2°E
        // Source: NASA GSFC https://eclipse.gsfc.nasa.gov/SEsearch/SEdata.php?Ecl=20340320
        "2034-03-20": BesselianElements(
            date: "2034-03-20", t0: 10.0,
            x:  [-0.2596090,  0.5481629,  0.0000234, -0.0000090],
            y:  [ 0.2207520,  0.1755790, -0.0000080, -0.0000028],
            d:  [-0.0551300,  0.0160420,  0.0000000,  0.0000000],
            m:  [328.139130, 15.0044000,  0.0000000,  0.0000000],
            l1: [ 0.5386310, -0.0000665, -0.0000127,  0.0000000],
            l2: [-0.0074690, -0.0000662, -0.0000126,  0.0000000],
            tanF1: 0.0046952, tanF2: 0.0046718, mu0: 328.139130, deltaT: 80.4),
    ]

    // MARK: - Besselian → Center-Line Path Computation (Espenak / Meeus method)

    /// Compute the eclipse path (center-line + path width) entirely from Besselian elements.
    ///
    /// Algorithm (Espenak / Meeus; cross-verified against SonyCRSDK EclipseCalculationService):
    ///   1. For each time step, evaluate Besselian polynomials → (x, y, d, μ, l2) via Horner's method.
    ///   2. If x²+y² ≥ 1 the shadow axis misses Earth — skip.
    ///   3. ζ = √(1 − x²− y²)
    ///   4. Geocentric latitude:  sin φ' = y·cos d + ζ·sin d
    ///   5. Local hour angle:     H = atan2(x, ζ·cos d − y·sin d)    [degrees]
    ///   6. Geodetic latitude:    φ = atan(tan φ' / (1−f)²)          [WGS-84]
    ///   7. East longitude:       λ = H − μ(t)   ← NOTE: H minus mu, NOT mu minus H
    ///      (μ is the Greenwich Hour Angle; H is the local hour angle at the sub-shadow point;
    ///       λ_east = H − μ  because  H = μ + λ_east  →  λ_east = H − μ)
    ///   8. Path half-width:      w = |l2 − ζ·tanF2| · R_Earth / ζ
    ///
    /// Reference: SonyCRSDK/src/eclipse/services/solar/EclipseCalculationService.cpp
    ///            obsvconst1 = -lon * DEG_TO_RAD  →  h = mu - obsvconst1 = mu + lon_east
    ///            ∴ lon_east = h - mu = H - mu  ✓
    static func computePath(for elements: BesselianElements) -> EclipsePath {
        var centerPts: [(lat: Double, lon: Double)] = []
        var widthsKm:  [Double] = []

        // WGS-84: (1-f)² where f = 1/298.257223563
        let oneMinusFsq = pow(1.0 - 1.0 / 298.257223563, 2.0)

        // Scan ±3 h around t0, 1-minute resolution
        let nSteps   = 360
        let dtTotal  = 6.0
        let dtStep   = dtTotal / Double(nSteps)

        for i in 0...nSteps {
            let t  = elements.t0 - 3.0 + Double(i) * dtStep
            let dt = t - elements.t0

            // Evaluate Besselian polynomials via Horner's method (matches SonyCRSDK exactly)
            let x  = ((elements.x[3]*dt + elements.x[2])*dt + elements.x[1])*dt + elements.x[0]
            let y  = ((elements.y[3]*dt + elements.y[2])*dt + elements.y[1])*dt + elements.y[0]
            let dD = ((elements.d[2]*dt + elements.d[1])*dt) + elements.d[0]      // degrees
            var mu = ((elements.m[2]*dt + elements.m[1])*dt) + elements.m[0]      // degrees GHA
            let l2 = ((elements.l2[2]*dt + elements.l2[1])*dt) + elements.l2[0]

            // Normalize μ to [0, 360)
            mu = mu - 360.0 * floor(mu / 360.0)

            let dRad = dD * (.pi / 180.0)

            // Shadow axis must strike Earth
            let rho2 = x*x + y*y
            guard rho2 < 1.0 else { continue }
            let zeta = sqrt(1.0 - rho2)

            // Step 4: geocentric latitude
            let sinPhiGeo = y * cos(dRad) + zeta * sin(dRad)
            let phiGeo    = asin(max(-1.0, min(1.0, sinPhiGeo)))

            // Step 5: local hour angle H at sub-shadow point (degrees)
            let cosPhiCosH = zeta * cos(dRad) - y * sin(dRad)
            let H_deg = atan2(x, cosPhiCosH) * (180.0 / .pi)

            // Step 6: geodetic latitude
            let phiGeod = atan(tan(phiGeo) / oneMinusFsq) * (180.0 / .pi)

            // Step 7: east longitude = H − μ  (SonyCRSDK verified: lon_east = H − GHA)
            var lon = H_deg - mu
            while lon >  180.0 { lon -= 360.0 }
            while lon < -180.0 { lon += 360.0 }

            centerPts.append((lat: phiGeod, lon: lon))

            // Step 8: projected l2 → path width in km
            let l2proj = l2 - zeta * elements.tanF2
            let wKm = 2.0 * abs(l2proj) * 6378.137 / max(zeta, 0.05)
            widthsKm.append(wKm)
        }

        // Use the median width (robust against near-sunrise/sunset extremes)
        let sortedW = widthsKm.sorted()
        let medianW = sortedW.isEmpty ? 150.0 : sortedW[sortedW.count / 2]

        return EclipsePath(
            eclipseDate: elements.date,
            centerLine:  centerPts,
            widthKm:     max(medianW, 10.0))
    }
}
