import AppKit
import Foundation

final class MenuLocalizer {
    static let shared = MenuLocalizer()

    private let translations: [String: String]

    private init() {
        translations = Self.loadTranslations()
    }

    @MainActor
    func localizeMainMenu() {
        guard !translations.isEmpty else {
            return
        }

        NSApp.mainMenu?.items.forEach(localize)
    }

    @MainActor
    private func localize(_ item: NSMenuItem) {
        if !item.title.isEmpty, let localizedTitle = localizedTitle(for: item.title) {
            item.title = localizedTitle
        }

        if let submenu = item.submenu {
            if let localizedTitle = localizedTitle(for: submenu.title) {
                submenu.title = localizedTitle
            }
            submenu.items.forEach(localize)
        }
    }

    private func localizedTitle(for title: String) -> String? {
        let normalizedTitle = title.replacingOccurrences(of: "...", with: "…")

        if let translation = translations[title] ?? translations[normalizedTitle] {
            return translation
        }

        if normalizedTitle.hasPrefix("About ") {
            return "\(String(normalizedTitle.dropFirst("About ".count)))について"
        }

        if normalizedTitle.hasPrefix("Hide ") {
            return "\(String(normalizedTitle.dropFirst("Hide ".count)))を非表示"
        }

        if normalizedTitle.hasPrefix("Quit ") {
            return "\(String(normalizedTitle.dropFirst("Quit ".count)))を終了"
        }

        if normalizedTitle.hasSuffix(" Help") {
            return "\(String(normalizedTitle.dropLast(" Help".count)))ヘルプ"
        }

        return nil
    }

    private static func loadTranslations() -> [String: String] {
        guard let url = Bundle.main.url(
            forResource: "MenuLocalizable",
            withExtension: "strings",
            subdirectory: nil,
            localization: "ja"
        ) else {
            return [:]
        }

        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ),
            let translations = plist as? [String: String]
        else {
            return [:]
        }

        return translations
    }
}
