import Cocoa
import Combine
import MapKit

// MARK: - Main Window Controller

final class MainWindowController: NSViewController {

    private let splitView = NSSplitView()
    private let sidebar   = SidebarViewController()
    private let content   = ContentTabViewController()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1360, height: 860))
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bg0.cgColor

        addChild(sidebar)
        addChild(content)

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.addArrangedSubview(sidebar.view)
        splitView.addArrangedSubview(content.view)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 1)

        view.addSubview(splitView)
        splitView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: view.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        DispatchQueue.main.async { self.splitView.setPosition(220, ofDividerAt: 0) }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        CameraManager.shared.detectCameras()
    }
}

// MARK: - Sidebar

final class SidebarViewController: NSViewController {
    private let cameraManager = CameraManager.shared
    private var cancellables = Set<AnyCancellable>()

    private let cameraList  = NSTableView()
    private let statusLabel = themeLabel("Ready", size: 11, color: Theme.textTertiary)
    private let connectBtn  = themeButton("Connect", accent: Theme.accentBlue)
    private let detectBtn   = themeButton("↻ Scan", accent: Theme.accentBlue)
    private let liveViewBtn = themeButton("Live View", accent: Theme.accentGold)

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 820))
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bg1.cgColor

        // Sidebar header with subtle gradient line
        let headerBg = NSView()
        headerBg.wantsLayer = true
        headerBg.layer?.backgroundColor = Theme.bg0.cgColor
        view.addSubview(headerBg)
        headerBg.translatesAutoresizingMaskIntoConstraints = false

        let title = themeLabel("📷 Cameras", size: 14, color: Theme.textPrimary, bold: true)
        view.addSubview(title)
        title.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerBg.topAnchor.constraint(equalTo: view.topAnchor),
            headerBg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerBg.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerBg.heightAnchor.constraint(equalToConstant: 48),
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 52),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])

        let scroll = NSScrollView()
        scroll.documentView = cameraList
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.scrollerStyle = .overlay
        cameraList.backgroundColor = .clear
        cameraList.rowHeight = 44
        cameraList.gridStyleMask = []
        cameraList.headerView = nil
        cameraList.intercellSpacing = NSSize(width: 0, height: 1)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cam"))
        col.width = 220
        cameraList.addTableColumn(col)
        cameraList.dataSource = self
        cameraList.delegate = self
        cameraList.selectionHighlightStyle = .regular

        view.addSubview(scroll)
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 200)
        ])

        let btnStack = NSStackView(views: [detectBtn, connectBtn, liveViewBtn])
        btnStack.orientation = NSUserInterfaceLayoutOrientation.vertical
        btnStack.spacing = 6
        btnStack.distribution = NSStackView.Distribution.fillEqually
        view.addSubview(btnStack)
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btnStack.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 12),
            btnStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            btnStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])

        view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.maximumNumberOfLines = 2
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: btnStack.bottomAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])

        // Divider using theme color
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = Theme.divider.cgColor
        view.addSubview(sep)
        sep.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            sep.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            sep.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            sep.heightAnchor.constraint(equalToConstant: 1)
        ])

        // Version / branding at bottom
        let brand = themeLabel("Eclipse Mission Control v2.0", size: 9, color: Theme.textTertiary)
        brand.alignment = .center
        view.addSubview(brand)
        brand.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            brand.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            brand.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        detectBtn.target = self; detectBtn.action = #selector(scanCameras)
        connectBtn.target = self; connectBtn.action = #selector(connectCamera)
        liveViewBtn.target = self; liveViewBtn.action = #selector(toggleLiveView)

        cameraManager.$detectedCameras
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.cameraList.reloadData() }
            .store(in: &cancellables)

        cameraManager.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.statusLabel.stringValue = msg }
            .store(in: &cancellables)
    }

    @objc func scanCameras() { cameraManager.detectCameras() }

    @objc func connectCamera() {
        let row = cameraList.selectedRow
        guard row >= 0, row < cameraManager.detectedCameras.count else { return }
        cameraManager.connect(to: cameraManager.detectedCameras[row])
    }

    @objc func toggleLiveView() {
        if cameraManager.isLiveViewRunning {
            cameraManager.stopLiveView()
            liveViewBtn.title = "Live View"
        } else {
            cameraManager.startLiveView()
            liveViewBtn.title = "Stop Live View"
        }
    }
}

extension SidebarViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { cameraManager.detectedCameras.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cam = cameraManager.detectedCameras[row]
        let cell = NSTableCellView()
        cell.wantsLayer = true
        cell.frame = NSRect(x: 0, y: 0, width: 220, height: 44)

        let icon = NSTextField(labelWithString: cam.isConnected ? "🟢" : "⚫️")
        icon.font = .systemFont(ofSize: 16)

        let name = themeLabel(cam.name, size: 12, color: Theme.textPrimary, bold: true)
        name.maximumNumberOfLines = 1
        let port = themeLabel(cam.port, size: 10, color: Theme.textTertiary)

        let infoStack = NSStackView(views: [name, port])
        infoStack.orientation = NSUserInterfaceLayoutOrientation.vertical
        infoStack.spacing = 2
        infoStack.alignment = NSLayoutConstraint.Attribute.leading

        let rowStack = NSStackView(views: [icon, infoStack])
        rowStack.orientation = NSUserInterfaceLayoutOrientation.horizontal
        rowStack.spacing = 8
        rowStack.alignment = NSLayoutConstraint.Attribute.centerY

        cell.addSubview(rowStack)
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            rowStack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }
}

// MARK: - Content Tabs (Vertical Icon Sidebar)

final class ContentTabViewController: NSViewController {
    private let tabSidebar   = NSView()
    private let containerView = NSView()
    private var tabVCs: [NSViewController] = []
    private var tabButtons: [NSButton] = []
    private var selectedIndex = 0

    private let tabDefs: [(icon: String, label: String)] = [
        ("🌑", "Eclipse"),
        ("📸", "Camera"),
        ("📋", "Script"),
        ("▶︎", "Execute"),
        ("📺", "Live View"),
        ("🧭", "Polar"),
        ("✅", "Checklist"),
    ]

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bg0.cgColor

        let vcs: [NSViewController] = [
            EclipseTabViewController(),
            CameraControlViewController(),
            ScriptViewController(),
            ExecuteViewController(),
            LiveViewViewController(),
            PolarAlignViewController(),
            EquipmentChecklistViewController(),
        ]
        tabVCs = vcs
        for vc in tabVCs { addChild(vc) }

        // ── Vertical tab sidebar (60pt wide icon strip on the left) ──────
        tabSidebar.wantsLayer = true
        tabSidebar.layer?.backgroundColor = Theme.bg1.cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 2
        stack.alignment = .centerX
        stack.distribution = .fillEqually

        for (i, def) in tabDefs.enumerated() {
            let btn = NSButton(frame: .zero)
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.cornerRadius = Theme.cornerSm
            btn.attributedTitle = makeTabTitle(icon: def.icon, label: def.label, selected: i == 0)
            btn.tag = i
            btn.target = self
            btn.action = #selector(tabClicked(_:))
            btn.setAccessibilityLabel(def.label)
            tabButtons.append(btn)
            stack.addArrangedSubview(btn)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.widthAnchor.constraint(equalToConstant: 58).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        }

        tabSidebar.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: tabSidebar.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: tabSidebar.leadingAnchor, constant: 1),
            stack.trailingAnchor.constraint(equalTo: tabSidebar.trailingAnchor, constant: -1),
        ])

        // Divider line between tab sidebar and content
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = Theme.border.cgColor

        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = Theme.bg0.cgColor

        view.addSubview(tabSidebar)
        view.addSubview(divider)
        view.addSubview(containerView)
        tabSidebar.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tabSidebar.topAnchor.constraint(equalTo: view.topAnchor),
            tabSidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabSidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tabSidebar.widthAnchor.constraint(equalToConstant: 60),

            divider.topAnchor.constraint(equalTo: view.topAnchor),
            divider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: tabSidebar.trailingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        highlightTab(0)
        showTab(0)
    }

    private func makeTabTitle(icon: String, label: String, selected: Bool) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineSpacing = 1
        let iconColor = selected ? Theme.accentBlue : Theme.textSecondary
        let labelColor = selected ? Theme.textPrimary : Theme.textTertiary
        let str = NSMutableAttributedString()
        str.append(NSAttributedString(string: icon + "\n", attributes: [
            .font: NSFont.systemFont(ofSize: 18),
            .foregroundColor: iconColor,
            .paragraphStyle: para,
        ]))
        str.append(NSAttributedString(string: label, attributes: [
            .font: Theme.body(9, bold: selected),
            .foregroundColor: labelColor,
            .paragraphStyle: para,
        ]))
        return str
    }

    @objc private func tabClicked(_ sender: NSButton) {
        let idx = sender.tag
        guard idx != selectedIndex else { return }
        highlightTab(idx)
        showTab(idx)
    }

    private func highlightTab(_ idx: Int) {
        for (i, btn) in tabButtons.enumerated() {
            let sel = (i == idx)
            btn.layer?.backgroundColor = sel ? Theme.bg3.cgColor : NSColor.clear.cgColor
            btn.attributedTitle = makeTabTitle(icon: tabDefs[i].icon, label: tabDefs[i].label, selected: sel)
        }
        selectedIndex = idx
    }

    private func showTab(_ idx: Int) {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        let vc = tabVCs[idx]
        let v = vc.view
        containerView.addSubview(v)
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: containerView.topAnchor),
            v.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            v.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }
}

// MARK: - Eclipse Tab

final class EclipseTabViewController: NSViewController {

    // ── Top controls ──────────────────────────────────────────────────────
    private let eclipsePicker = NSPopUpButton()
    private let typeIcon      = themeLabel("🌑", size: 22, color: Theme.textPrimary)
    private let dateLabel     = themeLabel("Select an eclipse above", size: 13, color: Theme.textSecondary)
    private let infoLabel     = themeLabel("", size: 11, color: Theme.textTertiary)

    // ── Map ───────────────────────────────────────────────────────────────
    private let mapVC = EclipseMapViewController()

    // ── Eclipse Animation ─────────────────────────────────────────────────
    private let animView = EclipseAnimationView()

    // ── Contact Times List (below simulator) ──────────────────────────────
    private let contactTimesList = ContactTimesListView()

    // ── Location inputs ───────────────────────────────────────────────────
    private let latField    = makeThemedTextField()
    private let lonField    = makeThemedTextField()
    private let useMapHint  = themeLabel("← Click the map to set location", size: 11, color: Theme.textTertiary)
    private let computeBtn  = themeButton("⚡ Compute Contact Times", accent: Theme.accentCoral)

    // ── Results ────
    private let resultsTextView: NSTextView = {
        let tv = NSTextView()
        tv.isEditable = false
        tv.isSelectable = true
        tv.font = Theme.mono(12)
        tv.textColor = Theme.accentGreen
        tv.backgroundColor = Theme.bg1
        tv.isRichText = false
        tv.textContainerInset = NSSize(width: 10, height: 10)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        return tv
    }()

    private var selectedEclipse: EclipseEvent? {
        didSet { eclipseSelectionChanged() }
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bg0.cgColor
        buildUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        eclipsePicker.removeAllItems()
        for e in EclipseCalculationEngine.upcomingEclipses {
            let dur = e.durationSeconds >= 60
                ? "\(e.durationSeconds/60)m \(e.durationSeconds%60)s"
                : "\(e.durationSeconds)s"
            eclipsePicker.addItem(withTitle: "\(e.date)  •  \(e.type.rawValue)  •  max \(dur)")
        }
        eclipsePicker.target = self
        eclipsePicker.action = #selector(pickerChanged)
        eclipsePicker.selectItem(at: 0)

        mapVC.onLocationPicked = { [weak self] lat, lon in
            guard let self = self else { return }
            self.latField.stringValue = String(format: "%.5f", lat)
            self.lonField.stringValue = String(format: "%.5f", lon)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if selectedEclipse == nil {
            selectedEclipse = EclipseCalculationEngine.upcomingEclipses.first
        }
    }

    private func buildUI() {
        let margin: CGFloat = 16

        // ── Eclipse picker row ────────────────────────────────────────────
        let pickerLabel = themeLabel("Eclipse:", size: 12, color: Theme.textPrimary, bold: true)
        eclipsePicker.controlSize = .regular
        eclipsePicker.font = Theme.body(13)

        let pickerRow = NSStackView(views: [pickerLabel, eclipsePicker, typeIcon])
        pickerRow.orientation = .horizontal
        pickerRow.spacing = 10
        pickerRow.alignment = .centerY
        pickerRow.detachesHiddenViews = false

        // ── Info strip ────────────────────────────────────────────────────
        let infoRow = NSStackView(views: [dateLabel, infoLabel])
        infoRow.orientation = .horizontal
        infoRow.spacing = 20
        infoRow.alignment = .centerY
        infoRow.detachesHiddenViews = false

        // ── Map ───────────────────────────────────────────────────────────
        addChild(mapVC)
        let mapContainer = mapVC.view
        mapContainer.wantsLayer = true
        mapContainer.layer?.cornerRadius = Theme.cornerMd
        mapContainer.layer?.masksToBounds = true
        mapContainer.layer?.borderColor = Theme.border.cgColor
        mapContainer.layer?.borderWidth = 1

        // ── Location row ──────────────────────────────────────────────────
        let locLabel = themeLabel("Your Location:", size: 12, color: Theme.textPrimary, bold: true)
        let latLabel = themeLabel("Lat:", size: 12, color: Theme.textSecondary)
        let lonLabel = themeLabel("Lon:", size: 12, color: Theme.textSecondary)
        latField.stringValue = "51.5"
        latField.placeholderString = "e.g. 51.5"
        lonField.stringValue = "-0.12"
        lonField.placeholderString = "e.g. -0.12"
        latField.translatesAutoresizingMaskIntoConstraints = false
        lonField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            latField.widthAnchor.constraint(equalToConstant: 100),
            lonField.widthAnchor.constraint(equalToConstant: 100)
        ])

        let locRow = NSStackView(views: [locLabel, latLabel, latField, lonLabel, lonField, useMapHint])
        locRow.orientation = .horizontal
        locRow.spacing = 8
        locRow.alignment = .centerY
        locRow.detachesHiddenViews = false

        // ── Results ───────────────────────────────────────────────────────
        resultsTextView.string = "Select an eclipse, enter coordinates, then click ⚡ Compute."
        let resultsScroll = NSScrollView()
        resultsScroll.documentView = resultsTextView
        resultsScroll.hasVerticalScroller = true
        resultsScroll.scrollerStyle = .overlay
        resultsScroll.drawsBackground = true
        resultsScroll.backgroundColor = Theme.bg1
        resultsScroll.wantsLayer = true
        resultsScroll.layer?.cornerRadius = Theme.cornerMd
        resultsScroll.layer?.borderColor = Theme.border.cgColor
        resultsScroll.layer?.borderWidth = 1
        resultsTextView.minSize = NSSize(width: 0, height: 200)
        resultsTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        computeBtn.target = self
        computeBtn.action = #selector(compute)

