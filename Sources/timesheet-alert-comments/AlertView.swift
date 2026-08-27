import SwiftUI

struct AlertView: View {
    var onClose: () -> Void
    var onSkip: () -> Void

    @ObservedObject private var settings = AppSettings.shared
    @State private var commentText: String = ""
    @State private var selectedPreset: String = ""
    @State private var selectedTime: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Timesheet Update Needed")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(currentWeekLabel())
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.2))
                .cornerRadius(4)
            }
            .padding(.bottom, 4)

            HStack {
                Text("What are you working on?")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text("Time Spent:")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.trailing, 2)
            }

            // Dynamic presets and Time increments
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(settings.presetTags, id: \.self) { preset in
                            Button(action: { selectedPreset = preset }) {
                                Text(preset)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedPreset == preset ? Color.blue : Color.white.opacity(0.15))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Divider().background(Color.white.opacity(0.5)).frame(height: 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(["15m", "30m", "1h", "2h"], id: \.self) { time in
                            Button(action: { 
                                if selectedTime == time { selectedTime = "" } else { selectedTime = time }
                            }) {
                                Text(time)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedTime == time ? Color.green : Color.white.opacity(0.15))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .frame(maxWidth: 160) // Prevent time buttons from taking all space
            }

            // Text editor
            ZStack(alignment: .topLeading) {
                if commentText.isEmpty {
                    Text("Enter comment here...")
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $commentText)
                    .scrollContentBackground(.hidden)
                    .background(Color.black.opacity(0.2))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .frame(height: 80)
                    .onChange(of: commentText) { newValue in
                        AlertWindowController.shared?.isUserTyping = !newValue.isEmpty
                    }
            }

            HStack {
                Button("Open Replicon") {
                    if let url = URL(string: "https://na4.replicon.com/CventG3/my/timesheet/earliest-not-submitted") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.2))

                if !commentText.isEmpty {
                    Text("Typing detected (window locked)")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                Spacer()
                Button(action: submit) {
                    Text("Submit (⌘ + Enter)")
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
        .background(
            ZStack {
                Color(red: 0.2, green: 0.05, blue: 0.05).opacity(settings.alertBackgroundOpacity)
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
            }
        )
        .cornerRadius(settings.alertCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: settings.alertCornerRadius)
                .stroke(Color.red.opacity(0.6), lineWidth: settings.alertBorderWidth)
        )
    }

    private func submit() {
        var finalComment = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !selectedTime.isEmpty {
            finalComment = "[\(selectedTime)] \(finalComment)"
        }
        let screenshotURL = AlertWindowController.shared?.currentScreenshotURL
        StorageManager.shared.saveComment(preset: selectedPreset, comment: finalComment, screenshotURL: screenshotURL)
        onClose()
    }

    private func currentWeekLabel() -> String {
        let cal = Calendar.current
        let today = Date()
        let mon = cal.date(from: cal.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: today))!
        let fri = cal.date(byAdding: .day, value: 4, to: mon)!
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let year = cal.component(.year, from: mon)
        return "Week of \(fmt.string(from: mon)) – \(fmt.string(from: fri)), \(year)"
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blendingMode
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blendingMode
    }
}
