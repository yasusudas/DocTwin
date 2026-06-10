import Foundation

enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case nameAscending
    case nameDescending
    case modifiedNewest
    case modifiedOldest

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .nameAscending:
            return "名前順"
        case .nameDescending:
            return "名前の逆順"
        case .modifiedNewest:
            return "更新日が新しい順"
        case .modifiedOldest:
            return "更新日が古い順"
        }
    }
}