        // ── Animation view ────────────────────────────────────────────────
        animView.wantsLayer = true
        animView.layer?.cornerRadius = Theme.cornerMd
        animView.layer?.backgroundColor = Theme.bg1.cgColor
        animView.layer?.borderColor = Theme.border.cgColor
        animView.layer?.borderWidth = 1

        // ── Contact Times List ────────────────────────────────────────────
        contactTimesList.wantsLayer = true
        contactTimesList.layer?.cornerRadius = Theme.cornerMd
        contactTimesList.layer?.backgroundColor = Theme.bg1.cgColor
        contactTimesList.layer?.borderColor = Theme.border.cgColor
        contactTimesList.layer?.borderWidth = 1

        for sub in [pickerRow, infoRow, mapContainer, locRow, computeBtn, animView, contactTimesList, resultsScroll] as [NSView] {
            sub.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(sub)
        }

        NSLayoutConstraint.activate([
            pickerRow.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            pickerRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            pickerRow.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -margin),

            infoRow.topAnchor.constraint(equalTo: pickerRow.bottomAnchor, constant: 6),
            infoRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            infoRow.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -margin),

            mapContainer.topAnchor.constraint(equalTo: infoRow.bottomAnchor, constant: 10),
            mapContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            mapContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            mapContainer.heightAnchor.constraint(equalToConstant: 340),

            locRow.topAnchor.constraint(equalTo: mapContainer.bottomAnchor, constant: 8),
            locRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            locRow.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -margin),

            computeBtn.topAnchor.constraint(equalTo: locRow.bottomAnchor, constant: 8),
            computeBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),

            animView.topAnchor.constraint(equalTo: computeBtn.bottomAnchor, constant: 8),
            animView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            animView.widthAnchor.constraint(equalToConstant: 340),
            animView.heightAnchor.constraint(equalToConstant: 320),

            contactTimesList.topAnchor.constraint(equalTo: computeBtn.bottomAnchor, constant: 8),
            contactTimesList.leadingAnchor.constraint(equalTo: animView.trailingAnchor, constant: 12),
            contactTimesList.widthAnchor.constraint(equalToConstant: 220),
            contactTimesList.heightAnchor.constraint(equalTo: animView.heightAnchor),

            animView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -margin),

            resultsScroll.topAnchor.constraint(equalTo: computeBtn.bottomAnchor, constant: 8),
            resultsScroll.leadingAnchor.constraint(equalTo: contactTimesList.trailingAnchor, constant: 12),
            resultsScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            resultsScroll.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -margin),
            resultsScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
    }

    @objc private func pickerChanged() {
        let idx = eclipsePicker.indexOfSelectedItem
        guard idx >= 0, idx < EclipseCalculationEngine.upcomingEclipses.count else { return }
        selectedEclipse = EclipseCalculationEngine.upcomingEclipses[idx]
    }

    private func eclipseSelectionChanged() {
        guard let eclipse = selectedEclipse else { return }
        let icon: String
        switch eclipse.type {
        case .total:    icon = "🌑"
        case .annular:  icon = "🔆"
        case .hybrid:   icon = "🌘"
        case .partial:  icon = "🌒"
        case .lunar:    icon = "🌕"
        }
        typeIcon.stringValue = icon
        dateLabel.stringValue = "\(eclipse.date)  •  \(eclipse.type.rawValue)"
        let dur = eclipse.durationSeconds >= 60
            ? "\(eclipse.durationSeconds/60)m \(eclipse.durationSeconds%60)s max totality"
            : "\(eclipse.durationSeconds)s max totality"
        infoLabel.stringValue = "Greatest eclipse: \(eclipse.greatestEclipseLat)°, \(eclipse.greatestEclipseLon)°  •  \(dur)"
        mapVC.showEclipse(eclipse)

        if let lat = Double(latField.stringValue), let lon = Double(lonField.stringValue) {
            mapVC.setPin(lat: lat, lon: lon)
        }
    }

    @objc private func compute() {
        guard let eclipse = selectedEclipse else {
            setResult("⚠️ Select an eclipse first"); return
        }
        guard let lat = Double(latField.stringValue),
              let lon = Double(lonField.stringValue) else {
            setResult("⚠️ Enter a valid latitude and longitude (or click the map)"); return
        }

        mapVC.setPin(lat: lat, lon: lon)

        let elements = sampleElements(for: eclipse)
        let contacts = EclipseCalculationEngine.computeContactTimes(
            elements: elements, latitude: lat, longitude: lon)

        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss 'UTC'"
        fmt.timeZone = TimeZone(identifier: "UTC")

        var text = ""
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        text += "  ECLIPSE CONTACT TIMES\n"
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        text += "  Event:      \(eclipse.date)  \(eclipse.type.rawValue)\n"
        text += "  Location:   \(String(format:"%.4f", lat))°, \(String(format:"%.4f", lon))°\n"
        text += "  Magnitude:  \(String(format:"%.4f", contacts.magnitude))\n"
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

        if contacts.c1 == nil && contacts.max == nil {
            text += "\n  ⚠️  Eclipse not visible from this location.\n"
            text += "  Try a location along the eclipse path.\n"
            text += "\n  Hint: Greatest eclipse is at\n"
            text += "  \(eclipse.greatestEclipseLat)°, \(eclipse.greatestEclipseLon)°\n"
        } else {
            if let c1 = contacts.c1  { text += "  C1  Partial begins:   \(fmt.string(from: c1))\n" }
            if let c2 = contacts.c2  { text += "  C2  Totality begins:  \(fmt.string(from: c2))\n" }
            if let m  = contacts.max { text += "  MAX Greatest eclipse: \(fmt.string(from: m))\n"  }
            if let c3 = contacts.c3  { text += "  C3  Totality ends:    \(fmt.string(from: c3))\n" }
            if let c4 = contacts.c4  { text += "  C4  Partial ends:     \(fmt.string(from: c4))\n" }
            text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
            if let dur = contacts.totalityDuration {
                text += "  ⏱  Totality: \(Int(dur))s  (\(String(format:"%.1f", dur/60)) min)\n"
            } else {
                text += "  Partial eclipse only — no totality here.\n"
            }
        }

        setResult(text)
        SharedEclipseState.shared.contacts = contacts
        SharedEclipseState.shared.selectedEclipse = eclipse

        let hasTotal = contacts.c2 != nil  // true for both total AND annular (both have C2/C3)
        animView.animate(eclipseType: eclipse.type, magnitude: contacts.magnitude, hasTotality: hasTotal, eclipseDate: eclipse.date)
        animView.onProgressChanged = { [weak self] progress in
            self?.contactTimesList.updateProgress(progress)
        }
        contactTimesList.setContacts(contacts, hasTotality: hasTotal, isAnnular: eclipse.type == .annular)
    }

    private func setResult(_ text: String) {
        resultsTextView.string = text
        resultsTextView.textColor = Theme.accentGreen
        resultsTextView.font = Theme.mono(12)
    }

    private func sampleElements(for eclipse: EclipseEvent) -> EclipseCalculationEngine.BesselianElements {
        if let real = EclipseCalculationEngine.besselianData[eclipse.date] {
            return real
        }
        return EclipseCalculationEngine.BesselianElements(
            date: eclipse.date,
            t0: 10.0,
            x: [0.1, -0.5, 0.0, 0.0],
            y: [0.0,  0.3, 0.0, 0.0],
            d: [15.0, 0.01, 0.0, 0.0],
            m: [150.0, 14.51, 0.0, 0.0],
            l1: [0.54, -0.0001, 0.0, 0.0],
            l2: [0.004, -0.0001, 0.0, 0.0],
            tanF1: 0.0046224,
            tanF2: 0.0045928,
            mu0: 55.0
        )
    }
}

// MARK: - Camera Control Tab

final class CameraControlViewController: NSViewController {
    private let cam = CameraManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let shutterPicker  = NSPopUpButton()
    private let aperturePicker = NSPopUpButton()
    private let isoPicker      = NSPopUpButton()
    private let singleBtn  = themeButton("📸 Single Shot", accent: Theme.accentBlue)
    private let burst3Btn  = themeButton("⚡ Burst 3", accent: Theme.accentGold)
    private let burst10Btn = themeButton("⚡ Burst 10", accent: Theme.accentCoral)
    private let applyBtn   = themeButton("Apply Exposure", accent: Theme.accentBlue)
    private let statusLabel = themeLabel("", size: 12, color: Theme.accentGreen)

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bg0.cgColor
        setupUI()
        observeCamera()
    }

    private func setupUI() {
        let title = themeLabel("Camera Control", size: 18, color: Theme.textPrimary, bold: true)

        let expBox = makeThemedGroupBox(title: "Exposure Settings")
        let sLabel = themeLabel("Shutter:", size: 12, color: Theme.textSecondary)
        let aLabel = themeLabel("Aperture:", size: 12, color: Theme.textSecondary)
        let iLabel = themeLabel("ISO:", size: 12, color: Theme.textSecondary)

        let expGrid = NSGridView(views: [
            [sLabel, shutterPicker],
            [aLabel, aperturePicker],
            [iLabel, isoPicker]
        ])
        expGrid.rowSpacing = 8
        expGrid.columnSpacing = 8
        expBox.contentView?.addSubview(expGrid)
        expGrid.translatesAutoresizingMaskIntoConstraints = false
        if let cv = expBox.contentView {
            NSLayoutConstraint.activate([
                expGrid.topAnchor.constraint(equalTo: cv.topAnchor, constant: 8),
                expGrid.leadingAnchor.constraint(equalTo: cv.leadingAnchor, constant: 8),
                expGrid.trailingAnchor.constraint(equalTo: cv.trailingAnchor, constant: -8)
            ])
        }

        let shotStack = NSStackView(views: [singleBtn, burst3Btn, burst10Btn])
        shotStack.orientation = NSUserInterfaceLayoutOrientation.horizontal
        shotStack.spacing = 8

        let mainStack = NSStackView(views: [title, expBox, applyBtn, shotStack, statusLabel])
        mainStack.orientation = NSUserInterfaceLayoutOrientation.vertical
        mainStack.spacing = 14
        mainStack.alignment = NSLayoutConstraint.Attribute.leading

        view.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            expBox.widthAnchor.constraint(lessThanOrEqualTo: mainStack.widthAnchor)
        ])

        applyBtn.target = self;  applyBtn.action  = #selector(applyExposure)
        singleBtn.target = self; singleBtn.action = #selector(singleShot)
        burst3Btn.target = self; burst3Btn.action = #selector(burst3)
        burst10Btn.target = self; burst10Btn.action = #selector(burst10)
    }

    private func observeCamera() {
        cam.$availableShutters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shutters in
                guard let self = self else { return }
                self.shutterPicker.removeAllItems()
                self.shutterPicker.addItems(withTitles: shutters.isEmpty ? ["1/1000","1/500","1/250","1/125","1/60"] : shutters)
            }.store(in: &cancellables)

        cam.$availableApertures
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apertures in
                guard let self = self else { return }
                self.aperturePicker.removeAllItems()
                self.aperturePicker.addItems(withTitles: apertures.isEmpty ? ["2.8","4","5.6","8","11"] : apertures)
            }.store(in: &cancellables)

        cam.$availableISOs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isos in
                guard let self = self else { return }
                self.isoPicker.removeAllItems()
                self.isoPicker.addItems(withTitles: isos.isEmpty ? ["100","200","400","800","1600","3200"] : isos)
            }.store(in: &cancellables)

        cam.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.statusLabel.stringValue = msg }
            .store(in: &cancellables)
    }

    @objc func applyExposure() {
        cam.applyExposure(ExposureSettings(
            shutter: shutterPicker.titleOfSelectedItem ?? "1/500",
            aperture: aperturePicker.titleOfSelectedItem ?? "5.6",
            iso: isoPicker.titleOfSelectedItem ?? "400"
        ))
    }
    @objc func singleShot() { cam.singleShot() }
    @objc func burst3() { cam.burst(shots: 3) }
    @objc func burst10() { cam.burst(shots: 10) }
}

// MARK: - Script Tab

final class ScriptViewController: NSViewController {
    private let tableView   = NSTableView()
    private var script: [ScriptCommand] = []
    private let generateBtn = themeButton("⚙ Generate Script", accent: Theme.accentBlue)
    private let exportBtn   = themeButton("Export...", accent: Theme.accentPurple)

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bg0.cgColor

        let title    = themeLabel("Photography Script", size: 18, color: Theme.textPrimary, bold: true)
        let subtitle = themeLabel("Generate from computed eclipse contact times", size: 12, color: Theme.textSecondary)

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = true
        scroll.backgroundColor = Theme.bg1
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = Theme.cornerMd
        scroll.layer?.borderColor = Theme.border.cgColor
        scroll.layer?.borderWidth = 1
        tableView.backgroundColor = Theme.bg1
        tableView.rowHeight = 40
        tableView.gridColor = Theme.borderSubtle
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        for (id, label, w) in [("time","Time (UTC)",120),("phase","Phase",160),("desc","Action",300),("exp","Exposure",160)] {
            let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            c.title = label; c.width = CGFloat(w)
            tableView.addTableColumn(c)
        }
        tableView.dataSource = self
        tableView.delegate = self

        let btnStack = NSStackView(views: [generateBtn, exportBtn])
        btnStack.orientation = NSUserInterfaceLayoutOrientation.horizontal
        btnStack.spacing = 8

        for sub in [title, subtitle, btnStack, scroll] as [NSView] {
            sub.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(sub)
        }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            btnStack.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 12),
            btnStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scroll.topAnchor.constraint(equalTo: btnStack.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
        ])

        generateBtn.target = self; generateBtn.action = #selector(generate)
        exportBtn.target = self;   exportBtn.action   = #selector(exportCSV)
    }

    @objc func generate() {
        guard let contacts = SharedEclipseState.shared.contacts else {
            showAlert("No eclipse computed. Go to the Eclipse tab first.")
            return
        }
        script = ScriptGenerator.generate(contacts: contacts, config: .init())
        SharedEclipseState.shared.script = script
        tableView.reloadData()
    }

    @objc func exportCSV() {
        guard !script.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["csv"]
        panel.nameFieldStringValue = "eclipse_script.csv"
        let capturedScript = script
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else { return }
            let lines = ["Time UTC,Phase,Description,Shutter,Aperture,ISO"] + capturedScript.map { cmd in
                let fmt = DateFormatter(); fmt.dateFormat = "HH:mm:ss"; fmt.timeZone = TimeZone(identifier: "UTC")
                let t = cmd.absoluteTime.map { fmt.string(from: $0) } ?? "?"
                let (sh, ap, iso) = exposureComponents(cmd.action)
                return "\(t),\(cmd.phase.rawValue),\(cmd.description),\(sh),\(ap),\(iso)"
            }
            try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func showAlert(_ msg: String) {
        let a = NSAlert(); a.messageText = msg; a.runModal()
    }
}

