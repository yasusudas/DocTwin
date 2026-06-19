import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 0) {
            TabStripView()
                .environmentObject(viewModel)

            Divider()

            Group {
                if let tab = viewModel.selectedTab {
                    DocumentReaderView(tab: tab)
                        .id(tab.id)
                } else {
                    LibraryBrowserView()
                        .environmentObject(viewModel)
                }
            }

            Divider()

            StatusBar()
                .environmentObject(viewModel)
        }
        .frame(minWidth: 980, minHeight: 640)
        .background(
            ZStack {
                KeyboardEventMonitor(
                    onLeftArrow: { viewModel.previousPage() },
                    onRightArrow: { viewModel.nextPage() },
                    onCloseTab: { handleCommandW() }
                )
                .frame(width: 0, height: 0)

                WindowRestorationDisabler()
                    .frame(width: 0, height: 0)
            }
        )
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.chooseLibraryFolder()
                } label: {
                    Label("フォルダを選択", systemImage: "folder")
                }
                .help("フォルダを選択")

                SortMenu()
                    .environmentObject(viewModel)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .inactive {
                viewModel.saveSessionState()
            }
        }
    }

    private func handleCommandW() {
        if viewModel.openTabs.isEmpty {
            (NSApp.keyWindow ?? NSApp.mainWindow)?.miniaturize(nil)
        } else {
            viewModel.closeSelectedTab()
        }
    }
}

private struct StatusBar: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HStack(spacing: 12) {
            Text(viewModel.statusMessage)
                .lineLimit(1)

            if let preparationSummary = viewModel.preparationSummary {
                Text(preparationSummary)
                    .lineLimit(1)
            }

            if viewModel.isSearchIndexing {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.68)
            }

            Text(viewModel.searchIndexStatus)
                .lineLimit(1)

            Spacer()

            if let libraryURL = viewModel.libraryURL {
                Text(libraryURL.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 18)
        .frame(height: 28)
        .background(.bar)
    }
}
