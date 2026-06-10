import SwiftUI

struct SortMenu: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Menu {
            Section("このフォルダだけ") {
                ForEach(LibrarySortOrder.allCases) { sortOrder in
                    Button {
                        viewModel.setCurrentFolderSortOrder(sortOrder)
                    } label: {
                        menuLabel(
                            title: sortOrder.title,
                            isSelected: viewModel.currentFolderSortOrder == sortOrder
                        )
                    }
                }
            }

            Section("すべてのフォルダに適用") {
                ForEach(LibrarySortOrder.allCases) { sortOrder in
                    Button {
                        viewModel.applySortOrderToAllFolders(sortOrder)
                    } label: {
                        menuLabel(
                            title: sortOrder.title,
                            isSelected: viewModel.globalSortOrder == sortOrder && viewModel.folderSortOrders.isEmpty
                        )
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.grid.3x2")
                    .font(.system(size: 15, weight: .medium))

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .frame(width: 34, height: 26)
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .disabled(viewModel.libraryURL == nil)
        .help("並び替え")
        .accessibilityLabel("並び替え")
    }

    @ViewBuilder
    private func menuLabel(title: String, isSelected: Bool) -> some View {
        if isSelected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