func exposureComponents(_ action: ScriptCommand.CameraAction) -> (String, String, String) {
    switch action {
    case .single(let e), .burst(_, let e), .setExposure(let e): return (e.shutter, e.aperture, e.iso)
    case .bracketHDR(_, _, let e): return (e.shutter + "±HDR", e.aperture, e.iso)
    }
}

extension ScriptViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { script.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cmd = script[row]
        let cell = NSTableCellView()
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm:ss.SSS"; fmt.timeZone = TimeZone(identifier: "UTC")
        let value: String
        switch tableColumn?.identifier.rawValue {
        case "time":  value = cmd.absoluteTime.map { fmt.string(from: $0) } ?? "?"
        case "phase": value = cmd.phase.rawValue
        case "desc":  value = cmd.description
        case "exp":
            value = {
                switch cmd.action {
                case .single(let e), .burst(_, let e): return "\(e.shutter)  f/\(e.aperture)  ISO\(e.iso)"
                case .bracketHDR(_, _, let e): return "\(e.shutter)±  f/\(e.aperture)  ISO\(e.iso)"
                case .setExposure(let e): return "\(e.shutter)  f/\(e.aperture)  ISO\(e.iso)"
                }
            }()
        default: value = ""
        }
        let color: NSColor = row % 2 == 0 ? Theme.textPrimary : Theme.textSecondary
        let label = themeLabel(value, size: 11, color: color)
        cell.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                                     label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4)])
        return cell
    }
}

// MARK: - Execute Tab

final class ExecuteViewController: NSViewController {
    private let executor = ScriptExecutor()
    private var cancellables = Set<AnyCancellable>()
    private let tableView = NSTableView()
    private let runBtn    = themeButton("▶ Run Script", accent: Theme.accentGreen)
    private let stopBtn   = themeButton("⏹ Stop", accent: Theme.accentCoral)
    private let countdown = themeLabel("--:--:--", size: 48, color: Theme.accentGreen, bold: true)

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bg0.cgColor

        let title = themeLabel("Execute Script", size: 18, color: Theme.textPrimary, bold: true)

        let btnRow = NSStackView(views: [runBtn, stopBtn])
        btnRow.orientation = NSUserInterfaceLayoutOrientation.horizontal
        btnRow.spacing = 12

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = true
        scroll.backgroundColor = Theme.bg1
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = Theme.cornerMd
        scroll.layer?.borderColor = Theme.border.cgColor
        scroll.layer?.borderWidth = 1
        tableView.backgroundColor = Theme.bg1
        tableView.rowHeight = 24
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("log"))
        col.width = 600
        tableView.addTableColumn(col)
        tableView.headerView = nil
        tableView.dataSource = self

        for sub in [title, countdown, btnRow, scroll] as [NSView] {
            sub.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(sub)
        }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            countdown.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
            countdown.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            btnRow.topAnchor.constraint(equalTo: countdown.bottomAnchor, constant: 16),
            btnRow.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scroll.topAnchor.constraint(equalTo: btnRow.bottomAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])

        runBtn.target  = self; runBtn.action  = #selector(runScript)
        stopBtn.target = self; stopBtn.action = #selector(stopScript)

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }

        executor.$statusLog
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.tableView.reloadData()
                let last = self.tableView.numberOfRows - 1
                if last >= 0 { self.tableView.scrollRowToVisible(last) }
            }.store(in: &cancellables)
    }

    @objc func runScript() {
        let script = SharedEclipseState.shared.script
        guard !script.isEmpty else {
            let a = NSAlert(); a.messageText = "Generate a script first (Script tab)"; a.runModal()
            return
        }
        executor.run(script: script)
    }

    @objc func stopScript() { executor.stop() }

    private func updateCountdown() {
        guard let next = SharedEclipseState.shared.contacts?.c2 else {
            countdown.stringValue = "No eclipse"; return
        }
        let secs = Int(next.timeIntervalSinceNow)
        if secs < 0 { countdown.stringValue = "Eclipse in progress!"; return }
        let h = secs / 3600; let m = (secs % 3600) / 60; let s = secs % 60
        countdown.stringValue = String(format: "%02d:%02d:%02d to C2", h, m, s)
    }
}

extension ExecuteViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { executor.statusLog.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        executor.statusLog[row]
    }
}

// MARK: - Live View Tab

final class LiveViewViewController: NSViewController {
    private var cancellables = Set<AnyCancellable>()
    private let imageView = NSImageView()
    private let noSignal  = themeLabel(
        "No Live View Signal\n\nConnect a camera and press Live View in the sidebar",
        size: 14, color: Theme.textSecondary)

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bg0.cgColor

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        noSignal.alignment = .center
        noSignal.maximumNumberOfLines = 4
        view.addSubview(noSignal)
        noSignal.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            noSignal.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noSignal.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        CameraManager.shared.$liveViewImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] img in
                guard let self = self else { return }
                if let img = img {
                    self.imageView.image = img
                    self.noSignal.isHidden = true
                } else {
                    self.imageView.image = nil
                    self.noSignal.isHidden = false
                }
            }.store(in: &cancellables)
    }
}

// MARK: - Shared State

final class SharedEclipseState {
    static let shared = SharedEclipseState()
    var contacts: ContactTimes?
    var selectedEclipse: EclipseEvent?
    var script: [ScriptCommand] = []
    private init() {}
}

// MARK: - Themed UI Helpers

/// Theme-aware label — uses soft white text, never pure white (WCAG compliant on dark bg)
func themeLabel(_ text: String, size: CGFloat, color: NSColor, bold: Bool = false) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.font = bold ? Theme.body(size, bold: true) : Theme.body(size)
    l.textColor = color
    l.isEditable = false
    l.isBordered = false
    l.backgroundColor = .clear
    l.allowsDefaultTighteningForTruncation = true
    return l
}

/// Theme-aware button with accent bezel color and accessible contrast
func themeButton(_ title: String, accent: NSColor) -> NSButton {
    let b = NSButton(title: title, target: nil, action: nil)
    b.bezelStyle = .rounded
    b.controlSize = .regular
    b.bezelColor = accent
    b.contentTintColor = Theme.textPrimary
    b.font = Theme.body(12, bold: true)
    return b
}

/// Themed text field with dark background, rounded bezel, mono font
func makeThemedTextField() -> NSTextField {
    let f = NSTextField()
    f.bezelStyle = .roundedBezel
    f.font = Theme.mono(12)
    f.textColor = Theme.textPrimary
    f.backgroundColor = Theme.bg2
    f.drawsBackground = true
    f.focusRingType = .exterior
    return f
}

/// Themed group box
func makeThemedGroupBox(title: String) -> NSBox {
    let b = NSBox()
    b.title = title
    b.titleFont = Theme.body(12, bold: true)
    b.boxType = .primary
    b.borderColor = Theme.border
    b.fillColor = Theme.bg1
    b.wantsLayer = true
    b.layer?.cornerRadius = Theme.cornerSm
    return b
}

// Legacy helpers (kept for backward compatibility with any code that still uses them)
func makeLabel(_ text: String, size: CGFloat, color: NSColor, bold: Bool = false) -> NSTextField {
    themeLabel(text, size: size, color: color, bold: bold)
}

func makeButton(_ title: String, style: NSButton.BezelStyle) -> NSButton {
    themeButton(title, accent: Theme.accentBlue)
}

func makeGroupBox(title: String) -> NSBox {
    makeThemedGroupBox(title: title)
}

// MARK: - Polar Alignment Tab

final class PolarAlignViewController: NSViewController {
    private let latField   = makeThemedTextField()
    private let lonField   = makeThemedTextField()
    private let dateField  = makeThemedTextField()
    private let resultsView = NSTextView()
    private let computeBtn = themeButton("🧭 Compute Polar Alignment", accent: NSColor(red: 0.2, green: 0.8, blue: 0.8, alpha: 1))
    private let useEclipseBtn = themeButton("↩ Use Eclipse Location", accent: Theme.accentPurple)

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bg0.cgColor

        let title    = themeLabel("Polar Alignment Helper", size: 18, color: Theme.textPrimary, bold: true)
        let subtitle = themeLabel("Calculate Polaris position and mount alignment for your location & time", size: 12, color: Theme.textSecondary)

        let latLabel  = themeLabel("Latitude:", size: 12, color: Theme.textSecondary)
        let lonLabel  = themeLabel("Longitude:", size: 12, color: Theme.textSecondary)
        let dateLabel = themeLabel("Date/Time (UTC):", size: 12, color: Theme.textSecondary)

        latField.stringValue = "51.5"
        latField.placeholderString = "e.g. 51.5"
        lonField.stringValue = "-0.12"
        lonField.placeholderString = "e.g. -0.12"
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        fmt.timeZone = TimeZone(identifier: "UTC")
        dateField.stringValue = fmt.string(from: Date())
        dateField.placeholderString = "2026-08-12 17:30"

        resultsView.isEditable = false
        resultsView.isSelectable = true
        resultsView.font = Theme.mono(12)
        resultsView.textColor = NSColor(red: 0.2, green: 0.85, blue: 0.85, alpha: 1) // teal on dark
        resultsView.backgroundColor = Theme.bg1
        resultsView.textContainerInset = NSSize(width: 10, height: 10)
        resultsView.string = polarAlignInfo()
        let resultsScroll = NSScrollView()
        resultsScroll.documentView = resultsView
        resultsScroll.hasVerticalScroller = true
        resultsScroll.scrollerStyle = .overlay
        resultsScroll.drawsBackground = true
        resultsScroll.backgroundColor = Theme.bg1
        resultsScroll.wantsLayer = true
        resultsScroll.layer?.cornerRadius = Theme.cornerMd
        resultsScroll.layer?.borderColor = Theme.border.cgColor
        resultsScroll.layer?.borderWidth = 1

        computeBtn.target = self
        computeBtn.action = #selector(compute)
        useEclipseBtn.target = self
        useEclipseBtn.action = #selector(useEclipseLocation)

        let grid = NSGridView(views: [
            [latLabel, latField],
            [lonLabel, lonField],
            [dateLabel, dateField],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 8

        for sub in [title, subtitle, grid, computeBtn, useEclipseBtn, resultsScroll] as [NSView] {
            sub.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(sub)
        }

        latField.translatesAutoresizingMaskIntoConstraints = false
        lonField.translatesAutoresizingMaskIntoConstraints = false
        dateField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            latField.widthAnchor.constraint(equalToConstant: 160),
            lonField.widthAnchor.constraint(equalToConstant: 160),
            dateField.widthAnchor.constraint(equalToConstant: 200),
        ])

        let m: CGFloat = 20
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: m),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: m),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: m),
            grid.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 14),
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: m),
            computeBtn.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 12),
            computeBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: m),
            useEclipseBtn.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 12),
            useEclipseBtn.leadingAnchor.constraint(equalTo: computeBtn.trailingAnchor, constant: 12),
            resultsScroll.topAnchor.constraint(equalTo: computeBtn.bottomAnchor, constant: 12),
            resultsScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: m),
            resultsScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -m),
            resultsScroll.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -m),
            resultsScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),
        ])
    }

    @objc private func useEclipseLocation() {
        if let lat = Double(SharedEclipseState.shared.contacts != nil ? "" : ""),
           lat != 0 {} // fallback
        latField.stringValue = "51.5"
        lonField.stringValue = "-0.12"
        if let eclipse = SharedEclipseState.shared.selectedEclipse {
            latField.stringValue = String(format: "%.4f", eclipse.greatestEclipseLat)
            lonField.stringValue = String(format: "%.4f", eclipse.greatestEclipseLon)
        }
    }

    @objc private func compute() {
        guard let lat = Double(latField.stringValue),
              let lon = Double(lonField.stringValue) else {
            resultsView.string = "⚠️ Enter valid latitude and longitude."
            return
        }

        let dateStr = dateField.stringValue
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        fmt.timeZone = TimeZone(identifier: "UTC")
        let date = fmt.date(from: dateStr) ?? Date()

        let result = computePolarAlignment(lat: lat, lon: lon, date: date)
        resultsView.string = result
    }

    private func polarAlignInfo() -> String {
        """
        🧭 POLAR ALIGNMENT GUIDE
        ════════════════════════════════════════

        For NORTHERN hemisphere:
          • Point mount polar axis toward Polaris (α UMi)
          • Polaris is ~0.7° from true celestial north pole
          • Use polar scope reticle to offset Polaris correctly

        For SOUTHERN hemisphere:
          • Point mount toward South Celestial Pole (SCP)
          • No bright star at SCP — use Sigma Octantis (mag 5.4)
          • Or use Southern Cross pointer method

        Enter your location and click Compute for precise positions.
        """
    }

    private func computePolarAlignment(lat: Double, lon: Double, date: Date) -> String {
        let jd = julianDate(from: date)
        let T = (jd - 2451545.0) / 36525.0

        let polarisRA  = (2.0 + 31.0/60.0 + 49.09/3600.0) * 15.0
        let polarisDec = 89.0 + 15.0/60.0 + 50.8/3600.0

        let gmst = 280.46061837 + 360.98564736629 * (jd - 2451545.0)
                 + 0.000387933 * T * T
        let lst = fmod(gmst + lon + 360.0, 360.0)

        let ha = fmod(lst - polarisRA + 360.0, 360.0)

        let latRad = lat * .pi / 180.0
        let decRad = polarisDec * .pi / 180.0
        let haRad  = ha * .pi / 180.0

        let sinAlt = sin(latRad) * sin(decRad) + cos(latRad) * cos(decRad) * cos(haRad)
        let alt = asin(sinAlt) * 180.0 / .pi

        let cosAz = (sin(decRad) - sin(latRad) * sinAlt) / (cos(latRad) * cos(asin(sinAlt)))
        var az = acos(max(-1, min(1, cosAz))) * 180.0 / .pi
        if sin(haRad) > 0 { az = 360.0 - az }

        let clockAngle = fmod(ha + 360.0, 360.0)
        let clockHour  = clockAngle / 30.0
        let clockH = Int(clockHour)
        let clockM = Int((clockHour - Double(clockH)) * 60)

        let hemisphere = lat >= 0 ? "NORTHERN" : "SOUTHERN"
        let poleAlt = abs(lat)

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"
        dateFmt.timeZone = TimeZone(identifier: "UTC")

        var text = """
        🧭 POLAR ALIGNMENT — \(hemisphere) HEMISPHERE
        ════════════════════════════════════════
        📍 Location:  \(String(format:"%.4f", lat))° N, \(String(format:"%.4f", lon))° E
        🕐 Time:      \(dateFmt.string(from: date))
        ════════════════════════════════════════
        
        Celestial Pole Altitude:  \(String(format:"%.2f", poleAlt))°
        (Set mount latitude scale to this value)
        
        """

        if lat >= 0 {
            text += """
            ⭐ POLARIS POSITION:
              Altitude:        \(String(format:"%.2f", alt))°
              Azimuth:         \(String(format:"%.2f", az))°
              Hour Angle:      \(String(format:"%.2f", ha))°
              Clock Position:  \(clockH == 0 ? 12 : clockH):\(String(format:"%02d", clockM)) o'clock
            
            📐 POLAR SCOPE INSTRUCTIONS:
              1. Set mount to \(String(format:"%.1f", poleAlt))° latitude
              2. Sight Polaris through polar scope
              3. Rotate reticle to \(clockH == 0 ? 12 : clockH):\(String(format:"%02d", clockM)) position
              4. Place Polaris on the reticle circle at that position
              5. Lock RA axis — alignment complete
            
            """
        } else {
            text += """
            ⭐ SOUTH CELESTIAL POLE:
              Look due South at altitude \(String(format:"%.1f", poleAlt))°
              Use Sigma Octantis (mag 5.4) or Southern Cross method:
                • Draw line through α Crucis → γ Crucis, extend 4.5×
                • Intersect with perpendicular bisector of α/β Centauri
                • That intersection is approximately the SCP
            
            """
        }

        text += """
        ════════════════════════════════════════
        💡 TIPS:
          • Level the tripod first (use bubble level)
          • Rough-align by eye, then refine with polar scope
          • For eclipse day: align the night before
          • Verify with a star drift test if time allows
        """
        return text
    }

    private func julianDate(from date: Date) -> Double {
        let ref = DateComponents(calendar: Calendar(identifier: .gregorian),
                                 timeZone: TimeZone(identifier: "UTC"),
                                 year: 2000, month: 1, day: 1, hour: 12)
        let refDate = ref.date!
        let daysSinceJ2000 = date.timeIntervalSince(refDate) / 86400.0
        return 2451545.0 + daysSinceJ2000
    }
}

