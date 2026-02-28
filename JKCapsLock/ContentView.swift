import SwiftUI
import AppKit

//
final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var capsMonitor: CapsLockMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        capsMonitor = CapsLockMonitor()
        statusBarController = StatusBarController(capsMonitor: capsMonitor!)
        capsMonitor?.onChange = { [weak self] isOn in
            DispatchQueue.main.async {
                self?.statusBarController?.updateAppearance(isCapsOn: isOn)
            }
        }
        // push initial state
        statusBarController?.updateAppearance(isCapsOn: capsMonitor?.isCapsLockOn ?? false)
    }

    func applicationWillTerminate(_ notification: Notification) {
        capsMonitor?.stop()
    }
}

/// Monitors Caps Lock state using a combination of CGEventSource key state query (initial) and NSEvent flag-change monitoring.
final class CapsLockMonitor {
    // kVK_CapsLock = 0x39 (57)
    private let capsKeyCode: CGKeyCode = 57
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // Current state
    private(set) var isCapsLockOn: Bool = false

    /// Called when state changes
    var onChange: ((Bool) -> Void)?

    init() {
        isCapsLockOn = CapsLockMonitor.queryCapsLockState(keyCode: capsKeyCode)
        startMonitoring()
    }

    deinit {
        stop()
    }

    func stop() {
        if let g = globalMonitor {
            NSEvent.removeMonitor(g)
            globalMonitor = nil
        }
        if let l = localMonitor {
            NSEvent.removeMonitor(l)
            localMonitor = nil
        }
    }

    private func startMonitoring() {
        // Global monitor: receives flagsChanged events even when app isn't active
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.flagsChanged(event: event)
        }

        // Local monitor: receives events when app is active (safer for immediate response)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.flagsChanged(event: event)
            return event
        }
    }

    private func flagsChanged(event: NSEvent) {
        let newState = event.modifierFlags.contains(.capsLock)
        if newState != isCapsLockOn {
            isCapsLockOn = newState
            onChange?(newState)
        }
    }

    /// Query current hardware state using CGEventSource keyState
    private static func queryCapsLockState(keyCode: CGKeyCode) -> Bool {
        return CGEventSource.keyState(.combinedSessionState, key: keyCode)
    }
}

/// Controls the menu bar item and its appearance
final class StatusBarController {
    private var statusItem: NSStatusItem
    private var capsMonitor: CapsLockMonitor

    init(capsMonitor: CapsLockMonitor) {
        self.capsMonitor = capsMonitor
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // DO NOT set button.action/target when using statusItem.menu
        // just set an initial appearance
        updateAppearance(isCapsOn: capsMonitor.isCapsLockOn)

        // build and attach the menu
        constructMenu()
    }

    private func constructMenu() {
        let menu = NSMenu()

        // show a non-clickable status label
        let statusLabel = NSMenuItem(title: "Caps Lock: \(capsMonitor.isCapsLockOn ? "ON" : "OFF")",
                                     action: nil,
                                     keyEquivalent: "")
        statusLabel.isEnabled = false
       // menu.addItem(statusLabel)

        menu.addItem(NSMenuItem.separator())

        // create quit item and set target to self so selector resolves
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }


    func updateAppearance(isCapsOn: Bool) {
        guard let button = statusItem.button else { return }

        // Prefer SF Symbol if available; fall back to a text indicator
        if #available(macOS 11.0, *) {
            if let image = NSImage(systemSymbolName: isCapsOn ? "capslock.fill" : "capslock", accessibilityDescription: nil) {
                image.isTemplate = true // respects dark/light menu bar
                button.image = image
                button.title = ""
                return
            }
        }

        // Fallback: show "⇪" plus ON/OFF small text
        let title = isCapsOn ? "⇪ ON" : "⇪ off"
        button.image = nil
        button.title = title
    }

    @objc private func menuClicked(_ sender: Any?) {
        // Left click opens menu by default because we assigned one; right click could be used to toggle.
        // We'll allow right-click to toggle caps lock (simulate press) — BUT note: programmatically toggling Caps Lock
        // is non-trivial and system-level; so here we just open menu. If you want to toggle Caps Lock key state,
        // you need to synthesize a keyboard event which may require permissions and is not recommended.
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
//
// NOTES for the developer / user:
// 1) This is a minimal single-file macOS Status Bar app using SwiftUI app lifecycle + AppDelegate.
// 2) To use in Xcode: create a new macOS App project (SwiftUI), replace the main App file with this file.
// 3) The code uses NSEvent global/local monitors to watch for flagsChanged events and uses
//    CGEventSource.keyState to read the initial Caps Lock state.
// 4) If the SF Symbol "capslock" or "capslock.fill" isn't available on your macOS version, the code
//    falls back to a simple title "⇪ ON" / "⇪ off".
// 5) If you plan to distribute this app widely, test on Intel and Apple Silicon, and consider
//    prompting the user for Accessibility permission if you expand to more invasive input monitoring.
// 6) For better UX, you might add: a prefs window to choose icon/text, sound, or visual toast when caps is on,
//    and a toggle to show/hide the menu bar icon on login.
//
// Optional improvement directions:
// - Use an image asset (colored template) for clearer visual state.
// - Add launch-at-login using ServiceManagement framework.
// - Add Settings screen (SwiftUI) to let user choose text or SF Symbol and whether a notification should be shown.

