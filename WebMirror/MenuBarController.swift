import SwiftUI
import LaunchAtLogin

class MenuBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var launchAtLoginItem: NSMenuItem?
    private var webcamManager: WebcamManager
    private var menu: NSMenu
    private var currentPopoverSize: (width: CGFloat, height: CGFloat) = (480, 240)
    private var globalClickMonitor: Any?
    private let iconNames = ["camcoder", "dslr", "eyes", "rearmirror", "sidemirror", "webcam", "webcam2"]


    override init() {
        if let savedSize = UserDefaults.standard.array(forKey: "SavedPopoverSize") as? [CGFloat], savedSize.count == 2 {
                currentPopoverSize = (savedSize[0], savedSize[1])
            }
        
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        self.webcamManager = WebcamManager()
        self.menu = NSMenu()

        super.init()
        
        loadSavedIcon()

        if let button = statusItem.button {
            let icon = NSImage(named: "webcam")
            icon?.isTemplate = true
            button.image = icon
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }


        popover.contentViewController = NSHostingController(rootView: WebcamView(webcamManager: webcamManager))
        popover.behavior = .transient
        popover.delegate = self

        setupMenu()
    }

    
    private func setupMenu() {
        menu.removeAllItems()
        
        menu.addItem(NSMenuItem.separator())

        let changeSizeLabelItem = NSMenuItem()
        changeSizeLabelItem.attributedTitle = NSAttributedString(string: "Change Preview Size", attributes: [.font: NSFont.systemFont(ofSize: 11)])
        menu.addItem(changeSizeLabelItem)
            
        let smallSizeItem = NSMenuItem(title: "Smol", action: #selector(setSmallSize), keyEquivalent: "")
        smallSizeItem.target = self
        
        let mediumSizeItem = NSMenuItem(title: "Average", action: #selector(setMediumSize), keyEquivalent: "")
        mediumSizeItem.target = self
    
        let largeSizeItem = NSMenuItem(title: "Beeg", action: #selector(setLargeSize), keyEquivalent: "")
        largeSizeItem.target = self
    
        menu.addItem(smallSizeItem)
        menu.addItem(mediumSizeItem)
        menu.addItem(largeSizeItem)

        menu.addItem(NSMenuItem.separator())
        
        let moreMenu = NSMenu()
            let chooseRandomIconItem = NSMenuItem(title: "Choose Random Icon", action: #selector(chooseRandomIcon), keyEquivalent: "")
            chooseRandomIconItem.target = self
            moreMenu.addItem(chooseRandomIconItem)
        
            moreMenu.addItem(NSMenuItem.separator())

            launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
                launchAtLoginItem?.target = self
                updateLaunchAtLoginState()
                if let launchAtLoginItem = launchAtLoginItem {
                    moreMenu.addItem(launchAtLoginItem)
                }
            
            let resetPermissionsItem = NSMenuItem(title: "Reset Permissions", action: #selector(resetPermissions), keyEquivalent: "")
                resetPermissionsItem.target = self
                moreMenu.addItem(resetPermissionsItem)
            
            let aboutItem = NSMenuItem(title: "About", action: #selector(openAboutWindow), keyEquivalent: "")
            aboutItem.target = self
            moreMenu.addItem(aboutItem)
            
            let aboutMenuItem = NSMenuItem(title: "More", action: nil, keyEquivalent: "")
                menu.setSubmenu(moreMenu, for: aboutMenuItem)
                menu.addItem(aboutMenuItem)
        
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit WebMirror", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    
    @objc private func statusItemClicked(_ sender: AnyObject?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover()
        }
    }
    
    
    @objc private func setSmallSize() {
        updatePopoverSize(width: 380, height: 190)
    }

    @objc private func setMediumSize() {
        updatePopoverSize(width: 480, height: 240)
    }

    @objc private func setLargeSize() {
        updatePopoverSize(width: 640, height: 320)
    }

    
    private func updatePopoverSize(width: CGFloat, height: CGFloat) {
        currentPopoverSize = (width, height)
        popover.contentSize = NSSize(width: width, height: height)

        // Save to UserDefaults
        UserDefaults.standard.set([width, height], forKey: "SavedPopoverSize")

        if popover.isShown {
            popover.performClose(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.popover.contentViewController = NSHostingController(rootView: WebcamView(webcamManager: self.webcamManager))
                self.popover.contentSize = NSSize(width: width, height: height)
                self.showPopover()
            }
        }

        updateSizeCheckmarks()
    }
    
    
    private func updateSizeCheckmarks() {
        for item in menu.items {
            if let submenu = item.submenu {
                for subItem in submenu.items {
                    switch subItem.title {
                    case "Smol":
                        subItem.state = (currentPopoverSize == (380, 190)) ? .on : .off
                    case "Average":
                        subItem.state = (currentPopoverSize == (480, 240)) ? .on : .off
                    case "Beeg":
                        subItem.state = (currentPopoverSize == (640, 320)) ? .on : .off
                    default:
                        break
                    }
                }
            }
        }
    }



    private func togglePopover() {
        if popover.isShown {
            print("[DEBUG] Popover is shown → Closing popover")
            popover.performClose(nil)
            closePopover()
        } else {
            print("[DEBUG] Popover is not shown → Showing popover and starting session")
            showPopover()
        }
    }

    
    private func showPopover() {
        if let button = statusItem.button {
            popover.contentViewController = NSHostingController(rootView: WebcamView(webcamManager: webcamManager))
            popover.contentSize = NSSize(width: currentPopoverSize.width, height: currentPopoverSize.height)

            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            print("[DEBUG] Popover shown, starting session")
            startSession()
            
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                self?.closePopover()
            }
        }
    }
    
    
    private func closePopover() {
        popover.performClose(nil)

        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }

        print("[DEBUG] Popover closed and global click monitor removed")
    }


    func popoverDidClose(_ notification: Notification) {
        print("[DEBUG] Popover closed, stopping session")
        stopSession()
    }

    
    private func startSession() {
        DispatchQueue.global(qos: .background).async {
            print("[DEBUG] Starting camera session...")
            self.webcamManager.startSession()

            DispatchQueue.main.async {
                print("[DEBUG] Camera session started (ensured on main thread)")
            }
        }
    }
    

    private func stopSession() {
        DispatchQueue.global(qos: .background).async {
            print("[DEBUG] Stopping camera session...")
            self.webcamManager.stopSession()

            DispatchQueue.main.async {
                print("[DEBUG] Camera session stopped (ensured on main thread)")
            }
        }
    }
    
    
    @objc private func chooseRandomIcon() {
        guard let randomIconName = iconNames.randomElement() else { return }

        UserDefaults.standard.set(randomIconName, forKey: "selectedMenuBarIcon")

        updateMenuBarIcon(named: randomIconName)
    }
    
    
    private func updateMenuBarIcon(named iconName: String) {
        if let button = statusItem.button {
            let icon = NSImage(named: iconName)
            icon?.isTemplate = true
            button.image = icon
        }
    }
    
    
    private func loadSavedIcon() {
        let savedIconName = UserDefaults.standard.string(forKey: "selectedMenuBarIcon") ?? "webcam"
        updateMenuBarIcon(named: savedIconName)
    }
    
    
    @objc private func resetPermissions() {
        let alert = NSAlert()
        alert.messageText = "Reset Camera Permissions"
        alert.informativeText = "Have you tried turning it off and on again? :3"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open Settings")
        alert.runModal()

        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
        NSWorkspace.shared.open(url)
    }

    
    @objc private func openAboutWindow() {
        let windowWidth: CGFloat = 280
        let windowHeight: CGFloat = 150

        let aboutWindow = NSWindow(
            contentRect: NSMakeRect(0, 0, windowWidth, windowHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        aboutWindow.title = ""
        aboutWindow.isReleasedWhenClosed = false
        aboutWindow.level = .floating
        aboutWindow.center()

        let contentView = NSView(frame: NSMakeRect(0, 0, windowWidth, windowHeight))

        let iconSize: CGFloat = 60
        let spacing: CGFloat = 4
        let totalContentHeight = iconSize + 45
        let startY = (windowHeight - totalContentHeight) / 2 + iconSize

        let appIcon = NSImageView(frame: NSRect(x: (windowWidth - iconSize) / 2, y: startY, width: iconSize, height: iconSize))
        if let icon = NSApp.applicationIconImage {
            appIcon.image = icon
        }

        // App Name
        let appNameLabel = NSTextField(labelWithString: "WebMirror")
        appNameLabel.frame = NSRect(x: 0, y: startY - (20 + spacing), width: windowWidth, height: 20)
        appNameLabel.alignment = .center
        appNameLabel.font = NSFont.boldSystemFont(ofSize: 14)

        let versionLabel = NSTextField(labelWithString: "Version :3 (Just for Funzies)")
        versionLabel.frame = NSRect(x: 0, y: startY - (40 + 2 * spacing), width: windowWidth, height: 20)
        versionLabel.alignment = .center
        versionLabel.font = NSFont.systemFont(ofSize: 10)

        let authorLabel = NSTextField(labelWithString: "by ")
        authorLabel.frame = NSRect(x: 0, y: startY - (65 + 3 * spacing), width: windowWidth, height: 20)
        authorLabel.alignment = .center
        authorLabel.font = NSFont.systemFont(ofSize: 10)
        authorLabel.textColor = NSColor.secondaryLabelColor

        contentView.addSubview(appIcon)
        contentView.addSubview(appNameLabel)
        contentView.addSubview(versionLabel)
        contentView.addSubview(authorLabel)

        aboutWindow.contentView = contentView
        aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    
    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.isEnabled.toggle()
        updateLaunchAtLoginState()
    }
    
    
    private func updateLaunchAtLoginState() {
        launchAtLoginItem?.state = LaunchAtLogin.isEnabled ? .on : .off
    }
    

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
