import AppKit
import MapKit
import CoreLocation

// MARK: - Eclipse Path Data (detailed waypoints from NASA path tables)

struct EclipsePath {
    let eclipseDate: String
    let centerLine:  [(lat: Double, lon: Double)]
    let northLimit:  [(lat: Double, lon: Double)]   // real north limit (empty = use computed offset)
    let southLimit:  [(lat: Double, lon: Double)]   // real south limit (empty = use computed offset)
    let widthKm:     Double

    /// Convenience init for eclipses without explicit N/S limit data
    init(eclipseDate: String, centerLine: [(lat: Double, lon: Double)], widthKm: Double) {
        self.eclipseDate = eclipseDate
        self.centerLine  = centerLine
        self.northLimit  = []
        self.southLimit  = []
        self.widthKm     = widthKm
    }

    /// Full init with explicit N/S limits (preferred — avoids high-lat geometry errors)
    init(eclipseDate: String,
         centerLine: [(lat: Double, lon: Double)],
         northLimit: [(lat: Double, lon: Double)],
         southLimit: [(lat: Double, lon: Double)],
         widthKm: Double) {
        self.eclipseDate = eclipseDate
        self.centerLine  = centerLine
        self.northLimit  = northLimit
        self.southLimit  = southLimit
        self.widthKm     = widthKm
    }
}

extension EclipseCalculationEngine {

    // MARK: - Eclipse Paths (computed from Besselian elements)
    //
    // Paths are NOT hardcoded. Each EclipsePath is derived mathematically
    // from the Besselian elements stored in `besselianData` using the standard
    // Espenak/Meeus fundamental-plane → geodetic projection.
    // Eclipses without Besselian data use a single-point fallback so the
    // greatest-eclipse marker still appears correctly on the map.

    /// Lazily computed map: eclipse date string → EclipsePath.
    static let eclipsePaths: [String: EclipsePath] = {
        var result: [String: EclipsePath] = [:]

        // --- Computed from Besselian elements ---
        for (date, elements) in besselianData {
            let path = computePath(for: elements)
            guard !path.centerLine.isEmpty else { continue }
            result[date] = path
        }

        // --- Fallback stubs for eclipses not yet in besselianData ---
        // Only the greatest-eclipse point is provided; the map will place
        // a marker there but draw no band (no Besselian data to compute from).
        // NOTE: 2029-01-26 is a partial eclipse globally (|γ|>1); no umbral path exists.
        let stubs: [(date: String, lat: Double, lon: Double, wKm: Double)] = [
            ("2029-01-26", -70.2,  -22.8,  0),   // Partial only — no umbral/annular path
        ]
        for s in stubs where result[s.date] == nil {
            result[s.date] = EclipsePath(
                eclipseDate: s.date,
                centerLine:  [(lat: s.lat, lon: s.lon)],
                widthKm:     s.wKm)
        }

        return result
    }()

}

// MARK: - Map View Controller