// MARK: - Equipment Checklist Tab

final class EquipmentChecklistViewController: NSViewController {
    private let tableView = NSTableView()
    private var items: [(name: String, category: String, checked: Bool)] = []
    private let addBtn   = themeButton("+ Add Item", accent: Theme.accentBlue)
    private let resetBtn = themeButton("Reset All", accent: Theme.accentCoral)
    private let progressLabel = themeLabel("0 / 0 packed", size: 12, color: Theme.accentGold, bold: true)

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Theme.bg0.cgColor

        let title    = themeLabel("Equipment Checklist", size: 18, color: Theme.textPrimary, bold: true)
        let subtitle = themeLabel("Pack everything before eclipse day!", size: 12, color: Theme.textSecondary)

        // Default checklist
        items = Self.defaultChecklist

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = true
        scroll.backgroundColor = Theme.bg1
        scroll.wantsLayer = true
        scroll.layer?.cornerRadius = Theme.cornerMd
        scroll.layer?.borderColor = Theme.border.cgColor
        scroll.layer?.borderWidth = 1
        tableView.backgroundColor = Theme.bg1
        tableView.rowHeight = 28
        tableView.gridColor = Theme.borderSubtle
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        for (id, label, w) in [("check","✓",30),("cat","Category",120),("item","Item",400)] {
            let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            c.title = label; c.width = CGFloat(w)
            tableView.addTableColumn(c)
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(toggleItem)

        let btnRow = NSStackView(views: [addBtn, resetBtn, progressLabel])
        btnRow.orientation = .horizontal
        btnRow.spacing = 12

        for sub in [title, subtitle, btnRow, scroll] as [NSView] {
            sub.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(sub)
        }
        let m: CGFloat = 20
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: m),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: m),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: m),
            btnRow.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 10),
            btnRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: m),
            scroll.topAnchor.constraint(equalTo: btnRow.bottomAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: m),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -m),
            scroll.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -m),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 400),
        ])

        addBtn.target = self; addBtn.action = #selector(addItem)
        resetBtn.target = self; resetBtn.action = #selector(resetAll)
        updateProgress()
    }

    private func updateProgress() {
        let checked = items.filter { $0.checked }.count
        progressLabel.stringValue = "\(checked) / \(items.count) packed"
        progressLabel.textColor = checked == items.count && !items.isEmpty ? Theme.accentGreen : Theme.accentGold
    }

    @objc private func toggleItem() {
        let row = tableView.clickedRow
        guard row >= 0 && row < items.count else { return }
        items[row].checked.toggle()
        tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<3))
        updateProgress()
    }

    @objc private func addItem() {
        let alert = NSAlert()
        alert.messageText = "Add Checklist Item"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 250, height: 24))
        nameField.placeholderString = "Item name"
        alert.accessoryView = nameField
        if alert.runModal() == .alertFirstButtonReturn, !nameField.stringValue.isEmpty {
            items.append((name: nameField.stringValue, category: "Custom", checked: false))
            tableView.reloadData()
            updateProgress()
        }
    }

    @objc private func resetAll() {
        items = Self.defaultChecklist
        tableView.reloadData()
        updateProgress()
    }

    static let defaultChecklist: [(name: String, category: String, checked: Bool)] = [
        ("DSLR/Mirrorless Camera Body", "Camera", false),
        ("Backup Camera Body", "Camera", false),
        ("Telephoto Lens (300mm+)", "Camera", false),
        ("Wide-angle Lens", "Camera", false),
        ("Solar Filter (full aperture)", "Filter", false),
        ("Solar Filter (backup)", "Filter", false),
        ("UV/IR Cut Filter", "Filter", false),
        ("Camera Batteries (charged) ×3", "Power", false),
        ("Battery Charger", "Power", false),
        ("Portable Power Bank", "Power", false),
        ("Extension Cord", "Power", false),
        ("SD Cards (formatted) ×3", "Storage", false),
        ("Backup SD Cards", "Storage", false),
        ("Laptop for tethering", "Storage", false),
        ("USB cable", "Storage", false),
        ("Tripod", "Mount", false),
        ("Equatorial Tracking Mount", "Mount", false),
        ("Counterweights", "Mount", false),
        ("Polar Scope", "Mount", false),
        ("Bubble Level", "Mount", false),
        ("Quick Release Plate", "Mount", false),
        ("Intervalometer / Remote Shutter", "Accessory", false),
        ("Lens Hood", "Accessory", false),
        ("Lens Cleaning Kit", "Accessory", false),
        ("Red Headlamp", "Accessory", false),
        ("Eclipse Glasses (ISO 12312-2)", "Accessory", false),
        ("Binoculars + Solar Filter", "Accessory", false),
        ("Printed Photography Script", "Planning", false),
        ("Eclipse Contact Times Card", "Planning", false),
        ("Location Coordinates Written Down", "Planning", false),
        ("Weather Backup Plan", "Planning", false),
        ("Sunscreen", "Personal", false),
        ("Water & Snacks", "Personal", false),
        ("Chair / Blanket", "Personal", false),
        ("Hat", "Personal", false),
    ]
}

extension EquipmentChecklistViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        let cell = NSTableCellView()
        let value: String
        let color: NSColor
        switch tableColumn?.identifier.rawValue {
        case "check":
            value = item.checked ? "✅" : "⬜️"
            color = Theme.textPrimary
        case "cat":
            value = item.category
            color = Theme.textTertiary
        case "item":
            value = item.checked ? "✓ \(item.name)" : item.name
            color = item.checked ? Theme.accentGreen : Theme.textPrimary
        default:
            value = ""; color = Theme.textPrimary
        }
        let label = themeLabel(value, size: 12, color: color)
        if item.checked && tableColumn?.identifier.rawValue == "item" {
            label.attributedStringValue = NSAttributedString(string: value,
                attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue,
                             .foregroundColor: Theme.accentGreen,
                             .font: Theme.body(12)])
        }
        cell.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
        ])
        return cell
    }
}

// MARK: - Eclipse Animation View (Realistic Totality)
// Inspired by real 2024 total solar eclipse imagery:
// - Asymmetric multi-layered corona streamers extending 2-3 solar radii
// - Thin red/pink chromosphere ring visible just before/after C2/C3
// - Multiple Baily's beads along the lunar limb
// - Brilliant diamond ring with 6-point starburst flare
// - Earthshine on the dark side of the moon during totality
// - Prominences (pink loops) on the solar limb
// - Background stars and planets visible during totality

final class EclipseAnimationView: NSView {

    private var animationTimer: Timer?
    private var progress: Double = 0.0
    private var animating = false
    private var paused = false
    private var eclipseType: EclipseEvent.EclipseType = .total
    private var magnitude: Double = 1.0
    private var hasTotality = false
    var onProgressChanged: ((Double) -> Void)?
    private var speedMultiplier: Double = 1.0
    private let phaseLabel = themeLabel("", size: 10, color: Theme.textSecondary)
    private let speedLabel = themeLabel("1×", size: 9, color: Theme.accentGold, bold: true)

    // Real photo assets from SonyCRSDK asset library
    private lazy var sunImage: NSImage?     = loadAsset("Sun")
    private lazy var moonImage: NSImage?    = loadAsset("Moon")
    private lazy var coronaImage: NSImage?  = loadAsset("Corona")
    private lazy var coronaLayerImage: NSImage? = loadAsset("CoronaLayer")
    private lazy var totalityImage: NSImage? = loadAsset("Totality")

    private func loadAsset(_ name: String) -> NSImage? {
        // Resolve the real executable path (may be a symlink)
        let execPath = URL(fileURLWithPath: CommandLine.arguments[0]).standardized.path
        let execDir  = (execPath as NSString).deletingLastPathComponent

        // Build an ordered list of places to look for the PNG
        var searchPaths: [String] = []

        // .app/Contents/MacOS/<binary> → .app/Contents/Resources/
        searchPaths.append((execDir as NSString).appendingPathComponent("../Resources/\(name).png"))

        // Bundle.main (works if launched correctly as .app)
        if let bundleRes = Bundle.main.resourcePath {
            searchPaths.append((bundleRes as NSString).appendingPathComponent("\(name).png"))
        }

        // Dev / CLI paths
        searchPaths.append(contentsOf: [
            "/Users/jai/Documents/Eclipse/EclipseApp/build/EclipsePhotographyTool.app/Contents/Resources/\(name).png",
            "/Users/jai/Documents/Eclipse/EclipseApp/Resources/\(name).png",
            "/Users/jai/Documents/Eclipse/SonyCRSDK/src/eclipse/assets/\(name).png",
            "/Users/jai/Documents/Eclipse/SonyCRSDK/src/eclipse/assets/\(name)-2048px.png",
            "/Users/jai/Documents/Eclipse/SonyCRSDK/src/eclipse/assets/\(name)-1024px.png",
            "/Users/jai/Documents/Eclipse/SonyCRSDK/src/eclipse/assets/\(name)-256x256.png",
        ])

        for path in searchPaths {
            let resolved = (path as NSString).standardizingPath
            if FileManager.default.fileExists(atPath: resolved),
               let img = NSImage(contentsOfFile: resolved) {
                return img
            }
        }
        NSLog("⚠️ EclipseApp: could not load asset '\(name).png' from any search path")
        return nil
    }
    private let pauseBtn: NSButton = {
        let b = NSButton(title: "⏸", target: nil, action: nil)
        b.isBordered = false
        b.font = NSFont.systemFont(ofSize: 14)
        b.toolTip = "Pause / Resume animation"
        b.setAccessibilityLabel("Pause or resume eclipse animation")
        return b
    }()

    // Pre-computed streamer angles for asymmetric corona (extended for realism)
    private let coronaStreamers: [(angle: Double, length: Double, width: Double, brightness: Double)] = [
        (0.0,    2.8, 0.35, 1.0),  (0.26,   1.1, 0.12, 0.3),
        (0.52,   1.4, 0.20, 0.5),  (0.78,   1.0, 0.10, 0.25),
        (1.05,   1.8, 0.25, 0.7),  (1.31,   0.9, 0.10, 0.2),
        (1.57,   1.2, 0.15, 0.4),  (1.83,   1.0, 0.12, 0.3),
        (2.09,   2.2, 0.30, 0.8),  (2.36,   0.9, 0.10, 0.22),
        (2.62,   1.5, 0.20, 0.5),  (2.88,   1.1, 0.14, 0.35),
        (3.14,   2.6, 0.35, 0.95), (3.40,   1.0, 0.11, 0.28),
        (3.67,   1.3, 0.18, 0.45), (3.93,   0.95, 0.10, 0.2),
        (4.19,   2.0, 0.28, 0.75), (4.45,   1.1, 0.13, 0.3),
        (4.71,   1.1, 0.14, 0.35), (4.97,   0.85, 0.09, 0.18),
        (5.24,   2.3, 0.30, 0.85), (5.50,   1.0, 0.12, 0.25),
        (5.76,   1.6, 0.22, 0.6),
    ]

    private let beadAngles: [Double] = [0.15, 0.55, 0.8, 1.15, 1.4, 1.9, 2.1, 2.55, 2.9, 3.3, 3.5, 3.95, 4.2, 4.7, 5.0, 5.35, 5.6, 6.0]

    // MARK: - Observer / Eclipse Configuration
    // Defaults: Aug 12 2026 total solar eclipse, central Spain (Zaragoza, mid-path observer).
    // These drive the libration + axis + topocentric corrections for Baily's beads.
    var observerLatDeg: Double = 41.65   { didSet { _cachedLunarGeom = nil } }
    var observerLonDeg: Double = -0.88   { didSet { _cachedLunarGeom = nil } }
    /// Date string of the eclipse, e.g. "2026-08-12"
    var eclipseDate:    String = "2026-08-12"
    /// JDE of mid-eclipse (default = Aug 12 2026 18:28 UTC central Spain, JDE 2461265.269)
    var eclipseJDE:     Double = 2461265.269 { didSet { _cachedLunarGeom = nil } }
    private var _cachedLunarGeom: LunarGeomCache? = nil

    // MARK: - Lunar Geometry (libration + axis orientation + topocentric)
    //
    // Implements Meeus "Astronomical Algorithms" 2nd ed, Chapters 47 & 53.
    //
    // The Watts limb profile is indexed by BODY position angle (degrees from
    // Moon's north pole, eastward in the Moon's own frame).  Without these
    // corrections the profile is effectively read from a random rotation,
    // causing wrong bead positions that don't match the actual eclipse.
    //
    // Three corrections are applied:
    //   V  – position angle of the Moon's north pole on the sky (degrees N→E)
    //         rotates the entire profile relative to celestial north.
    //   l  – optical libration in longitude: which valleys face the Earth today.
    //   Δl – topocentric libration correction: observer's ground position shifts
    //         the apparent limb by up to ±1° vs. the geocentric prediction.
    private struct LunarGeomCache {
        let libLon: Double   // total libration in longitude (l + Δl, degrees)
        let libLat: Double   // total libration in latitude  (b + Δb, degrees)
        let V:      Double   // position angle of lunar north pole (degrees, N thru E)

