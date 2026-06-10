import AppKit
import SwiftUI

struct PersistentHSplitView<Leading: View, Trailing: View>: NSViewRepresentable {
    let storageKey: String
    let leadingMinWidth: CGFloat
    let trailingMinWidth: CGFloat
    let leading: Leading
    let trailing: Trailing

    init(
        storageKey: String,
        leadingMinWidth: CGFloat,
        trailingMinWidth: CGFloat,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.storageKey = storageKey
        self.leadingMinWidth = leadingMinWidth
        self.trailingMinWidth = trailingMinWidth
        self.leading = leading()
        self.trailing = trailing()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            storageKey: storageKey,
            leadingMinWidth: leadingMinWidth,
            trailingMinWidth: trailingMinWidth
        )
    }

    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator

        let leadingHost = NSHostingView(rootView: leading)
        let trailingHost = NSHostingView(rootView: trailing)

        leadingHost.setContentHuggingPriority(.defaultLow, for: .horizontal)
        trailingHost.setContentHuggingPriority(.defaultLow, for: .horizontal)

        splitView.addSubview(leadingHost)
        splitView.addSubview(trailingHost)

        context.coordinator.install(
            splitView: splitView,
            leadingHost: leadingHost,
            trailingHost: trailingHost
        )
        context.coordinator.scheduleStoredRatioRestore()

        return splitView
    }

    func updateNSView(_ splitView: NSSplitView, context: Context) {
        context.coordinator.update(
            storageKey: storageKey,
            leadingMinWidth: leadingMinWidth,
            trailingMinWidth: trailingMinWidth,
            leading: leading,
            trailing: trailing
        )
        context.coordinator.scheduleStoredRatioRestore()
    }

    final class Coordinator: NSObject, NSSplitViewDelegate {
        private var storageKey: String
        private var leadingMinWidth: CGFloat
        private var trailingMinWidth: CGFloat
        private let defaults: UserDefaults
        private weak var splitView: NSSplitView?
        private var leadingHost: NSHostingView<Leading>?
        private var trailingHost: NSHostingView<Trailing>?
        private var didAttemptInitialRestore = false
        private var isRestoringStoredRatio = false
        private var isRestoreScheduled = false

        init(
            storageKey: String,
            leadingMinWidth: CGFloat,
            trailingMinWidth: CGFloat,
            defaults: UserDefaults = .standard
        ) {
            self.storageKey = storageKey
            self.leadingMinWidth = leadingMinWidth
            self.trailingMinWidth = trailingMinWidth
            self.defaults = defaults
        }

        func install(
            splitView: NSSplitView,
            leadingHost: NSHostingView<Leading>,
            trailingHost: NSHostingView<Trailing>
        ) {
            self.splitView = splitView
            self.leadingHost = leadingHost
            self.trailingHost = trailingHost
        }

        func update(
            storageKey: String,
            leadingMinWidth: CGFloat,
            trailingMinWidth: CGFloat,
            leading: Leading,
            trailing: Trailing
        ) {
            if self.storageKey != storageKey {
                self.storageKey = storageKey
                didAttemptInitialRestore = false
            }

            self.leadingMinWidth = leadingMinWidth
            self.trailingMinWidth = trailingMinWidth
            leadingHost?.rootView = leading
            trailingHost?.rootView = trailing
        }

        func scheduleStoredRatioRestore() {
            guard !didAttemptInitialRestore, !isRestoreScheduled else {
                return
            }

            isRestoreScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }

                self.isRestoreScheduled = false
                guard let splitView = self.splitView else {
                    return
                }

                self.applyStoredRatioIfNeeded(to: splitView)
            }
        }

        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let splitView = notification.object as? NSSplitView else {
                return
            }

            if !didAttemptInitialRestore {
                applyStoredRatioIfNeeded(to: splitView)
                return
            }

            guard !isRestoringStoredRatio else {
                return
            }

            saveCurrentRatio(from: splitView)
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMinCoordinate proposedMinimumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            let bounds = dividerBounds(for: splitView.bounds.width)
            return min(max(proposedMinimumPosition, bounds.lowerBound), bounds.upperBound)
        }

        func splitView(
            _ splitView: NSSplitView,
            constrainMaxCoordinate proposedMaximumPosition: CGFloat,
            ofSubviewAt dividerIndex: Int
        ) -> CGFloat {
            let bounds = dividerBounds(for: splitView.bounds.width)
            return min(max(proposedMaximumPosition, bounds.lowerBound), bounds.upperBound)
        }

        private func applyStoredRatioIfNeeded(to splitView: NSSplitView) {
            guard !didAttemptInitialRestore else {
                return
            }

            guard canMeasure(splitView) else {
                return
            }

            didAttemptInitialRestore = true

            guard let storedRatio = defaults.object(forKey: storageKey) as? Double else {
                return
            }

            isRestoringStoredRatio = true
            splitView.setPosition(
                constrainedDividerPosition(
                    for: CGFloat(storedRatio),
                    totalWidth: splitView.bounds.width
                ),
                ofDividerAt: 0
            )
            isRestoringStoredRatio = false
        }

        private func saveCurrentRatio(from splitView: NSSplitView) {
            guard canMeasure(splitView) else {
                return
            }

            let leadingWidth = splitView.subviews[0].frame.width
            let ratio = min(max(leadingWidth / splitView.bounds.width, 0), 1)
            defaults.set(Double(ratio), forKey: storageKey)
        }

        private func canMeasure(_ splitView: NSSplitView) -> Bool {
            splitView.subviews.count >= 2 && splitView.bounds.width > 0
        }

        private func constrainedDividerPosition(for ratio: CGFloat, totalWidth: CGFloat) -> CGFloat {
            let bounds = dividerBounds(for: totalWidth)
            let proposedPosition = totalWidth * min(max(ratio, 0), 1)
            return min(max(proposedPosition, bounds.lowerBound), bounds.upperBound)
        }

        private func dividerBounds(for totalWidth: CGFloat) -> ClosedRange<CGFloat> {
            guard totalWidth > 0 else {
                return 0...0
            }

            let lowerBound = min(max(leadingMinWidth, 0), totalWidth)
            let upperBound = max(0, min(totalWidth - trailingMinWidth, totalWidth))

            guard lowerBound <= upperBound else {
                let fallback = min(max(totalWidth * 0.5, 0), totalWidth)
                return fallback...fallback
            }

            return lowerBound...upperBound
        }
    }
}
