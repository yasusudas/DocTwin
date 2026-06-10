import AppKit
import Foundation
import DocTwinCore

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var libraryURL: URL?
    @Published private(set) var libraryTree: LibraryFolder?
    @Published private(set) var currentFolderID: LibraryFolder.ID?
    @Published private(set) var documents: [ReferenceDocument] = []
    @Published private(set) var openTabs: [DocumentTab] = []
    @Published private(set) var selectedTabID: DocumentTab.ID?
    @Published private(set) var statusMessage: String = "解説フォルダを選択してください。"
    @Published private(set) var preparationSummary: String?
    @Published private(set) var globalSortOrder: LibrarySortOrder = .nameAscending
    @Published private(set) var folderSortOrders: [String: LibrarySortOrder] = [:]

    private let manager: LibraryManager
    private let defaults: UserDefaults
    private let lastLibraryPathKey = "lastLibraryPath"
    private let globalSortOrderKey = "globalSortOrder"
    private let folderSortOrdersKey = "folderSortOrders"
    private let openTabPathsKey = "openTabPaths"
    private let openTabPageIndicesKey = "openTabPageIndices"
    private let selectedTabPathKey = "selectedTabPath"
    private let isShowingLibraryKey = "isShowingLibrary"
    private var didApplyInitialLibrarySelection = false
    private var didRestoreOpenTabs = false
    private var didRestoreSelectedTab = false
    private var libraryChangeMonitor: LibraryChangeMonitor?
    private var monitoredLibraryPath: String?
    private var automaticRescanTask: Task<Void, Never>?

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

    var currentFolder: LibraryFolder? {
        guard let libraryTree else {
            return nil
        }

        guard let currentFolderID else {
            return libraryTree
        }

        return libraryTree.folder(withID: currentFolderID) ?? libraryTree
    }

    var currentFolderPath: [LibraryFolder] {
        guard let libraryTree else {
            return []
        }

        guard let currentFolderID else {
            return [libraryTree]
        }

        return libraryTree.path(to: currentFolderID) ?? [libraryTree]
    }

    var canNavigateToParentFolder: Bool {
        guard let libraryTree, let currentFolder else {
            return false
        }

        return currentFolder.id != libraryTree.id
    }

    var canGoToPreviousPage: Bool {
        selectedTab?.canGoToPreviousPage ?? false
    }

    var canGoToNextPage: Bool {
        selectedTab?.canGoToNextPage ?? false
    }

    var currentFolderSortOrder: LibrarySortOrder {
        guard let currentFolder else {
            return globalSortOrder
        }

        return sortOrder(for: currentFolder)
    }

    init(manager: LibraryManager = LibraryManager(), defaults: UserDefaults = .standard) {
        self.manager = manager
        self.defaults = defaults
        restoreSortSettings()
        restoreLastLibrary()
    }

    deinit {
        automaticRescanTask?.cancel()
        libraryChangeMonitor?.stop()
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
        statusMessage = currentFolder.map { "\($0.name) を表示しています。" } ?? "PDF一覧を表示しています。"
        saveOpenTabState()
    }

    func showLibraryOnLaunch() {
        guard !didApplyInitialLibrarySelection else {
            return
        }

        didApplyInitialLibrarySelection = true
        guard !didRestoreSelectedTab else {
            return
        }
        selectedTabID = nil
    }

    func openFolder(_ folder: LibraryFolder) {
        currentFolderID = folder.id
        selectedTabID = nil
        statusMessage = "\(folder.name) を表示しています。"
        saveOpenTabState()
    }

    func showFolder(_ folderID: LibraryFolder.ID) {
        guard let folder = libraryTree?.folder(withID: folderID) else {
            return
        }

        openFolder(folder)
    }

    func showParentFolder() {
        guard canNavigateToParentFolder else {
            return
        }

        let path = currentFolderPath
        guard path.count >= 2 else {
            return
        }

        openFolder(path[path.count - 2])
    }

    func openDocument(_ document: ReferenceDocument) {
        if openTabs.contains(where: { $0.id == document.id }) {
            selectedTabID = document.id
            statusMessage = "\(document.title) を表示しています。"
            saveOpenTabState()
            return
        }

        do {
            let tab = try makeDocumentTab(document: document)
            openTabs.append(tab)
            selectedTabID = tab.id
            statusMessage = "\(document.title) を開きました。"
            saveOpenTabState()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func selectTab(_ tabID: DocumentTab.ID) {
        guard openTabs.contains(where: { $0.id == tabID }) else {
            selectedTabID = nil
            saveOpenTabState()
            return
        }
        selectedTabID = tabID
        saveOpenTabState()
    }

    func moveTab(_ tabID: DocumentTab.ID, to destinationIndex: Int) {
        guard let sourceIndex = openTabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }

        let tab = openTabs.remove(at: sourceIndex)
        let insertionIndex = min(max(destinationIndex, 0), openTabs.count)

        guard sourceIndex != insertionIndex else {
            openTabs.insert(tab, at: sourceIndex)
            return
        }

        openTabs.insert(tab, at: insertionIndex)
        saveOpenTabState()
    }

    func closeTab(_ tabID: DocumentTab.ID) {
        guard let index = openTabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }

        openTabs.remove(at: index)

        guard selectedTabID == tabID else {
            saveOpenTabState()
            return
        }

        if openTabs.indices.contains(index) {
            selectedTabID = openTabs[index].id
        } else if let lastTab = openTabs.last {
            selectedTabID = lastTab.id
        } else {
            selectedTabID = nil
        }

        saveOpenTabState()
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

    func sortedFolders(in folder: LibraryFolder) -> [LibraryFolder] {
        folder.folders.sorted { compare($0.url, $1.url, order: sortOrder(for: folder)) }
    }

    func sortedDocuments(in folder: LibraryFolder) -> [ReferenceDocument] {
        folder.documents.sorted { compare($0.pdfURL, $1.pdfURL, order: sortOrder(for: folder)) }
    }

    func setCurrentFolderSortOrder(_ sortOrder: LibrarySortOrder) {
        guard let currentFolder else {
            return
        }

        folderSortOrders[currentFolder.id] = sortOrder
        saveFolderSortOrders()
        statusMessage = "\(currentFolder.name) の並び順を \(sortOrder.title) にしました。"
    }

    func applySortOrderToAllFolders(_ sortOrder: LibrarySortOrder) {
        globalSortOrder = sortOrder
        folderSortOrders.removeAll()
        defaults.set(sortOrder.rawValue, forKey: globalSortOrderKey)
        saveFolderSortOrders()
        statusMessage = "すべてのフォルダの並び順を \(sortOrder.title) にしました。"
    }

    func sortOrder(for folder: LibraryFolder) -> LibrarySortOrder {
        folderSortOrders[folder.id] ?? globalSortOrder
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

    private func setLibrary(_ url: URL, remember: Bool, isAutomaticUpdate: Bool = false) {
        do {
            let result = try manager.prepareLibrary(at: url)
            let scannedTree = try manager.libraryTree(in: url)
            let scannedDocuments = scannedTree.recursiveDocuments
            let previousFolderID = currentFolderID

            libraryURL = url
            libraryTree = scannedTree
            currentFolderID = previousFolderID.flatMap { scannedTree.folder(withID: $0)?.id } ?? scannedTree.id
            documents = scannedDocuments
            preparationSummary = "\(result.pdfCount)件のPDF / Markdown未作成 \(result.missingMarkdownCount)件"
            startMonitoringLibrary(at: url)

            if remember {
                defaults.set(url.path, forKey: lastLibraryPathKey)
            }

            if didRestoreOpenTabs {
                removeTabsMissingFrom(scannedDocuments)
            } else {
                restoreOpenTabs(from: scannedDocuments)
                didRestoreOpenTabs = true
            }

            if isAutomaticUpdate {
                openTabs.forEach { $0.reloadExplanation() }
            }

            if selectedTabID == nil || selectedTab == nil {
                selectedTabID = nil
            }

            saveOpenTabState()

            if isAutomaticUpdate {
                statusMessage = "フォルダの変更を反映しました。"
            } else if scannedDocuments.isEmpty {
                statusMessage = scannedTree.folders.isEmpty ? "PDFが見つかりません。" : "フォルダ一覧を読み込みました。"
            } else {
                statusMessage = "PDF一覧を読み込みました。"
            }
        } catch {
            statusMessage = error.localizedDescription
            preparationSummary = nil
        }
    }

    private func startMonitoringLibrary(at url: URL) {
        let path = url.standardizedFileURL.path
        guard monitoredLibraryPath != path else {
            return
        }

        libraryChangeMonitor?.stop()
        automaticRescanTask?.cancel()

        libraryChangeMonitor = LibraryChangeMonitor(url: url) { [weak self] in
            self?.scheduleAutomaticLibraryRescan()
        }
        monitoredLibraryPath = path
    }

    private func scheduleAutomaticLibraryRescan() {
        guard let libraryURL else {
            return
        }

        automaticRescanTask?.cancel()

        let url = libraryURL
        automaticRescanTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)

            guard !Task.isCancelled else {
                return
            }

            self?.applyAutomaticLibraryUpdate(for: url)
        }
    }

    private func applyAutomaticLibraryUpdate(for url: URL) {
        guard libraryURL?.standardizedFileURL.path == url.standardizedFileURL.path else {
            return
        }

        setLibrary(url, remember: false, isAutomaticUpdate: true)
    }

    private func removeTabsMissingFrom(_ scannedDocuments: [ReferenceDocument]) {
        let validIDs = Set(scannedDocuments.map(\.id))
        openTabs.removeAll { !validIDs.contains($0.id) }

        if let selectedTabID, !validIDs.contains(selectedTabID) {
            self.selectedTabID = nil
        }
    }

    private func restoreOpenTabs(from scannedDocuments: [ReferenceDocument]) {
        let documentsByID = Dictionary(uniqueKeysWithValues: scannedDocuments.map { ($0.id, $0) })
        let pageIndicesByID = restoreOpenTabPageIndices()
        let restoredTabs = (defaults.stringArray(forKey: openTabPathsKey) ?? []).compactMap { path -> DocumentTab? in
            guard let document = documentsByID[path] else {
                return nil
            }

            return try? makeDocumentTab(
                document: document,
                initialPageIndex: pageIndicesByID[path] ?? 0
            )
        }

        openTabs = restoredTabs

        guard defaults.bool(forKey: isShowingLibraryKey) == false else {
            selectedTabID = nil
            return
        }

        if
            let selectedTabPath = defaults.string(forKey: selectedTabPathKey),
            restoredTabs.contains(where: { $0.id == selectedTabPath })
        {
            selectedTabID = selectedTabPath
            didRestoreSelectedTab = true
        } else if let firstTab = restoredTabs.first {
            selectedTabID = firstTab.id
            didRestoreSelectedTab = true
        } else {
            selectedTabID = nil
        }
    }

    private func saveOpenTabState() {
        defaults.set(openTabs.map(\.id), forKey: openTabPathsKey)
        defaults.set(
            Dictionary(uniqueKeysWithValues: openTabs.map { ($0.id, $0.currentPageIndex) }),
            forKey: openTabPageIndicesKey
        )
        defaults.set(selectedTabID == nil, forKey: isShowingLibraryKey)

        if let selectedTabID {
            defaults.set(selectedTabID, forKey: selectedTabPathKey)
        } else {
            defaults.removeObject(forKey: selectedTabPathKey)
        }

        defaults.synchronize()
    }

    private func makeDocumentTab(document: ReferenceDocument, initialPageIndex: Int = 0) throws -> DocumentTab {
        let tab = try DocumentTab(document: document, initialPageIndex: initialPageIndex)
        tab.onPageIndexChanged = { [weak self] _, _ in
            Task { @MainActor in
                self?.saveOpenTabState()
            }
        }
        return tab
    }

    private func restoreOpenTabPageIndices() -> [String: Int] {
        guard let storedPageIndices = defaults.dictionary(forKey: openTabPageIndicesKey) else {
            return [:]
        }

        return storedPageIndices.reduce(into: [:]) { result, item in
            if let pageIndex = item.value as? Int {
                result[item.key] = pageIndex
            } else if let pageIndex = item.value as? NSNumber {
                result[item.key] = pageIndex.intValue
            }
        }
    }

    private func restoreSortSettings() {
        if
            let rawSortOrder = defaults.string(forKey: globalSortOrderKey),
            let sortOrder = LibrarySortOrder(rawValue: rawSortOrder)
        {
            globalSortOrder = sortOrder
        }

        guard let rawFolderSortOrders = defaults.dictionary(forKey: folderSortOrdersKey) as? [String: String] else {
            return
        }

        folderSortOrders = rawFolderSortOrders.reduce(into: [:]) { result, item in
            if let sortOrder = LibrarySortOrder(rawValue: item.value) {
                result[item.key] = sortOrder
            }
        }
    }

    private func saveFolderSortOrders() {
        let rawFolderSortOrders = folderSortOrders.mapValues(\.rawValue)
        defaults.set(rawFolderSortOrders, forKey: folderSortOrdersKey)
    }

    private func compare(_ lhs: URL, _ rhs: URL, order: LibrarySortOrder) -> Bool {
        switch order {
        case .nameAscending:
            return compareName(lhs, rhs) == .orderedAscending
        case .nameDescending:
            return compareName(lhs, rhs) == .orderedDescending
        case .modifiedNewest:
            return compareModificationDate(lhs, rhs, newestFirst: true)
        case .modifiedOldest:
            return compareModificationDate(lhs, rhs, newestFirst: false)
        }
    }

    private func compareName(_ lhs: URL, _ rhs: URL) -> ComparisonResult {
        lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent)
    }

    private func compareModificationDate(_ lhs: URL, _ rhs: URL, newestFirst: Bool) -> Bool {
        let lhsDate = modificationDate(for: lhs) ?? .distantPast
        let rhsDate = modificationDate(for: rhs) ?? .distantPast

        guard lhsDate != rhsDate else {
            return compareName(lhs, rhs) == .orderedAscending
        }

        return newestFirst ? lhsDate > rhsDate : lhsDate < rhsDate
    }

    private func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private static var defaultLibraryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("DocTwin", isDirectory: true)
    }
}
