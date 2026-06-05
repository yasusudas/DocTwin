import XCTest
@testable import DocTwinCore

final class LibraryManagerTests: XCTestCase {
    func testPrepareLibraryCreatesMetadataWithoutCreatingMissingMarkdown() throws {
        let directoryURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let pdfURL = directoryURL.appendingPathComponent("Sample.pdf")
        FileManager.default.createFile(atPath: pdfURL.path, contents: Data())

        let manager = LibraryManager()
        let result = try manager.prepareLibrary(at: directoryURL)

        XCTAssertEqual(result.pdfCount, 1)
        XCTAssertEqual(result.missingMarkdownCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.metadataDirectoryURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("Sample.md").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: result.metadataDirectoryURL.appendingPathComponent("explanation-template.md").path))
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

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
