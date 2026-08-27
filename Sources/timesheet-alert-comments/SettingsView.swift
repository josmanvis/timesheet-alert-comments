import SwiftUI
import AppKit

struct SettingsView: View {
    @State private var selectedTab: String? = "General"

    var body: some View {
        Group {
            if #available(macOS 13.0, *) {
                NavigationSplitView {
                    List(selection: $selectedTab) {
                        Label("General", systemImage: "clock").tag("General")
                        Label("Presets", systemImage: "tag").tag("Presets")
                        Label("Storage", systemImage: "folder").tag("Storage")
                        Label("Skills", systemImage: "brain").tag("Skills")
                        Label("History", systemImage: "clock.arrow.circlepath").tag("History")
                        Label("Timesheet", systemImage: "calendar").tag("Timesheet")
                        Label("Appearance", systemImage: "paintbrush").tag("Appearance")
                    }
                    .navigationSplitViewColumnWidth(min: 150, ideal: 160, max: 220)
                } detail: {
                    detailView()
                }
            } else {
                NavigationView {
                    List(selection: $selectedTab) {
                        Label("General", systemImage: "clock").tag("General")
                        Label("Presets", systemImage: "tag").tag("Presets")
                        Label("Storage", systemImage: "folder").tag("Storage")
                        Label("Skills", systemImage: "brain").tag("Skills")
                        Label("History", systemImage: "clock.arrow.circlepath").tag("History")
                        Label("Timesheet", systemImage: "calendar").tag("Timesheet")
                        Label("Appearance", systemImage: "paintbrush").tag("Appearance")
                    }
                    .frame(minWidth: 150, idealWidth: 160, maxWidth: 220)
                    
                    detailView()
                }
            }
        }
    }
    
    @ViewBuilder
    private func detailView() -> some View {
        Group {
            switch selectedTab {
            case "General": GeneralTab().navigationTitle("General")
            case "Presets": PresetsTab().navigationTitle("Presets")
            case "Storage": StorageTab().navigationTitle("Storage")
            case "Skills": SkillsTab().navigationTitle("Skills")
            case "History": HistoryTab().navigationTitle("History")
            case "Timesheet": TimesheetTab().navigationTitle("Timesheet")
            case "Appearance": AppearanceTab().navigationTitle("Appearance")
            default: Text("Select an item").foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 550, minHeight: 450)
    }
}

extension View {
    @ViewBuilder
    func compatFormStyle() -> some View {
        if #available(macOS 13.0, *) {
            self.formStyle(.grouped)
        } else {
            self
        }
    }
}

// MARK: - General

struct GeneralTab: View {
    @ObservedObject private var s = AppSettings.shared

    var body: some View {
        Form {
            Section("Alert Schedule") {
                HStack {
                    Text("Remind me every")
                    Spacer()
                    Stepper("\(s.intervalMinutes) min",
                            value: $s.intervalMinutes, in: 1...480, step: 5)
                        .frame(width: 170)
                }
                HStack {
                    Text("Retry after skip / dismiss")
                    Spacer()
                    Stepper("\(s.skipRetryMinutes) min",
                            value: $s.skipRetryMinutes, in: 1...120, step: 5)
                        .frame(width: 170)
                }
            }

            Section("Auto-dismiss") {
                Toggle("Auto-dismiss if no interaction", isOn: $s.autoDismissEnabled)
                if s.autoDismissEnabled {
                    HStack {
                        Text("Dismiss after")
                        Spacer()
                        Stepper("\(s.autoDismissSeconds) sec",
                                value: $s.autoDismissSeconds, in: 10...600, step: 10)
                            .frame(width: 170)
                    }
                }
            }

            Section("Startup") {
                Toggle("Show Settings window on app startup", isOn: $s.showSettingsOnStartup)
            }
            
            Section("CLI Tool") {
                HStack {
                    Text("Install `tac` to /usr/local/bin to log time and trigger alerts from terminal.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Install CLI") { installCLI() }
                }
            }

            Spacer()
            HStack {
                Spacer()
                Button("Reset All to Defaults") { s.resetToDefaults() }
                    .foregroundColor(.red)
            }
            .padding(.bottom, 4)
        }
        .compatFormStyle()
        .padding(.horizontal)
    }

