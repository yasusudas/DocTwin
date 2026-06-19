import PDFKit
import DocTwinCore
import SwiftUI

struct LibraryBrowserView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @FocusState private var isPDFSearchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LibraryHeader(isPDFSearchFieldFocused: $isPDFSearchFieldFocused)
                .environmentObject(viewModel)

            if viewModel.isPDFSearchActive {
                PDFSearchResultsView()
                    .environmentObject(viewModel)
                    .dismissPDFSearchFocus($isPDFSearchFieldFocused)
            } else if let folder = viewModel.currentFolder, !folder.folders.isEmpty || !folder.documents.isEmpty {
                DocumentGridView(folder: folder)
                    .environmentObject(viewModel)
                    .dismissPDFSearchFocus($isPDFSearchFieldFocused)
            } else {
                EmptyLibraryView()
                    .environmentObject(viewModel)
                    .dismissPDFSearchFocus($isPDFSearchFieldFocused)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct DocumentGridView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let folder: LibraryFolder

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
                    ForEach(viewModel.sortedFolders(in: folder)) { folder in
                        FolderCard(folder: folder) {
                            viewModel.openFolder(folder)
                        }
                    }

                    ForEach(viewModel.sortedDocuments(in: folder)) { document in
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
    @FocusState.Binding var isPDFSearchFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Group {
                    if viewModel.canNavigateToParentFolder {
                        Button {
                            viewModel.showParentFolder()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.hoverIcon)
                        .focusable(false)
                        .help("上の階層")
                    }

                    Text(viewModel.currentFolder?.name ?? viewModel.libraryTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()
                }
                .dismissPDFSearchFocus($isPDFSearchFieldFocused)

                PDFSearchField(isFocused: $isPDFSearchFieldFocused)
                    .environmentObject(viewModel)
                    .frame(width: 310)

                if let folder = viewModel.currentFolder {
                    Text("\(folder.folders.count + folder.documents.count)項目")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .dismissPDFSearchFocus($isPDFSearchFieldFocused)
                }
            }

            BreadcrumbBar()
                .environmentObject(viewModel)
                .dismissPDFSearchFocus($isPDFSearchFieldFocused)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}

private struct PDFSearchField: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("PDF全文検索", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.clearSearchQuery()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .focusable(false)
                .help("検索を消去")
            }
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.42), lineWidth: 1)
        )
    }
}

private struct PDFSearchResultsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("検索結果")
                    .font(.headline)

                Text("\(viewModel.searchResults.count)件")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if viewModel.isSearchIndexing {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.72)
                }

                Spacer()

                Text(viewModel.searchIndexStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            if viewModel.searchResults.isEmpty {
                EmptySearchResultsView()
                    .environmentObject(viewModel)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.searchResults) { result in
                            PDFSearchResultRow(result: result) {
                                viewModel.openSearchResult(result)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct PDFSearchResultRow: View {
    let result: PDFSearchResult
    let onOpen: () -> Void

    var body: some View {
        LibraryCardSurface(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 26)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(result.documentTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Text("p.\(result.pageNumber)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(result.snippet)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityLabel("\(result.documentTitle) \(result.pageNumber)ページ")
        .help(result.pdfURL.path)
    }
}

private struct EmptySearchResultsView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 10) {
            if viewModel.isSearchIndexing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .regular))
                    .foregroundStyle(.tertiary)
            }

            Text(viewModel.isSearchIndexing ? "インデックスを更新しています" : "一致するページがありません")
                .font(.headline)

            Text(viewModel.searchIndexStatus)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

private struct BreadcrumbBar: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        let path = viewModel.currentFolderPath

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(path.indices, id: \.self) { index in
                    let folder = path[index]

                    Button {
                        viewModel.showFolder(folder.id)
                    } label: {
                        Text(index == 0 ? viewModel.libraryTitle : folder.name)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(index == path.count - 1 ? .primary : .secondary)
                    .disabled(index == path.count - 1)

                    if index < path.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .font(.footnote)
        .frame(height: 18)
    }
}

private struct LibraryCardSurface<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    @GestureState private var isPressing = false
    @State private var isHovering = false

    private let cornerRadius: CGFloat = 9

    var body: some View {
        content()
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)
            .scaleEffect(isPressing ? 0.975 : 1)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressing) { _, state, _ in
                        state = true
                    }
                    .onEnded { value in
                        guard isClick(value) else {
                            return
                        }

                        action()
                    }
            )
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: isPressing)
            .accessibilityAddTraits(.isButton)
    }

    private var backgroundColor: Color {
        if isPressing {
            return Color(nsColor: .separatorColor).opacity(0.24)
        }

        if isHovering {
            return Color(nsColor: .separatorColor).opacity(0.16)
        }

        return .clear
    }

    private var borderColor: Color {
        if isPressing {
            return Color(nsColor: .separatorColor).opacity(0.42)
        }

        if isHovering {
            return Color(nsColor: .separatorColor).opacity(0.28)
        }

        return .clear
    }

    private var shadowColor: Color {
        isHovering || isPressing ? Color.black.opacity(0.08) : .clear
    }

    private var shadowRadius: CGFloat {
        isHovering || isPressing ? 5 : 0
    }

    private var shadowYOffset: CGFloat {
        isPressing ? 1 : 2
    }

    private func isClick(_ value: DragGesture.Value) -> Bool {
        abs(value.translation.width) < 8 && abs(value.translation.height) < 8
    }
}

