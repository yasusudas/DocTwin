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
              chtml: {
                displayAlign: 'left',
                displayIndent: '0'
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

            :focus,
            :focus-visible,
            mjx-container:focus,
            mjx-container:focus-visible {
              outline: none !important;
              box-shadow: none !important;
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

            .math-display {
              margin: 0.9em 0;
              overflow-x: auto;
              text-align: left;
            }

            mjx-container {
              overflow-x: auto;
              overflow-y: hidden;
              max-width: 100%;
            }

            mjx-container[display="true"] {
              margin: 0.9em 0 !important;
              text-align: left !important;
            }
          </style>
        </head>
        <body>
          <main id="content"></main>
          <script>
            const payload = \#(payloadJSON);
            const content = document.getElementById('content');

            window.addEventListener('keydown', event => {
              if (event.key === 'Tab') {
                event.preventDefault();
                event.stopPropagation();

                if (document.activeElement && document.activeElement.blur) {
                  document.activeElement.blur();
                }
              }
            }, true);

            window.addEventListener('focusin', event => {
              const target = event.target;

              if (target && target !== document.body && target !== document.documentElement && target.blur) {
                requestAnimationFrame(() => target.blur());
              }
            }, true);

            function escapeHTML(value) {
              return value
                .replaceAll('&', '&amp;')
                .replaceAll('<', '&lt;')
                .replaceAll('>', '&gt;')
                .replaceAll('"', '&quot;')
                .replaceAll("'", '&#039;');
            }

            function maskCodeFences(source) {
              const masks = [];

              const masked = (source || '').replace(/(```[\s\S]*?```|~~~[\s\S]*?~~~)/g, block => {
                const id = 'DOC_TWIN_CODE_' + masks.length + '_MASK';
                masks.push({ id, block });
                return id;
              });

              return { masked, masks };
            }

            function unmaskCodeFences(source, masks) {
              let output = source;

              for (const item of masks) {
                output = output.split(item.id).join(item.block);
              }

              return output;
            }

            function protectBold(source) {
              return source.replace(/\*\*([^*\n]+?)\*\*/g, '<strong>$1</strong>');
            }

            function protectLooseLatexBlocks(source, addMath) {
              const lines = source.replace(/\r\n?/g, '\n').split('\n');
              const output = [];
              let index = 0;
              let inFence = false;
              let fenceMarker = '';
              const matrixPattern = /\\begin\{(?:array|matrix|pmatrix|bmatrix|Bmatrix|vmatrix|Vmatrix|smallmatrix)\}/;

              while (index < lines.length) {
                const line = lines[index];
                const trimmed = line.trim();
                const fenceMatch = trimmed.match(/^(```+|~~~+)/);

                if (fenceMatch) {
                  if (!inFence) {
                    inFence = true;
                    fenceMarker = fenceMatch[1][0];
                  } else if (trimmed.startsWith(fenceMarker.repeat(3))) {
                    inFence = false;
                  }

                  output.push(line);
                  index += 1;
                  continue;
                }

                if (inFence || trimmed === '') {
                  output.push(line);
                  index += 1;
                  continue;
                }

                const paragraph = [];
                while (index < lines.length && lines[index].trim() !== '') {
                  paragraph.push(lines[index]);
                  index += 1;
                }

                const paragraphText = paragraph.join('\n');
                const alreadyDelimited = paragraphText.includes('$$') || paragraphText.includes('\\[');

                if (!alreadyDelimited && matrixPattern.test(paragraphText)) {
                  output.push(addMath(paragraphText, true));
                } else {
                  output.push(...paragraph);
                }
              }

              return output.join('\n');
            }

            function protectDelimitedMath(source, addMath) {
              let protectedSource = source
                .replace(/\$\$([\s\S]*?)\$\$/g, (_, body) => addMath(body, true))
                .replace(/\\\[([\s\S]*?)\\\]/g, (_, body) => addMath(body, true))
                .replace(/\\\(([\s\S]*?)\\\)/g, (_, body) => addMath(body, false));

              protectedSource = protectedSource.replace(/(^|[^$])\$([^$\n]+?)\$(?!\$)/g, (_, prefix, body) => {
                return prefix + addMath(body, false);
              });

              return protectedSource;
            }

            function protectMath(source) {
              const tokens = [];

              function addMath(body, display) {
                const token = 'DOC_TWIN_MATH_' + tokens.length + '_TOKEN';
                tokens.push({ token, body, display });
                return token;
              }

              const looseProtected = protectLooseLatexBlocks(source || '', addMath);
              const protectedSource = protectDelimitedMath(looseProtected, addMath);

              return { source: protectedSource, tokens };
            }

            function restoreMath(html, tokens) {
              let restored = html;

              for (const item of tokens) {
                const escapedBody = escapeHTML(item.body.trim());
                const replacement = item.display
                  ? '<div class="math-display">\\[' + escapedBody + '\\]</div>'
                  : '<span class="math-inline">\\(' + escapedBody + '\\)</span>';

                restored = restored.split(item.token).join(replacement);
              }

              return restored.replace(/<p>\s*(<div class="math-display">[\s\S]*?<\/div>)\s*<\/p>/g, '$1');
            }

            function renderMarkdown() {
              if (!content || content.dataset.rendered === 'true') {
                return;
              }

              if (window.marked) {
                marked.setOptions({ gfm: true, breaks: false });
                const codeMasked = maskCodeFences(payload.source || '');
                const mathProtected = protectMath(codeMasked.masked);
                const boldProtected = protectBold(mathProtected.source);
                const markdownSource = unmaskCodeFences(boldProtected, codeMasked.masks);
                const rawHTML = marked.parse(markdownSource);
                const restoredHTML = restoreMath(rawHTML, mathProtected.tokens);
                content.innerHTML = window.DOMPurify ? DOMPurify.sanitize(restoredHTML) : restoredHTML;
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
