import AppKit
import SwiftUI

struct KeyboardEventMonitor: NSViewRepresentable {
    var onLeftArrow: () -> Void
    var onRightArrow: () -> Void
    var onCloseTab: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLeftArrow: onLeftArrow, onRightArrow: onRightArrow, onCloseTab: onCloseTab)
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.installIfNeeded()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onLeftArrow = onLeftArrow
        context.coordinator.onRightArrow = onRightArrow
        context.coordinator.onCloseTab = onCloseTab
        context.coordinator.installIfNeeded()
    }

    final class Coordinator {
        var onLeftArrow: () -> Void
        var onRightArrow: () -> Void
        var onCloseTab: () -> Void
        private var monitor: Any?

        init(
            onLeftArrow: @escaping () -> Void,
            onRightArrow: @escaping () -> Void,
            onCloseTab: @escaping () -> Void
        ) {
            self.onLeftArrow = onLeftArrow
            self.onRightArrow = onRightArrow
            self.onCloseTab = onCloseTab
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func installIfNeeded() {
            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else {
                    return event
                }

                if self.shouldHandleCloseTab(event: event) {
                    self.onCloseTab()
                    return nil
                }

                if self.shouldSuppressTabTraversal(event: event) {
                    self.clearKeyFocus()
                    return nil
                }

                guard self.shouldHandlePageNavigation(event: event) else {
                    return event
                }

                switch event.keyCode {
                case 123:
                    self.onLeftArrow()
                    return nil
                case 124:
                    self.onRightArrow()
                    return nil
                default:
                    return event
                }
            }
        }

        private func shouldHandlePageNavigation(event: NSEvent) -> Bool {
            guard NSApp.modalWindow == nil, NSApp.keyWindow?.isMainWindow == true else {
                return false
            }

            let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            guard event.modifierFlags.intersection(blockedModifiers).isEmpty else {
                return false
            }

            if let firstResponder = NSApp.keyWindow?.firstResponder,
               firstResponder is NSTextView || firstResponder is NSTextField {
                return false
            }

            return event.keyCode == 123 || event.keyCode == 124
        }

        private func shouldSuppressTabTraversal(event: NSEvent) -> Bool {
            guard NSApp.modalWindow == nil, NSApp.keyWindow?.isMainWindow == true else {
                return false
            }

            let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
            guard event.modifierFlags.intersection(blockedModifiers).isEmpty else {
                return false
            }

            return event.keyCode == 48
        }

        private func clearKeyFocus() {
            guard let keyWindow = NSApp.keyWindow else {
                return
            }

            keyWindow.makeFirstResponder(nil)
        }

        private func shouldHandleCloseTab(event: NSEvent) -> Bool {
            guard NSApp.modalWindow == nil, NSApp.keyWindow?.isMainWindow == true else {
                return false
            }

            let relevantModifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard relevantModifiers == .command else {
                return false
            }

            return event.keyCode == 13 || event.charactersIgnoringModifiers?.lowercased() == "w"
        }
    }
}
