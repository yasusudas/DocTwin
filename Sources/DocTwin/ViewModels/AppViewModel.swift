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
    @Published var searchQuery: String = "" {
        didSet {
            schedulePDFSearch()
        }
    }
    @Published private(set) var searchResults: [PDFSearchResult] = []
    @Published private(set) var isSearchIndexing = false
    @Published private(set) var searchIndexStatus: String = "全文検索インデックス未作成"

    private let defaults: UserDefaults
    private let pdfSearchIndex: PDFSearchIndex
    private let lastLibraryPathKey = "lastLibraryPath"
    private let globalSortOrderKey = "globalSortOrder"
    private let folderSortOrdersKey = "folderSortOrders"
    private let openTabPathsKey = "openTabPaths"
    private let openTabPageIndicesKey = "openTabPageIndices"
    private let selectedTabPathKey = "selectedTabPath"
    private let isShowingLibraryKey = "isShowingLibrary"
    private let currentFolderIDKey = "currentFolderID"
    private var didRestoreOpenTabs = false
    private var libraryChangeMonitor: LibraryChangeMonitor?
    private var monitoredLibraryPath: String?
    private var libraryLoadTask: Task<Void, Never>?
    private var libraryLoadGeneration = 0
    private var automaticRescanTask: Task<Void, Never>?
    private var periodicLibraryScanTask: Task<Void, Never>?
    private var pendingSearchTask: Task<Void, Never>?
    private var searchIndexGeneration = 0
    private let periodicLibraryScanIntervalNanoseconds: UInt64 = 10 * 60 * 1_000_000_000

    var selectedTab: DocumentTab? {
        guard let selectedTabID else {
            return nil
        }
        return openTabs.first { $0.id == selectedTabID }
    }

    var isShowingLibrary: Bool {
        selectedTabID == nil
    }

    var isPDFSearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    init(
        defaults: UserDefaults = .standard,
        pdfSearchIndex: PDFSearchIndex = PDFSearchIndex()
    ) {
        self.defaults = defaults
        self.pdfSearchIndex = pdfSearchIndex
        restoreSortSettings()
        restoreLastLibrary()
        registerSessionPersistenceHandlers()
    }

    func saveSessionState() {
        saveOpenTabState()
    }

    deinit {
        libraryLoadTask?.cancel()
        automaticRescanTask?.cancel()
        periodicLibraryScanTask?.cancel()
        pendingSearchTask?.cancel()
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
        openDocument(document, pageIndex: nil)
    }

    func openDocument(_ document: ReferenceDocument, pageIndex: Int) {
        openDocument(document, pageIndex: Optional(pageIndex))
    }

    func clearSearchQuery() {
        searchQuery = ""
        searchResults = []
    }

    func openSearchResult(_ result: PDFSearchResult) {
        guard let document = documents.first(where: { $0.id == result.documentID }) else {
            statusMessage = "検索結果のPDFが見つかりません: \(result.documentTitle)"
            return
        }

        openDocument(document, pageIndex: result.pageNumber - 1)
    }

    private func openDocument(_ document: ReferenceDocument, pageIndex: Int?) {
        if let tab = openTabs.first(where: { $0.id == document.id }) {
            selectedTabID = document.id
            if let pageIndex {
                tab.currentPageIndex = min(max(pageIndex, 0), max(tab.pageCount - 1, 0))
            }
            statusMessage = "\(document.title) を表示しています。"
            saveOpenTabState()
            return
        }

        do {
            let tab = try makeDocumentTab(document: document, initialPageIndex: pageIndex ?? 0)
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
        if isAutomaticUpdate, libraryLoadTask != nil {
            statusMessage = "フォルダの変更を確認中です。"
            return
        }

        libraryLoadTask?.cancel()
        libraryLoadGeneration += 1
        let generation = libraryLoadGeneration

        statusMessage = isAutomaticUpdate ? "フォルダの変更を確認しています。" : "PDF一覧を読み込み中..."

        libraryLoadTask = Task.detached(priority: .userInitiated) { [url, remember, isAutomaticUpdate] in
            let scanResult = Result {
                try scanLibrary(at: url)
            }

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run { [weak self] in
                self?.applyLibraryScanResult(
                    scanResult,
                    for: url,
                    remember: remember,
                    isAutomaticUpdate: isAutomaticUpdate,
                    generation: generation
                )
            }
        }
    }

    private func applyLibraryScanResult(
        _ scanResult: Result<LibraryScanResult, Error>,
        for url: URL,
        remember: Bool,
        isAutomaticUpdate: Bool,
        generation: Int
    ) {
        guard generation == libraryLoadGeneration else {
            return
        }

        libraryLoadTask = nil

        switch scanResult {
        case .success(let scan):
            let scannedTree = scan.tree
            let scannedDocuments = scan.documents
            let previousFolderID = currentFolderID

            libraryURL = url
            libraryTree = scannedTree
            documents = scannedDocuments
            preparationSummary = "\(scan.result.pdfCount)件のPDF / Markdown未作成 \(scan.result.missingMarkdownCount)件"
            startMonitoringLibrary(at: url)
            refreshPDFSearchIndex(for: scannedDocuments)

            if remember {
                defaults.set(url.path, forKey: lastLibraryPathKey)
            }

            if didRestoreOpenTabs {
                currentFolderID = previousFolderID.flatMap { scannedTree.folder(withID: $0)?.id } ?? scannedTree.id
                removeTabsMissingFrom(scannedDocuments)
            } else {
                currentFolderID = restoredFolderID(in: scannedTree, previousFolderID: previousFolderID)
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
        case .failure(let error):
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
        startPeriodicLibraryScan(at: url)
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

    private func startPeriodicLibraryScan(at url: URL) {
        periodicLibraryScanTask?.cancel()

        let path = url.standardizedFileURL.path
        let interval = periodicLibraryScanIntervalNanoseconds
        periodicLibraryScanTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: interval)

                guard !Task.isCancelled else {
                    return
                }

                await MainActor.run {
                    guard
                        let self,
                        self.libraryURL?.standardizedFileURL.path == path
                    else {
                        return
                    }

                    self.applyAutomaticLibraryUpdate(for: url)
                }
            }
        }
    }

    private func refreshPDFSearchIndex(for documents: [ReferenceDocument]) {
        searchIndexGeneration += 1
        let generation = searchIndexGeneration
        let indexDocuments = documents.map(PDFSearchIndexDocument.init)

        isSearchIndexing = true
        searchIndexStatus = "全文検索インデックスを更新中..."
        if isPDFSearchActive {
            searchResults = []
        }

        pdfSearchIndex.update(documents: indexDocuments) { [weak self] result in
            Task { @MainActor in
                guard let self, self.searchIndexGeneration == generation else {
                    return
                }

                self.isSearchIndexing = false

                switch result {
                case .success(let update):
                    self.searchIndexStatus = self.searchIndexStatusMessage(for: update)
                    if self.isPDFSearchActive {
                        self.runPDFSearch(query: self.searchQuery)
                    }
                case .failure(let error):
                    self.searchIndexStatus = "全文検索インデックス更新に失敗: \(error.localizedDescription)"
                }
            }
        }
    }

    private func schedulePDFSearch() {
        pendingSearchTask?.cancel()

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        pendingSearchTask = Task { [weak self, query] in
            try? await Task.sleep(nanoseconds: 180_000_000)

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.runPDFSearch(query: query)
            }
        }
    }

    private func runPDFSearch(query: String) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            searchResults = []
            return
        }

        pdfSearchIndex.search(query: normalizedQuery) { [weak self, normalizedQuery] results in
            Task { @MainActor in
                guard
                    let self,
                    self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == normalizedQuery
                else {
                    return
                }

                self.searchResults = results
            }
        }
    }

    private func searchIndexStatusMessage(for update: PDFSearchIndexUpdate) -> String {
        var details: [String] = []

        if update.indexedCount > 0 {
            details.append("更新 \(update.indexedCount)件")
        }
        if update.removedCount > 0 {
            details.append("削除 \(update.removedCount)件")
        }
        if update.failedCount > 0 {
            details.append("失敗 \(update.failedCount)件")
        }
        if details.isEmpty {
            details.append("差分なし")
        }

        return "全文検索: \(update.totalDocuments)件 / \(update.totalPages)ページ（\(details.joined(separator: "、"))）"
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
        } else if let firstTab = restoredTabs.first {
            selectedTabID = firstTab.id
        } else {
            selectedTabID = nil
        }
    }

    private func restoredFolderID(
        in tree: LibraryFolder,
        previousFolderID: LibraryFolder.ID?
    ) -> LibraryFolder.ID? {
        if
            let previousFolderID,
            tree.folder(withID: previousFolderID) != nil
        {
            return previousFolderID
        }

        if
            let savedFolderID = defaults.string(forKey: currentFolderIDKey),
            tree.folder(withID: savedFolderID) != nil
        {
            return savedFolderID
        }

        return tree.id
    }

    private func registerSessionPersistenceHandlers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.saveOpenTabState()
            }
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

        if let currentFolderID {
            defaults.set(currentFolderID, forKey: currentFolderIDKey)
        } else if let libraryTree {
            defaults.set(libraryTree.id, forKey: currentFolderIDKey)
        } else {
            defaults.removeObject(forKey: currentFolderIDKey)
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

private struct LibraryScanResult {
    let result: LibraryPreparationResult
    let tree: LibraryFolder
    let documents: [ReferenceDocument]
}

private func scanLibrary(at url: URL) throws -> LibraryScanResult {
    let manager = LibraryManager()
    let tree = try manager.libraryTree(in: url)
    let documents = tree.recursiveDocuments
    let missingMarkdownCount = documents.filter {
        !FileManager.default.fileExists(atPath: $0.explanationURL.path)
    }.count
    let result = LibraryPreparationResult(
        pdfCount: documents.count,
        missingMarkdownCount: missingMarkdownCount
    )

    return LibraryScanResult(
        result: result,
        tree: tree,
        documents: documents
    )
}
