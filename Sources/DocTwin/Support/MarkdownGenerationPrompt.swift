import Foundation
import DocTwinCore

enum MarkdownGenerationPrompt {
    static func make(for document: ReferenceDocument, pageCount: Int) -> String {
        let pdfURL = document.pdfURL.standardizedFileURL
        let directoryURL = pdfURL.deletingLastPathComponent()
        let markdownURL = document.explanationURL.standardizedFileURL
        let template = loadTemplate()

        return """
        # DocTwin Markdown生成依頼

        ## 1. PDFファイルのあるディレクトリ

        このPDFが置かれているディレクトリは次の通りです。

        ```text
        \(directoryURL.path)
        ```

        対象PDF:

        ```text
        \(pdfURL.path)
        ```

        PDFページ数:

        ```text
        \(pageCount)
        ```

        ## 2. PDFと同名のMarkdownファイルを生成する指示

        上記のPDFを読み取り、PDFファイルと同じディレクトリに、PDFと完全に同名で拡張子だけを `.md` に変更したMarkdownファイルを生成してください。

        生成するMarkdownファイル:

        ```text
        \(markdownURL.path)
        ```

        ファイル名の空白、記号、全角文字、バージョン番号、大文字小文字は変更しないでください。

        生成するMarkdown本文は、DocTwinのページ別解説ビューアで読み込むため、下記のプロンプトに完全に従ってください。

        ## 3. PDFページ別解説Markdown生成プロンプト

        \(template)
        """
    }

    private static func loadTemplate() -> String {
        guard let url = Bundle.main.url(
            forResource: "PageExplanationGeneratorPrompt",
            withExtension: "md"
        ) else {
            return """
            # PDFページ別解説Markdown生成プロンプト

            プロンプトテンプレートをアプリリソースから読み込めませんでした。
            """
        }

        return (try? String(contentsOf: url, encoding: .utf8)) ?? """
        # PDFページ別解説Markdown生成プロンプト

        プロンプトテンプレートを読み込めませんでした。
        """
    }
}