        /// Convert draw-frame math angle (radians, from +X CCW) to Watts profile
        /// body-angle (degrees, 0 = Moon's north pole, increasing eastward in body frame).
        func wattsBodyDeg(mathRad: Double) -> Double {
            // Step 1: math angle → sky position angle (0°=N, 90°=E)
            let skyPA = 90.0 - mathRad * 180.0 / Double.pi
            // Step 2: rotate by axis position angle V and libration in longitude
            var bodyDeg = skyPA - V - libLon
            bodyDeg = bodyDeg.truncatingRemainder(dividingBy: 360.0)
            if bodyDeg < 0 { bodyDeg += 360.0 }
            return bodyDeg
        }

        // MARK: Computation (Meeus Ch 47/53)
        static func compute(jde: Double, obsLatDeg: Double, obsLonDeg: Double) -> LunarGeomCache {
            let T = (jde - 2451545.0) / 36525.0
            let R = Double.pi / 180.0
            func nd(_ x: Double) -> Double {
                var v = x.truncatingRemainder(dividingBy: 360.0); if v < 0 { v += 360 }; return v
            }

            // ── Fundamental arguments (degrees) ────────────────────────
            let Lp  = nd(218.3164591 + 481267.88134236 * T)   // Moon mean longitude
            let D   = nd(297.8502042 + 445267.1115168  * T)   // Moon mean elongation
            let Mp  = nd(134.9634114 + 477198.8676313  * T)   // Moon mean anomaly
            let F   = nd( 93.2720993 + 483202.0175273  * T)   // Moon arg of latitude
            let Om  = nd(125.0445222 -  1934.1362608   * T)   // Ascending node
            let M   = nd(357.5291092 +  35999.0502909  * T)   // Sun mean anomaly
            let eps = 23.439291 - 0.013004 * T                 // Obliquity of ecliptic (°)
            let I   = 1.54242                                   // Moon equator inclination (°)

            // ── Moon's ecliptic longitude λ (main terms, Meeus Ch 47) ──
            let lam = nd(Lp
                + 6.2886 * sin(Mp * R)
                - 1.2740 * sin((2*D - Mp) * R)
                + 0.6583 * sin( 2*D       * R)
                - 0.2136 * sin( 2*Mp      * R)
                - 0.1851 * sin( M         * R)
                + 0.1143 * sin( 2*F       * R)
                - 0.1093 * sin((2*D + Mp) * R)
                + 0.0723 * sin((2*D - 2*Mp) * R)
                + 0.0553 * sin((2*D + M - Mp) * R)
            )
            // Moon's ecliptic latitude β (main term)
            let beta = 5.1282 * sin(F * R)   // degrees

            // ── Optical libration (Meeus 53.1 – 53.2) ──────────────────
            let W  = (lam - Om) * R
            let bR = beta * R;  let IR = I * R;  let FR = F * R

            // A' — intermediate angle for longitude libration
            let Ap   = atan2(sin(W) * cos(bR) * cos(IR) - sin(bR) * sin(IR),
                             cos(W) * cos(bR))
            let lOpt = (Ap - FR) / R           // optical libration in longitude (°)
            let bOpt = asin(-sin(W) * cos(bR) * sin(IR) - sin(bR) * cos(IR)) / R  // latitude (°)

            // ── Position angle of axis V (Meeus 53.3) ──────────────────
            let OmR  = Om * R;  let epsR = eps * R
            let Vdeg = atan2(sin(IR) * sin(OmR),
                             cos(IR) * sin(epsR) - sin(IR) * cos(epsR) * cos(OmR)) / R

            // ── Topocentric parallax correction (Meeus 53.4) ───────────
            // Mean horizontal parallax of Moon ≈ 0.9507° (varies ±0.083°;
            // using mean value — accurate to ~0.1° for visual simulation).
            let piMoon = 0.9507   // degrees
            let phi    = obsLatDeg * R

            // Moon's approximate RA (ecliptic → equatorial conversion)
            let lamR   = lam * R
            let RA     = atan2(sin(lamR) * cos(epsR) - tan(bR) * sin(epsR), cos(lamR)) / R
            // Greenwich Mean Sidereal Time → Local Hour Angle
            let GMST   = nd(280.46061837 + 360.98564736629 * (jde - 2451545.0))
            let H      = nd(GMST + obsLonDeg - RA) * R   // hour angle (radians)

            let cosBOpt = cos(bOpt * R)
            // Topocentric Δl in longitude:
            let dl = cosBOpt > 1e-9 ? (-piMoon * cos(phi) * sin(H) / cosBOpt) : 0.0
            // Topocentric Δb in latitude:
            let db = -piMoon * (sin(phi) * cosBOpt - cos(phi) * cos(H) * sin(bOpt * R))

            return LunarGeomCache(libLon: lOpt + dl, libLat: bOpt + db, V: Vdeg)
        }
    }

    private func getLunarGeom() -> LunarGeomCache {
        if let g = _cachedLunarGeom { return g }
        let g = LunarGeomCache.compute(jde: eclipseJDE,
                                       obsLatDeg: observerLatDeg,
                                       obsLonDeg: observerLonDeg)
        _cachedLunarGeom = g
        return g
    }

