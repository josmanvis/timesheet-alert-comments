import SwiftUI
import AppKit

@main
struct AppLauncher {
    static func main() throws {
        let args = CommandLine.arguments.dropFirst()
        // macOS app launch arguments start with -, we only trigger CLI mode if there are positional args
        if args.contains(where: { !$0.hasPrefix("-") }) {
            handleCLI()
            exit(0)
        }
        TimesheetApp.main()
    }
}

struct TimesheetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock.badge.exclamationmark", accessibilityDescription: "Timesheet Alert")
            // Ensure the image fits nicely
            button.image?.isTemplate = true
        }
        
        setupMenu()
        
        // Ensure storage exists
        StorageManager.shared.ensureStorageDirectoryExists()
        
        // Start the timer
        TimerManager.shared.startTimer()
        
        // Show settings on startup if enabled
        if AppSettings.shared.showSettingsOnStartup {
            openSettings()
        }
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(triggerAlert),
            name: NSNotification.Name("TimesheetTriggerAlert"),
            object: nil
        )
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Trigger Alert Now", action: #selector(triggerAlert), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Open Logs Folder", action: #selector(openLogsFolder), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc func triggerAlert() {
        TimerManager.shared.triggerAlert()
    }
    
    @objc func openLogsFolder() {
        StorageManager.shared.openStorageDirectory()
    }
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 750, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView())
            self.settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
