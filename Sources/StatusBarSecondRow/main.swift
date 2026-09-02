import AppKit
import ServiceManagement

private let rowHeight: CGFloat = 28
private let rowInset: CGFloat = 4
private let iconSize: CGFloat = 16
private let controlButtonSize: CGFloat = 18
private let appButtonSize: CGFloat = 22
private let dragHandleWidth: CGFloat = 12
private let controlGap: CGFloat = 2
private let separatorGap: CGFloat = 6
private let separatorWidth: CGFloat = 1
private let minWindowWidth: CGFloat = 70

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let appRow = AppRowWindow()
    private var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        appRow.show()
        observeWorkspace()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.appRow.reloadApps()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    private func observeWorkspace() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let notifications: [NSNotification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        ]

        for name in notifications {
            workspaceCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.appRow.reloadApps()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.appRow.reposition()
            }
        }
    }
}

@main
enum StatusBarSecondRow {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
private final class AppRowWindow {
    private let panel: NSPanel
    private let scrollView = NSScrollView()
    private let stackView = NSStackView()
    private let collapseButton = ControlButton()
    private let settingsButton = ControlButton()
    private let separatorView = NSBox()
    private var appButtons: [pid_t: NSButton] = [:]
    private var hasFitInitialWidth = false
    private var isCollapsed = UserDefaults.standard.bool(forKey: Defaults.isCollapsedKey)

    init() {
        panel = NSPanel(
            contentRect: Self.windowFrame(width: 320),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        let background = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        background.translatesAutoresizingMaskIntoConstraints = false
        background.autoresizingMask = [.width, .height]
        background.blendingMode = .behindWindow
        background.material = .menu
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 8
        background.layer?.masksToBounds = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .none

        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 7
        stackView.edgeInsets = NSEdgeInsets(top: rowInset, left: rowInset, bottom: rowInset, right: rowInset)
        stackView.frame = NSRect(x: 0, y: 0, width: 1, height: rowHeight - 4)

        scrollView.documentView = stackView

        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.boxType = .separator

        let quitButton = Self.iconButton(symbol: "xmark.circle.fill", tooltip: "退出")
        quitButton.target = self
        quitButton.action = #selector(quit)

        let collapseSymbol = isCollapsed ? "chevron.left.circle.fill" : "chevron.right.circle.fill"
        let collapseTooltip = isCollapsed ? "展开" : "收起"
        Self.configureIconButton(collapseButton, symbol: collapseSymbol, tooltip: collapseTooltip)
        collapseButton.target = self
        collapseButton.action = #selector(toggleCollapsed)

        Self.configureIconButton(settingsButton, symbol: "gearshape.fill", tooltip: "设置")
        settingsButton.target = self
        settingsButton.action = #selector(showSettingsMenu(_:))

        let dragHandle = DragHandleView()
        dragHandle.translatesAutoresizingMaskIntoConstraints = false
        dragHandle.onDragEnded = { [weak self] frame in
            self?.save(frame: frame)
        }

        let root = NSView()
        root.addSubview(background)
        root.addSubview(scrollView)
        root.addSubview(quitButton)
        root.addSubview(collapseButton)
        root.addSubview(settingsButton)
        root.addSubview(dragHandle)
        root.addSubview(separatorView)
        panel.contentView = root

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            background.topAnchor.constraint(equalTo: root.topAnchor),
            background.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            quitButton.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: rowInset),
            quitButton.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            quitButton.widthAnchor.constraint(equalToConstant: controlButtonSize),
            quitButton.heightAnchor.constraint(equalToConstant: controlButtonSize),

            collapseButton.leadingAnchor.constraint(equalTo: quitButton.trailingAnchor, constant: controlGap),
            collapseButton.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            collapseButton.widthAnchor.constraint(equalToConstant: controlButtonSize),
            collapseButton.heightAnchor.constraint(equalToConstant: controlButtonSize),

            settingsButton.leadingAnchor.constraint(equalTo: collapseButton.trailingAnchor, constant: controlGap),
            settingsButton.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: controlButtonSize),
            settingsButton.heightAnchor.constraint(equalToConstant: controlButtonSize),

            dragHandle.leadingAnchor.constraint(equalTo: settingsButton.trailingAnchor, constant: controlGap),
            dragHandle.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            dragHandle.widthAnchor.constraint(equalToConstant: dragHandleWidth),
            dragHandle.heightAnchor.constraint(equalToConstant: controlButtonSize),

