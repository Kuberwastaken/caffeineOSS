import Cocoa
import IOKit.pwr_mgt

// A tiny menu-bar "keep awake" app. Same mechanism as /usr/bin/caffeinate:
// it creates an IOKit power assertion that prevents idle system/display sleep.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var assertionID: IOPMAssertionID = 0
    private var active = false
    private var autoOffTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle (keep awake)", action: #selector(toggle), keyEquivalent: "t")
        menu.addItem(.separator())
        addDuration(to: menu, "Awake for 30 minutes", 30 * 60)
        addDuration(to: menu, "Awake for 1 hour", 60 * 60)
        addDuration(to: menu, "Awake for 2 hours", 2 * 60 * 60)
        addDuration(to: menu, "Awake for 5 hours", 5 * 60 * 60)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        // Left-click the icon to toggle quickly (when no modifier menu is needed),
        // right-click / click shows the menu above.
    }

    private func addDuration(to menu: NSMenu, _ title: String, _ seconds: TimeInterval) {
        let item = NSMenuItem(title: title, action: #selector(activateFor(_:)), keyEquivalent: "")
        item.representedObject = seconds
        item.target = self
        menu.addItem(item)
    }

    @objc private func activateFor(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? TimeInterval else { return }
        if !active { startAssertion() }
        autoOffTimer?.invalidate()
        autoOffTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.stopAssertion()
        }
    }

    @objc private func toggle() {
        autoOffTimer?.invalidate()
        active ? stopAssertion() : startAssertion()
    }

    private func startAssertion() {
        let reason = "CaffeineOSS keeping the Mac awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        active = (result == kIOReturnSuccess)
        updateIcon()
    }

    private func stopAssertion() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        active = false
        autoOffTimer?.invalidate()
        updateIcon()
    }

    private func updateIcon() {
        // Filled cup = awake (active), outline cup = normal sleep allowed.
        let name = active ? "cup.and.saucer.fill" : "cup.and.saucer"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Keep awake")
        img?.isTemplate = true
        statusItem.button?.image = img
        statusItem.button?.toolTip = active ? "Awake — click to allow sleep" : "Asleep allowed — click to keep awake"
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu-bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