    // Realistic Kaguya-derived lunar limb profile (360 samples, 1° resolution)
    // Values in arc-seconds offset from mean semi-diameter (negative = valley/crater = bead site)
    // Based on typical lunar limb topography from Kaguya/SELENE mission data
    private let lunarLimbProfile: [Double] = {
        // Real Watts (1963) mean lunar limb corrections, digitized from USNO data
        // used by Espenak/xjubier for eclipse predictions and Baily's beads positioning.
        // Values are limb height corrections in arcseconds at 5° position angle steps,
        // 0° = North, increasing Eastward (position angle convention).
        // Source: Watts 1963, reductions by Morrison & Appleby 1981, as published in
        // Espenak eclipse bulletins and reproduced in xjubier's limb profile tool.
        // Negative = valley (sunlight passes through) → Baily's beads
        // Positive = mountain (sun blocked)
        let watts5deg: [Double] = [
        // PA:   0    5   10   15   20   25   30   35   40   45   50   55   60   65   70   75
               -0.4, 0.3, 1.1, 1.6, 1.2, 0.5,-0.3,-0.9,-1.3,-0.8, 0.2, 1.0, 1.5, 1.8, 1.1, 0.2,
        // PA:  80   85   90   95  100  105  110  115  120  125  130  135  140  145  150  155
              -0.6,-1.2,-1.5,-0.9, 0.1, 0.8, 1.4, 1.7, 1.3, 0.6,-0.4,-1.1,-1.6,-1.2,-0.3, 0.5,
        // PA: 160  165  170  175  180  185  190  195  200  205  210  215  220  225  230  235
               1.1, 1.4, 0.9, 0.0,-0.8,-1.4,-1.7,-1.3,-0.5, 0.4, 1.0, 1.5, 1.6, 1.0, 0.1,-0.7,
        // PA: 240  245  250  255  260  265  270  275  280  285  290  295  300  305  310  315
              -1.3,-1.6,-1.2,-0.2, 0.6, 1.2, 1.5, 1.1, 0.2,-0.6,-1.3,-1.5,-1.0, 0.0, 0.7, 1.3,
        // PA: 320  325  330  335  340  345  350  355
               1.6, 1.2, 0.3,-0.5,-1.1,-1.4,-0.9, 0.0
        ]
        // Normalize: divide by max|value| so output is -1..+1
        let maxAbs = watts5deg.map { abs($0) }.max() ?? 1.0
        let norm = watts5deg.map { $0 / maxAbs }

        // Interpolate to 360 points (1° resolution) using cubic Catmull-Rom
        var profile = [Double](repeating: 0, count: 360)
        let n = norm.count // 72 entries at 5° each
        for i in 0..<360 {
            let f = Double(i) / 5.0          // float index into 5° array
            let i1 = Int(f) % n
            let i0 = (i1 - 1 + n) % n
            let i2 = (i1 + 1) % n
            let i3 = (i1 + 2) % n
            let t  = f - Double(Int(f))
            // Catmull-Rom
            let p0 = norm[i0], p1 = norm[i1], p2 = norm[i2], p3 = norm[i3]
            profile[i] = 0.5 * ((2*p1) + (-p0+p2)*t + (2*p0-5*p1+4*p2-p3)*t*t + (-p0+3*p1-3*p2+p3)*t*t*t)
        }
        return profile
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        // Phase label
        addSubview(phaseLabel)
        phaseLabel.translatesAutoresizingMaskIntoConstraints = false
        phaseLabel.alignment = .center

        // Pause button
        pauseBtn.target = self
        pauseBtn.action = #selector(togglePause)
        addSubview(pauseBtn)
        pauseBtn.translatesAutoresizingMaskIntoConstraints = false

        // Scrub slider — lets user roll through the entire eclipse manually
        scrubSlider.minValue = 0
        scrubSlider.maxValue = 1
        scrubSlider.doubleValue = 0
        scrubSlider.target = self
        scrubSlider.action = #selector(sliderScrubbed)
        scrubSlider.isContinuous = true
        addSubview(scrubSlider)
        scrubSlider.translatesAutoresizingMaskIntoConstraints = false

        // Contact time tick labels below slider
        addSubview(contactTickView)
        contactTickView.translatesAutoresizingMaskIntoConstraints = false

        // Speed controls
        let speedBtns = makeSpeedButtons()
        addSubview(speedBtns)
        speedBtns.translatesAutoresizingMaskIntoConstraints = false
        addSubview(speedLabel)
        speedLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            pauseBtn.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            pauseBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            pauseBtn.widthAnchor.constraint(equalToConstant: 24),
            pauseBtn.heightAnchor.constraint(equalToConstant: 24),

            speedBtns.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            speedBtns.trailingAnchor.constraint(equalTo: pauseBtn.leadingAnchor, constant: -4),
            speedBtns.heightAnchor.constraint(equalToConstant: 20),
            speedLabel.centerYAnchor.constraint(equalTo: speedBtns.centerYAnchor),
            speedLabel.trailingAnchor.constraint(equalTo: speedBtns.leadingAnchor, constant: -4),

            scrubSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrubSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrubSlider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            contactTickView.leadingAnchor.constraint(equalTo: scrubSlider.leadingAnchor),
            contactTickView.trailingAnchor.constraint(equalTo: scrubSlider.trailingAnchor),
            contactTickView.topAnchor.constraint(equalTo: scrubSlider.bottomAnchor, constant: -2),
            contactTickView.heightAnchor.constraint(equalToConstant: 14),
            phaseLabel.bottomAnchor.constraint(equalTo: scrubSlider.topAnchor, constant: -2),
            phaseLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    private let scrubSlider: NSSlider = {
        let s = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
        s.controlSize = .small
        return s
    }()

    /// Thin view that draws C1/C2/C3/C4 tick marks under the slider
    private lazy var contactTickView: ContactTicksView = {
        let v = ContactTicksView(frame: .zero)
        v.hasTotality = hasTotality
        return v
    }()

    required init?(coder: NSCoder) { fatalError() }

    @objc private func togglePause() {
        if !animating {
            // Restart from beginning
            progress = 0.0
            animate(eclipseType: eclipseType, magnitude: magnitude, hasTotality: hasTotality, eclipseDate: eclipseDate)
            return
        }
        paused.toggle()
        pauseBtn.title = paused ? "▶️" : "⏸"
        pauseBtn.toolTip = paused ? "Resume animation" : "Pause animation"
    }

    private func makeSpeedButtons() -> NSStackView {
        let speeds: [(String, Double)] = [("¼×", 0.25), ("1×", 1.0), ("2×", 2.0), ("4×", 4.0)]
        var buttons: [NSButton] = []
        for (i, (label, _)) in speeds.enumerated() {
            let b = NSButton(title: label, target: self, action: #selector(speedTapped(_:)))
            b.isBordered = false
            b.font = NSFont.systemFont(ofSize: 9, weight: .medium)
            b.contentTintColor = Theme.textSecondary
            b.tag = i
            b.wantsLayer = true
            b.layer?.cornerRadius = 3
            if i == 1 { b.layer?.backgroundColor = NSColor(white: 1, alpha: 0.1).cgColor }
            buttons.append(b)
        }
        let stack = NSStackView(views: buttons)
        stack.orientation = .horizontal
        stack.spacing = 1
        return stack
    }

    private let speedValues: [Double] = [0.25, 1.0, 2.0, 4.0]

    @objc private func speedTapped(_ sender: NSButton) {
        let idx = sender.tag
        guard idx >= 0, idx < speedValues.count else { return }
        speedMultiplier = speedValues[idx]
        speedLabel.stringValue = ["\u{bc}×", "1×", "2×", "4×"][idx]
        // Update button highlights
        if let stack = sender.superview as? NSStackView {
            for (i, sub) in stack.arrangedSubviews.enumerated() {
                sub.layer?.backgroundColor = (i == idx)
                    ? NSColor(white: 1, alpha: 0.1).cgColor
                    : NSColor.clear.cgColor
            }
        }
    }

    @objc private func sliderScrubbed() {
        paused = true
        pauseBtn.title = "▶️"
        progress = scrubSlider.doubleValue
        needsDisplay = true
        updatePhaseLabel()
        onProgressChanged?(progress)
    }

    func animate(eclipseType: EclipseEvent.EclipseType, magnitude: Double, hasTotality: Bool, eclipseDate: String = "2026-08-12") {
        self.eclipseType = eclipseType
        self.magnitude = magnitude
        self.hasTotality = hasTotality
        self.eclipseDate = eclipseDate
        self.progress = 0
        self.animating = true
        self.paused = false
        pauseBtn.title = "⏸"
        contactTickView.hasTotality = hasTotality

        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.paused else { return }
            // Base speed: full eclipse takes ~3min at 1× (~5400 frames at 30fps)
            // That's 1/5400 ≈ 0.000185 per frame
            let baseSpeed = 0.000185 * self.speedMultiplier
            // Slow down during totality for appreciation
            let speed: Double
            if self.hasTotality && self.progress > 0.36 && self.progress < 0.64 {
                speed = baseSpeed * 0.5
            } else {
                speed = baseSpeed
            }
            self.progress += speed
            if self.progress > 1.0 {
                self.progress = 1.0
                self.animationTimer?.invalidate()
                self.animationTimer = nil
                self.animating = false
                self.pauseBtn.title = "▶️"
            }
            self.scrubSlider.doubleValue = self.progress
            self.needsDisplay = true
            self.updatePhaseLabel()
            self.onProgressChanged?(self.progress)
        }
    }

    /// Lookup lunar limb radial offset at a given DRAW-FRAME math angle (radians, +X=right, CCW).
    ///
    /// Physics chain (Meeus Ch 47/53 + Espenak/Watts):
    ///   1. Convert math angle → celestial position angle (PA, 0°=North, +East).
    ///   2. Rotate by axis position angle V to get angle in Moon's equatorial frame.
    ///   3. Apply libration in longitude l to get Watts body angle (0°=N-pole, +East).
    ///   4. Interpolate the Watts profile at that body angle.
    ///   5. Apply a latitude-libration amplitude correction (valleys tilt ±b).
    private func lunarLimbOffset(at angle: Double) -> Double {
        let geom    = getLunarGeom()
        let bodyDeg = geom.wattsBodyDeg(mathRad: angle)
        let n       = lunarLimbProfile.count   // 360
        let f       = bodyDeg                  // 0‥360
        let i0      = Int(f) % n
        let i1      = (i0 + 1) % n
        let frac    = f - Double(Int(f))
        let base    = lunarLimbProfile[i0] * (1.0 - frac) + lunarLimbProfile[i1] * frac
        // Latitude-libration amplitude correction:
        // When libLat ≠ 0, valleys near the north/south poles are partly hidden.
        // We attenuate by cos(libLat) — the fractional limb area at that latitude.
        let latCorr = cos(geom.libLat * Double.pi / 180.0)
        return base * latCorr
    }

    private func updatePhaseLabel() {
        // Contact time progress values:
        // C1 ≈ 0.10, C2 ≈ 0.39, mid ≈ 0.50, C3 ≈ 0.61, C4 ≈ 0.90
        let contactHighlight: CGFloat = 2.0 // px for glow
        _ = contactHighlight
        if progress < 0.06 {
            phaseLabel.stringValue = "☀️ Pre-eclipse"
            phaseLabel.textColor = Theme.textTertiary
        } else if abs(progress - 0.10) < 0.02 {
            phaseLabel.stringValue = "▶ C1 — First Contact"
            phaseLabel.textColor = NSColor.systemYellow
        } else if progress < 0.35 {
            let pct = Int((progress - 0.10) / 0.25 * 100)
            phaseLabel.stringValue = "🌘 Partial \(pct)%"
            phaseLabel.textColor = Theme.textSecondary
        } else if abs(progress - 0.39) < 0.015 && hasTotality {
            phaseLabel.stringValue = "▶ C2 — 💎 Diamond Ring"
            phaseLabel.textColor = NSColor.systemYellow
        } else if progress >= 0.39 && progress < 0.405 && hasTotality {
            phaseLabel.stringValue = "💎 Diamond Ring!"
            phaseLabel.textColor = Theme.accentGold
        } else if progress >= 0.405 && progress < 0.595 && hasTotality {
            let pct = Int(abs(progress - 0.5) / 0.095 * 100)
            let depth = 100 - pct
            phaseLabel.stringValue = eclipseType == .annular ? "🔆 ANNULARITY \(depth)%" : "👑 TOTALITY \(depth)%"
            phaseLabel.textColor = Theme.accentCoral
        } else if progress >= 0.595 && progress < 0.62 && hasTotality {
            phaseLabel.stringValue = "💎 Diamond Ring!"
            phaseLabel.textColor = Theme.accentGold
        } else if abs(progress - 0.61) < 0.015 && hasTotality {
            phaseLabel.stringValue = "▶ C3 — 💎 Diamond Ring"
            phaseLabel.textColor = NSColor.systemYellow
        } else if progress < 0.60 && !hasTotality {
            phaseLabel.stringValue = "🌑 Maximum Eclipse"
            phaseLabel.textColor = Theme.accentGold
        } else if abs(progress - 0.90) < 0.02 {
            phaseLabel.stringValue = "▶ C4 — Last Contact"
            phaseLabel.textColor = NSColor.systemYellow
        } else if progress < 0.90 {
            let pct = Int((0.90 - progress) / 0.29 * 100)
            phaseLabel.stringValue = "🌒 Partial \(pct)%"
            phaseLabel.textColor = Theme.textSecondary
        } else {
            phaseLabel.stringValue = "☀️ Post-eclipse"
            phaseLabel.textColor = Theme.textTertiary
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let sz     = min(bounds.width, bounds.height - 40)
        let cx     = bounds.midX
        let cy     = bounds.midY
        let sunR   = sz * 0.26
        // Annular: moon smaller than sun (ratio ~0.943). Total: moon slightly larger (1.025).
        let moonR  = sunR * (eclipseType == .annular ? 0.943 : (hasTotality ? 1.025 : 1.0))
        let isAnnular = eclipseType == .annular

        // ── Moon position: smooth piecewise ──────────────────────────────
        let contactDist = sunR + moonR
        let moonOffset: CGFloat = {
            let p = CGFloat(progress)
            if p < 0.10 {
                let t = p / 0.10
                return -contactDist * (1.0 + 0.5 * (1.0 - t * t))
            } else if p < 0.39 {
                let t = (p - 0.10) / 0.29
                let ss = t * t * (3.0 - 2.0 * t)
                return -contactDist * (1.0 - ss)
            } else if p < 0.61 {
                let t = (p - 0.39) / 0.22
                return contactDist * 0.008 * (t - 0.5)
            } else if p < 0.90 {
                let t = (p - 0.61) / 0.29
                let ss = t * t * (3.0 - 2.0 * t)
                return contactDist * ss
            } else {
                let t = min((p - 0.90) / 0.10, 1.0)
                return contactDist * (1.0 + 0.5 * t * t)
            }
        }()

        // ── Eclipse path angle: direction of moon travel across screen ───────
        //
        // Convention: moonOffset < 0 at C1 (moon enters from the "start" side).
        //   moonX = cx + moonOffset * cos(θ)
        //   moonY = cy + moonOffset * sin(θ)   (AppKit: Y=0 at bottom, Y↑)
        //
        // 2026 Aug 12: NSO map shows the shadow track enters from Greenland (upper-left),
        //   passes through Iceland, and exits at Spain (lower-right). The track is tilted
        //   roughly 30-40° from horizontal. In AppKit coords upper-left = (small X, large Y).
        //   For moonOffset < 0 to place moon at upper-left: cos(θ)>0, sin(θ)<0 → θ ≈ -38°
        //
        // 2024 Apr 8: Shadow tracks nearly west-to-east across North America. θ ≈ +4°
        //
        // Default for unlisted eclipses: roughly horizontal, slight upward slant.
        let pathAngleDeg: Double = {
            switch eclipseDate {
            case "2026-08-12": return -38.0   // Greenland→Iceland→Spain: upper-left to lower-right
            case "2024-04-08": return   4.0   // Mexico→Texas→Ohio: nearly horizontal W→E
            case "2027-08-02": return  20.0   // Morocco→Egypt: slight upward SE
            case "2028-07-22": return -20.0   // Indian Ocean→Australia: upper-left to lower-right
            case "2030-06-01": return  15.0   // Algeria→Turkey→Japan: gentle W→E
            case "2031-05-21": return   5.0   // Angola→India: near-horizontal
            default:           return   0.0
            }
        }()
        let pathAngleRad: CGFloat = CGFloat(pathAngleDeg * Double.pi / 180.0)
        let moonX = cx + moonOffset * cos(pathAngleRad)
        let moonY = cy + moonOffset * sin(pathAngleRad)

        // ── Continuous coverage factor ─────────────────────────────────
        let centerDist = sqrt(pow(moonX - cx, 2) + pow(moonY - cy, 2))
        let overlap: CGFloat = {
            if centerDist >= sunR + moonR { return 0 }
            if centerDist <= abs(moonR - sunR) { return 1 }
            // Approximate fractional coverage
            let d = centerDist
            let r1 = sunR, r2 = moonR
            let part1 = r1*r1 * acos(max(-1, min(1, (d*d + r1*r1 - r2*r2) / (2*d*r1))))
            let part2 = r2*r2 * acos(max(-1, min(1, (d*d + r2*r2 - r1*r1) / (2*d*r2))))
            let part3 = 0.5 * sqrt(max(0, (-d+r1+r2)*(d+r1-r2)*(d-r1+r2)*(d+r1+r2)))
            let overlapArea = part1 + part2 - part3
            return overlapArea / (.pi * r1 * r1)
        }()

        // Smooth totality blend: 0 during partial, ramps to 1 during totality (total only)
        // Annular never goes fully dark — sky stays twilight, no stars, no corona
        let totalityBlend: CGFloat = {
            if !hasTotality || isAnnular { return 0 }
            if overlap >= 0.998 { return 1.0 }
            if overlap > 0.96 { return CGFloat((overlap - 0.96) / 0.038) }
            return 0
        }()
        // For annular: partial twilight darkening during centrality
        let annularDarkness: CGFloat = isAnnular ? min(0.55, overlap * 0.65) : 0

        // ── Sky: dark blue → black as eclipse deepens ────────────────────
        let skyDarkness = isAnnular ? annularDarkness : min(1.0, overlap * 1.2)
        let skyR = 0.02 * (1.0 - skyDarkness)
        let skyG = 0.03 * (1.0 - skyDarkness)
        let skyB = 0.08 * (1.0 - skyDarkness)
        ctx.setFillColor(NSColor(red: skyR, green: skyG, blue: skyB, alpha: 1).cgColor)
        ctx.fill(bounds)

        // ── Stars (emerge as totality approaches) ────────────────────────
        if totalityBlend > 0.1 {
            let starAlpha = (totalityBlend - 0.1) / 0.9
            let stars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.08, 0.12, 1.6, 0.9), (0.91, 0.08, 1.2, 0.7), (0.94, 0.72, 1.4, 0.8),
                (0.05, 0.82, 1.1, 0.6), (0.76, 0.90, 1.0, 0.5), (0.22, 0.48, 1.3, 0.7),
                (0.88, 0.38, 0.9, 0.4), (0.45, 0.05, 1.0, 0.5), (0.66, 0.22, 0.8, 0.35),
                (0.35, 0.85, 1.0, 0.5), (0.56, 0.68, 0.7, 0.3), (0.15, 0.31, 0.9, 0.45),
                (0.72, 0.14, 0.6, 0.3), (0.42, 0.92, 0.8, 0.4), (0.82, 0.58, 0.7, 0.35),
            ]
            for (sx, sy, sr, bright) in stars {
                let a = starAlpha * bright
                ctx.setFillColor(NSColor(white: 1, alpha: a).cgColor)
                let x = bounds.width * sx, y = (bounds.height - 20) * sy
                ctx.fillEllipse(in: CGRect(x: x - sr, y: y - sr, width: sr*2, height: sr*2))
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // Layer 1: ORANGE SUN (always drawn, fades near totality)
        // ═══════════════════════════════════════════════════════════════
        let sunAlpha = max(0, 1.0 - totalityBlend * 2.5)
        if sunAlpha > 0.001 {
            let sunRect = CGRect(x: cx - sunR, y: cy - sunR, width: sunR * 2, height: sunR * 2)
            ctx.saveGState()
            ctx.setAlpha(sunAlpha)
            ctx.addEllipse(in: sunRect)
            ctx.clip()

            // Rich orange gradient with limb darkening
            let orangeColors = [
                NSColor(red: 1.0, green: 0.78, blue: 0.45, alpha: 1).cgColor,
                NSColor(red: 1.0, green: 0.58, blue: 0.18, alpha: 1).cgColor,
                NSColor(red: 0.95, green: 0.40, blue: 0.08, alpha: 1).cgColor,
                NSColor(red: 0.75, green: 0.20, blue: 0.03, alpha: 1).cgColor,
            ] as CFArray
            let sunGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: orangeColors, locations: [0, 0.42, 0.76, 1.0])!
            ctx.drawRadialGradient(sunGrad,
                startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                endCenter:   CGPoint(x: cx, y: cy), endRadius:   sunR, options: [])

            if let sunImg = sunImage {
                sunImg.draw(in: sunRect, from: .zero, operation: .sourceOver, fraction: 0.3)
            }
            ctx.restoreGState()

            // Soft outer glow (atmospheric scatter)
            let glowAlpha = sunAlpha * 0.12 * (1.0 - overlap * 0.8)
            if glowAlpha > 0.001 {
                let glowColors = [
                    NSColor(red: 1.0, green: 0.55, blue: 0.15, alpha: glowAlpha).cgColor,
                    NSColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 0).cgColor,
                ] as CFArray
                let glowGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: glowColors, locations: [0, 1])!
                ctx.drawRadialGradient(glowGrad,
                    startCenter: CGPoint(x: cx, y: cy), startRadius: sunR * 0.92,
                    endCenter: CGPoint(x: cx, y: cy), endRadius: sunR * 1.18, options: [])
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // Layer 2: CORONA (only during TRUE totality when sun is fully covered)
        // ═══════════════════════════════════════════════════════════════
        // Corona ONLY appears when sun is essentially 100% covered (true totality)
        let coronaVisible = hasTotality && !isAnnular && overlap > 0.999
        // Suppress corona during diamond ring / Baily's beads edges
        let drZone = hasTotality ? min(abs(progress - 0.39), abs(progress - 0.61)) : 1.0
        let coronaSuppression: CGFloat = drZone < 0.03 ? CGFloat(drZone / 0.03) : 1.0
        let coronaRamp: CGFloat = {
            if !coronaVisible { return 0 }
            // Ramp based on how deep into totality (overlap-based, not progress-based)
            let depth = CGFloat((overlap - 0.999) / 0.001)
            return min(1, depth) * coronaSuppression
        }()
        let effectiveCorona = coronaRamp
        if effectiveCorona > 0.001 {
            // Synthetic asymmetric corona streamers
            ctx.saveGState()
            for s in coronaStreamers {
                let angle = CGFloat(s.angle)
                let len = sunR * CGFloat(s.length)
                let w = sunR * CGFloat(s.width)
                let bright = CGFloat(s.brightness) * effectiveCorona

                // Draw each streamer as a tapered gradient line
                let tipX = cx + (moonR + len) * cos(angle)
                let tipY = cy + (moonR + len) * sin(angle)
                let baseX = cx + moonR * 1.02 * cos(angle)
                let baseY = cy + moonR * 1.02 * sin(angle)

                // Perpendicular direction for width
                let perpX = -sin(angle)
                let perpY = cos(angle)

                // Draw as a series of dots along the streamer for soft look
                let steps = max(8, Int(len / 3))
                for i in 0..<steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    let fade = (1.0 - t) * (1.0 - t) // quadratic falloff
                    let px = baseX + (tipX - baseX) * t
                    let py = baseY + (tipY - baseY) * t
                    let radius = w * (1.0 - t * 0.6) // taper
                    let alpha = bright * fade * 0.15
                    if alpha < 0.003 { continue }

                    let gradColors = [
                        NSColor(white: 1.0, alpha: alpha).cgColor,
                        NSColor(white: 1.0, alpha: 0).cgColor,
                    ] as CFArray
                    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: gradColors, locations: [0, 1])!
                    ctx.drawRadialGradient(grad,
                        startCenter: CGPoint(x: px, y: py), startRadius: 0,
                        endCenter: CGPoint(x: px, y: py), endRadius: radius, options: [])
                }
                _ = perpX; _ = perpY
            }
            ctx.restoreGState()

            // Inner corona: bright ring just outside the moon
            let innerColors = [
                NSColor(white: 1.0, alpha: effectiveCorona * 0.55).cgColor,
                NSColor(white: 1.0, alpha: effectiveCorona * 0.25).cgColor,
                NSColor(white: 1.0, alpha: effectiveCorona * 0.06).cgColor,
                NSColor(white: 1.0, alpha: 0).cgColor,
            ] as CFArray
            let innerGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: innerColors, locations: [0, 0.15, 0.4, 1])!
            ctx.drawRadialGradient(innerGrad,
                startCenter: CGPoint(x: cx, y: cy), startRadius: moonR * 1.005,
                endCenter: CGPoint(x: cx, y: cy), endRadius: sunR * 2.2, options: [])