            separatorView.leadingAnchor.constraint(equalTo: dragHandle.trailingAnchor, constant: separatorGap),
            separatorView.centerYAnchor.constraint(equalTo: root.centerYAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: separatorWidth),
            separatorView.heightAnchor.constraint(equalToConstant: 14),

            scrollView.leadingAnchor.constraint(equalTo: separatorView.trailingAnchor, constant: separatorGap),
            scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -rowInset),
            scrollView.topAnchor.constraint(equalTo: root.topAnchor, constant: 2),
            scrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -2)
        ])

        scrollView.isHidden = isCollapsed
        separatorView.isHidden = isCollapsed
        reloadApps()
    }

    func show() {
        fitWindowToContent()
        panel.orderFrontRegardless()
    }

    func reposition() {
        hasFitInitialWidth = false
        fitWindowToContent()
    }

    func reloadApps() {
        let visibleWindowPIDs = Set(Self.visibleWindowOwnerPIDs())
        let apps = NSWorkspace.shared.runningApplications
            .filter { Self.shouldShow($0, visibleWindowPIDs: visibleWindowPIDs) }
            .uniquedByBundleIdentifier()
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

        let pids = Set(apps.map(\.processIdentifier))
        for (pid, button) in appButtons where !pids.contains(pid) {
            button.removeFromSuperview()
            appButtons[pid] = nil
        }

        for app in apps where appButtons[app.processIdentifier] == nil {
            let button = Self.button(for: app)
            button.target = self
            button.action = #selector(activateApp(_:))
            button.menu = appMenu(for: app)
            appButtons[app.processIdentifier] = button
            stackView.addArrangedSubview(button)
        }

        stackView.subviews
            .compactMap { $0 as? AppButton }
            .sorted {
                ($0.runningApp?.localizedName ?? "") < ($1.runningApp?.localizedName ?? "")
            }
            .forEach { button in
                stackView.removeArrangedSubview(button)
                stackView.addArrangedSubview(button)
            }

        updateDocumentSize()
    }

    @objc private func activateApp(_ sender: AppButton) {
        sender.runningApp?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    @objc private func activateAppFromMenu(_ sender: NSMenuItem) {
        appFromMenuItem(sender)?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    @objc private func quitAppFromMenu(_ sender: NSMenuItem) {
        appFromMenuItem(sender)?.terminate()
        reloadApps()
    }

    @objc private func forceQuitAppFromMenu(_ sender: NSMenuItem) {
        appFromMenuItem(sender)?.forceTerminate()
        reloadApps()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func showSettingsMenu(_ sender: NSButton) {
        let menu = NSMenu()
        let launchAtLoginItem = NSMenuItem(
            title: Self.launchAtLoginTitle,
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = Self.launchAtLoginState
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 StatusBarSecondRow", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.maxY + 4), in: sender)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
            NSLog("Failed to update launch at login: \(error.localizedDescription)")
        }
    }

    @objc private func toggleCollapsed() {
        isCollapsed.toggle()
        scrollView.isHidden = isCollapsed
        let symbol = isCollapsed ? "chevron.left.circle.fill" : "chevron.right.circle.fill"
        let tooltip = isCollapsed ? "展开" : "收起"
        collapseButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        collapseButton.image?.size = NSSize(width: 13, height: 13)
        collapseButton.toolTip = tooltip
        UserDefaults.standard.set(isCollapsed, forKey: Defaults.isCollapsedKey)
        separatorView.isHidden = isCollapsed
        fitWindowToContent()
    }

    private static func shouldShow(_ app: NSRunningApplication, visibleWindowPIDs: Set<pid_t>) -> Bool {
        guard !app.isTerminated,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let bundleURL = app.bundleURL,
              bundleURL.pathExtension == "app",
              app.localizedName?.isEmpty == false,
              Bundle(url: bundleURL)?.hasUsableIcon == true else {
            return false
        }

        return app.activationPolicy == .regular ||
               (app.activationPolicy == .accessory && visibleWindowPIDs.contains(app.processIdentifier))
    }

    private static func button(for app: NSRunningApplication) -> AppButton {
        let button = AppButton()
        button.runningApp = app
        button.image = app.icon
        button.title = ""
        button.toolTip = app.localizedName
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: appButtonSize),
            button.heightAnchor.constraint(equalToConstant: appButtonSize)
        ])

        return button
    }

    private static var launchAtLoginTitle: String {
        SMAppService.mainApp.status == .requiresApproval ? "开机启动（需系统批准）" : "开机启动"
    }

    private static var launchAtLoginState: NSControl.StateValue {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .on
        case .requiresApproval:
            return .mixed
        default:
            return .off
        }
    }

    private func appMenu(for app: NSRunningApplication) -> NSMenu {
        let menu = NSMenu()
        let appName = app.localizedName ?? "App"

        let activateItem = NSMenuItem(title: "切换到 \(appName)", action: #selector(activateAppFromMenu(_:)), keyEquivalent: "")
        activateItem.target = self
        activateItem.representedObject = app.processIdentifier
        menu.addItem(activateItem)

        let quitItem = NSMenuItem(title: "退出 \(appName)", action: #selector(quitAppFromMenu(_:)), keyEquivalent: "")
        quitItem.target = self
        quitItem.representedObject = app.processIdentifier
        menu.addItem(quitItem)

        let forceQuitItem = NSMenuItem(title: "强制退出 \(appName)", action: #selector(forceQuitAppFromMenu(_:)), keyEquivalent: "")
        forceQuitItem.target = self
        forceQuitItem.representedObject = app.processIdentifier
        menu.addItem(forceQuitItem)

        return menu
    }

    private func appFromMenuItem(_ item: NSMenuItem) -> NSRunningApplication? {
        guard let pid = item.representedObject as? pid_t else {
            return nil
        }

        return NSRunningApplication(processIdentifier: pid)
    }

    private static func iconButton(symbol: String, tooltip: String) -> NSButton {
        let button = ControlButton()
        configureIconButton(button, symbol: symbol, tooltip: tooltip)
        return button
    }

    private static func configureIconButton(_ button: NSButton, symbol: String, tooltip: String) {
        button.title = ""
        button.translatesAutoresizingMaskIntoConstraints = false
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.image?.size = NSSize(width: 13, height: 13)
        button.toolTip = tooltip
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyUpOrDown
    }

    private func updateDocumentSize() {
        stackView.layoutSubtreeIfNeeded()
        let contentWidth = stackView.fittingSize.width + rowInset
        stackView.frame = NSRect(
            x: 0,
            y: 0,
            width: contentWidth,
            height: max(rowHeight - 4, stackView.fittingSize.height)
        )
        fitWindowToContent()
    }

    private func fitWindowToContent() {
        let collapsedWidth = rowInset + controlButtonSize + controlGap + controlButtonSize + controlGap + controlButtonSize + controlGap + dragHandleWidth + rowInset
        let expandedWidth = collapsedWidth + separatorGap + separatorWidth + separatorGap + rowInset
        let fixedWidth = isCollapsed ? collapsedWidth : expandedWidth
        let desiredWidth = fixedWidth + (isCollapsed ? 0 : stackView.frame.width)
        let frame = hasFitInitialWidth
            ? NSRect(x: panel.frame.maxX - desiredWidth, y: panel.frame.minY, width: desiredWidth, height: rowHeight)
            : Self.windowFrame(width: desiredWidth, savedMaxX: UserDefaults.standard.object(forKey: Defaults.maxXKey) as? CGFloat, savedMinY: UserDefaults.standard.object(forKey: Defaults.minYKey) as? CGFloat)

        let clampedFrame = Self.clamped(frame)
        panel.setFrame(clampedFrame, display: true)
        save(frame: clampedFrame)
        hasFitInitialWidth = true
    }

    private func save(frame: NSRect) {
        UserDefaults.standard.set(frame.maxX, forKey: Defaults.maxXKey)
        UserDefaults.standard.set(frame.minY, forKey: Defaults.minYKey)
    }

    private static func windowFrame(width requestedWidth: CGFloat, savedMaxX: CGFloat? = nil, savedMinY: CGFloat? = nil) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 600)
        let width = min(max(minWindowWidth, requestedWidth), max(minWindowWidth, visibleFrame.width - 16))
        let x = (savedMaxX ?? visibleFrame.maxX - 8) - width
        let y = savedMinY ?? visibleFrame.maxY - rowHeight - 4
        return NSRect(x: x, y: y, width: width, height: rowHeight)
    }

    fileprivate static func clamped(_ frame: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 600)
        let width = min(frame.width, max(minWindowWidth, visibleFrame.width - 16))
        let minX = visibleFrame.minX + 8
        let maxX = visibleFrame.maxX - width - 8
        let minY = visibleFrame.minY + 8
        let maxY = visibleFrame.maxY - rowHeight - 4

        return NSRect(
            x: min(max(frame.minX, minX), maxX),
            y: min(max(frame.minY, minY), maxY),
            width: width,
            height: rowHeight
        )
    }

    private static func visibleWindowOwnerPIDs() -> [pid_t] {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var seen = Set<pid_t>()
        return windowList.compactMap { window in
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  seen.insert(pid).inserted else {
                return nil
            }

            return pid
        }
    }
}

