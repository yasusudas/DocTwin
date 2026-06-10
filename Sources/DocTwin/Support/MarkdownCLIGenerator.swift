import Foundation
import DocTwinCore

struct MarkdownCLIGenerationResult {
    let fileWasCreatedByCLI: Bool
    let savedFromStandardOutput: Bool
}

enum MarkdownCLIGeneratorError: Error, LocalizedError {
    case missingCommand
    case timedOut(TimeInterval)
    case emptyOutput(String)
    case processFailed(exitCode: Int32, stderr: String, stdout: String)

    var errorDescription: String? {
        switch self {
        case .missingCommand:
            return "CLIコマンドが設定されていません。AI生成設定でコマンドを設定してください。"
        case .timedOut(let seconds):
            return "CLI生成がタイムアウトしました（\(Int(seconds))秒）。"
        case .emptyOutput(let stderr):
            if stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "CLIの出力が空でした。"
            }
            return "CLIの出力が空でした: \(stderr)"
        case .processFailed(let exitCode, let stderr, let stdout):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                : stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "CLI生成に失敗しました（終了コード: \(exitCode)）。"
                : "CLI生成に失敗しました（終了コード: \(exitCode)）: \(detail)"
        }
    }
}

enum MarkdownCLIGenerator {
    static func generate(prompt: String, document: ReferenceDocument) throws -> MarkdownCLIGenerationResult {
        let settings = MarkdownCLISettings.current()
        let commandTemplate = settings.commandTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commandTemplate.isEmpty else {
            throw MarkdownCLIGeneratorError.missingCommand
        }

        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("DocTwinMarkdownGeneration-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDirectory)
        }

        let promptFile = tempDirectory.appendingPathComponent("prompt.md")
        let outputFile = tempDirectory.appendingPathComponent("output.md")
        try prompt.write(to: promptFile, atomically: true, encoding: .utf8)

        let command = replacePlaceholders(
            in: commandTemplate,
            promptFile: promptFile,
            outputFile: outputFile,
            document: document
        )

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.currentDirectoryURL = document.pdfURL.deletingLastPathComponent()
        process.environment = environment(
            promptFile: promptFile,
            outputFile: outputFile,
            document: document
        )

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let outputLock = NSLock()
        var stdoutData = Data()
        var stderrData = Data()

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            outputLock.lock()
            stdoutData.append(data)
            outputLock.unlock()
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            outputLock.lock()
            stderrData.append(data)
            outputLock.unlock()
        }

        defer {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
        }

        try process.run()

        let deadline = Date().addingTimeInterval(settings.timeoutSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.1)
        }

        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.5)
            if process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            process.waitUntilExit()
            throw MarkdownCLIGeneratorError.timedOut(settings.timeoutSeconds)
        }

        process.waitUntilExit()
        Thread.sleep(forTimeInterval: 0.05)

        outputLock.lock()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        outputLock.unlock()

        if markdownFileExists(document.explanationURL) {
            return MarkdownCLIGenerationResult(fileWasCreatedByCLI: true, savedFromStandardOutput: false)
        }

        if process.terminationStatus != 0 {
            throw MarkdownCLIGeneratorError.processFailed(
                exitCode: process.terminationStatus,
                stderr: stderr,
                stdout: stdout
            )
        }

        if markdownFileExists(outputFile) {
            try fileManager.copyItem(at: outputFile, to: document.explanationURL)
            return MarkdownCLIGenerationResult(fileWasCreatedByCLI: false, savedFromStandardOutput: true)
        }

        let markdown = sanitizeMarkdownOutput(stdout)
        guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MarkdownCLIGeneratorError.emptyOutput(stderr)
        }

        try markdown.write(to: document.explanationURL, atomically: true, encoding: .utf8)
        return MarkdownCLIGenerationResult(fileWasCreatedByCLI: false, savedFromStandardOutput: true)
    }

    private static func markdownFileExists(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        let data = try? Data(contentsOf: url)
        return data?.isEmpty == false
    }

    private static func replacePlaceholders(
        in command: String,
        promptFile: URL,
        outputFile: URL,
        document: ReferenceDocument
    ) -> String {
        command
            .replacingOccurrences(of: "{promptFile}", with: shellEscape(promptFile.path))
            .replacingOccurrences(of: "{outputFile}", with: shellEscape(outputFile.path))
            .replacingOccurrences(of: "{pdfFile}", with: shellEscape(document.pdfURL.path))
            .replacingOccurrences(of: "{markdownFile}", with: shellEscape(document.explanationURL.path))
            .replacingOccurrences(of: "{directory}", with: shellEscape(document.pdfURL.deletingLastPathComponent().path))
    }

    private static func environment(
        promptFile: URL,
        outputFile: URL,
        document: ReferenceDocument
    ) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let existingPath = environment["PATH"] ?? ""
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let extraPaths = [
            "\(homePath)/.local/bin",
            "\(homePath)/.npm-global/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        environment["PATH"] = (extraPaths + [existingPath])
            .filter { !$0.isEmpty }
            .joined(separator: ":")
        environment["DOCTWIN_PROMPT_FILE"] = promptFile.path
        environment["DOCTWIN_OUTPUT_FILE"] = outputFile.path
        environment["DOCTWIN_PDF_FILE"] = document.pdfURL.path
        environment["DOCTWIN_MARKDOWN_FILE"] = document.explanationURL.path
        environment["DOCTWIN_DIRECTORY"] = document.pdfURL.deletingLastPathComponent().path
        return environment
    }

    private static func shellEscape(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func sanitizeMarkdownOutput(_ output: String) -> String {
        var trimmed = output
            .replacingOccurrences(
                of: #"\u{001B}\[[0-9;?]*[ -/]*[@-~]"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.hasPrefix("```") else {
            return trimmed + "\n"
        }

        var lines = trimmed.components(separatedBy: .newlines)
        if let first = lines.first, first.hasPrefix("```") {
            lines.removeFirst()
        }
        if let last = lines.last, last.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
            lines.removeLast()
        }
        trimmed = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed + "\n"
    }
}