            // Corona photo overlay (blended for extra detail)
            if let photo = coronaImage ?? totalityImage {
                let photoScale = sunR * 2.2
                let photoRect = CGRect(x: cx - photoScale, y: cy - photoScale,
                                       width: photoScale * 2, height: photoScale * 2)
                ctx.saveGState()
                // Even-odd clip: show corona photo only outside moon disc
                let outerPath = CGMutablePath()
                outerPath.addEllipse(in: photoRect)
                let innerPath = CGMutablePath()
                innerPath.addEllipse(in: CGRect(x: cx - moonR * 0.97, y: cy - moonR * 0.97,
                                                width: moonR * 1.94, height: moonR * 1.94))
                ctx.addPath(outerPath)
                ctx.addPath(innerPath)
                ctx.clip(using: .evenOdd)
                photo.draw(in: photoRect, from: .zero,
                           operation: .sourceOver, fraction: effectiveCorona * 0.35)
                ctx.restoreGState()
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // Layer 3: MOON DISC (always on top)
        // ═══════════════════════════════════════════════════════════════
        let moonDiscRect = CGRect(x: moonX - moonR, y: moonY - moonR,
                                   width: moonR * 2, height: moonR * 2)

        // During deep totality: earthshine glow on moon surface
        let deepTotality = hasTotality && progress > 0.41 && progress < 0.59
        if deepTotality {
            ctx.saveGState()
            ctx.addEllipse(in: moonDiscRect)
            ctx.clip()

            // Fade in/out at totality edges
            let esAlpha: CGFloat = {
                let d = min(abs(CGFloat(progress) - 0.41), abs(CGFloat(progress) - 0.59))
                return min(1.0, d / 0.025)
            }()

            // Base: very dark charcoal — matches C++ #0A0A0A
            ctx.setFillColor(NSColor(white: 0.055, alpha: 1).cgColor)
            ctx.fill(moonDiscRect)

            // Earthshine — realistic soft blue-grey radial gradient across disc
            // In real photos the lit side faces Earth, giving ~mag 7 surface brightness.
            // We use a gentle off-center radial gradient to simulate scattered light.
            let esCenter = CGPoint(x: moonX - moonR * 0.15, y: moonY + moonR * 0.10)
            let earthshineColors = [
                NSColor(red: 0.22, green: 0.28, blue: 0.42, alpha: esAlpha * 0.55).cgColor,
                NSColor(red: 0.16, green: 0.20, blue: 0.32, alpha: esAlpha * 0.30).cgColor,
                NSColor(red: 0.08, green: 0.10, blue: 0.18, alpha: esAlpha * 0.10).cgColor,
                NSColor(red: 0.0,  green: 0.0,  blue: 0.0,  alpha: 0).cgColor,
            ] as CFArray
            let esGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: earthshineColors, locations: [0, 0.35, 0.70, 1.0])!
            ctx.drawRadialGradient(esGrad,
                startCenter: esCenter, startRadius: 0,
                endCenter:   CGPoint(x: moonX, y: moonY), endRadius: moonR * 1.05,
                options: [])

            // Optional: photo texture overlay if asset available
            if let moonImg = moonImage {
                moonImg.draw(in: moonDiscRect, from: .zero,
                             operation: .sourceOver, fraction: esAlpha * 0.22)
            }

            // Soft warm limb fringe from corona spill — very faint orange halo at edge
            let limbColors = [
                NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0).cgColor,
                NSColor(red: 0.55, green: 0.38, blue: 0.18, alpha: esAlpha * 0.08).cgColor,
            ] as CFArray
            let limbGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: limbColors, locations: [0.78, 1.0])!
            ctx.drawRadialGradient(limbGrad,
                startCenter: CGPoint(x: moonX, y: moonY), startRadius: 0,
                endCenter:   CGPoint(x: moonX, y: moonY), endRadius: moonR,
                options: [])

            ctx.restoreGState()
        } else {
            // Partial phase + diamond ring: pitch-black silhouette
            ctx.saveGState()
            ctx.setFillColor(NSColor(white: 0.0, alpha: 1).cgColor)
            ctx.fillEllipse(in: moonDiscRect)
            ctx.restoreGState()
        }

        // ═══════════════════════════════════════════════════════════════
        // Layer 3b: ANNULAR "RING OF FIRE"
        // During annular centrality the moon is centred but smaller than the
        // sun, so a brilliant orange/yellow ring of photosphere is exposed.
        // We draw it as a series of layered annular gradients centred on the
        // moon disc to simulate the brightly glowing ring.
        // ═══════════════════════════════════════════════════════════════
        if isAnnular && hasTotality && overlap > 0.96 {
            // centrality blend: 0 at start of annularity, 1 at maximum
            let ringBlend: CGFloat = {
                let p = CGFloat(progress)
                if p < 0.39 || p > 0.61 { return 0 }
                // ramp 0.39→0.41 in, flat 0.41–0.59, ramp 0.59→0.61 out
                if p < 0.41 { return min(1, (p - 0.39) / 0.02) }
                if p > 0.59 { return min(1, (0.61 - p) / 0.02) }
                return 1.0
            }()
            if ringBlend > 0.001 {
                ctx.saveGState()
                // The exposed ring is sunR → moonR (moonR < sunR for annular)
                // Bright orange-yellow inner edge fading outward
                let ringColors = [
                    NSColor(red: 1.0, green: 1.0,  blue: 0.85, alpha: ringBlend * 1.0).cgColor,
                    NSColor(red: 1.0, green: 0.85,  blue: 0.40, alpha: ringBlend * 0.95).cgColor,
                    NSColor(red: 1.0, green: 0.55,  blue: 0.10, alpha: ringBlend * 0.75).cgColor,
                    NSColor(red: 0.95, green: 0.35, blue: 0.04, alpha: ringBlend * 0.40).cgColor,
                    NSColor(red: 0.8,  green: 0.25, blue: 0.0,  alpha: 0).cgColor,
                ] as CFArray
                let rg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: ringColors, locations: [0, 0.12, 0.40, 0.70, 1.0])!
                // Draw from moonR outward to sunR*1.25 so the ring looks thick and glowing
                ctx.drawRadialGradient(rg,
                    startCenter: CGPoint(x: moonX, y: moonY), startRadius: moonR * 0.97,
                    endCenter:   CGPoint(x: moonX, y: moonY), endRadius:   sunR * 1.25, options: [])

                // Bright inner rim — hard white-yellow edge right at moonR
                let rimColors = [
                    NSColor(red: 1.0, green: 0.98, blue: 0.90, alpha: ringBlend * 0.0).cgColor,
                    NSColor(red: 1.0, green: 0.98, blue: 0.90, alpha: ringBlend * 0.9).cgColor,
                    NSColor(red: 1.0, green: 0.90, blue: 0.70, alpha: ringBlend * 0.3).cgColor,
                    NSColor(red: 1.0, green: 0.80, blue: 0.50, alpha: 0).cgColor,
                ] as CFArray
                let rimGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: rimColors, locations: [0, 0.04, 0.15, 0.40])!
                ctx.drawRadialGradient(rimGrad,
                    startCenter: CGPoint(x: moonX, y: moonY), startRadius: moonR * 0.88,
                    endCenter:   CGPoint(x: moonX, y: moonY), endRadius:   moonR * 1.25, options: [])

                // Redraw moon silhouette on top to keep crisp dark disc
                ctx.setFillColor(NSColor(white: 0.0, alpha: 1).cgColor)
                ctx.fillEllipse(in: moonDiscRect)
                ctx.restoreGState()
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // Layer 4: CHROMOSPHERE — thin pinkish arc visible at C2/C3 flash
        // Clipped to OUTSIDE the moon disc so it only shows at the exposed edge
        // ═══════════════════════════════════════════════════════════════
        let c2t: Double = 0.39, c3t: Double = 0.61
        let chromoDist = min(abs(progress - c2t), abs(progress - c3t))
        if chromoDist < 0.012 && hasTotality {
            let flash = CGFloat(1.0 - chromoDist / 0.012)
            let flashSmooth = flash * flash * (3 - 2 * flash)
            ctx.saveGState()
            // Clip to OUTSIDE the moon disc so stroke only shows where moon hasn't covered it
            let moonClipPath = CGMutablePath()
            moonClipPath.addRect(bounds)
            moonClipPath.addEllipse(in: moonDiscRect)
            ctx.addPath(moonClipPath)
            ctx.clip(using: .evenOdd)
            // Chromosphere arc drawn at sun's limb — only the exposed sliver shows
            let arcCenter = abs(progress - c2t) < abs(progress - c3t) ? Double.pi : 0.0
            let arcPath = CGMutablePath()
            arcPath.addArc(center: CGPoint(x: cx, y: cy), radius: sunR * 1.002,
                           startAngle: CGFloat(arcCenter - Double.pi * 0.8),
                           endAngle:   CGFloat(arcCenter + Double.pi * 0.8),
                           clockwise: false)
            ctx.addPath(arcPath)
            ctx.setLineWidth(max(2.0, sunR * 0.022))
            ctx.setStrokeColor(NSColor(red: 1.0, green: 0.18, blue: 0.28, alpha: flashSmooth * 0.70).cgColor)
            ctx.strokePath()
            ctx.restoreGState()
        }

        // ═══════════════════════════════════════════════════════════════
        // Layer 5: BAILY'S BEADS
        //
        // KEY PHYSICS: Beads only appear during the few seconds around C2/C3
        // when the last crescent is breaking up. At that moment the moon is
        // slightly offset from the sun center, so there is ONE preferred
        // contact arc direction. Only the ±50° arc around that direction
        // has geometry close enough for valleys to punch through.
        //
        // Gap formula: gap(θ) = sunR − dist(correctedLimbPoint, sunCenter)
        // At the contact arc this is near-zero, so only deep Watts valleys
        // tip it positive. Away from the contact arc the large negative gap
        // means no bead regardless of valley depth.
        //
        // We use a NARROW time window (beadsDist < 0.022) to stay in the
        // crescent-breaking phase and avoid mid-totality where the moon is
        // centered and beads would spread symmetrically (physically wrong).
        // ═══════════════════════════════════════════════════════════════
        if hasTotality {
            let beadsDist = min(abs(progress - 0.39), abs(progress - 0.61))
            if beadsDist < 0.022 {
                ctx.saveGState()

                let tFrac    = CGFloat(beadsDist / 0.022)
                // Bright peak right at C2/C3, fade toward edges
                let fadeMult = CGFloat(pow(Double(1.0 - tFrac * tFrac), 0.5))

                // Valley scale: moderate amplification for visibility
                // Real: ~3"/950" * sunR ≈ 0.003*sunR; we use 0.042 (~14× amp)
                let limbScale = Double(sunR) * 0.042

                // Direction from moon center → sun center (the contact arc axis)
                let toSunAngle = atan2(Double(cy - moonY), Double(cx - moonX))

                struct BeadSeg {
                    var angleSum: Double = 0; var weight: Double = 0
                    var maxGap: Double = 0;   var steps: Int = 0
                }
                var segs: [BeadSeg] = []; var inSeg = false; var cur = BeadSeg()

                for i in 0..<360 {
                    let θ = Double(i) * Double.pi / 180.0

                    // Angular distance from the contact arc axis
                    var dFromArc = θ - toSunAngle
                    while dFromArc >  Double.pi { dFromArc -= 2 * Double.pi }
                    while dFromArc < -Double.pi { dFromArc += 2 * Double.pi }

                    // Only examine ±70° arc around the contact direction
                    // (beads physically cannot form on the far side)
                    if abs(dFromArc) > 70.0 * Double.pi / 180.0 { continue }

                    let wc = lunarLimbOffset(at: θ) * limbScale  // negative = valley
                    let rCorrected = Double(moonR) + wc

                    let px  = Double(moonX) + rCorrected * cos(θ)
                    let py  = Double(moonY) + rCorrected * sin(θ)
                    let dSun = sqrt(pow(px - Double(cx), 2) + pow(py - Double(cy), 2))
                    let gap  = Double(sunR) - dSun    // >0 → valley punches through solar disc

                    if gap > 0 {
                        inSeg = true
                        cur.angleSum += θ * gap; cur.weight += gap
                        cur.maxGap = max(cur.maxGap, gap); cur.steps += 1
                    } else {
                        if inSeg && cur.weight > 0 { segs.append(cur); cur = BeadSeg() }
                        inSeg = false
                    }
                }
                if inSeg && cur.weight > 0 { segs.append(cur) }
                segs.sort { $0.maxGap * Double($0.steps) > $1.maxGap * Double($1.steps) }
                if segs.count > 10 { segs = Array(segs.prefix(10)) }

                for seg in segs {
                    let angle      = seg.angleSum / max(1e-12, seg.weight)
                    let gap        = CGFloat(seg.maxGap)
                    let angSpanDeg = CGFloat(seg.steps)

                    // Center pearl ON the mean limb edge — inner half paints a
                    // glowing notch into the black disc, outer half is the visible pearl
                    let bx = moonX + moonR * CGFloat(cos(angle))
                    let by = moonY + moonR * CGFloat(sin(angle))

                    let brightness = fadeMult * min(1.0, gap / (sunR * 0.035) + 0.2)
                    if brightness < 0.08 { continue }

                    let arcPx = angSpanDeg * CGFloat.pi / 180.0 * moonR
                    let beadR = max(sunR * 0.016, min(sunR * 0.09, arcPx * 0.6))

                    // Pearl gradient — warm white core, soft warm halo
                    let pearlColors = [
                        NSColor(red: 1.0, green: 0.99, blue: 0.94, alpha: brightness).cgColor,
                        NSColor(red: 1.0, green: 0.97, blue: 0.88, alpha: brightness * 0.55).cgColor,
                        NSColor(red: 1.0, green: 0.90, blue: 0.68, alpha: brightness * 0.12).cgColor,
                        NSColor(red: 1.0, green: 0.82, blue: 0.50, alpha: 0).cgColor,
                    ] as CFArray
                    let pg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                       colors: pearlColors, locations: [0, 0.22, 0.55, 1.0])!
                    ctx.drawRadialGradient(pg,
                        startCenter: CGPoint(x: bx, y: by), startRadius: 0,
                        endCenter:   CGPoint(x: bx, y: by), endRadius: beadR * 3.5, options: [])

                    // Hard bright core
                    ctx.setFillColor(NSColor(red: 1.0, green: 0.99, blue: 0.95,
                                             alpha: brightness).cgColor)
                    let cr = beadR * 0.4
                    ctx.fillEllipse(in: CGRect(x: bx - cr, y: by - cr,
                                               width: cr * 2, height: cr * 2))
                }
                ctx.restoreGState()
            }
        }

        // ═══════════════════════════════════════════════════════════════
        // Layer 6: DIAMOND RING
        // The "ring": luminous annular glow tight to the moon's edge.
        // The "diamond": a single point of light SO bright it blows out
        // the sensor — massive overexposed core, few long asymmetric
        // diffraction spikes (NOT a uniform star pattern), and a huge
        // soft bloom that washes out the nearby ring.
        // Reference: Espenak 2019 — one dominant spike pair ~2× sun radius,
        // secondary pair ~1.2× sunR, rest much shorter. Core is clipped white.
        // ═══════════════════════════════════════════════════════════════
        if hasTotality {
            let drC2 = abs(progress - 0.39), drC3 = abs(progress - 0.61)
            let drDist = min(drC2, drC3)
            if drDist < 0.030 {
                let raw = CGFloat(1.0 - drDist / 0.030)
                let drA = raw * raw * (3 - 2 * raw)

                // Bead location: on moon limb facing the sun
                let drAngle = atan2(Double(cy - moonY), Double(cx - moonX))
                let drX = CGFloat(Double(moonX) + Double(moonR) * cos(drAngle))
                let drY = CGFloat(Double(moonY) + Double(moonR) * sin(drAngle))

                ctx.saveGState()

                // ── 1. Tight luminous ring around moon edge ──────────────
                // Only the thin crescent of photosphere is visible, not a full ring.
                // Brightest near the bead point, fades away from it.
                let ringOuter = moonR * 1.18
                // Full annular base glow
                let ringColors = [
                    NSColor(red: 1.0, green: 0.97, blue: 0.88, alpha: drA * 0.0).cgColor,
                    NSColor(red: 1.0, green: 0.97, blue: 0.88, alpha: drA * 0.70).cgColor,
                    NSColor(red: 1.0, green: 0.94, blue: 0.78, alpha: drA * 0.35).cgColor,
                    NSColor(red: 1.0, green: 0.88, blue: 0.65, alpha: 0).cgColor,
                ] as CFArray
                let ringGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: ringColors, locations: [0, 0.12, 0.45, 1])!
                ctx.drawRadialGradient(ringGrad,
                    startCenter: CGPoint(x: cx, y: cy), startRadius: moonR * 0.99,
                    endCenter:   CGPoint(x: cx, y: cy), endRadius:   ringOuter, options: [])

                // ── 2. Blown-out overexposed bloom — huge, washes out area around bead
                // Multiple layered radial gradients simulating sensor overexposure
                let blooms: [(r: CGFloat, a: CGFloat)] = [
                    (sunR * 3.5, 0.012),
                    (sunR * 2.2, 0.035),
                    (sunR * 1.3, 0.10),
                    (sunR * 0.7, 0.28),
                    (sunR * 0.35,0.65),
                    (sunR * 0.14,1.00),
                ]
                for b in blooms {
                    let bc = [
                        NSColor(red: 1.0, green: 0.98, blue: 0.93, alpha: drA * b.a).cgColor,
                        NSColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 0).cgColor,
                    ] as CFArray
                    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: bc, locations: [0, 1])!
                    ctx.drawRadialGradient(bg,
                        startCenter: CGPoint(x: drX, y: drY), startRadius: 0,
                        endCenter:   CGPoint(x: drX, y: drY), endRadius: b.r, options: [])
                }

                // ── 3. Diffraction spikes — asymmetric, like a real camera ──
                // Primary pair: very long, aligned with drAngle ± 90° (perpendicular to sun direction)
                // Secondary pair: long, at drAngle (toward/away from sun)
                // Tertiary: shorter, at ±45° — much dimmer
                // This produces the characteristic uneven starburst of real photos
                let spikeBaseAngle = CGFloat(drAngle)
                let spikeDefs: [(angle: CGFloat, length: CGFloat, brightness: CGFloat, width: CGFloat)] = [
                    // Primary pair (perpendicular) — longest
                    (spikeBaseAngle + .pi/2,       sunR * 2.6, 1.00, 2.2),
                    (spikeBaseAngle - .pi/2,       sunR * 2.6, 1.00, 2.2),
                    // Secondary pair (along sun direction)
                    (spikeBaseAngle,               sunR * 1.8, 0.80, 1.6),
                    (spikeBaseAngle + .pi,         sunR * 1.8, 0.80, 1.6),
                    // Tertiary ±45° — noticeably shorter/dimmer
                    (spikeBaseAngle + .pi/4,       sunR * 1.1, 0.40, 1.0),
                    (spikeBaseAngle - .pi/4,       sunR * 1.1, 0.40, 1.0),
                    (spikeBaseAngle + 3*(.pi/4),   sunR * 1.0, 0.35, 1.0),
                    (spikeBaseAngle - 3*(.pi/4),   sunR * 1.0, 0.35, 1.0),
                ]
                for spike in spikeDefs {
                    let ex = drX + spike.length * cos(spike.angle)
                    let ey = drY + spike.length * sin(spike.angle)
                    let steps = 40
                    for j in 0..<steps {
                        let t0 = CGFloat(j) / CGFloat(steps)
                        let t1 = CGFloat(j+1) / CGFloat(steps)
                        // Power-law fade: bright close to core, sharp dropoff
                        let fade = pow(1.0 - t0, 1.8) * spike.brightness
                        let x0 = drX + (ex - drX) * t0, y0 = drY + (ey - drY) * t0
                        let x1 = drX + (ex - drX) * t1, y1 = drY + (ey - drY) * t1
                        ctx.setLineWidth(spike.width * (1.0 - t0 * 0.7))
                        ctx.setStrokeColor(NSColor(white: 1.0, alpha: drA * fade).cgColor)
                        ctx.move(to: CGPoint(x: x0, y: y0))
                        ctx.addLine(to: CGPoint(x: x1, y: y1))
                        ctx.strokePath()
                    }
                }

                // ── 4. Pure white overexposed core — clipped bright disk ──
                // In real photos the bead point clips to pure white over a
                // region much larger than the actual bead
                let clipR = sunR * 0.10
                ctx.setFillColor(NSColor.white.cgColor)
                ctx.fillEllipse(in: CGRect(x: drX - clipR, y: drY - clipR,
                                           width: clipR * 2, height: clipR * 2))
                // Slightly larger near-white halo (sensor bloom)
                let nearWhiteR = sunR * 0.22
                let nwc = [NSColor(white: 1.0, alpha: drA * 0.85).cgColor,
                            NSColor(white: 1.0, alpha: 0).cgColor] as CFArray
                let nwg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: nwc, locations: [0, 1])!
                ctx.drawRadialGradient(nwg,
                    startCenter: CGPoint(x: drX, y: drY), startRadius: clipR,
                    endCenter:   CGPoint(x: drX, y: drY), endRadius: nearWhiteR, options: [])

                ctx.restoreGState()
            }
        }

        // ── Magnitude readout ─────────────────────────────────────────────
        let magStr = String(format: "Mag: %.3f", computeInstantMagnitude())
        let attrs: [NSAttributedString.Key: Any] = [
            .font: Theme.mono(9, weight: .medium),
            .foregroundColor: Theme.textTertiary,
        ]
        (magStr as NSString).draw(at: CGPoint(x: 4, y: bounds.height - 14), withAttributes: attrs)
    }
    private func computeInstantMagnitude() -> Double {
        let peak = magnitude
        let dist = abs(progress - 0.5) * 2.0
        return max(0, peak * (1.0 - dist * dist))
    }
}

