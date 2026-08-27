import Foundation
import AppKit

class StorageManager {
    static let shared = StorageManager()

    private var logURL: URL {
        URL(fileURLWithPath: AppSettings.shared.logPath)
    }

    // MARK: - Directory management

    func ensureStorageDirectoryExists() {
        let s = AppSettings.shared
        // For per-entry mode, create the directory itself.
        // For single-file mode, create the parent directory.
        let dirURL = s.logFormat == .perEntry
            ? logURL
            : logURL.deletingLastPathComponent()

        if !FileManager.default.fileExists(atPath: dirURL.path) {
            do {
                try FileManager.default.createDirectory(at: dirURL,
                                                         withIntermediateDirectories: true)
            } catch {
                print("Error creating directory: \(error)")
            }
        }
    }

    func openStorageDirectory() {
        ensureStorageDirectoryExists()
        let s = AppSettings.shared
        if s.logFormat == .singleFile {
            // Reveal the file in Finder (or open parent dir if file doesn't exist yet)
            if FileManager.default.fileExists(atPath: logURL.path) {
                NSWorkspace.shared.activateFileViewerSelecting([logURL])
            } else {
                NSWorkspace.shared.open(logURL.deletingLastPathComponent())
            }
        } else {
            NSWorkspace.shared.open(logURL)
        }
    }

    // MARK: - Debugging & History

    func checkPermissions() -> (isReadable: Bool, isWritable: Bool) {
        let path = logURL.path
        let isReadable = FileManager.default.isReadableFile(atPath: path)
        let isWritable = FileManager.default.isWritableFile(atPath: path)
        return (isReadable, isWritable)
    }

    func fetchHistory() -> [String] {
        ensureStorageDirectoryExists()
        var history: [String] = []

        if AppSettings.shared.logFormat == .singleFile {
            let actualURL = getSingleFileURL()
            if let content = try? String(contentsOf: actualURL, encoding: .utf8) {
                history = content.components(separatedBy: .newlines)
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    .reversed()
            }
        } else {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: logURL, includingPropertiesForKeys: nil)
                let mdFiles = files.filter { $0.pathExtension == "md" }.sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
                for file in mdFiles {
                    if let content = try? String(contentsOf: file, encoding: .utf8) {
                        history.append(content)
                    }
                }
            } catch {
                print("Failed to fetch history: \(error)")
            }
        }

        return history
    }

    private func getSingleFileURL() -> URL {
        var actualURL = logURL
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: actualURL.path, isDirectory: &isDir), isDir.boolValue {
            actualURL = actualURL.appendingPathComponent("timesheet.log")
        }
        return actualURL
    }

    // MARK: - Screenshots

    func captureScreenshot() -> URL? {
        ensureStorageDirectoryExists()
        let attachmentsDir: URL
        if AppSettings.shared.logFormat == .singleFile {
            attachmentsDir = logURL.deletingLastPathComponent().appendingPathComponent("attachments")
        } else {
            attachmentsDir = logURL.appendingPathComponent("attachments")
        }
        
        do {
            try FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
        } catch {
            print("Failed to create attachments directory: \(error)")
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "screenshot_\(formatter.string(from: Date())).png"
        let fileURL = attachmentsDir.appendingPathComponent(filename)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", fileURL.path]
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                return fileURL
            } else {
                print("screencapture failed with status \(task.terminationStatus)")
            }
        } catch {
            print("Failed to run screencapture: \(error)")
        }
        
        return nil
    }

    // MARK: - Saving

    func saveComment(preset: String, comment: String, screenshotURL: URL? = nil) {
        ensureStorageDirectoryExists()
        switch AppSettings.shared.logFormat {
        case .singleFile: saveSingleFileLine(preset: preset, comment: comment, screenshotURL: screenshotURL)
        case .perEntry:   savePerEntryFile(preset: preset, comment: comment, screenshotURL: screenshotURL)
        }
    }

    // Appends one line: "2026-08-12 14:30  Coding / Dev: working on FORUM-17644"
    // Compatible with the timesheet-week-estimator skill parser.
    private func saveSingleFileLine(preset: String, comment: String, screenshotURL: URL?) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let timestamp = formatter.string(from: Date())

        let presetPart   = preset.isEmpty  ? nil : preset
        let commentPart  = comment.isEmpty ? nil : comment.trimmingCharacters(in: .whitespacesAndNewlines)

        var body: String
        switch (presetPart, commentPart) {
        case let (p?, c?): body = "\(p): \(c)"
        case let (p?, nil): body = p
        case let (nil, c?): body = c
        default: body = "(no entry)"
        }

        if let screenshotURL = screenshotURL {
            let relativePath = "attachments/\(screenshotURL.lastPathComponent)"
            body += " [Screenshot: \(relativePath)]"
        }

        let line = "\(timestamp)  \(body)\n"

        let actualURL = getSingleFileURL()

        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: actualURL.path) {
                if let handle = try? FileHandle(forWritingTo: actualURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: actualURL, options: .atomic)
            }
        }
    }

    // Creates one .md file per entry (original behavior).
    private func savePerEntryFile(preset: String, comment: String, screenshotURL: URL?) {
        let fileFormatter = DateFormatter()
        fileFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "\(fileFormatter.string(from: Date())).md"
        let fileURL = logURL.appendingPathComponent(filename)

        let contentFormatter = DateFormatter()
        contentFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = contentFormatter.string(from: Date())
        let presetDisplay = preset.isEmpty ? "None" : preset

        var markdown = """
        # Timesheet Comment Entry
        - **Timestamp**: \(timestamp)
        - **Preset**: \(presetDisplay)
        """

        if let screenshotURL = screenshotURL {
            let relativePath = "attachments/\(screenshotURL.lastPathComponent)"
            markdown += "\n- **Screenshot**: ![](\(relativePath))"
        }

        markdown += """
        
        ## Comment
        \(comment.isEmpty ? "No additional comment." : comment)
        """

        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to save entry: \(error)")
        }
    }
}
