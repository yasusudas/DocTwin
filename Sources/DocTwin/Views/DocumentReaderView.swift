import SwiftUI

struct DocumentReaderView: View {
    @ObservedObject var tab: DocumentTab

    var body: some View {
        PersistentHSplitView(
            storageKey: "DocumentReaderSplitRatio",
            leadingMinWidth: 480,
            trailingMinWidth: 360
        ) {
            PDFPane(tab: tab)
        } trailing: {
            ExplanationPane(tab: tab)
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
                .buttonStyle(.hoverIcon)
                .focusable(false)
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
                .buttonStyle(.hoverIcon)
                .focusable(false)
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
                .buttonStyle(.hoverIcon)
                .focusable(false)
                .help("解説を再読み込み")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if tab.hasExplanationMarkdown {
                MarkdownMathView(
                    markdown: tab.markdownSource,
                    title: tab.title,
                    baseURL: tab.baseURL
                )
            } else {
                MissingExplanationView(tab: tab)
            }
        }
    }
}

private struct MissingExplanationView: View {
    @ObservedObject var tab: DocumentTab

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text("対応するMarkdownファイルがありません")
                    .font(.headline)

                Text(tab.document.explanationURL.lastPathComponent)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Button {
                tab.copyMarkdownGenerationPromptToPasteboard()
            } label: {
                Label("mdファイルを生成", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let promptCopyMessage = tab.promptCopyMessage {
                Text(promptCopyMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
