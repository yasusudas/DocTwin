import XCTest
@testable import DocTwinCore

final class PageMarkdownDocumentTests: XCTestCase {
    func testUnmarkedMarkdownReturnsOriginalText() {
        let markdown = """
        # 全体解説

        通常のMarkdownです。
        """

        let document = PageMarkdownDocument(markdown: markdown)

        XCTAssertFalse(document.hasPageMarkers)
        XCTAssertEqual(document.markdown(forPage: 2), markdown)
    }

    func testReturnsExactPageBlock() {
        let markdown = """
        <!-- page: 1 -->
        ## p.1

        1ページ目です。
        <!-- /page -->

        <!-- page: 2 -->
        ## p.2

        2ページ目です。
        <!-- /page -->
        """

        let document = PageMarkdownDocument(markdown: markdown)

        XCTAssertEqual(
            document.markdown(forPage: 2),
            """
            ## p.2

            2ページ目です。
            """
        )
    }

    func testExactPageBlockTakesPriorityOverRange() {
        let markdown = """
        <!-- pages: 2-4 -->
        ## 範囲
        <!-- /pages -->

        <!-- page: 3 -->
        ## 個別
        <!-- /page -->
        """

        let document = PageMarkdownDocument(markdown: markdown)

        XCTAssertEqual(document.markdown(forPage: 3), "## 個別")
    }

    func testReturnsRangeBlock() {
        let markdown = """
        <!-- pages: 3-5 -->
        ## p.3〜p.5

        共通解説です。
        <!-- /pages -->
        """

        let document = PageMarkdownDocument(markdown: markdown)

        XCTAssertEqual(
            document.markdown(forPage: 4),
            """
            ## p.3〜p.5

            共通解説です。
            """
        )
    }

    func testReturnsDefaultWhenPageDoesNotMatch() {
        let markdown = """
        <!-- page: 1 -->
        ## p.1
        <!-- /page -->

        <!-- default -->
        ## 未設定

        このページには個別解説がありません。
        <!-- /default -->
        """

        let document = PageMarkdownDocument(markdown: markdown)

        XCTAssertEqual(
            document.markdown(forPage: 9),
            """
            ## 未設定

            このページには個別解説がありません。
            """
        )
    }
}