    private func installCLI() {
        let execPath = Bundle.main.executableURL?.path ?? ""
        let script = """
        #!/bin/bash
        "\(execPath)" "$@"
        """
        
        do {
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("tac_tmp_script")
            try script.write(to: tmpURL, atomically: true, encoding: .utf8)
            
            let appleScriptSource = """
            do shell script "mkdir -p /usr/local/bin && cp '\(tmpURL.path)' /usr/local/bin/tac && chmod +x /usr/local/bin/tac" with administrator privileges
            """
            
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: appleScriptSource) {
                appleScript.executeAndReturnError(&error)
                if let err = error {
                    let errorMessage = err[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                    throw NSError(domain: "InstallCLI", code: 1, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                }
            }
            
            let successAlert = NSAlert()
            successAlert.messageText = "CLI Installed Successfully!"
            successAlert.informativeText = "The 'tac' command is now available in your terminal.\n\nWould you like a quick tour of what you can do with it?"
            successAlert.addButton(withTitle: "Take Tour")
            successAlert.addButton(withTitle: "No Thanks")
            
            let response = successAlert.runModal()
            if response == .alertFirstButtonReturn {
                let tourScript = """
                tell application "Terminal"
                    activate
                    do script "clear; echo '🎉 Welcome to the Timesheet Alert Comments CLI (tac)!'; echo ''; tac help"
                end tell
                """
                var tourError: NSDictionary?
                if let ascript = NSAppleScript(source: tourScript) {
                    ascript.executeAndReturnError(&tourError)
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Installation Failed"
            alert.informativeText = "Could not install to /usr/local/bin/tac.\n\nError: \(error.localizedDescription)"
            alert.runModal()
        }
    }
}

// MARK: - Presets

struct PresetsTab: View {
    @ObservedObject private var s = AppSettings.shared
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick-pick tags shown in the alert panel. Drag rows to reorder.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            List {
                ForEach(Array(s.presetTags.enumerated()), id: \.offset) { index, tag in
                    HStack(spacing: 10) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        Text(tag)
                        Spacer()
                        Button {
                            guard index > 0 else { return }
                            s.presetTags.swapAt(index, index - 1)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(index == 0)
                        Button {
                            guard index < s.presetTags.count - 1 else { return }
                            s.presetTags.swapAt(index, index + 1)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(index == s.presetTags.count - 1)
                        Button {
                            s.presetTags.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 2)
                }
            }
            .frame(minHeight: 180)
            .cornerRadius(6)
            .padding(.horizontal)

            HStack {
                TextField("Add new tag…", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit { addTag() }
                Button("Add", action: addTag)
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .padding(.top, 12)
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !s.presetTags.contains(trimmed) else { return }
        s.presetTags.append(trimmed)
        newTag = ""
    }
}

// MARK: - Storage

struct StorageTab: View {
    @ObservedObject private var s = AppSettings.shared
    @State private var isReadable = false
    @State private var isWritable = false

    var body: some View {
        Form {
            Section("Log Format") {
                Picker("Format", selection: $s.logFormat) {
                    ForEach(LogFormat.allCases, id: \.self) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(.radioGroup)
                Group {
                    if s.logFormat == .singleFile {
                        Text("Appends one timestamped line per entry to a single file. Compatible with the timesheet-week-estimator skill.")
                    } else {
                        Text("Creates one .md file per entry in a directory. Easier to browse individual entries.")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Section(s.logFormat == .singleFile ? "Log File Path" : "Log Directory Path") {
                HStack {
                    TextField("Path", text: $s.logPath)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("Choose…") { choosePath() }
                    Button("Open") { StorageManager.shared.openStorageDirectory() }
                }
                Text(s.logFormat == .singleFile
                     ? "Entries are appended to this file. Parent directory is created if needed."
                     : "Entry .md files are saved inside this directory.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Permissions") {
                HStack {
                    if isReadable && isWritable {
                        Text("OK")
                            .foregroundColor(.green)
                    } else {
                        Text("Issues Detected")
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Label(isReadable ? "Readable" : "Not Readable", systemImage: isReadable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isReadable ? .green : .red)
                        .font(.caption)
                    Label(isWritable ? "Writable" : "Not Writable", systemImage: isWritable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isWritable ? .green : .red)
                        .font(.caption)
                    
                    Button("Refresh") { refresh() }
                }
                Text("Checks if the app has read/write access to the configured path.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .compatFormStyle()
        .padding(.horizontal)
        .onAppear {
            refresh()
        }
    }

    private func choosePath() {
        if s.logFormat == .perEntry {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.prompt = "Choose Directory"
            if panel.runModal() == .OK, let url = panel.url {
                s.logPath = url.path
                refresh()
            }
        } else {
            let panel = NSSavePanel()
            panel.prompt = "Choose Log File"
            let current = URL(fileURLWithPath: s.logPath)
            panel.nameFieldStringValue = current.lastPathComponent
            panel.directoryURL = current.deletingLastPathComponent()
            if panel.runModal() == .OK, let url = panel.url {
                s.logPath = url.path
                refresh()
            }
        }
    }

    private func refresh() {
        let perms = StorageManager.shared.checkPermissions()
        isReadable = perms.isReadable
        isWritable = perms.isWritable
    }
}

// MARK: - Appearance

struct AppearanceTab: View {
    @ObservedObject private var s = AppSettings.shared

    var body: some View {
        Form {
            Section("Position") {
                Picker("Alert position", selection: $s.alertPosition) {
                    ForEach(AlertPosition.allCases, id: \.self) { pos in
                        Text(pos.rawValue).tag(pos)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Edge padding")
                    Spacer()
                    Stepper("\(Int(s.alertEdgePadding)) pt",
                            value: $s.alertEdgePadding, in: 0...100, step: 4)
                        .frame(width: 170)
                }
            }

            Section("Panel Size") {
                HStack {
                    Text("Width")
                    Spacer()
                    Stepper("\(Int(s.alertWidth)) pt",
                            value: $s.alertWidth, in: 250...700, step: 10)
                        .frame(width: 170)
                }
                HStack {
                    Text("Height")
                    Spacer()
                    Stepper("\(Int(s.alertHeight)) pt",
                            value: $s.alertHeight, in: 180...600, step: 10)
                        .frame(width: 170)
                }
            }

            Section("Styling") {
                HStack {
                    Text("Background Opacity")
                    Spacer()
                    Slider(value: $s.alertBackgroundOpacity, in: 0.0...1.0, step: 0.05)
                        .frame(width: 130)
                    Text(String(format: "%.2f", s.alertBackgroundOpacity))
                        .frame(width: 40, alignment: .trailing)
                }
                HStack {
                    Text("Corner Radius")
                    Spacer()
                    Stepper("\(Int(s.alertCornerRadius)) pt",
                            value: $s.alertCornerRadius, in: 0...50, step: 2)
                        .frame(width: 170)
                }
                HStack {
                    Text("Border Width")
                    Spacer()
                    Stepper(String(format: "%.1f pt", s.alertBorderWidth),
                            value: $s.alertBorderWidth, in: 0...10, step: 0.5)
                        .frame(width: 170)
                }
            }
        }
        .compatFormStyle()
        .padding(.horizontal)
    }
}

// MARK: - Skills

struct SkillsTab: View {
    @StateObject private var installer = SkillInstaller.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Install AI skills from the repository.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if installer.isFetching {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ProgressView("Fetching skills...")
                        Spacer()
                    }
                    Spacer()
                }
                .frame(minHeight: 180)
            } else if installer.availableSkills.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button("Fetch Available Skills") {
                            installer.fetchSkills()
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .frame(minHeight: 180)
            } else {
                List {
                    ForEach(installer.availableSkills, id: \.self) { skill in
                        HStack {
                            Text(skill)
                            Spacer()
                            Button("Install") {
                                installer.installSkill(skill)
                            }
                            .disabled(installer.isInstalling)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .frame(minHeight: 180)
                .cornerRadius(6)
                .padding(.horizontal)
                
                HStack {
                    Spacer()
                    Button("Refresh") {
                        installer.fetchSkills()
                    }
                    .disabled(installer.isInstalling)
                    .padding(.horizontal)
                }
            }

            if let error = installer.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }
            if let success = installer.successMessage {
                Text(success)
                    .foregroundColor(.green)
                    .font(.caption)
                    .padding(.horizontal)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
}

// MARK: - History

enum EntrySortOrder: String, CaseIterable {
    case newestFirst = "Newest First"
    case oldestFirst = "Oldest First"
}

struct ParsedHistoryEntry: Identifiable {
    let id = UUID()
    let dateStr: String
    let date: Date?
    let preset: String
    let comment: String
    let raw: String
}

struct HistoryTab: View {
    @State private var history: [String] = []
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var sortOrder: EntrySortOrder = .newestFirst
    @State private var useDateFilter: Bool = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    
    private let df1: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df
    }()
    
    private let df2: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()
    
    var parsedEntries: [ParsedHistoryEntry] {
        let entries = history.compactMap { entry -> ParsedHistoryEntry in
            var dateStr = ""
            var date: Date? = nil
            var preset = ""
            var comment = ""
            
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
            return ParsedHistoryEntry(dateStr: dateStr, date: date, preset: preset, comment: comment, raw: entry)
        }
        
        let filtered = entries.filter { entry in
            let matchesSearch = searchText.isEmpty || entry.raw.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = selectedFilter == "All" || entry.preset == selectedFilter
            let matchesDate: Bool
            if useDateFilter, let d = entry.date {
                let start = Calendar.current.startOfDay(for: startDate)
                let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
                matchesDate = d >= start && d < end
            } else {
                matchesDate = true
            }
            return matchesSearch && matchesFilter && matchesDate
        }
        
        return filtered.sorted { a, b in
            let dateA = a.date ?? Date.distantPast
            let dateB = b.date ?? Date.distantPast
            if sortOrder == .newestFirst {
                return dateA > dateB
            } else {
                return dateA < dateB
            }
        }
    }
    
    var uniquePresets: [String] {
        var presets: Set<String> = ["All"]
        // We look at all raw history, not just filtered, to build the filter list
        let allEntries = history.compactMap { entry -> String? in
            if AppSettings.shared.logFormat == .singleFile {
                let parts = entry.components(separatedBy: "  ")
                if parts.count >= 2 {
                    let rest = parts.dropFirst().joined(separator: "  ")
                    if let colonRange = rest.range(of: ": ") {
                        return String(rest[..<colonRange.lowerBound])
                    }
                }
                return nil
            } else {
                let lines = entry.components(separatedBy: .newlines)
                for line in lines {
                    if line.hasPrefix("- **Preset**:") {
                        return line.replacingOccurrences(of: "- **Preset**: ", with: "")
                    }
                }
                return nil
            }
        }
        allEntries.forEach { if !$0.isEmpty { presets.insert($0) } }
        return presets.sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("History")
                    .font(.subheadline)
                    .bold()
                
                Spacer()
                Button("Refresh") {
                    refresh()
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Picker("Preset:", selection: $selectedFilter) {
                        ForEach(uniquePresets, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    
                    Picker("Sort:", selection: $sortOrder) {
                        ForEach(EntrySortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
                
                HStack {
                    Toggle("Filter by date:", isOn: $useDateFilter)
                    if useDateFilter {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .labelsHidden()
                        Text("to")
                        DatePicker("", selection: $endDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }
            .padding(.horizontal)
            
            if parsedEntries.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("No entries found.")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    Spacer()
                }
            } else {
                List {
                    ForEach(parsedEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.dateStr)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if !entry.preset.isEmpty {
                                    Text(entry.preset)
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            Text(entry.comment)
                                .font(.body)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .cornerRadius(6)
                .padding(.horizontal)
                .searchable(text: $searchText, prompt: "Search history...")
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .onAppear {
            refresh()
        }
    }
    
    private func refresh() {
        history = StorageManager.shared.fetchHistory()
    }
}

// MARK: - Timesheet

struct TimesheetTab: View {
    @State private var weekOffset: Int = 0
    @StateObject private var generator = TimesheetGenerator()
    
    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E d"
        return f
    }()

    private let rangeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM d"
        return f
    }()

    private var weekRangeHeading: String {
        guard generator.weekDates.count == 5,
              let first = generator.weekDates.first,
              let last = generator.weekDates.last else { return "" }
        return "\(rangeFormatter.string(from: first)) - \(rangeFormatter.string(from: last))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Target Week:")
                Picker("", selection: $weekOffset) {
                    Text("This Week").tag(0)
                    Text("Last Week").tag(-1)
                    Text("2 Weeks Ago").tag(-2)
                    Text("3 Weeks Ago").tag(-3)
                }
                .pickerStyle(.menu)
                .frame(width: 150)
                .onChange(of: weekOffset) { _ in
                    generator.generate(weekOffset: weekOffset)
                }
                
                Spacer()
                
                Button("Generate Timesheet") {
                    generator.generate(weekOffset: weekOffset)
                }
                .disabled(generator.isGenerating)
            }
            
            if generator.isGenerating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                    Text("Gathering data and parsing Replicon rows...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if !generator.repliconRows.isEmpty {
                Text(weekRangeHeading)
                    .font(.headline)
                    .padding(.bottom, 4)

                // Table Header
                HStack(spacing: 0) {
                    Text("Task").bold().frame(width: 160, alignment: .leading)
                    Text("Client").bold().frame(width: 70, alignment: .leading)
                    
                    if generator.weekDates.count == 5 {
                        ForEach(generator.weekDates, id: \.self) { date in
                            Text(df.string(from: date)).bold().frame(width: 55, alignment: .center)
                        }
                    }
                    Text("Total").bold().frame(width: 55, alignment: .center)
                }
                .font(.caption)
                .padding(.bottom, 4)
                .padding(.horizontal, 8)
                
                Divider()
                
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(generator.repliconRows) { row in
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(row.task).font(.subheadline).bold()
                                    Text(row.project).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                                }
                                .frame(width: 160, alignment: .leading)
                                
                                Text(row.client)
                                    .font(.caption)
                                    .frame(width: 70, alignment: .leading)
                                
                                ForEach(0..<5, id: \.self) { i in
                                    Text(String(format: "%.1f", row.hours[i]))
                                        .font(.caption)
                                        .frame(width: 55, alignment: .center)
                                        .foregroundColor(row.hours[i] > 0 ? .primary : .secondary.opacity(0.2))
                                }
                                
                                Text(String(format: "%.1f", row.total))
                                    .font(.subheadline)
                                    .bold()
                                    .frame(width: 55, alignment: .center)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 8)
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(4)
                            .padding(.bottom, 4)
                        }
                    }
                }
                
                Divider()
                
                // Footer
                HStack(spacing: 0) {
                    Text("Total Hours").bold().frame(width: 230, alignment: .leading)
                    
                    ForEach(0..<5, id: \.self) { i in
                        let dailyTotal = generator.repliconRows.map { $0.hours[i] }.reduce(0, +)
                        Text(String(format: "%.1f", dailyTotal))
                            .bold()
                            .frame(width: 55, alignment: .center)
                    }
                    
                    let grandTotal = generator.repliconRows.map { $0.total }.reduce(0, +)
                    Text(String(format: "%.1f", grandTotal))
                        .bold()
                        .frame(width: 55, alignment: .center)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.top, 4)
            } else if let error = generator.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                Spacer()
            } else {
                Spacer()
                Text("No data to display. Click Generate.")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
        .onAppear {
            if generator.activities.isEmpty && !generator.isGenerating {
                generator.generate(weekOffset: weekOffset)
            }
        }
    }
}

