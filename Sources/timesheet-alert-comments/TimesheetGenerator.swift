import Foundation
import EventKit

struct RepliconRow: Identifiable {
    let id = UUID()
    let task: String
    let client: String
    let project: String
    var hours: [Double] = Array(repeating: 0.0, count: 5) // 0=Mon, 1=Tue, 2=Wed, 3=Thu, 4=Fri
    
    var total: Double { hours.reduce(0, +) }
}

struct TimesheetActivity: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let source: Source
    let detail: String
    var task: String
    var client: String
    var project: String
    var duration: Double
    
    enum Source: String {
        case calendar = "Calendar"
        case git = "Git Commit"
        case local = "App Log"
    }
}

class TimesheetGenerator: ObservableObject {
    @Published var activities: [TimesheetActivity] = []
    @Published var repliconRows: [RepliconRow] = []
    @Published var isGenerating = false
    @Published var errorMessage: String? = nil
    
    // For UI headers
    @Published var weekDates: [Date] = []
    
    private let eventStore = EKEventStore()
    
    func generate(weekOffset: Int) {
        isGenerating = true
        errorMessage = nil
        activities = []
        repliconRows = []
        
        DispatchQueue.global(qos: .userInitiated).async {
            let cal = Calendar.current
            let today = Date()
            
            // The week is Mon -> Fri.
            // Let's find the most recent Monday
            let components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday], from: today)
            // weekday: 1=Sun, 2=Mon ... 7=Sat. We want to go back to Monday (2).
            let daysToSubtract = (components.weekday! + 7 - 2) % 7
            var lastMon = cal.date(byAdding: .day, value: -daysToSubtract, to: cal.startOfDay(for: today))!
            // Apply offset
            lastMon = cal.date(byAdding: .weekOfYear, value: weekOffset, to: lastMon)!
            
            var dates: [Date] = []
            for i in 0..<5 {
                dates.append(cal.date(byAdding: .day, value: i, to: lastMon)!)
            }
            let friEnd = cal.date(byAdding: .day, value: 1, to: dates.last!)! // Midnight Friday
            
            var newActivities: [TimesheetActivity] = []
            
