import PDFKit
import DocTwinCore
import SwiftUI

struct LibraryBrowserView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibraryHeader()
                .environmentObject(viewModel)

            if viewModel.documents.isEmpty {
                EmptyLibraryView()
                    .environmentObject(viewModel)
            } else {
                DocumentGridView()
                    .environmentObject(viewModel)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct DocumentGridView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    private let cardWidth: CGFloat = 162
    private let horizontalPadding: CGFloat = 24
    private let horizontalSpacing: CGFloat = 28
    private let verticalSpacing: CGFloat = 24

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVGrid(
                    columns: columns(for: geometry.size.width),
                    alignment: .leading,
                    spacing: verticalSpacing
                ) {
                    ForEach(viewModel.documents) { document in
                        PDFDocumentCard(document: document) {
                            viewModel.openDocument(document)
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        let availableWidth = max(cardWidth, width - horizontalPadding * 2)
        let columnCount = max(1, Int((availableWidth + horizontalSpacing) / (cardWidth + horizontalSpacing)))

        return Array(
            repeating: GridItem(.fixed(cardWidth), spacing: horizontalSpacing, alignment: .top),
            count: columnCount
        )
    }
}

private struct LibraryHeader: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            Text(viewModel.libraryTitle)
                .font(.headline)
                .lineLimit(1)

            HStack {
                Spacer()

                Text("\(viewModel.documents.count) PDFs")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct PDFDocumentCard: View {
    let document: ReferenceDocument
    let onOpen: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .frame(width: 150, height: 104)
                    .shadow(color: .black.opacity(isHovering ? 0.20 : 0.13), radius: isHovering ? 4 : 2, x: 0, y: 1)

                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 146, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    FileTypeIcon(kind: .pdf, size: 34, color: .secondary.opacity(0.55))
                        .frame(width: 150, height: 104)
                }
            }

            VStack(spacing: 3) {
                Text(document.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 150)

                Text(modifiedDateText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(isHovering ? Color(nsColor: .controlBackgroundColor).opacity(0.85) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 9))
        .onTapGesture(perform: onOpen)
        .onHover { isHovering = $0 }
        .onAppear {
            thumbnail = thumbnail ?? Self.makeThumbnail(for: document.pdfURL)
        }
        .accessibilityLabel(document.title)
        .accessibilityAddTraits(.isButton)
        .help(document.pdfURL.lastPathComponent)
    }

    private var modifiedDateText: String {
        guard
            let values = try? document.pdfURL.resourceValues(forKeys: [.contentModificationDateKey]),
            let date = values.contentModificationDate
        else {
            return ""
        }

        return date.formatted(.dateTime.year().month().day().hour().minute())
    }

    private static func makeThumbnail(for url: URL) -> NSImage? {
        guard
            let pdfDocument = PDFDocument(url: url),
            let firstPage = pdfDocument.page(at: 0)
        else {
            return nil
        }

        return firstPage.thumbnail(of: CGSize(width: 300, height: 208), for: .mediaBox)
    }
}

private struct EmptyLibraryView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.tertiary)

            Text(viewModel.libraryURL == nil ? "フォルダ未選択" : "PDFなし")
                .font(.headline)

            Button {
                viewModel.chooseLibraryFolder()
            } label: {
                Label("フォルダを選択", systemImage: "folder")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
