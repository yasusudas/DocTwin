import AppKit
import Foundation
import DocTwinCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var libraryURL: URL?
    @Published private(set) var documents: [ReferenceDocument] = []
    @Published private(set) var openTabs: [DocumentTab] = []
    @Published private(set) var selectedTabID: DocumentTab.ID?
    @Published private(set) var statusMessage: String = "解説フォルダを選択してください。"
    @Published private(set) var preparationSummary: String?

    private let manager: LibraryManager
    private let defaults: UserDefaults
    private let lastLibraryPathKey = "lastLibraryPath"
    private var didApplyInitialLibrarySelection = false

    var selectedTab: DocumentTab? {
        guard let selectedTabID else {
            return nil
        }
        return openTabs.first { $0.id == selectedTabID }
    }

    var isShowingLibrary: Bool {
        selectedTabID == nil
    }

    var libraryTitle: String {
        libraryURL?.lastPathComponent ?? "DocTwin"
    }

    var canGoToPreviousPage: Bool {
        selectedTab?.canGoToPreviousPage ?? false
    }

    var canGoToNextPage: Bool {
        selectedTab?.canGoToNextPage ?? false
    }

    init(manager: LibraryManager = LibraryManager(), defaults: UserDefaults = .standard) {
        self.manager = manager
        self.defaults = defaults
        restoreLastLibrary()
    }

    func chooseLibraryFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "選択"
        panel.message = "PDFと同名のMarkdownファイルを置くフォルダを選択してください。"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        setLibrary(url, remember: true)
    }

    func rescanLibrary() {
        guard let libraryURL else {
            chooseLibraryFolder()
            return
        }
        setLibrary(libraryURL, remember: true)
    }

    func showLibrary() {
        selectedTabID = nil
        statusMessage = "PDF一覧を表示しています。"
    }

    func showLibraryOnLaunch() {
        guard !didApplyInitialLibrarySelection else {
            return
        }

        didApplyInitialLibrarySelection = true
        selectedTabID = nil
    }

    func openDocument(_ document: ReferenceDocument) {
        if openTabs.contains(where: { $0.id == document.id }) {
            selectedTabID = document.id
            statusMessage = "\(document.title) を表示しています。"
            return
        }

        do {
            let tab = try DocumentTab(document: document)
            openTabs.append(tab)
            selectedTabID = tab.id
            statusMessage = "\(document.title) を開きました。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func selectTab(_ tabID: DocumentTab.ID) {
        guard openTabs.contains(where: { $0.id == tabID }) else {
            selectedTabID = nil
            return
        }
        selectedTabID = tabID
    }

    func closeTab(_ tabID: DocumentTab.ID) {
        guard let index = openTabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }

        openTabs.remove(at: index)

        guard selectedTabID == tabID else {
            return
        }

        if openTabs.indices.contains(index) {
            selectedTabID = openTabs[index].id
        } else if let lastTab = openTabs.last {
            selectedTabID = lastTab.id
        } else {
            selectedTabID = nil
        }
    }

    func closeSelectedTab() {
        guard let selectedTabID else {
            return
        }

        closeTab(selectedTabID)
    }

    func reloadExplanation() {
        selectedTab?.reloadExplanation()
    }

    func previousPage() {
        selectedTab?.previousPage()
    }

    func nextPage() {
        selectedTab?.nextPage()
    }

    func updateCurrentPageFromViewer(_ pageIndex: Int) {
        selectedTab?.updateCurrentPageFromViewer(pageIndex)
    }

    private func restoreLastLibrary() {
        if
            let path = defaults.string(forKey: lastLibraryPathKey),
            FileManager.default.fileExists(atPath: path)
        {
            setLibrary(URL(fileURLWithPath: path), remember: false)
            return
        }

        let defaultURL = Self.defaultLibraryURL
        if FileManager.default.fileExists(atPath: defaultURL.path) {
            setLibrary(defaultURL, remember: true)
        }
    }

    private func setLibrary(_ url: URL, remember: Bool) {
        do {
            let result = try manager.prepareLibrary(at: url)
            let scannedDocuments = try manager.documents(in: url)

            libraryURL = url
            documents = scannedDocuments
            preparationSummary = "\(result.pdfCount)件のPDF / Markdown未作成 \(result.missingMarkdownCount)件"

            if remember {
                defaults.set(url.path, forKey: lastLibraryPathKey)
            }

            removeTabsMissingFrom(scannedDocuments)

            if selectedTabID == nil || selectedTab == nil {
                selectedTabID = nil
            }

            statusMessage = scannedDocuments.isEmpty ? "PDFが見つかりません。" : "PDF一覧を読み込みました。"
        } catch {
            statusMessage = error.localizedDescription
            preparationSummary = nil
        }
    }

    private func removeTabsMissingFrom(_ scannedDocuments: [ReferenceDocument]) {
        let validIDs = Set(scannedDocuments.map(\.id))
        openTabs.removeAll { !validIDs.contains($0.id) }

        if let selectedTabID, !validIDs.contains(selectedTabID) {
            self.selectedTabID = nil
        }
    }

    private static var defaultLibraryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("DocTwin", isDirectory: true)
    }
}