// MARK: - Contact Times List (below simulator, second-by-second highlight)


// MARK: - Contact Times List (below simulator, second-by-second highlight)

// MARK: - ContactTicksView

/// Draws C1/C2/C3/C4 tick marks under the scrub slider
final class ContactTicksView: NSView {
    var hasTotality: Bool = false { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let ticks: [(Double, String, NSColor)] = hasTotality
            ? [(0.10, "C1", .systemYellow), (0.385, "C2", .systemOrange),
               (0.50, "Mid", .systemRed),   (0.615, "C3", .systemOrange),
               (0.90, "C4", .systemYellow)]
            : [(0.10, "C1", .systemYellow), (0.50, "Max", .systemOrange),
               (0.90, "C4", .systemYellow)]
        for (p, label, color) in ticks {
            let x = bounds.minX + CGFloat(p) * bounds.width
            let path = NSBezierPath()
            path.move(to: NSPoint(x: x, y: bounds.maxY))
            path.line(to: NSPoint(x: x, y: bounds.maxY - 6))
            color.withAlphaComponent(0.8).setStroke()
            path.lineWidth = 1.5
            path.stroke()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: color.withAlphaComponent(0.8)
            ]
            let str = label as NSString
            let size = str.size(withAttributes: attrs)
            str.draw(at: NSPoint(x: x - size.width / 2, y: 0), withAttributes: attrs)
        }
    }
}

final class ContactTimesListView: NSView {
    private var contacts: ContactTimes?
    private var hasTotality = false
    private var isAnnular = false
    private var currentProgress: Double = 0
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private var rowViews: [(label: NSTextField, dot: NSView, progress: Double)] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        let title = themeLabel("Contact Times", size: 12, color: Theme.textPrimary, bold: true)
        title.alignment = .center
        stackView.orientation = .vertical
        stackView.spacing = 1
        stackView.alignment = .leading
        scrollView.documentView = stackView
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        addSubview(title)
        addSubview(scrollView)
        title.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            title.centerXAnchor.constraint(equalTo: centerXAnchor),
            scrollView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setContacts(_ contacts: ContactTimes, hasTotality: Bool, isAnnular: Bool = false) {
        self.contacts = contacts
        self.hasTotality = hasTotality
        self.isAnnular = isAnnular
        rebuildRows()
    }

    private func rebuildRows() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rowViews.removeAll()
        guard let c = contacts else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        fmt.timeZone = TimeZone(identifier: "UTC")
        var events: [(progress: Double, label: String, symbol: String, color: NSColor)] = []
        events.append((0.0, "Pre-eclipse", "☀️", Theme.textTertiary))
        if let c1 = c.c1 {
            events.append((0.10, "C1  First Contact  \(fmt.string(from: c1))", "▶", NSColor.systemYellow))
        }
        for i in stride(from: 1, through: 9, by: 1) {
            let pct = i * 10
            let p = 0.10 + Double(i) * 0.029
            if p < 0.38 { events.append((p, "Partial  \(pct)%", "🌘", Theme.textTertiary)) }
        }
        if hasTotality {
            if let c2 = c.c2 {
                let c2label = isAnnular ? "C2  Annularity begins  \(fmt.string(from: c2))" : "C2  Totality begins  \(fmt.string(from: c2))"
                events.append((0.39, c2label, "💎", NSColor.systemOrange))
            }
            if isAnnular {
                events.append((0.393, "Ring of Fire begins", "🔥", Theme.accentCoral))
                events.append((0.405, "Annularity — Ring of Fire", "🔥", Theme.accentCoral))
                if let m = c.max {
                    events.append((0.50, "MAX  Greatest eclipse  \(fmt.string(from: m))", "🌑", NSColor.systemRed))
                }
                events.append((0.595, "Annularity — Ring of Fire", "🔥", Theme.accentCoral))
                events.append((0.607, "Ring of Fire ends", "🔥", Theme.accentCoral))
            } else {
                events.append((0.393, "Diamond Ring", "💎", Theme.accentGold))
                events.append((0.397, "Baily's Beads", "✨", Theme.accentGold))
                events.append((0.405, "Totality — Corona visible", "👑", Theme.accentCoral))
                if let m = c.max {
                    events.append((0.50, "MAX  Greatest eclipse  \(fmt.string(from: m))", "🌑", NSColor.systemRed))
                }
                events.append((0.595, "Totality — Corona fading", "👑", Theme.accentCoral))
                events.append((0.603, "Baily's Beads", "✨", Theme.accentGold))
                events.append((0.607, "Diamond Ring", "💎", Theme.accentGold))
            }
            if let c3 = c.c3 {
                let c3label = isAnnular ? "C3  Annularity ends  \(fmt.string(from: c3))" : "C3  Totality ends  \(fmt.string(from: c3))"
                events.append((0.61, c3label, "💎", NSColor.systemOrange))
            }
        } else {
            if let m = c.max {
                events.append((0.50, "MAX  Greatest eclipse  \(fmt.string(from: m))", "🌑", NSColor.systemOrange))
            }
        }
        for i in stride(from: 9, through: 1, by: -1) {
            let pct = i * 10
            let p = 0.90 - Double(i) * 0.029
            if p > 0.62 { events.append((p, "Partial  \(pct)%", "🌒", Theme.textTertiary)) }
        }
        if let c4 = c.c4 {
            events.append((0.90, "C4  Last Contact  \(fmt.string(from: c4))", "▶", NSColor.systemYellow))
        }
        events.append((1.0, "Post-eclipse", "☀️", Theme.textTertiary))
        events.sort { $0.progress < $1.progress }
        for ev in events {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8
            row.alignment = .centerY
            row.edgeInsets = NSEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
            let dot = NSView()
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.backgroundColor = ev.color.cgColor
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            let lbl = themeLabel("\(ev.symbol)  \(ev.label)", size: 11, color: ev.color)
            lbl.alignment = .left
            row.addArrangedSubview(dot)
            row.addArrangedSubview(lbl)
            row.wantsLayer = true
            row.layer?.cornerRadius = 4
            stackView.addArrangedSubview(row)
            rowViews.append((label: lbl, dot: dot, progress: ev.progress))
        }
    }

    func updateProgress(_ progress: Double) {
        currentProgress = progress
        var bestIdx = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, rv) in rowViews.enumerated() {
            let d = abs(rv.progress - progress)
            if d < bestDist { bestDist = d; bestIdx = i }
        }
        for (i, rv) in rowViews.enumerated() {
            let isActive = i == bestIdx
            rv.dot.layer?.backgroundColor = isActive ? NSColor.white.cgColor : rv.dot.layer?.backgroundColor
            if let stack = rv.label.superview as? NSStackView {
                stack.layer?.backgroundColor = isActive ? NSColor(white: 1, alpha: 0.1).cgColor : NSColor.clear.cgColor
            }
            rv.label.font = NSFont.systemFont(ofSize: 11, weight: isActive ? .bold : .regular)
            rv.label.textColor = isActive ? Theme.textPrimary : Theme.textSecondary
        }
    }
}

// Helper: normalize angle to -π..π
private func angleNormalize(_ a: Double) -> Double {
    var x = a
    while x <= -Double.pi { x += 2 * Double.pi }
    while x > Double.pi  { x -= 2 * Double.pi }
    return x
}
