import PDFKit
import SwiftUI

struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument?
    @Binding var currentPageIndex: Int
    var onPageChanged: (Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = ContainedPagePDFView()
        pdfView.autoScales = false
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.displaysPageBreaks = false
        pdfView.backgroundColor = .textBackgroundColor
        pdfView.minScaleFactor = 0.05
        pdfView.maxScaleFactor = 5.0
        pdfView.clearSelection()

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self

        var didApplyProgrammaticChange = false

        if pdfView.document !== document {
            context.coordinator.performProgrammaticPageChange(targetPageIndex: currentPageIndex) {
                pdfView.document = document
            }
            didApplyProgrammaticChange = true
            (pdfView as? ContainedPagePDFView)?.scheduleFitToContainer()
        }

        guard
            let document,
            currentPageIndex >= 0,
            currentPageIndex < document.pageCount,
            let page = document.page(at: currentPageIndex),
            pdfView.currentPage !== page
        else {
            if !didApplyProgrammaticChange {
                (pdfView as? ContainedPagePDFView)?.scheduleFitToContainer()
            }
            return
        }

        context.coordinator.performProgrammaticPageChange(targetPageIndex: currentPageIndex) {
            pdfView.go(to: page)
        }
        (pdfView as? ContainedPagePDFView)?.scheduleFitToContainer()
    }

    final class Coordinator: NSObject {
        var parent: PDFKitView
        private var isApplyingProgrammaticPageChange = false
        private var protectedProgrammaticPageIndex: Int?

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func pageChanged(_ notification: Notification) {
            guard
                let pdfView = notification.object as? PDFView,
                let document = pdfView.document,
                let currentPage = pdfView.currentPage
            else {
                return
            }

            let pageIndex = document.index(for: currentPage)
            guard pageIndex != NSNotFound else {
                return
            }

            guard !isApplyingProgrammaticPageChange else {
                return
            }

            if let protectedProgrammaticPageIndex {
                if pageIndex == protectedProgrammaticPageIndex {
                    self.protectedProgrammaticPageIndex = nil
                }
                return
            }

            DispatchQueue.main.async {
                self.parent.onPageChanged(pageIndex)
            }
        }

        func performProgrammaticPageChange(targetPageIndex: Int, _ change: () -> Void) {
            isApplyingProgrammaticPageChange = true
            protectedProgrammaticPageIndex = targetPageIndex
            change()

            DispatchQueue.main.async { [weak self] in
                self?.isApplyingProgrammaticPageChange = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard self?.protectedProgrammaticPageIndex == targetPageIndex else {
                    return
                }

                self?.protectedProgrammaticPageIndex = nil
            }
        }
    }
}

private final class ContainedPagePDFView: PDFView {
    private let targetContainerRatio: CGFloat = 0.95
    private var lastFittedBoundsSize: CGSize = .zero
    private var isFitScheduled = false

    override var acceptsFirstResponder: Bool {
        false
    }

    override func layout() {
        super.layout()

        guard bounds.size != lastFittedBoundsSize else {
            return
        }

        scheduleFitToContainer()
    }

    override func mouseDown(with event: NSEvent) {
        clearSelection()
    }

    override func mouseDragged(with event: NSEvent) {
        clearSelection()
    }

    override func mouseUp(with event: NSEvent) {
        clearSelection()
    }

    override func rightMouseDown(with event: NSEvent) {
        clearSelection()
    }

    override func rightMouseDragged(with event: NSEvent) {
        clearSelection()
    }

    override func rightMouseUp(with event: NSEvent) {
        clearSelection()
    }

    override func otherMouseDown(with event: NSEvent) {
        clearSelection()
    }

    override func otherMouseDragged(with event: NSEvent) {
        clearSelection()
    }

    override func otherMouseUp(with event: NSEvent) {
        clearSelection()
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        clearSelection()
        return nil
    }

    override func clearSelection() {
        super.clearSelection()
        setCurrentSelection(nil, animate: false)
    }

    func scheduleFitToContainer() {
        guard !isFitScheduled else {
            return
        }

        isFitScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.isFitScheduled = false
            self.fitCurrentPageToContainer()
        }
    }

    private func fitCurrentPageToContainer() {
        guard
            bounds.width > 1,
            bounds.height > 1,
            let document,
            let page = currentPage ?? document.page(at: 0)
        else {
            return
        }

        autoScales = false
        lastFittedBoundsSize = bounds.size

        let pageBounds = page.bounds(for: displayBox)
        guard pageBounds.width > 0, pageBounds.height > 0 else {
            return
        }

        let targetWidth = bounds.width * targetContainerRatio
        let targetHeight = bounds.height * targetContainerRatio
        let widthScale = targetWidth / pageBounds.width
        let heightScale = targetHeight / pageBounds.height
        let targetScale = min(widthScale, heightScale)

        scaleFactor = min(max(targetScale, minScaleFactor), maxScaleFactor)
    }
}