            // 1. Fetch Calendar Events
            let semaphore = DispatchSemaphore(value: 0)
            var hasAccess = false
            if #available(macOS 14.0, *) {
                self.eventStore.requestFullAccessToEvents { granted, _ in
                    hasAccess = granted
                    semaphore.signal()
                }
            } else {
                self.eventStore.requestAccess(to: .event) { granted, _ in
                    hasAccess = granted
                    semaphore.signal()
                }
            }
            semaphore.wait()
            
            if hasAccess {
                let predicate = self.eventStore.predicateForEvents(withStart: lastMon, end: friEnd, calendars: nil)
                let events = self.eventStore.events(matching: predicate)
                
                for event in events {
                    guard !event.isAllDay else { continue }
                    let title = event.title ?? "Event"
                    if title.localizedCaseInsensitiveContains("Birthday") ||
                        title.localizedCaseInsensitiveContains("Holiday") {
                        continue
                    }
                    let duration = event.endDate.timeIntervalSince(event.startDate) / 3600.0
                    let detail = "\(title) (\(String(format: "%.1f", duration))h)"
                    
                    let is1on1 = title.localizedCaseInsensitiveContains("1:1") || title.localizedCaseInsensitiveContains("one on one")
                    let task = is1on1 ? "One-on-One" : "Group"
                    
                    newActivities.append(TimesheetActivity(date: event.startDate, source: .calendar, detail: detail, task: task, client: "Cvent", project: "Meetings", duration: duration))
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Calendar access denied. Results may be incomplete."
                }
            }
            
            // 2. Fetch Git Commits
            let gitActivities = self.fetchGitCommits(start: lastMon, end: friEnd)
            newActivities.append(contentsOf: gitActivities)
            
            // 3. Fetch Local App Logs
            let localActivities = self.fetchLocalLogs(start: lastMon, end: friEnd)
            newActivities.append(contentsOf: localActivities)
            
            // Sort
            newActivities.sort { $0.date < $1.date }
            
            // Aggregate into RepliconRows
            var rowDict: [String: RepliconRow] = [:]
            for act in newActivities {
                let key = "\(act.client)|\(act.project)|\(act.task)"
                if rowDict[key] == nil {
                    rowDict[key] = RepliconRow(task: act.task, client: act.client, project: act.project)
                }
                
                // Find day index
                let dayIndex = cal.dateComponents([.day], from: lastMon, to: act.date).day ?? 0
                if dayIndex >= 0 && dayIndex < 5 {
                    rowDict[key]!.hours[dayIndex] += act.duration
                }
            }
            
            let sortedRows = rowDict.values.sorted { $0.total > $1.total }
            
            DispatchQueue.main.async {
                self.weekDates = dates
                self.activities = newActivities
                self.repliconRows = sortedRows
                self.isGenerating = false
            }
        }
    }
    
    private func fetchGitCommits(start: Date, end: Date) -> [TimesheetActivity] {
        var results: [TimesheetActivity] = []
        let fm = FileManager.default
        let developerDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Developer")
        
        guard let dirs = try? fm.contentsOfDirectory(at: developerDir, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else {
            return []
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let startStr = dateFormatter.string(from: start)
        let endStr = dateFormatter.string(from: end)
        
        for dir in dirs {
            let gitDir = dir.appendingPathComponent(".git")
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: gitDir.path, isDirectory: &isDir), isDir.boolValue {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.currentDirectoryURL = dir
                process.arguments = ["log", "--author=\(NSUserName())", "--after=\(startStr)", "--before=\(endStr)", "--format=%aI|%s"]
                
                let pipe = Pipe()
                process.standardOutput = pipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                        for line in lines {
                            let parts = line.components(separatedBy: "|")
                            if parts.count >= 2 {
                                let dateStr = parts[0]
                                let subject = parts.dropFirst().joined(separator: "|")
                                if let date = dateFormatter.date(from: dateStr) {
                                    results.append(TimesheetActivity(date: date, source: .git, detail: "[\(dir.lastPathComponent)] \(subject)", task: "Development", client: "ON24", project: "Enhancement - Forum", duration: 0.5))
                                }
                            }
                        }
                    }
                } catch { }
            }
        }
        return results
    }
    
    private func fetchLocalLogs(start: Date, end: Date) -> [TimesheetActivity] {
        var results: [TimesheetActivity] = []
        let history = StorageManager.shared.fetchHistory()
        
        let df1 = DateFormatter()
        df1.dateFormat = "yyyy-MM-dd HH:mm"
        
        let df2 = DateFormatter()
        df2.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for entry in history {
            var dateStr = ""
            var date: Date? = nil
            var comment = ""
            var preset = ""
            
            if AppSettings.shared.logFormat == .singleFile {
                let parts = entry.components(separatedBy: "  ")
                if parts.count >= 2 {
                    dateStr = parts[0]
                    date = df1.date(from: dateStr) ?? df2.date(from: dateStr)
                    let rest = parts.dropFirst().joined(separator: "  ")
                    if let colonRange = rest.range(of: ": ") {
                        preset = String(rest[..<colonRange.lowerBound])
                        comment = String(rest[colonRange.upperBound...])
                    } else {
                        comment = rest
                    }
                } else {
                    comment = entry
                }
            } else {
                let lines = entry.components(separatedBy: .newlines)
                for line in lines {
                    if line.hasPrefix("- **Timestamp**:") {
                        dateStr = line.replacingOccurrences(of: "- **Timestamp**: ", with: "")
                        date = df2.date(from: dateStr) ?? df1.date(from: dateStr)
                    } else if line.hasPrefix("- **Preset**:") {
                        preset = line.replacingOccurrences(of: "- **Preset**: ", with: "")
                    }
                }
                if let commentIndex = lines.firstIndex(of: "## Comment") {
                    let commentLines = lines.suffix(from: commentIndex + 1)
                    comment = commentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            
            if let d = date, d >= start, d <= end {
                let detail = preset.isEmpty ? comment : "[\(preset)] \(comment)"
                
                var duration = 1.0
                if comment.contains("[15m]") { duration = 0.25 }
                else if comment.contains("[30m]") { duration = 0.5 }
                else if comment.contains("[1h]") { duration = 1.0 }
                else if comment.contains("[2h]") { duration = 2.0 }
                else if comment.contains("[3h]") { duration = 3.0 }
                else if comment.contains("[4h]") { duration = 4.0 }
                else if comment.contains("[8h]") { duration = 8.0 }
                
                let lower = (preset + comment).lowercased()
                var task = "Technology"
                var client = "Cvent"
                var project = "Support"
                
                if lower.contains("code") || lower.contains("dev") || lower.contains("forum") {
                    task = "Development"
                    client = "ON24"
                    project = "Enhancement - Forum"
                } else if lower.contains("test") || lower.contains("qa") {
                    task = "Manual Testing"
                    client = "ON24"
                    project = "Enhancement - Forum"
                } else if lower.contains("meet") || lower.contains("sync") {
                    task = "Group"
                    client = "Cvent"
                    project = "Meetings"
                } else if lower.contains("admin") || lower.contains("timesheet") {
                    task = "Admin"
                    client = "Cvent"
                    project = "General"
                }
                
                results.append(TimesheetActivity(date: d, source: .local, detail: detail, task: task, client: client, project: project, duration: duration))
            }
        }
        return results
    }
}