private enum Defaults {
    static let isCollapsedKey = "isCollapsed"
    static let maxXKey = "windowMaxX"
    static let minYKey = "windowMinY"
}

private final class ControlButton: NSButton {
    private var isHovering = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 5
        alphaValue = 0.58
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override var isHighlighted: Bool {
        didSet {
            updateAppearance()
        }
    }

    private func updateAppearance() {
        alphaValue = isHovering || isHighlighted ? 1 : 0.58
        let alpha: CGFloat = isHighlighted ? 0.14 : (isHovering ? 0.08 : 0)
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(alpha).cgColor
    }
}

private final class AppButton: NSButton {
    weak var runningApp: NSRunningApplication?
    private var isHovering = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        updateAppearance()
    }

    override var isHighlighted: Bool {
        didSet {
            updateAppearance()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image else {
            return
        }

        let rect = NSRect(
            x: bounds.midX - iconSize / 2,
            y: bounds.midY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        image.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: isEnabled ? 1 : 0.35,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu else {
            return
        }

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private func updateAppearance() {
        let alpha: CGFloat = isHighlighted ? 0.16 : (isHovering ? 0.10 : 0)
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(alpha).cgColor
    }
}

private final class DragHandleView: NSView {
    private let imageView = NSImageView()
    private var dragStartFrame: NSRect?
    private var dragStartMouseLocation: NSPoint?
    var onDragEnded: ((NSRect) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        toolTip = "拖动"

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = NSImage(systemSymbolName: "grip.vertical", accessibilityDescription: "拖动") ??
            NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "拖动")
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        imageView.contentTintColor = .secondaryLabelColor
        imageView.imageScaling = .scaleProportionallyDown
        imageView.alphaValue = 0.5

        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 12),
            imageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        imageView.alphaValue = 0.9
    }

    override func mouseExited(with event: NSEvent) {
        imageView.alphaValue = 0.5
    }

    override func mouseDown(with event: NSEvent) {
        dragStartFrame = window?.frame
        dragStartMouseLocation = NSEvent.mouseLocation
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let dragStartFrame,
              let dragStartMouseLocation else {
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let targetFrame = NSRect(
            x: dragStartFrame.minX + mouseLocation.x - dragStartMouseLocation.x,
            y: dragStartFrame.minY + mouseLocation.y - dragStartMouseLocation.y,
            width: dragStartFrame.width,
            height: dragStartFrame.height
        )

        window.setFrame(AppRowWindow.clamped(targetFrame), display: true)
    }

    override func mouseUp(with event: NSEvent) {
        if let frame = window?.frame {
            onDragEnded?(frame)
        }

        dragStartFrame = nil
        dragStartMouseLocation = nil
    }
}

private extension Bundle {
    var hasUsableIcon: Bool {
        if let iconFile = object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
           resourceExists(iconFile) {
            return true
        }

        if object(forInfoDictionaryKey: "CFBundleIconName") != nil ||
           object(forInfoDictionaryKey: "CFBundleIcons") != nil {
            return url(forResource: "Assets", withExtension: "car") != nil
        }

        return false
    }

    private func resourceExists(_ filename: String) -> Bool {
        let nsFilename = filename as NSString
        let name = nsFilename.deletingPathExtension
        let ext = nsFilename.pathExtension.isEmpty ? "icns" : nsFilename.pathExtension
        return url(forResource: name, withExtension: ext) != nil
    }
}

private extension Array where Element == NSRunningApplication {
    func uniquedByBundleIdentifier() -> [NSRunningApplication] {
        var seen = Set<String>()
        return filter { app in
            let key = app.bundleIdentifier ?? String(app.processIdentifier)
            return seen.insert(key).inserted
        }
    }
}
