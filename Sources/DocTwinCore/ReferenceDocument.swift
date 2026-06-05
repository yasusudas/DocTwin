import Foundation

public struct ReferenceDocument: Identifiable, Hashable {
    public let pdfURL: URL
    public let explanationURL: URL

    public var id: String {
        pdfURL.standardizedFileURL.path
    }

    public var title: String {
        pdfURL.deletingPathExtension().lastPathComponent
    }

    public init(pdfURL: URL, explanationURL: URL) {
        self.pdfURL = pdfURL
        self.explanationURL = explanationURL
    }
}
