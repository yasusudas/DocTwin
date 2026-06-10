import SwiftUI

struct MarkdownCLISettingsView: View {
    @AppStorage(MarkdownCLISettings.Keys.provider) private var providerRaw = MarkdownCLISettings.defaultProvider.rawValue
    @AppStorage(MarkdownCLISettings.Keys.commandTemplate) private var commandTemplate = MarkdownCLISettings.defaultProvider.defaultCommandTemplate
    @AppStorage(MarkdownCLISettings.Keys.timeoutSeconds) private var timeoutSeconds = MarkdownCLISettings.defaultTimeoutSeconds

    private var provider: MarkdownCLIProvider {
        MarkdownCLIProvider(rawValue: providerRaw) ?? MarkdownCLISettings.defaultProvider
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI生成設定")
                    .font(.title2.weight(.semibold))
                Text("Markdown未作成PDFで使うCLI生成コマンドを設定します。プロンプトは一時ファイルに保存され、CLIには環境変数で渡されます。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Form {
                Picker("CLI", selection: $providerRaw) {
                    ForEach(MarkdownCLIProvider.allCases) { provider in
                        Text(provider.title).tag(provider.rawValue)
                    }
                }
                .onChange(of: providerRaw) { newValue in
                    if let provider = MarkdownCLIProvider(rawValue: newValue), provider != .custom {
                        commandTemplate = provider.defaultCommandTemplate
                    }
                }

                Stepper(
                    "タイムアウト: \(Int(timeoutSeconds))秒",
                    value: $timeoutSeconds,
                    in: 60...14400,
                    step: 60
                )
            }
            .formStyle(.grouped)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("実行コマンド")
                        .font(.headline)

                    Spacer()

                    Button("既定に戻す") {
                        commandTemplate = provider.defaultCommandTemplate
                    }
                    .disabled(provider == .custom)
                }

                TextEditor(text: $commandTemplate)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 92)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.25))
                    }

                Text("利用できる環境変数: $DOCTWIN_PROMPT_FILE, $DOCTWIN_OUTPUT_FILE, $DOCTWIN_PDF_FILE, $DOCTWIN_MARKDOWN_FILE, $DOCTWIN_DIRECTORY")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("CLIが直接Markdownファイルを作成した場合はそれを読み込みます。作成されなかった場合は、CLIの標準出力をMarkdownとして保存します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(22)
        .frame(width: 620, height: 420)
    }
}

@MainActor
final class MarkdownCLISettingsWindowController {
    static let shared = MarkdownCLISettingsWindowController()

    private var window: NSWindow?
    private var windowDelegate: WindowDelegate?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AI生成設定"
        window.contentView = NSHostingView(rootView: MarkdownCLISettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        let delegate = WindowDelegate { [weak self] in
            self?.window = nil
            self?.windowDelegate = nil
        }
        window.delegate = delegate
        windowDelegate = delegate
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private final class WindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
