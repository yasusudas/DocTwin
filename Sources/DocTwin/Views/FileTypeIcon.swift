import AppKit
import SwiftUI

enum FileTypeIconKind {
    case folder
    case pdf
    case markdown
}

struct FileTypeIcon: View {
    let kind: FileTypeIconKind
    var size: CGFloat = 16
    var color: Color = .secondary

    var body: some View {
        if kind == .folder {
            Image(nsImage: IconImageStore.image(for: kind))
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: size, height: size * IconImageStore.folderDisplayHeightRatio)
                .accessibilityHidden(true)
        } else {
            Image(nsImage: IconImageStore.image(for: kind))
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

private enum IconImageStore {
    // Icons from @vscode/codicons, CC-BY-4.0. Copyright Microsoft Corporation.
    static let folderDisplayHeightRatio: CGFloat = 414 / 512

    static func image(for kind: FileTypeIconKind) -> NSImage {
        switch kind {
        case .folder:
            return folder
        case .pdf:
            return pdf
        case .markdown:
            return markdown
        }
    }

    private static let folder = loadOriginalImage(named: "FolderIcon") ?? makeTemplateImage(
        svg: """
        <svg width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
          <path d="M1.5 3C0.672 3 0 3.672 0 4.5V12.5C0 13.328 0.672 14 1.5 14H14.5C15.328 14 16 13.328 16 12.5V5.5C16 4.672 15.328 4 14.5 4H8.414C8.149 4 7.895 3.895 7.707 3.707L6.793 2.793C6.512 2.512 6.13 2.354 5.732 2.354H1.5C0.672 2.354 0 3.026 0 3.854V4.5C0 3.672 0.672 3 1.5 3Z"/>
          <path d="M0 5.25C0 4.422 0.672 3.75 1.5 3.75H14.5C15.328 3.75 16 4.422 16 5.25V12.5C16 13.328 15.328 14 14.5 14H1.5C0.672 14 0 13.328 0 12.5V5.25Z" opacity="0.72"/>
        </svg>
        """
    )

    private static let pdf = makeTemplateImage(
        svg: """
        <svg width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
          <path d="M13.5 7H13V5.414C13 5.016 12.842 4.635 12.561 4.353L9.647 1.439C9.366 1.158 8.984 1 8.586 1H5C3.895 1 3 1.895 3 3V7H2.5C1.673 7 1 7.673 1 8.5V13.5C1 14.327 1.673 15 2.5 15H13.5C14.327 15 15 14.327 15 13.5V8.5C15 7.673 14.327 7 13.5 7ZM9 2.207L11.793 5H9.5C9.224 5 9 4.776 9 4.5V2.207ZM4 3C4 2.448 4.448 2 5 2H8V4.5C8 5.328 8.672 6 9.5 6H12V7H4V3ZM14 13.5C14 13.775 13.775 14 13.5 14H2.5C2.224 14 2 13.775 2 13.5V8.5C2 8.225 2.224 8 2.5 8H13.5C13.775 8 14 8.225 14 8.5V13.5Z"/>
          <path d="M4.5 9H3.5C3.224 9 3 9.224 3 9.5V12.5C3 12.776 3.224 13 3.5 13C3.776 13 4 12.776 4 12.5V12H4.5C5.327 12 6 11.327 6 10.5C6 9.673 5.327 9 4.5 9ZM4.5 11H4V10H4.5C4.776 10 5 10.225 5 10.5C5 10.775 4.776 11 4.5 11Z"/>
          <path d="M8 9H7.5C7.224 9 7 9.224 7 9.5V12.5C7 12.776 7.224 13 7.5 13H8C9.103 13 10 12.103 10 11C10 9.897 9.103 9 8 9ZM8 12V10C8.552 10 9 10.448 9 11C9 11.552 8.552 12 8 12Z"/>
          <path d="M13 9H11.5C11.224 9 11 9.224 11 9.5V12.5C11 12.776 11.224 13 11.5 13C11.776 13 12 12.776 12 12.5V12H12.5C12.776 12 13 11.776 13 11.5C13 11.224 12.776 11 12.5 11H12V10H13C13.276 10 13.5 9.776 13.5 9.5C13.5 9.224 13.276 9 13 9Z"/>
        </svg>
        """
    )

    private static let markdown = makeTemplateImage(
        svg: """
        <svg width="16" height="16" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg" fill="currentColor">
          <path d="M9 3.5V11.5C9 11.776 8.776 12 8.5 12C8.224 12 8 11.776 8 11.5V4.831L5.376 7.83C5.187 8.048 4.814 8.048 4.624 7.83L2 4.831V11.5C2 11.776 1.776 12 1.5 12C1.224 12 1 11.776 1 11.5V3.5C1 3.292 1.129 3.105 1.324 3.032C1.521 2.96 1.74 3.014 1.876 3.171L5 6.741L8.124 3.171C8.261 3.014 8.478 2.959 8.676 3.032C8.871 3.105 9 3.292 9 3.5ZM14.854 9.146C14.659 8.951 14.342 8.951 14.147 9.146L13.001 10.292V3.5C13.001 3.224 12.777 3 12.501 3C12.225 3 12.001 3.224 12.001 3.5V10.293L10.855 9.147C10.66 8.952 10.343 8.952 10.148 9.147C9.953 9.342 9.953 9.659 10.148 9.854L12.148 11.854C12.246 11.952 12.757 11.952 12.855 11.854L14.855 9.854C15.05 9.659 15.05 9.342 14.855 9.147L14.854 9.146Z"/>
        </svg>
        """
    )

    private static func makeTemplateImage(svg: String) -> NSImage {
        let image = NSImage(data: Data(svg.utf8)) ?? NSImage(size: NSSize(width: 16, height: 16))
        image.isTemplate = true
        return image
    }

    private static func loadOriginalImage(named name: String) -> NSImage? {
        let projectResourcesURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("\(name).png")

        let candidateURLs = [
            Bundle.main.url(forResource: name, withExtension: "png"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(name).png"),
            projectResourcesURL,
        ]

        for resourceURL in candidateURLs.compactMap({ $0 }) {
            guard let image = NSImage(contentsOf: resourceURL) else {
                continue
            }

            image.isTemplate = false
            return image
        }

        return nil
    }
}
