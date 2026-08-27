import Foundation

// ANSI Escape Codes for CLI styling
struct CLIColors {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
}

func handleCLI() {
    let args = CommandLine.arguments.dropFirst()
    guard let command = args.first else {
        printUsage()
        return
    }
    
    switch command {
    case "log":
        let remaining = Array(args.dropFirst())
        if remaining.isEmpty {
            print("\n\(CLIColors.red)❌ Error:\(CLIColors.reset) Missing comment text.\n")
            printUsage()
            return
        }
        
        let comment: String
        let preset: String
        
        if remaining.count >= 2, AppSettings.shared.presetTags.contains(remaining[0]) {
            preset = remaining[0]
            comment = remaining.dropFirst().joined(separator: " ")
        } else {
            preset = ""
            comment = remaining.joined(separator: " ")
        }
        
        StorageManager.shared.saveComment(preset: preset, comment: comment)
        
        print("\n\(CLIColors.green)✅ Successfully logged entry:\(CLIColors.reset)")
        if !preset.isEmpty {
            print("   \(CLIColors.bold)\(CLIColors.blue)Preset:\(CLIColors.reset)  \(preset)")
        }
        print("   \(CLIColors.bold)\(CLIColors.blue)Comment:\(CLIColors.reset) \(comment)\n")
        
    case "trigger":
        DistributedNotificationCenter.default().post(name: NSNotification.Name("TimesheetTriggerAlert"), object: nil)
        print("\n\(CLIColors.green)🔔 Alert successfully triggered in the UI app!\(CLIColors.reset)\n")
        
    case "timesheet":
        print("\n\(CLIColors.cyan)⏳ Generating timesheet (fetching Git/Calendar/Local)...\(CLIColors.reset)")
        
        let generator = TimesheetGenerator()
        generator.generate(weekOffset: 0)
        
        while generator.isGenerating {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.1))
        }
        
        if let error = generator.errorMessage {
            print("\n\(CLIColors.red)❌ Error:\(CLIColors.reset) \(error)\n")
        } else {
            print("\n\(CLIColors.bold)\(CLIColors.cyan)📊 TIMESHEET SUMMARY (THIS WEEK)\(CLIColors.reset)\n")
            
            // String formatting padding using C-style formatter
            let header = String(format: "%-20s | %-12s | %-25s | %-6s", "Task", "Client", "Project", "Total")
            print("\(CLIColors.bold)\(header)\(CLIColors.reset)")
            print(String(repeating: "—", count: 72))
            
            var totalHours = 0.0
            for row in generator.repliconRows {
                totalHours += row.total
                let taskPad = String(row.task.prefix(20)).padding(toLength: 20, withPad: " ", startingAt: 0)
                let clientPad = String(row.client.prefix(12)).padding(toLength: 12, withPad: " ", startingAt: 0)
                let projPad = String(row.project.prefix(25)).padding(toLength: 25, withPad: " ", startingAt: 0)
                
                let rowStr = String(format: "%@ | %@ | %@ | %5.1fh", taskPad, clientPad, projPad, row.total)
                print(rowStr)
            }
            
            print(String(repeating: "—", count: 72))
            print("\(CLIColors.bold)\(CLIColors.green)Total Hours:\(CLIColors.reset) \(String(format: "%.1f", totalHours))h\n")
        }
        
    case "help":
        printUsage()
        
    default:
        print("\n\(CLIColors.red)❌ Unknown command:\(CLIColors.reset) \(command)")
        printUsage()
    }
}

func printUsage() {
    print("""
    
    \(CLIColors.cyan)\(CLIColors.bold)⏱️  Timesheet Alert Comments CLI (tac)\(CLIColors.reset)
    
    \(CLIColors.bold)USAGE:\(CLIColors.reset)
      tac \(CLIColors.green)<command>\(CLIColors.reset) [arguments]
      
    \(CLIColors.bold)COMMANDS:\(CLIColors.reset)
      \(CLIColors.green)log\(CLIColors.reset) \(CLIColors.yellow)[preset]\(CLIColors.reset) <comment>   ✏️  Save a log entry (preset must match existing tags)
      \(CLIColors.green)trigger\(CLIColors.reset)                  🔔 Trigger the UI alert popup
      \(CLIColors.green)timesheet\(CLIColors.reset)                📊 Generate and print this week's timesheet summary
      \(CLIColors.green)help\(CLIColors.reset)                     💡 Show this help message
      
    \(CLIColors.bold)EXAMPLES:\(CLIColors.reset)
      tac log "Coding / Dev" "Refactored the login screen"
      tac log "Did some admin work"
      
    """)
}
