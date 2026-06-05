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
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
