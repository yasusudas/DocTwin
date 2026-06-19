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
                Label("生成プロンプトをコピー", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(tab.isGeneratingMarkdownWithCLI)

            Button {
                tab.generateMarkdownWithCLI()
            } label: {
                if tab.isGeneratingMarkdownWithCLI {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("CLIで生成中")
                    }
                } else {
                    Label("CLIで生成して保存", systemImage: "terminal")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(tab.isGeneratingMarkdownWithCLI)

            if tab.isGeneratingMarkdownWithCLI {
                CLIGenerationProgressPanel(tab: tab)
            }

            Button {
                MarkdownCLISettingsWindowController.shared.show()
            } label: {
                Label("AI生成設定", systemImage: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(tab.isGeneratingMarkdownWithCLI)

            if let promptCopyMessage = tab.promptCopyMessage {
                Text(promptCopyMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct CLIGenerationProgressPanel: View {
    @ObservedObject var tab: DocumentTab

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(tab.cliGenerationProgressMessage ?? "CLIがMarkdownを生成中です。")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)

                Spacer()

                elapsedTimeView
            }

            ProgressView()
                .progressViewStyle(.linear)

            Text("CLIの種類によって正確な残り時間は取得できないため、完了までこのまま待ってください。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 380)
        .padding(.top, 2)
    }

    private var elapsedTimeView: some View {
        TimelineView(.periodic(from: tab.cliGenerationStartedAt ?? Date(), by: 1)) { context in
            Text(elapsedText(at: context.date))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 62, alignment: .trailing)
    }

    private func elapsedText(at date: Date) -> String {
        guard let startedAt = tab.cliGenerationStartedAt else {
            return "0:00"
        }

        let elapsedSeconds = max(0, Int(date.timeIntervalSince(startedAt)))
        return String(format: "%d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
    }
}
