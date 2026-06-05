import Foundation

public struct LibraryPreparationResult: Equatable {
    public let pdfCount: Int
    public let missingMarkdownCount: Int
    public let metadataDirectoryURL: URL

    public init(pdfCount: Int, missingMarkdownCount: Int, metadataDirectoryURL: URL) {
        self.pdfCount = pdfCount
        self.missingMarkdownCount = missingMarkdownCount
        self.metadataDirectoryURL = metadataDirectoryURL
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
    public static let metadataDirectoryName = ".doctwin"

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func prepareLibrary(at directoryURL: URL) throws -> LibraryPreparationResult {
        try validateDirectory(directoryURL)

        let metadataURL = directoryURL.appendingPathComponent(Self.metadataDirectoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: metadataURL.path) {
            try fileManager.createDirectory(at: metadataURL, withIntermediateDirectories: true)
        }

        let metadataReadmeURL = metadataURL.appendingPathComponent("README.md")
        if !fileManager.fileExists(atPath: metadataReadmeURL.path) {
            try metadataReadmeText.write(to: metadataReadmeURL, atomically: true, encoding: .utf8)
        }

        let documents = try documents(in: directoryURL)
        let missingMarkdownCount = documents.filter {
            !fileManager.fileExists(atPath: $0.explanationURL.path)
        }.count

        return LibraryPreparationResult(
            pdfCount: documents.count,
            missingMarkdownCount: missingMarkdownCount,
            metadataDirectoryURL: metadataURL
        )
    }

    public func documents(in directoryURL: URL) throws -> [ReferenceDocument] {
        try validateDirectory(directoryURL)

        let contents = try regularFiles(in: directoryURL)
        let pdfURLs = contents
            .filter { $0.pathExtension.lowercased() == "pdf" }
            .sorted {
                $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
            }

        return pdfURLs.map { pdfURL in
            ReferenceDocument(
                pdfURL: pdfURL,
                explanationURL: existingExplanationURL(for: pdfURL, in: contents) ?? expectedExplanationURL(for: pdfURL)
            )
        }
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

    private func regularFiles(in directoryURL: URL) throws -> [URL] {
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return urls.filter { url in
            (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
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

    private var metadataReadmeText: String {
        """
        # DocTwin

        このフォルダはDocTwinが管理するメタデータ用です。

        選択したフォルダ直下にPDFと同名のMarkdownファイルを置くと、右ペインに解説として表示します。
        例: `Paper.pdf` に対して `Paper.md`

        """
    }
}
