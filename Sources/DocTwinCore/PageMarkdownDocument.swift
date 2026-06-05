import Foundation

public struct PageMarkdownDocument {
    public let originalMarkdown: String
    public let commonMarkdown: String?
    public let defaultMarkdown: String?

    private let sections: [PageMarkdownSection]

    public init(markdown: String) {
        originalMarkdown = markdown

        let parsed = Self.parse(markdown)
        commonMarkdown = parsed.common
        defaultMarkdown = parsed.default
        sections = parsed.sections
    }

    public var hasPageMarkers: Bool {
        commonMarkdown != nil || defaultMarkdown != nil || !sections.isEmpty
    }

    public func markdown(forPage pageNumber: Int) -> String {
        guard hasPageMarkers else {
            return originalMarkdown
        }

        let exactMatches = sections.filter {
            $0.kind == .page && $0.contains(pageNumber)
        }

        if !exactMatches.isEmpty {
            return joinedMarkdown(exactMatches.map(\.markdown))
        }

        let rangeMatches = sections.filter {
            $0.kind == .pages && $0.contains(pageNumber)
        }

        if !rangeMatches.isEmpty {
            return joinedMarkdown(rangeMatches.map(\.markdown))
        }

        if let defaultMarkdown, !defaultMarkdown.isEmpty {
            return defaultMarkdown
        }

        if let commonMarkdown, !commonMarkdown.isEmpty {
            return commonMarkdown
        }

        return """
        ## p.\(pageNumber) の解説

        このページに対応する解説ブロックはありません。

        """
    }

    private static func parse(_ markdown: String) -> ParsedMarkdown {
        let pattern = #"<!--\s*(common|default|page\s*:\s*([0-9]+)|pages\s*:\s*([0-9]+)\s*-\s*([0-9]+))\s*-->(.*?)<!--\s*/\s*(common|default|page|pages)\s*-->"#
        let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )

        let source = markdown as NSString
        let matches = regex?.matches(
            in: markdown,
            options: [],
            range: NSRange(location: 0, length: source.length)
        ) ?? []

        var common: String?
        var fallback: String?
        var sections: [PageMarkdownSection] = []

        for match in matches {
            let marker = source.string(for: match.range(at: 1)).lowercased()
            let body = source.string(for: match.range(at: 5)).trimmingMarkdownBlock()
            let closeMarker = source.string(for: match.range(at: 6)).lowercased()

            if marker == "common", closeMarker == "common" {
                common = common ?? body
                continue
            }

            if marker == "default", closeMarker == "default" {
                fallback = fallback ?? body
                continue
            }

            if marker.hasPrefix("page"), closeMarker == "page" {
                let pageNumber = source.integer(for: match.range(at: 2))
                sections.append(
                    PageMarkdownSection(
                        kind: .page,
                        startPage: pageNumber,
                        endPage: pageNumber,
                        markdown: body
                    )
                )
                continue
            }

            if marker.hasPrefix("pages"), closeMarker == "pages" {
                let startPage = source.integer(for: match.range(at: 3))
                let endPage = source.integer(for: match.range(at: 4))

                sections.append(
                    PageMarkdownSection(
                        kind: .pages,
                        startPage: min(startPage, endPage),
                        endPage: max(startPage, endPage),
                        markdown: body
                    )
                )
            }
        }

        return ParsedMarkdown(common: common, default: fallback, sections: sections)
    }

    private func joinedMarkdown(_ parts: [String]) -> String {
        parts
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n---\n\n")
    }
}

private struct ParsedMarkdown {
    let common: String?
    let `default`: String?
    let sections: [PageMarkdownSection]
}

private struct PageMarkdownSection {
    let kind: PageMarkdownSectionKind
    let startPage: Int
    let endPage: Int
    let markdown: String

    func contains(_ pageNumber: Int) -> Bool {
        startPage <= pageNumber && pageNumber <= endPage
    }
}

private enum PageMarkdownSectionKind {
    case page
    case pages
}

private extension NSString {
    func string(for range: NSRange) -> String {
        guard range.location != NSNotFound else {
            return ""
        }
        return substring(with: range)
    }

    func integer(for range: NSRange) -> Int {
        Int(string(for: range)) ?? 0
    }
}

private extension String {
    func trimmingMarkdownBlock() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