private struct FolderCard: View {
    let folder: LibraryFolder
    let onOpen: () -> Void

    private let folderIconSize: CGFloat = 116

    var body: some View {
        LibraryCardSurface(action: onOpen) {
            VStack(spacing: 10) {
                FileTypeIcon(kind: .folder, size: folderIconSize, color: Color.accentColor.opacity(0.82))
                    .frame(width: 150, height: 104)

                VStack(spacing: 3) {
                    Text(folder.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(width: 150)

                    Text(folderSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityLabel(folder.name)
        .help(folder.url.path)
    }

    private var folderSubtitle: String {
        "\(folder.recursiveDocumentCount)項目"
    }
}

private struct PDFDocumentCard: View {
    let document: ReferenceDocument
    let onOpen: () -> Void

    @State private var thumbnail: NSImage?
    @State private var loadedThumbnailSignature: PDFThumbnailSignature?
    @State private var isHovering = false

    var body: some View {
        LibraryCardSurface(action: onOpen) {
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
                }
            }
        }
        .onHover { isHovering = $0 }
        .task(id: thumbnailSignature) {
            reloadThumbnailIfNeeded()
        }
        .accessibilityLabel(document.title)
        .help(document.pdfURL.lastPathComponent)
    }

    private var thumbnailSignature: PDFThumbnailSignature {
        PDFThumbnailSignature(url: document.pdfURL)
    }

    private static func makeThumbnail(for url: URL) -> NSImage? {
        guard
            let pdfDocument = PDFDocument(url: url),
            let firstPage = pdfDocument.page(at: 0)
        else {
            return nil
        }

        return firstPage.thumbnail(of: CGSize(width: 300, height: 208), for: .cropBox)
    }

    private func reloadThumbnailIfNeeded() {
        let signature = thumbnailSignature
        guard loadedThumbnailSignature != signature else {
            return
        }

        loadedThumbnailSignature = signature
        thumbnail = Self.makeThumbnail(for: document.pdfURL)
    }
}

private struct PDFThumbnailSignature: Hashable {
    let path: String
    let modificationDate: Date?
    let fileSize: Int?

    init(url: URL) {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])

        path = url.standardizedFileURL.path
        modificationDate = values?.contentModificationDate
        fileSize = values?.fileSize
    }
}

private struct EmptyLibraryView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.tertiary)

            Text(emptyTitle)
                .font(.headline)

            if viewModel.canNavigateToParentFolder {
                Button {
                    viewModel.showParentFolder()
                } label: {
                    Label("上の階層へ", systemImage: "chevron.left")
                }
            } else {
                Button {
                    viewModel.chooseLibraryFolder()
                } label: {
                    Label("フォルダを選択", systemImage: "folder")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTitle: String {
        if viewModel.libraryURL == nil {
            return "フォルダ未選択"
        }

        return "空のフォルダ"
    }
}

private extension View {
    func dismissPDFSearchFocus(_ isFocused: FocusState<Bool>.Binding) -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                isFocused.wrappedValue = false
            }
        )
    }
}