final class EclipseMapViewController: NSViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    let mapView = MKMapView()
    var onLocationPicked: ((Double, Double) -> Void)?

    private var currentPath:        EclipsePath?
    private var currentPin:         MKPointAnnotation?
    private var locationManager:    CLLocationManager?
    private var searchCompleter:    MKLocalSearchCompleter?
    private var searchResults:      [MKLocalSearchCompletion] = []
    private var searchPopup:        NSWindow?

    // Search bar
    private let searchField = NSSearchField()
    private let locateBtn   = NSButton()

    private let mapContainer = NSView()  // placeholder until map is ready
    private var mapInstalled = false

    override func loadView() {
        view = NSView()

        // ── Search field overlay ───────────────────────────────────────
        searchField.placeholderString = "Search location…"
        searchField.bezelStyle        = .roundedBezel
        searchField.target            = self
        searchField.action            = #selector(searchFieldSubmit)
        searchField.delegate          = self
        searchField.wantsLayer        = true
        searchField.layer?.cornerRadius = 8

        // ── My Location button ──────────────────────────────────────────
        locateBtn.title     = "📍 My Location"
        locateBtn.bezelStyle = .rounded
        locateBtn.controlSize = .small
        locateBtn.target    = self
        locateBtn.action    = #selector(useMyLocation)

        // ── Layout: search row + placeholder container ──
        mapContainer.wantsLayer = true
        mapContainer.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor

        view.addSubview(searchField)
        view.addSubview(locateBtn)
        view.addSubview(mapContainer)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        locateBtn.translatesAutoresizingMaskIntoConstraints   = false
        mapContainer.translatesAutoresizingMaskIntoConstraints = false

        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        locateBtn.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        locateBtn.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchField.trailingAnchor.constraint(equalTo: locateBtn.leadingAnchor, constant: -8),
            searchField.heightAnchor.constraint(equalToConstant: 24),

            locateBtn.topAnchor.constraint(equalTo: view.topAnchor),
            locateBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            locateBtn.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),

            mapContainer.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 4),
            mapContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // MKLocalSearchCompleter for autocomplete
        searchCompleter = MKLocalSearchCompleter()
        searchCompleter?.delegate = self
        searchCompleter?.resultTypes = .address
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        // Defer map installation to next run loop iteration to ensure
        // the initial layout pass has fully completed
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.installMapIfNeeded()
            if let eclipse = self.pendingEclipse {
                self.pendingEclipse = nil
                self.showEclipse(eclipse)
            }
        }
    }

    private func installMapIfNeeded() {
        guard !mapInstalled else { return }
        mapInstalled = true

        mapView.delegate      = self
        mapView.mapType       = .standard
        mapView.showsCompass  = true
        mapView.showsZoomControls = true

        mapContainer.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: mapContainer.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: mapContainer.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: mapContainer.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: mapContainer.bottomAnchor),
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(mapClicked(_:)))
        mapView.addGestureRecognizer(click)
    }

    // MARK: - Location Search

    @objc private func searchFieldSubmit() {
        let q = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = q
        MKLocalSearch(request: req).start { [weak self] resp, _ in
            guard let self = self,
                  let item = resp?.mapItems.first else { return }
            let coord = item.placemark.coordinate
            self.setPin(lat: coord.latitude, lon: coord.longitude)
            self.mapView.setCenter(coord, animated: true)
            self.onLocationPicked?(coord.latitude, coord.longitude)
        }
    }

    // MARK: - My Location (CoreLocation)

    @objc private func useMyLocation() {
        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager?.delegate = self
        }
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.first else { return }
        let coord = loc.coordinate
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setPin(lat: coord.latitude, lon: coord.longitude)
            self.mapView.setCenter(coord, animated: true)
            self.onLocationPicked?(coord.latitude, coord.longitude)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }

    // MARK: - Map Click

    @objc private func mapClicked(_ gesture: NSClickGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coord = mapView.convert(point, toCoordinateFrom: mapView)
        setPin(lat: coord.latitude, lon: coord.longitude)
        onLocationPicked?(coord.latitude, coord.longitude)
    }

    // MARK: - Eclipse Display

    private var pendingEclipse: EclipseEvent?

    func showEclipse(_ eclipse: EclipseEvent) {
        guard mapInstalled else {
            pendingEclipse = eclipse
            return
        }
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        guard let path = EclipseCalculationEngine.eclipsePaths[eclipse.date] else {
            zoomTo(lat: eclipse.greatestEclipseLat, lon: eclipse.greatestEclipseLon, meters: 5_000_000)
            return
        }
        currentPath = path
        drawPath(path, type: eclipse.type)

        // Greatest eclipse marker
        let greatestPin = MKPointAnnotation()
        greatestPin.coordinate = CLLocationCoordinate2D(
            latitude: eclipse.greatestEclipseLat, longitude: eclipse.greatestEclipseLon)
        greatestPin.title = "Greatest Eclipse"
        greatestPin.subtitle = "\(eclipse.durationSeconds)s totality"
        mapView.addAnnotation(greatestPin)

        // Zoom to show the full path extent, not just the greatest eclipse point
        let lats = path.centerLine.map { $0.lat }
        let lons = path.centerLine.map { $0.lon }
        let midLat = (lats.min()! + lats.max()!) / 2.0
        let midLon = (lons.min()! + lons.max()!) / 2.0
        let spanLat = (lats.max()! - lats.min()!) * 1.5  // add 50% margin
        let spanLon = (lons.max()! - lons.min()!) * 1.5
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
            span: MKCoordinateSpan(
                latitudeDelta: min(max(spanLat, 20), 160),
                longitudeDelta: min(max(spanLon, 30), 360)))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mapView.setRegion(mapView.regionThatFits(region), animated: false)
        CATransaction.commit()
    }

    func setPin(lat: Double, lon: Double) {
        // Remove old observation pin (keep greatest-eclipse pin)
        if let pin = currentPin { mapView.removeAnnotation(pin) }
        let pin = MKPointAnnotation()
        pin.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        pin.title = String(format: "📍 %.4f°, %.4f°", lat, lon)
        mapView.addAnnotation(pin)
        currentPin = pin
    }

    // MARK: - Drawing

    private func drawPath(_ path: EclipsePath, type: EclipseEvent.EclipseType) {
        guard path.centerLine.count >= 2 else { return }

        // ── Center line (dashed red) ──────────────────────────────────────
        var centerCoords = path.centerLine.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let centerLine   = MKPolyline(coordinates: &centerCoords, count: centerCoords.count)
        centerLine.title = "center"
        mapView.addOverlay(centerLine, level: .aboveLabels)

        // ── Umbral band ───────────────────────────────────────────────────
        // Use real north/south limits when available; fall back to computed perpendicular offsets.
        // Always draw as TWO polylines (north edge + south edge) — NEVER a closed polygon —
        // so there is no spurious closing segment drawn across the map.
        let northCoords: [CLLocationCoordinate2D]
        let southCoords: [CLLocationCoordinate2D]

        if !path.northLimit.isEmpty && !path.southLimit.isEmpty {
            // Real limit data: use directly
            northCoords = path.northLimit.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            southCoords = path.southLimit.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        } else {
            // Fallback: perpendicular offset from center line.
            //
            // We work entirely in metres (flat-earth approximation per segment):
            //   dy = dLat * 111_000 m/deg
            //   dx = dLon * 111_000 * cos(lat) m/deg
            // The perpendicular unit vector in metres is (-dy, dx) / |(-dy, dx)|.
            // Convert back to degrees:
            //   perpLat_deg  = perpY_m / 111_000
            //   perpLon_deg  = perpX_m / (111_000 * cos(lat))   — but cap cos(lat) ≥ 0.10
            //                                                       so lon offset never explodes
            //                                                       at very high latitudes.
            let halfKm  = path.widthKm / 2.0
            let mPerDeg = 111_000.0
            var n: [CLLocationCoordinate2D] = []
            var s: [CLLocationCoordinate2D] = []
            let pts = path.centerLine
            for i in 0..<pts.count {
                let prevIdx = max(0, i - 1)
                let nextIdx = min(pts.count - 1, i + 1)
                let cosLat  = cos(pts[i].lat * .pi / 180.0)

                // Direction vector in metres
                let dLatM = (pts[nextIdx].lat - pts[prevIdx].lat) * mPerDeg
                let dLonM = (pts[nextIdx].lon - pts[prevIdx].lon) * mPerDeg * max(cosLat, 0.01)
                let len   = sqrt(dLatM * dLatM + dLonM * dLonM)

                let (perpLatM, perpLonM): (Double, Double)
                if len < 1.0 {
                    perpLatM = halfKm * 1000.0; perpLonM = 0
                } else {
                    // Perpendicular (rotate 90°): (-dLonM, dLatM)
                    perpLatM =  (-dLonM / len) * halfKm * 1000.0
                    perpLonM =  ( dLatM / len) * halfKm * 1000.0
                }

                // Convert back to degrees, capping cosLat so lon offset stays sane
                let perpLatDeg = perpLatM / mPerDeg
                let perpLonDeg = perpLonM / (mPerDeg * max(cosLat, 0.10))

                n.append(CLLocationCoordinate2D(latitude:  pts[i].lat + perpLatDeg,
                                                longitude: pts[i].lon + perpLonDeg))
                s.append(CLLocationCoordinate2D(latitude:  pts[i].lat - perpLatDeg,
                                                longitude: pts[i].lon - perpLonDeg))
            }
            northCoords = n
            southCoords = s
        }

        // Draw north edge
        var nc = northCoords
        let northLine = MKPolyline(coordinates: &nc, count: nc.count)
        northLine.title = type == .annular ? "annular-edge" : "total-edge"
        mapView.addOverlay(northLine, level: .aboveRoads)

        // Draw south edge
        var sc = southCoords
        let southLine = MKPolyline(coordinates: &sc, count: sc.count)
        southLine.title = type == .annular ? "annular-edge" : "total-edge"
        mapView.addOverlay(southLine, level: .aboveRoads)

        // Filled band: build polygon north→south by pairing endpoints (no weird closing arc)
        // Use the shorter of north/south arrays to keep them in sync
        let minCount = min(northCoords.count, southCoords.count)
        var bandCoords = Array(northCoords.prefix(minCount)) + Array(southCoords.prefix(minCount).reversed())
        let band = MKPolygon(coordinates: &bandCoords, count: bandCoords.count)
        band.title = type == .annular ? "annular" : "total"
        mapView.addOverlay(band, level: .aboveRoads)
    }

    private func zoomTo(lat: Double, lon: Double, meters: CLLocationDistance) {
        let clampedLat = min(meters, 15_000_000)
        let clampedLon = min(meters * 2, 30_000_000)
        var region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            latitudinalMeters: clampedLat, longitudinalMeters: clampedLon)
        // Clamp span to valid range
        region.span.latitudeDelta  = min(region.span.latitudeDelta, 160)
        region.span.longitudeDelta = min(region.span.longitudeDelta, 360)
        // Suppress layout during region change to prevent recursion
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mapView.setRegion(mapView.regionThatFits(region), animated: false)
        CATransaction.commit()
    }

    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let poly = overlay as? MKPolyline {
            let r = MKPolylineRenderer(polyline: poly)
            if poly.title == "center" {
                r.strokeColor = NSColor.systemRed
                r.lineWidth   = 2.5
                r.lineDashPattern = [6, 5]
            } else {
                // North/south limit edges
                let isAnnularEdge = poly.title == "annular-edge"
                r.strokeColor = (isAnnularEdge ? NSColor.systemOrange : NSColor.systemBlue).withAlphaComponent(0.7)
                r.lineWidth   = 1.5
            }
            return r
        }
        if let poly = overlay as? MKPolygon {
            let r = MKPolygonRenderer(polygon: poly)
            let isAnnular = poly.title == "annular"
            r.fillColor   = (isAnnular ? NSColor.systemOrange : NSColor.systemBlue).withAlphaComponent(0.15)
            r.strokeColor = NSColor.clear  // edges drawn separately as polylines — no double outline
            r.lineWidth   = 0
            return r
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        let pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "pin")
        pin.canShowCallout = true
        pin.pinTintColor   = (annotation.title == "Greatest Eclipse") ? .systemYellow : .systemGreen
        return pin
    }
}

// MARK: - NSSearchFieldDelegate (autocomplete)

extension EclipseMapViewController: NSSearchFieldDelegate, MKLocalSearchCompleterDelegate {
    func controlTextDidChange(_ obj: Notification) {
        let q = searchField.stringValue
        guard !q.isEmpty else { return }
        searchCompleter?.queryFragment = q
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Optionally show dropdown — for now just let user press Enter
        searchResults = completer.results
    }
}
