import Foundation

let logURL = URL(fileURLWithPath: "/Users/jose.viscasillas/.timesheet-alert-comments")
let fileFormatter = DateFormatter()
fileFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
let filename = "\(fileFormatter.string(from: Date())).md"
let fileURL = logURL.appendingPathComponent(filename)

let markdown = "Test Content"

do {
    try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
    print("SUCCESS: Wrote to \(fileURL.path)")
} catch {
    print("ERROR: \(error)")
}
