import SwiftUI

struct TabStripView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var draggedTabID: DocumentTab.ID?
    @State private var tabFrames: [DocumentTab.ID: CGRect] = [:]

    var body: some View {
        HStack(spacing: 8) {
            LibraryTabControl(
                isSelected: viewModel.isShowingLibrary,
                action: { viewModel.showLibrary() }
            )

            Divider()
                .frame(height: 22)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.openTabs) { tab in
                        TabButton(
                            tab: tab,
                            isSelected: tab.id == viewModel.selectedTabID,
                            isDragging: tab.id == draggedTabID,
                            onSelect: { viewModel.selectTab(tab.id) },
                            onClose: { viewModel.closeTab(tab.id) }
                        )
                        .background(TabFrameReader(tabID: tab.id))
                        .zIndex(tab.id == draggedTabID ? 1 : 0)
                        .simultaneousGesture(dragGesture(for: tab.id))
                    }
                }
                .padding(.vertical, 4)
                .coordinateSpace(name: TabStripCoordinateSpace.name)
                .onPreferenceChange(TabFramePreferenceKey.self) { frames in
                    tabFrames = frames
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(.bar)
    }

    private func dragGesture(for tabID: DocumentTab.ID) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(TabStripCoordinateSpace.name))
            .onChanged { value in
                if draggedTabID == nil {
                    draggedTabID = tabID
                }

                guard draggedTabID == tabID else {
                    return
                }

                let destinationIndex = destinationIndex(
                    for: value.location.x,
                    draggedTabID: tabID
                )

                withAnimation(.easeOut(duration: 0.08)) {
                    viewModel.moveTab(tabID, to: destinationIndex)
                }
            }
            .onEnded { _ in
                draggedTabID = nil
            }
    }

    private func destinationIndex(for locationX: CGFloat, draggedTabID: DocumentTab.ID) -> Int {
        let orderedTabIDs = viewModel.openTabs
            .map(\.id)
            .filter { $0 != draggedTabID }

        return orderedTabIDs.reduce(0) { insertionIndex, tabID in
            guard let frame = tabFrames[tabID], locationX > frame.midX else {
                return insertionIndex
            }

            return insertionIndex + 1
        }
    }
}

private struct LibraryTabControl: View {
    let isSelected: Bool
    let action: () -> Void

    @GestureState private var isPressing = false
    @State private var isHovering = false
    @State private var suppressHoverUntilExit = false

    var body: some View {
        Image(systemName: "house")
            .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .frame(width: 32, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .scaleEffect(isPressing ? 0.94 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressing) { _, state, _ in
                        state = true
                    }
                    .onEnded { value in
                        guard isClick(value) else {
                            return
                        }

                        suppressHoverUntilExit = true
                        action()
                    }
            )
            .onHover { isInside in
                isHovering = isInside
                if !isInside {
                    suppressHoverUntilExit = false
                }
            }
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: isPressing)
            .accessibilityLabel("PDF一覧")
            .accessibilityAddTraits(.isButton)
            .help("PDF一覧")
    }

    private var backgroundColor: Color {
        if isPressing {
            return Color.accentColor.opacity(0.18)
        }

        if isHovering && !suppressHoverUntilExit {
            return Color.accentColor.opacity(0.11)
        }

        return .clear
    }

    private func isClick(_ value: DragGesture.Value) -> Bool {
        abs(value.translation.width) < 8 && abs(value.translation.height) < 8
    }
}

private struct TabButton: View {
    let tab: DocumentTab
    let isSelected: Bool
    let isDragging: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var isCloseHovering = false

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 7) {
                FileTypeIcon(kind: .pdf)

                Text(tab.title)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
            .padding(.leading, 9)
            .frame(maxWidth: 180, alignment: .leading)
            .frame(height: 30)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)
            .accessibilityAddTraits(.isButton)

            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isCloseHovering ? Color.primary : Color.secondary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isCloseHovering ? Color(nsColor: .separatorColor).opacity(0.28) : Color.clear)
                        .frame(width: 18, height: 18)
                )
                .contentShape(Rectangle())
                .onTapGesture(perform: onClose)
                .onHover { isCloseHovering = $0 }
                .accessibilityLabel("タブを閉じる")
                .accessibilityAddTraits(.isButton)
            .help("タブを閉じる")
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.11) : Color(nsColor: .controlBackgroundColor).opacity(0.75))
        )
        .opacity(isDragging ? 0.55 : 1)
        .scaleEffect(isDragging ? 0.98 : 1)
        .animation(.easeOut(duration: 0.12), value: isDragging)
        .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

private enum TabStripCoordinateSpace {
    static let name = "DocTwinTabStripCoordinateSpace"
}

private struct TabFrameReader: View {
    let tabID: DocumentTab.ID

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: TabFramePreferenceKey.self,
                value: [tabID: proxy.frame(in: .named(TabStripCoordinateSpace.name))]
            )
        }
    }
}

private struct TabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [DocumentTab.ID: CGRect] = [:]

    static func reduce(value: inout [DocumentTab.ID: CGRect], nextValue: () -> [DocumentTab.ID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}
