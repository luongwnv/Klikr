import AppKit
import Carbon
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = AppSettings()
    private let model = AppModel()
    private let labels = LabelProvider()
    private let monitor = PhysicalMonitor()
    private let interceptor = ClickInterceptor()
    private let poster = EventPoster()
    private var layouts: [Layout] = []
    private var engine: KeyboardEngine!
    private var panel: KeyboardPanelController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var permissionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var appliedLayoutID = ""
    private var loginError = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        reloadLayouts()
        guard let initial = currentLayout() else {
            let alert = NSAlert()
            alert.messageText = L("alert.noLayouts")
            alert.informativeText = L("alert.noLayouts.info", LayoutStore.userDirectory.path)
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        appliedLayoutID = initial.id
        engine = KeyboardEngine(layout: initial, poster: poster)
        panel = KeyboardPanelController(engine: engine, labels: labels, settings: settings)
        if !PreLogin.isActiveMode {
            panel.view.contextMenuProvider = { [weak self] in
                let m = NSMenu()
                self?.populate(m)
                return m
            }
        }

        monitor.handler = { [weak self] event, flags in
            MainActor.assumeIsolated { self?.handlePhysical(event, flags: flags) }
        }
        interceptor.onDown = { [weak self] point in
            MainActor.assumeIsolated {
                let hit = self?.panel.interceptClick(at: point) ?? false
                PreLogin.log("tap click at \(point) hitKey=\(hit)")
                return hit
            }
        }
        interceptor.onUp = { [weak self] in
            MainActor.assumeIsolated { self?.engine.release() }
        }

        if !PreLogin.isActiveMode { setupStatusItem() }
        panel.apply()

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applySettings() }
            .store(in: &cancellables)

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.labels.reload()
                self?.panel.view.needsDisplay = true
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.panel.reposition() }
        }

        // At the login window there is no user session: no menu bar item, prompts or login items
        if PreLogin.isActiveMode {
            let canPost = CGPreflightPostEventAccess()
            poster.useIOHID = !canPost
            PreLogin.log("start uid=\(getuid()) euid=\(geteuid()) canPost=\(canPost) canListen=\(CGPreflightListenEventAccess()) "
                         + "axTrusted=\(AXIsProcessTrusted()) secureInput=\(IsSecureEventInputEnabled()) layout=\(initial.id)")
            PreLogin.log("interceptor=\(interceptor.start()) monitor=\(settings.trackPhysical ? monitor.start() : false) "
                         + "window=\(panel.panel.frame) level=\(panel.panel.level.rawValue)")
            return
        }

        if settings.isFirstLaunch {
            settings.isFirstLaunch = false
            setLaunchAtLogin(true)
            if !CGPreflightPostEventAccess() { CGRequestPostEventAccess() }
            if !CGPreflightListenEventAccess() { CGRequestListenEventAccess() }
            showSettings()
        }

        syncLaunchAtLogin()
        refreshPermissions()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshPermissions() }
        }
    }

    /// Opening Klikr again (Finder, Launchpad, Spotlight) while it runs shows the settings window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !PreLogin.isActiveMode { showSettings() }
        return false
    }

    // MARK: Settings & state

    private var colorwayCache: [String: Layout] = [:]

    private func currentLayout() -> Layout? {
        guard let base = layouts.first(where: { $0.id == settings.layoutID }) ?? layouts.first else { return nil }
        guard let cw = settings.colorways[base.id], cw != base.colorwayID else { return base }
        let key = "\(base.id)|\(cw)"
        if let cached = colorwayCache[key] { return cached }
        let l = base.withColorway(cw)
        colorwayCache[key] = l
        return l
    }

    private var layoutKey: String { "\(settings.layoutID)|\(settings.colorways[settings.layoutID] ?? "")" }

    private func reloadLayouts() {
        let result = LayoutStore.load()
        layouts = result.layouts
        colorwayCache = [:]
        model.layouts = layouts.map(LayoutSummary.init)
        model.loadErrors = result.errors
        if let engine, let l = currentLayout() {
            appliedLayoutID = layoutKey
            engine.setLayout(l)
            panel.apply()
        }
        previewKey = ""
        updatePreview()
    }

    private func applySettings() {
        if layoutKey != appliedLayoutID, let l = currentLayout() {
            appliedLayoutID = layoutKey
            engine.setLayout(l)
        }
        panel.apply()
        updateMonitor()
        updatePreview()
        settingsWindow?.title = L("window.settings")
    }

    private var previewKey = ""

    /// Re-renders the settings preview card when what it shows changed and the window is open.
    private func updatePreview() {
        guard settingsWindow?.isVisible == true || model.preview == nil, let l = currentLayout() else { return }
        let key = "\(layoutKey)|\(settings.renderStyle.rawValue)|\(settings.showLegends)"
        guard key != previewKey else { return }
        previewKey = key
        model.preview = Snapshot.previewImage(layout: l, photo: settings.renderStyle == .photo, legends: settings.showLegends)
    }

    private func refreshPermissions() {
        let post = CGPreflightPostEventAccess()
        let listen = CGPreflightListenEventAccess()
        if model.canPost != post { model.canPost = post }
        if model.canListen != listen { model.canListen = listen }
        refreshLoginStatus()
        updateMonitor()
    }

    private func updateMonitor() {
        if model.canPost, !interceptor.isRunning { interceptor.start() }
        if settings.trackPhysical {
            if !monitor.isRunning, model.canListen { monitor.start() }
        } else if monitor.isRunning {
            monitor.stop()
            engine.clearPhysical()
        }
    }

    private func handlePhysical(_ event: PhysicalEvent, flags: CGEventFlags) {
        if case .keyDown(40, false) = event,
           flags.contains([.maskControl, .maskAlternate, .maskCommand]) {
            settings.visible.toggle()
        }
        engine.handlePhysical(event, flags: flags)
    }

    // MARK: Launch at login

    private func setLaunchAtLogin(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "launchAtLoginWanted")
        loginError = false
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            model.loginStatus = L("error.change", error.localizedDescription)
            loginError = true
        }
        refreshLoginStatus()
    }

    /// Re-registers the login item from this copy of the app, so it follows the app after it moves (e.g. to /Applications).
    private func syncLaunchAtLogin() {
        let d = UserDefaults.standard
        let wanted = d.object(forKey: "launchAtLoginWanted") as? Bool ?? (SMAppService.mainApp.status == .enabled)
        d.set(wanted, forKey: "launchAtLoginWanted")
        guard wanted else { return }
        try? SMAppService.mainApp.register()
    }

    private func setPreLogin(_ on: Bool) {
        do {
            if on { try PreLogin.install() } else { try PreLogin.uninstall() }
        } catch {
            model.loginStatus = L("error.change", error.localizedDescription)
            loginError = true
        }
        model.preLoginInstalled = PreLogin.isInstalled
    }

    private func refreshLoginStatus() {
        let status = SMAppService.mainApp.status
        let on = status == .enabled
        if model.launchAtLogin != on { model.launchAtLogin = on }
        if model.preLoginInstalled != PreLogin.isInstalled { model.preLoginInstalled = PreLogin.isInstalled }
        let text: String
        switch status {
        case .requiresApproval: text = L("login.approval")
        case .notFound: text = L("login.notFound")
        default: text = ""
        }
        if !text.isEmpty || !loginError { model.loginStatus = text }
    }

    // MARK: Status item & menus

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = StatusIcon.image()
        statusItem.button?.setAccessibilityLabel("Klikr")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        MainActor.assumeIsolated {
            menu.removeAllItems()
            populate(menu)
        }
    }

    private func populate(_ menu: NSMenu) {
        menu.addItem(item(L(settings.visible ? "toggle.hide" : "toggle.visible"), #selector(toggleVisible)))
        let click = item(L("toggle.clickThrough"), #selector(toggleClickThrough))
        click.state = settings.clickThrough ? .on : .off
        menu.addItem(click)
        let photo = item(L("menu.photo"), #selector(togglePhoto))
        photo.state = settings.renderStyle == .photo ? .on : .off
        menu.addItem(photo)
        let legends = item(L("toggle.legends"), #selector(toggleLegends))
        legends.state = settings.showLegends ? .on : .off
        menu.addItem(legends)
        let track = item(L("toggle.track"), #selector(toggleTracking))
        track.state = settings.trackPhysical ? .on : .off
        menu.addItem(track)

        let layoutMenu = NSMenu()
        for l in layouts {
            let i = item(l.name, #selector(selectLayout(_:)))
            i.representedObject = l.id
            i.state = l.id == appliedLayoutID ? .on : .off
            layoutMenu.addItem(i)
        }
        let layoutItem = NSMenuItem(title: L("sec.layout"), action: nil, keyEquivalent: "")
        layoutItem.submenu = layoutMenu
        menu.addItem(layoutItem)

        let posMenu = NSMenu()
        for a in Anchor.allCases where a != .custom {
            let i = item(a.title, #selector(selectAnchor(_:)))
            i.representedObject = a.rawValue
            i.state = settings.anchor == a ? .on : .off
            posMenu.addItem(i)
        }
        let posItem = NSMenuItem(title: L("tab.position"), action: nil, keyEquivalent: "")
        posItem.submenu = posMenu
        menu.addItem(posItem)

        if !model.canPost || (settings.trackPhysical && !model.canListen) {
            menu.addItem(.separator())
            menu.addItem(item(L("menu.missing"), #selector(openSettings)))
        }
        menu.addItem(.separator())
        menu.addItem(item(L("menu.settings"), #selector(openSettings), key: ","))
        menu.addItem(item(L("menu.quit"), #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func toggleVisible() { settings.visible.toggle() }
    @objc private func toggleClickThrough() { settings.clickThrough.toggle() }
    @objc private func toggleTracking() { settings.trackPhysical.toggle() }
    @objc private func togglePhoto() { settings.renderStyle = settings.renderStyle == .photo ? .vector : .photo }
    @objc private func toggleLegends() { settings.showLegends.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func openSettings() { showSettings() }

    @objc private func selectLayout(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { settings.layoutID = id }
    }

    @objc private func selectAnchor(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let a = Anchor(rawValue: raw) { settings.anchor = a }
    }

    /// Menu bar shown while Settings puts the app in the Dock.
    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("menu.settings"), action: #selector(openSettingsFromMenu), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let winItem = NSMenuItem()
        let winMenu = NSMenu(title: L("menu.window"))
        winMenu.addItem(withTitle: L("menu.close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winMenu.addItem(withTitle: L("menu.minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winItem.submenu = winMenu
        main.addItem(winItem)
        NSApp.mainMenu = main
    }

    @objc private func openSettingsFromMenu() { showSettings() }

    private func showSettings() {
        if settingsWindow == nil {
            let actions = SettingsActions(
                setLaunchAtLogin: { [weak self] on in self?.setLaunchAtLogin(on) },
                setPreLogin: { [weak self] on in self?.setPreLogin(on) },
                openAccessibility: { [weak self] in
                    CGRequestPostEventAccess()
                    self?.openPrivacyPane("Privacy_Accessibility")
                },
                openInputMonitoring: { [weak self] in
                    CGRequestListenEventAccess()
                    self?.openPrivacyPane("Privacy_ListenEvent")
                })
            let host = NSHostingController(rootView: SettingsView(settings: settings, model: model, actions: actions))
            let w = NSWindow(contentViewController: host)
            w.title = L("window.settings")
            // The black header runs under the traffic lights
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.appearance = NSAppearance(named: .aqua)
            w.setContentSize(NSSize(width: 1000, height: 680))
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
            // Back to a menu bar only app once Settings closes
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { _ in
                MainActor.assumeIsolated {
                    Dropdown.close()
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
        updatePreview()
        if !PreLogin.isActiveMode { NSApp.setActivationPolicy(.regular) }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
