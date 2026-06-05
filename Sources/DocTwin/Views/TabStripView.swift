import SwiftUI

struct TabStripView: View {
    @EnvironmentObject private var viewModel: AppViewModel

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
                            onSelect: { viewModel.selectTab(tab.id) },
                            onClose: { viewModel.closeTab(tab.id) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(.bar)
    }
}

private struct LibraryTabControl: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "square.grid.2x2")
                .foregroundStyle(.secondary)

            Text("すべて")
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.11) : Color.clear)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture(perform: action)
        .accessibilityLabel("PDF一覧")
        .accessibilityAddTraits(.isButton)
        .help("PDF一覧")
    }
}

private struct TabButton: View {
    let tab: DocumentTab
    let isSelected: Bool
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
        .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}
