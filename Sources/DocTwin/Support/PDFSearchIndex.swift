import Foundation
import PDFKit
import DocTwinCore

struct PDFSearchIndexDocument: Hashable {
    let id: String
    let title: String
    let pdfURL: URL

    init(document: ReferenceDocument) {
        id = document.id
        title = document.title
        pdfURL = document.pdfURL
    }
}

struct PDFSearchResult: Identifiable, Hashable {
    let id: String
    let documentID: String
    let documentTitle: String
    let pdfURL: URL
    let pageNumber: Int
    let snippet: String
}

struct PDFSearchIndexUpdate: Hashable {
    let indexedCount: Int
    let skippedCount: Int
    let removedCount: Int
    let failedCount: Int
    let totalDocuments: Int
    let totalPages: Int
}

final class PDFSearchIndex {
    private let fileManager: FileManager
    private let storeURL: URL
    private let queue = DispatchQueue(label: "com.yasusu.DocTwin.PDFSearchIndex", qos: .utility)
    private var state: PDFSearchIndexState

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        storeURL = Self.defaultStoreURL(fileManager: fileManager)
        state = Self.loadState(from: storeURL) ?? PDFSearchIndexState()
    }

    func update(
        documents: [PDFSearchIndexDocument],
        completion: @escaping (Result<PDFSearchIndexUpdate, Error>) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else {
                return
            }

            let result = Result {
                try self.updateSynchronously(documents: documents)
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func search(
        query: String,
        limit: Int = 60,
        completion: @escaping ([PDFSearchResult]) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else {
                return
            }

            let results = self.searchSynchronously(query: query, limit: limit)
            DispatchQueue.main.async {
                completion(results)
            }
        }
    }

    private func updateSynchronously(documents: [PDFSearchIndexDocument]) throws -> PDFSearchIndexUpdate {
        var nextState = state
        let indexedDocuments = documents.sorted {
            $0.pdfURL.path.localizedStandardCompare($1.pdfURL.path) == .orderedAscending
        }
        let currentPaths = Set(indexedDocuments.map { Self.standardizedPath(for: $0.pdfURL) })
        let previousEntryCount = nextState.entries.count
        nextState.entries = nextState.entries.filter { currentPaths.contains($0.key) }
        let removedCount = previousEntryCount - nextState.entries.count

        var didChange = nextState.entries.count != previousEntryCount
        var indexedCount = 0
        var skippedCount = 0
        var failedCount = 0

        for document in indexedDocuments {
            let path = Self.standardizedPath(for: document.pdfURL)
            let signature = Self.fileSignature(for: document.pdfURL)

            if var existingEntry = nextState.entries[path], existingEntry.signature == signature {
                skippedCount += 1
                if existingEntry.title != document.title {
                    existingEntry.title = document.title
                    nextState.entries[path] = existingEntry
                    didChange = true
                }
                continue
            }

            do {
                let entry = try Self.extractEntry(
                    for: document,
                    path: path,
                    signature: signature
                )
                nextState.entries[path] = entry
                indexedCount += 1
                didChange = true
            } catch {
                nextState.entries.removeValue(forKey: path)
                failedCount += 1
                didChange = true
            }
        }

        let totalPages = nextState.entries.values.reduce(0) { $0 + $1.pageCount }
        let update = PDFSearchIndexUpdate(
            indexedCount: indexedCount,
            skippedCount: skippedCount,
            removedCount: removedCount,
            failedCount: failedCount,
            totalDocuments: nextState.entries.count,
            totalPages: totalPages
        )

        if didChange {
            nextState.updatedAt = Date()
            try save(nextState)
        }

        state = nextState
        return update
    }

    private func searchSynchronously(query: String, limit: Int) -> [PDFSearchResult] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        let terms = normalizedQuery
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !terms.isEmpty else {
            return []
        }

        var scoredResults: [ScoredPDFSearchResult] = []
        let entries = state.entries.values.sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }

        for entry in entries {
            for page in entry.pages where !page.text.isEmpty {
                guard let match = match(in: page.text, query: normalizedQuery, terms: terms) else {
                    continue
                }

                let result = PDFSearchResult(
                    id: "\(entry.path)#\(page.pageNumber)",
                    documentID: entry.documentID,
                    documentTitle: entry.title,
                    pdfURL: URL(fileURLWithPath: entry.path),
                    pageNumber: page.pageNumber,
                    snippet: Self.makeSnippet(from: page.text, around: match.range)
                )
                scoredResults.append(ScoredPDFSearchResult(result: result, score: match.score))
            }
        }

        return scoredResults
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                if lhs.result.documentTitle != rhs.result.documentTitle {
                    return lhs.result.documentTitle.localizedStandardCompare(rhs.result.documentTitle) == .orderedAscending
                }
                return lhs.result.pageNumber < rhs.result.pageNumber
            }
            .prefix(limit)
            .map(\.result)
    }

    private func match(
        in text: String,
        query: String,
        terms: [String]
    ) -> PDFSearchMatch? {
        let compareOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        if let range = text.range(of: query, options: compareOptions) {
            return PDFSearchMatch(range: range, score: 100 + query.count)
        }

        var firstRange: Range<String.Index>?
        var score = 0

        for term in terms {
            guard let range = text.range(of: term, options: compareOptions) else {
                return nil
            }

            if firstRange == nil {
                firstRange = range
            }
            score += term.count
        }

        guard let firstRange else {
            return nil
        }

        return PDFSearchMatch(range: firstRange, score: 40 + score)
    }

    private static func extractEntry(
        for document: PDFSearchIndexDocument,
        path: String,
        signature: PDFSearchFileSignature
    ) throws -> PDFSearchIndexEntry {
        guard let pdfDocument = PDFDocument(url: document.pdfURL), pdfDocument.pageCount > 0 else {
            throw PDFSearchIndexError.unreadablePDF(document.pdfURL.path)
        }

        var pages: [PDFSearchPage] = []
        pages.reserveCapacity(pdfDocument.pageCount)

        for pageIndex in 0..<pdfDocument.pageCount {
            autoreleasepool {
                let text = pdfDocument.page(at: pageIndex)?.string ?? ""
                pages.append(PDFSearchPage(pageNumber: pageIndex + 1, text: text))
            }
        }

        return PDFSearchIndexEntry(
            documentID: document.id,
            title: document.title,
            path: path,
            signature: signature,
            pageCount: pdfDocument.pageCount,
            pages: pages
        )
    }

    private static func fileSignature(for url: URL) -> PDFSearchFileSignature {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return PDFSearchFileSignature(
            modificationTime: values?.contentModificationDate?.timeIntervalSince1970,
            fileSize: values?.fileSize.map(Int64.init)
        )
    }

    private static func makeSnippet(
        from text: String,
        around range: Range<String.Index>
    ) -> String {
        let contextLength = 72
        let lowerBound = text.index(
            range.lowerBound,
            offsetBy: -contextLength,
            limitedBy: text.startIndex
        ) ?? text.startIndex
        let upperBound = text.index(
            range.upperBound,
            offsetBy: contextLength,
            limitedBy: text.endIndex
        ) ?? text.endIndex

        var snippet = String(text[lowerBound..<upperBound])
        snippet = snippet
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if lowerBound > text.startIndex {
            snippet = "..." + snippet
        }
        if upperBound < text.endIndex {
            snippet += "..."
        }

        return snippet
    }

    private static func standardizedPath(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private static func defaultStoreURL(fileManager: FileManager) -> URL {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)

        return applicationSupportURL
            .appendingPathComponent("DocTwin", isDirectory: true)
            .appendingPathComponent("SearchIndex", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("pdf-search-index.json")
    }

    private static func loadState(from url: URL) -> PDFSearchIndexState? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = JSONDecoder()
        return try? decoder.decode(PDFSearchIndexState.self, from: data)
    }

    private func save(_ state: PDFSearchIndexState) throws {
        try fileManager.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: storeURL, options: .atomic)
    }
}

private struct PDFSearchIndexState: Codable {
    var schemaVersion = 1
    var updatedAt: Date?
    var entries: [String: PDFSearchIndexEntry] = [:]
}

private struct PDFSearchIndexEntry: Codable {
    let documentID: String
    var title: String
    let path: String
    let signature: PDFSearchFileSignature
    let pageCount: Int
    let pages: [PDFSearchPage]
}

private struct PDFSearchFileSignature: Codable, Equatable {
    let modificationTime: TimeInterval?
    let fileSize: Int64?
}

private struct PDFSearchPage: Codable {
    let pageNumber: Int
    let text: String
}

private struct PDFSearchMatch {
    let range: Range<String.Index>
    let score: Int
}

private struct ScoredPDFSearchResult {
    let result: PDFSearchResult
    let score: Int
}

private enum PDFSearchIndexError: Error {
    case unreadablePDF(String)
}
