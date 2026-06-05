import Combine
import Foundation
import PDFKit
import DocTwinCore

final class DocumentTab: ObservableObject, Identifiable {
    let id: String
    let document: ReferenceDocument
    let pdfDocument: PDFDocument

    @Published var currentPageIndex: Int = 0 {
        didSet {
            refreshDisplayedMarkdownForCurrentPage()
        }
    }

    @Published private(set) var markdownSource: String = ""
    @Published private(set) var statusMessage: String?

    private var pageMarkdownDocument: PageMarkdownDocument?

    var title: String {
        document.title
    }

    var pageCount: Int {
        pdfDocument.pageCount
    }

    var pageLabel: String {
        guard pageCount > 0 else {
            return "- / -"
        }
        return "\(currentPageIndex + 1) / \(pageCount)"
    }

    var canGoToPreviousPage: Bool {
        currentPageIndex > 0
    }

    var canGoToNextPage: Bool {
        pageCount > 0 && currentPageIndex + 1 < pageCount
    }

    var baseURL: URL {
        document.pdfURL.deletingLastPathComponent()
    }

    init(document: ReferenceDocument) throws {
        guard let pdfDocument = PDFDocument(url: document.pdfURL), pdfDocument.pageCount > 0 else {
            throw DocumentTabError.unreadablePDF(document.pdfURL.lastPathComponent)
        }

        id = document.id
        self.document = document
        self.pdfDocument = pdfDocument

        reloadExplanation()
    }

    func reloadExplanation() {
        guard FileManager.default.fileExists(atPath: document.explanationURL.path) else {
            pageMarkdownDocument = nil
            markdownSource = missingExplanationMarkdown
            statusMessage = "対応するMarkdownファイルがありません: \(document.explanationURL.lastPathComponent)"
            return
        }

        do {
            let source = try String(contentsOf: document.explanationURL, encoding: .utf8)
            pageMarkdownDocument = PageMarkdownDocument(markdown: source)
            statusMessage = nil
            refreshDisplayedMarkdownForCurrentPage()
        } catch {
            pageMarkdownDocument = nil
            markdownSource = """
            # \(document.title)

            Markdownファイルを読み込めませんでした。

            `\(document.explanationURL.lastPathComponent)`
            """
            statusMessage = "Markdownを読み込めませんでした: \(document.explanationURL.lastPathComponent)"
        }
    }

    func previousPage() {
        guard canGoToPreviousPage else {
            return
        }
        currentPageIndex -= 1
    }

    func nextPage() {
        guard canGoToNextPage else {
            return
        }
        currentPageIndex += 1
    }

    func updateCurrentPageFromViewer(_ pageIndex: Int) {
        guard pageIndex >= 0, pageIndex < pageCount, currentPageIndex != pageIndex else {
            return
        }
        currentPageIndex = pageIndex
    }

    private func refreshDisplayedMarkdownForCurrentPage() {
        guard let pageMarkdownDocument else {
            return
        }

        markdownSource = pageMarkdownDocument.markdown(forPage: currentPageIndex + 1)
    }

    private var missingExplanationMarkdown: String {
        """
        # 対応するMarkdownファイルがありません

        このPDFに対応する解説Markdownが見つかりません。

        必要なファイル名: `\(document.explanationURL.lastPathComponent)`

        PDFと同名のMarkdownファイルを同じフォルダに置くと、ここに表示されます。
        """
    }
}

private enum DocumentTabError: Error, LocalizedError {
    case unreadablePDF(String)

    var errorDescription: String? {
        switch self {
        case .unreadablePDF(let fileName):
            return "PDFを読み込めませんでした: \(fileName)"
        }
    }
}
