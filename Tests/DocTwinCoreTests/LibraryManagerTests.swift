import XCTest
@testable import DocTwinCore

final class LibraryManagerTests: XCTestCase {
    func testPrepareLibraryDoesNotCreateFilesInReferenceDirectory() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let pdfURL = directoryURL.appendingPathComponent("Sample.pdf")
        FileManager.default.createFile(atPath: pdfURL.path, contents: Data())

        let manager = LibraryManager()
        let result = try manager.prepareLibrary(at: directoryURL)

        XCTAssertEqual(result.pdfCount, 1)
        XCTAssertEqual(result.missingMarkdownCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent(".doctwin").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("Sample.md").path))
    }

    func testPrepareLibraryKeepsExistingMarkdown() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        FileManager.default.createFile(
            atPath: directoryURL.appendingPathComponent("Paper.pdf").path,
            contents: Data()
        )

        let markdownURL = directoryURL.appendingPathComponent("Paper.md")
        try "# Existing".write(to: markdownURL, atomically: true, encoding: .utf8)

        let manager = LibraryManager()
        let result = try manager.prepareLibrary(at: directoryURL)
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)

        XCTAssertEqual(result.missingMarkdownCount, 0)
        XCTAssertEqual(markdown, "# Existing")
    }

    func testLibraryTreeIncludesFoldersWhenRootHasNoPDF() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let nestedDirectoryURL = directoryURL.appendingPathComponent("Week 01", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectoryURL, withIntermediateDirectories: true)

        FileManager.default.createFile(
            atPath: nestedDirectoryURL.appendingPathComponent("Lecture.pdf").path,
            contents: Data()
        )

        try "# Nested".write(
            to: nestedDirectoryURL.appendingPathComponent("lecture.MD"),
            atomically: true,
            encoding: .utf8
        )

        let manager = LibraryManager()
        let tree = try manager.libraryTree(in: directoryURL)

        XCTAssertTrue(tree.documents.isEmpty)
        XCTAssertEqual(tree.folders.map(\.name), ["Week 01"])
        XCTAssertEqual(tree.folders.first?.documents.map(\.title), ["Lecture"])
        XCTAssertEqual(tree.recursiveDocuments.map { $0.pdfURL.lastPathComponent }, ["Lecture.pdf"])
        XCTAssertEqual(tree.recursiveDocuments.first?.explanationURL.lastPathComponent, "lecture.MD")
    }

    func testPrepareLibraryCountsNestedMissingMarkdown() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let nestedDirectoryURL = directoryURL.appendingPathComponent("Slides", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectoryURL, withIntermediateDirectories: true)

        FileManager.default.createFile(
            atPath: nestedDirectoryURL.appendingPathComponent("Deck.pdf").path,
            contents: Data()
        )

        let manager = LibraryManager()
        let result = try manager.prepareLibrary(at: directoryURL)

        XCTAssertEqual(result.pdfCount, 1)
        XCTAssertEqual(result.missingMarkdownCount, 1)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
