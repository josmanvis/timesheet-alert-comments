import Foundation
import Combine

class TimerManager: ObservableObject {
    static let shared = TimerManager()

    private var timer: Timer?

    func startTimer() {
        resetTimer(disregarded: false)
    }

    func updateInterval(_ minutes: Int) {
        AppSettings.shared.intervalMinutes = minutes
        resetTimer(disregarded: false)
    }

    func triggerAlert() {
        DispatchQueue.main.async {
            AlertWindowController.showWindow()
        }
    }

    func resetTimer(disregarded: Bool) {
        timer?.invalidate()
        let minutes = disregarded
            ? AppSettings.shared.skipRetryMinutes
            : AppSettings.shared.intervalMinutes
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60),
                                     repeats: false) { [weak self] _ in
            self?.triggerAlert()
        }
    }
}
