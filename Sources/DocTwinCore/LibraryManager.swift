import Foundation

public struct LibraryPreparationResult: Equatable {
    public let pdfCount: Int
    public let missingMarkdownCount: Int

    public init(pdfCount: Int, missingMarkdownCount: Int) {
        self.pdfCount = pdfCount
        self.missingMarkdownCount = missingMarkdownCount
    }
}

public enum LibraryManagerError: Error, LocalizedError {
    case notDirectory(URL)

    public var errorDescription: String? {
        switch self {
        case .notDirectory(let url):
            return "\(url.path) はフォルダではありません。"
        }
    }
}

public final class LibraryManager {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func prepareLibrary(at directoryURL: URL) throws -> LibraryPreparationResult {
        try validateDirectory(directoryURL)

        let documents = try documents(in: directoryURL)
        let missingMarkdownCount = documents.filter {
            !fileManager.fileExists(atPath: $0.explanationURL.path)
        }.count

        return LibraryPreparationResult(
            pdfCount: documents.count,
            missingMarkdownCount: missingMarkdownCount
        )
    }

    public func documents(in directoryURL: URL) throws -> [ReferenceDocument] {
        try libraryTree(in: directoryURL).recursiveDocuments
    }

    public func libraryTree(in directoryURL: URL) throws -> LibraryFolder {
        try validateDirectory(directoryURL)
        return try folderTree(in: directoryURL)
    }

    public func expectedExplanationURL(for pdfURL: URL) -> URL {
        pdfURL.deletingPathExtension().appendingPathExtension("md")
    }

    private func validateDirectory(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else {
            throw LibraryManagerError.notDirectory(url)
        }
    }

    private func folderTree(in directoryURL: URL) throws -> LibraryFolder {
        let children = try childURLs(in: directoryURL)
        let regularFiles = children.filter { isRegularFile($0) }
        let folderURLs = children.filter { isDirectory($0) }

        let documents = regularFiles
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .map { pdfURL in
                ReferenceDocument(
                    pdfURL: pdfURL,
                    explanationURL: existingExplanationURL(for: pdfURL, in: regularFiles) ?? expectedExplanationURL(for: pdfURL)
                )
            }

        let folders = try folderURLs.map { try folderTree(in: $0) }

        return LibraryFolder(url: directoryURL, folders: folders, documents: documents)
    }

    private func childURLs(in directoryURL: URL) throws -> [URL] {
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return urls.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private func existingExplanationURL(for pdfURL: URL, in candidates: [URL]) -> URL? {
        let pdfStem = pdfURL.deletingPathExtension().lastPathComponent
        let markdownURLs = candidates.filter { $0.pathExtension.lowercased() == "md" }

        return markdownURLs.first {
            $0.deletingPathExtension().lastPathComponent == pdfStem
        } ?? markdownURLs.first {
            $0.deletingPathExtension().lastPathComponent.localizedCaseInsensitiveCompare(pdfStem) == .orderedSame
        }
    }

}
