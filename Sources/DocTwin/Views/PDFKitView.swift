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

        if pdfView.document !== document {
            pdfView.document = document
            (pdfView as? ContainedPagePDFView)?.scheduleFitToContainer()
        }

        guard
            let document,
            currentPageIndex >= 0,
            currentPageIndex < document.pageCount,
            let page = document.page(at: currentPageIndex),
            pdfView.currentPage !== page
        else {
            (pdfView as? ContainedPagePDFView)?.scheduleFitToContainer()
            return
        }

        pdfView.go(to: page)
        (pdfView as? ContainedPagePDFView)?.scheduleFitToContainer()
    }

    final class Coordinator: NSObject {
        var parent: PDFKitView

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

            DispatchQueue.main.async {
                self.parent.onPageChanged(pageIndex)
            }
        }
    }
}

private final class ContainedPagePDFView: PDFView {
    private let targetContainerRatio: CGFloat = 0.95
    private var lastFittedBoundsSize: CGSize = .zero
    private var isFitScheduled = false

    override func layout() {
        super.layout()

        guard bounds.size != lastFittedBoundsSize else {
            return
        }

        scheduleFitToContainer()
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
