import CoreServices
import Foundation

final class LibraryChangeMonitor {
    private let eventQueue = DispatchQueue(label: "DocTwin.LibraryChangeMonitor")
    private let onChange: @MainActor () -> Void
    private var stream: FSEventStreamRef?

    init(url: URL, onChange: @MainActor @escaping () -> Void) {
        self.onChange = onChange
        startMonitoring(url)
    }

    deinit {
        stop()
    }

    func stop() {
        guard let stream else {
            return
        }

        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func startMonitoring(_ url: URL) {
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer |
            kFSEventStreamCreateFlagUseCFTypes
        )

        stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            { _, contextInfo, eventCount, _, eventFlags, _ in
                guard let contextInfo else {
                    return
                }

                let monitor = Unmanaged<LibraryChangeMonitor>
                    .fromOpaque(contextInfo)
                    .takeUnretainedValue()
                monitor.handleEvents(count: eventCount, flags: eventFlags)
            },
            &context,
            [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.35,
            flags
        )

        guard let stream else {
            return
        }

        FSEventStreamSetDispatchQueue(stream, eventQueue)
        FSEventStreamStart(stream)
    }

    private func handleEvents(count: Int, flags: UnsafePointer<FSEventStreamEventFlags>) {
        guard (0..<count).contains(where: { isRelevantEvent(flags[$0]) }) else {
            return
        }

        Task { @MainActor [onChange] in
            onChange()
        }
    }

    private func isRelevantEvent(_ flags: FSEventStreamEventFlags) -> Bool {
        let ignoredFlags =
            FSEventStreamEventFlags(kFSEventStreamEventFlagItemInodeMetaMod) |
            FSEventStreamEventFlags(kFSEventStreamEventFlagItemFinderInfoMod) |
            FSEventStreamEventFlags(kFSEventStreamEventFlagItemChangeOwner) |
            FSEventStreamEventFlags(kFSEventStreamEventFlagItemXattrMod)

        return flags & ignoredFlags != flags
    }
}
