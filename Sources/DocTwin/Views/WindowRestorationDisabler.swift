import AppKit
import SwiftUI

struct WindowRestorationDisabler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        RestorationDisablingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? RestorationDisablingView)?.configureWindow()
    }
}

private final class RestorationDisablingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
    }

    func configureWindow() {
        guard let window else {
            return
        }

        window.isRestorable = false
        window.restorationClass = nil
        window.disableSnapshotRestoration()
    }
}
