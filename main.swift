import Cocoa

// A tiny menu-bar "keep awake" app.
//
// When active it does exactly what you'd type by hand:
//   caffeinate -dimsu          → prevent display / idle / disk / system sleep + keep "user active"
//   sudo pmset -a disablesleep 1  → also stop the forced sleep that happens when you CLOSE THE LID
//
// The plain IOKit assertion (what the old version did, == `caffeinate -d`) keeps the screen on
// while the lid is open, but the Mac still sleeps the instant you shut the lid. `disablesleep`
// is the only thing that defeats that — and it needs root, so we ask for admin once per toggle.
//
// Everything is undone when you toggle off, when a timer expires, or when you quit, so the
// laptop can sleep normally again the moment you're done. ☕
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var caffeinate: Process?       // the live `caffeinate -dimsu` child
    private var active = false
    private var sleepDisabled = false      // did we successfully run `pmset disablesleep 1`?
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
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
    }

    // Make sure we never leave the machine unable to sleep if we're killed/quit.
    func applicationWillTerminate(_ notification: Notification) {
        stopAssertion()
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
        active ? stopAssertion() : startAssertion()
    }

    @objc private func quit() {
        stopAssertion()
        NSApplication.shared.terminate(nil)
    }

    private func startAssertion() {
        // 1) Hold the full set of sleep assertions via Apple's own tool, kept alive as a child
        //    process for as long as we're active (no timeout, no utility → runs until we kill it).
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        p.arguments = ["-dimsu"]
        do {
            try p.run()
            caffeinate = p
        } catch {
            caffeinate = nil
        }

        // 2) Defeat lid-close (clamshell) sleep. Needs root → one admin prompt.
        sleepDisabled = setDisableSleep(true)

        active = caffeinate != nil || sleepDisabled
        updateIcon()
    }

    private func stopAssertion() {
        autoOffTimer?.invalidate()
        autoOffTimer = nil

        if let p = caffeinate, p.isRunning {
            p.terminate()
        }
        caffeinate = nil

        if sleepDisabled {
            _ = setDisableSleep(false)
            sleepDisabled = false
        }

        active = false
        updateIcon()
    }

    /// Runs `pmset -a disablesleep <0|1>` as root via a native admin prompt.
    /// Returns true on success (false if the user cancelled or it failed).
    @discardableResult
    private func setDisableSleep(_ on: Bool) -> Bool {
        let value = on ? "1" : "0"
        let script = "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func updateIcon() {
        // Filled cup = awake (active), outline cup = normal sleep allowed.
        let name = active ? "cup.and.saucer.fill" : "cup.and.saucer"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: "Keep awake")
        img?.isTemplate = true
        statusItem.button?.image = img

        if !active {
            statusItem.button?.toolTip = "Sleep allowed — click to keep awake"
        } else if sleepDisabled {
            statusItem.button?.toolTip = "Awake (lid-close sleep off) — click to allow sleep"
        } else {
            statusItem.button?.toolTip = "Awake (lid open only) — click to allow sleep"
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // menu-bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
