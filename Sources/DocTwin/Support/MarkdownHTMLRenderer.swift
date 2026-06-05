import Foundation

enum MarkdownHTMLRenderer {
    static func html(markdown: String, title: String) -> String {
        let payload = Payload(source: markdown, title: title)
        let payloadData = (try? JSONEncoder().encode(payload)) ?? Data(#"{"source":"","title":"解説"}"#.utf8)
        let payloadJSON = String(data: payloadData, encoding: .utf8) ?? #"{"source":"","title":"解説"}"#

        return #"""
        <!doctype html>
        <html lang="ja">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\#(escapedHTML(title))</title>
          <script>
            window.MathJax = {
              tex: {
                inlineMath: [['$', '$'], ['\\(', '\\)']],
                displayMath: [['$$', '$$'], ['\\[', '\\]']],
                processEscapes: true
              },
              options: { skipHtmlTags: ['script', 'noscript', 'style', 'textarea', 'pre', 'code'] }
            };
          </script>
          <script defer src="https://cdn.jsdelivr.net/npm/marked@12.0.2/marked.min.js"></script>
          <script defer src="https://cdn.jsdelivr.net/npm/dompurify@3.0.11/dist/purify.min.js"></script>
          <script defer src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
          <style>
            :root {
              color-scheme: light dark;
              --background: #ffffff;
              --text: #1f2328;
              --muted: #667085;
              --border: #d0d7de;
              --table-header: #f6f8fa;
              --code-background: #f6f8fa;
              --accent: #0a7ea4;
            }

            @media (prefers-color-scheme: dark) {
              :root {
                --background: #1f1f1f;
                --text: #f2f2f2;
                --muted: #b5bac1;
                --border: #3d444d;
                --table-header: #2a2d31;
                --code-background: #2a2d31;
                --accent: #66c7e8;
              }
            }

            html, body {
              margin: 0;
              min-height: 100%;
              background: var(--background);
              color: var(--text);
              font: 15px/1.65 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            }

            body {
              box-sizing: border-box;
              padding: 24px 28px 40px;
            }

            main {
              max-width: 920px;
            }

            h1, h2, h3, h4 {
              line-height: 1.25;
              margin: 1.35em 0 0.55em;
            }

            h1 {
              font-size: 28px;
              margin-top: 0;
            }

            h2 {
              border-bottom: 1px solid var(--border);
              font-size: 21px;
              padding-bottom: 0.25em;
            }

            h3 {
              font-size: 17px;
            }

            p, ul, ol, blockquote, pre, table {
              margin: 0.75em 0;
            }

            a {
              color: var(--accent);
            }

            blockquote {
              border-left: 4px solid var(--border);
              color: var(--muted);
              padding: 0.1em 0 0.1em 1em;
            }

            code {
              background: var(--code-background);
              border-radius: 4px;
              font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
              font-size: 0.92em;
              padding: 0.1em 0.28em;
            }

            pre {
              background: var(--code-background);
              border: 1px solid var(--border);
              border-radius: 6px;
              overflow: auto;
              padding: 12px;
            }

            pre code {
              background: transparent;
              padding: 0;
            }

            table {
              border-collapse: collapse;
              display: block;
              overflow-x: auto;
              width: 100%;
            }

            th, td {
              border: 1px solid var(--border);
              padding: 6px 10px;
            }

            th {
              background: var(--table-header);
              font-weight: 600;
            }

            img {
              height: auto;
              max-width: 100%;
            }

            mjx-container {
              overflow-x: auto;
              overflow-y: hidden;
              max-width: 100%;
            }
          </style>
        </head>
        <body>
          <main id="content"></main>
          <script>
            const payload = \#(payloadJSON);
            const content = document.getElementById('content');

            function escapeHTML(value) {
              return value
                .replaceAll('&', '&amp;')
                .replaceAll('<', '&lt;')
                .replaceAll('>', '&gt;')
                .replaceAll('"', '&quot;')
                .replaceAll("'", '&#039;');
            }

            function renderMarkdown() {
              if (!content || content.dataset.rendered === 'true') {
                return;
              }

              if (window.marked) {
                marked.setOptions({ gfm: true, breaks: false });
                const rawHTML = marked.parse(payload.source || '');
                content.innerHTML = window.DOMPurify ? DOMPurify.sanitize(rawHTML) : rawHTML;
              } else {
                content.innerHTML = '<pre><code>' + escapeHTML(payload.source || '') + '</code></pre>';
              }

              content.dataset.rendered = 'true';

              if (window.MathJax && MathJax.typesetPromise) {
                MathJax.typesetPromise([content]).catch(error => console.error(error));
              }
            }

            window.addEventListener('load', renderMarkdown);
            setTimeout(renderMarkdown, 1200);
          </script>
        </body>
        </html>
        """#
    }

    private static func escapedHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#039;")
    }

    private struct Payload: Encodable {
        let source: String
        let title: String
    }
}
