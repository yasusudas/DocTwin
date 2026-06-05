import SwiftUI

struct DocumentReaderView: View {
    @ObservedObject var tab: DocumentTab

    var body: some View {
        HSplitView {
            PDFPane(tab: tab)
                .frame(minWidth: 480)

            ExplanationPane(tab: tab)
                .frame(minWidth: 360)
        }
    }
}

private struct PDFPane: View {
    @ObservedObject var tab: DocumentTab

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                FileTypeIcon(kind: .pdf)

                Text(tab.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    tab.previousPage()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .disabled(!tab.canGoToPreviousPage)
                .help("前のページ")

                Text(tab.pageLabel)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 76)

                Button {
                    tab.nextPage()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .disabled(!tab.canGoToNextPage)
                .help("次のページ")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            PDFKitView(
                document: tab.pdfDocument,
                currentPageIndex: $tab.currentPageIndex,
                onPageChanged: { tab.updateCurrentPageFromViewer($0) }
            )
        }
    }
}

private struct ExplanationPane: View {
    @ObservedObject var tab: DocumentTab

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                FileTypeIcon(kind: .markdown)

                Text(tab.document.explanationURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button {
                    tab.reloadExplanation()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("解説を再読み込み")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            MarkdownMathView(
                markdown: tab.markdownSource,
                title: tab.title,
                baseURL: tab.baseURL
            )
        }
    }
}
