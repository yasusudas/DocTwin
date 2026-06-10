import AppKit
import SwiftUI

@main
struct DocTwinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("DocTwin") {
            ContentView()
                .environmentObject(viewModel)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandMenu("ページ") {
                Button("前のページ") {
                    viewModel.previousPage()
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!viewModel.canGoToPreviousPage)

                Button("次のページ") {
                    viewModel.nextPage()
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(!viewModel.canGoToNextPage)
            }

            CommandMenu("AI生成") {
                Button("CLI設定...") {
                    MarkdownCLISettingsWindowController.shared.show()
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidFinishRestoringWindows(_:)),
            name: NSApplication.didFinishRestoringWindowsNotification,
            object: NSApp
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuLocalizer.shared.localizeMainMenu()
        DispatchQueue.main.async {
            MenuLocalizer.shared.localizeMainMenu()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            MenuLocalizer.shared.localizeMainMenu()
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        MenuLocalizer.shared.localizeMainMenu()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    @objc private func applicationDidFinishRestoringWindows(_ notification: Notification) {
        NSApp.completeStateRestoration()
    }
}
