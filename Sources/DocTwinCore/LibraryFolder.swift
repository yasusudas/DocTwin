import Foundation

public struct LibraryFolder: Identifiable, Hashable {
    public let url: URL
    public let folders: [LibraryFolder]
    public let documents: [ReferenceDocument]

    public var id: String {
        url.standardizedFileURL.path
    }

    public var name: String {
        url.lastPathComponent
    }

    public var recursiveDocuments: [ReferenceDocument] {
        documents + folders.flatMap(\.recursiveDocuments)
    }

    public var recursiveDocumentCount: Int {
        documents.count + folders.reduce(0) { $0 + $1.recursiveDocumentCount }
    }

    public init(url: URL, folders: [LibraryFolder], documents: [ReferenceDocument]) {
        self.url = url
        self.folders = folders
        self.documents = documents
    }

    public func folder(withID id: ID) -> LibraryFolder? {
        if self.id == id {
            return self
        }

        for folder in folders {
            if let match = folder.folder(withID: id) {
                return match
            }
        }

        return nil
    }

    public func path(to id: ID) -> [LibraryFolder]? {
        if self.id == id {
            return [self]
        }

        for folder in folders {
            if let childPath = folder.path(to: id) {
                return [self] + childPath
            }
        }

        return nil
    }
}
