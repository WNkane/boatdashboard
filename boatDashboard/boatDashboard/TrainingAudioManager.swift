import AVFoundation

// MARK: - Training Audio Manager
// Handles TTS announcements and countdown beeps during workout sessions.

class TrainingAudioManager: NSObject, ObservableObject {

    @Published var isMuted: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        // Allow audio to mix with music playback (e.g. Spotify)
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .default,
            options: [.mixWithOthers, .duckOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            // 電話來電，系統自動暫停 synthesizer，不需額外操作
            break
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                try? AVAudioSession.sharedInstance().setActive(true)
            }
        @unknown default:
            break
        }
    }

    // MARK: - Public API

    /// Speak "開始" when ride begins.
    func announceStart() {
        speak("開始")
    }

    /// Speak "訓練完成，做得好" when all intervals finish.
    func announceFinish() {
        speak("訓練完成，做得好")
    }

    /// Announce next interval details: "第X段，有氧，3分鐘，目標心率148"
    func announceNextInterval(index: Int, interval: WorkoutInterval) {
        let zone     = zoneName(interval.targetHeartRate)
        let duration = formatDuration(interval.durationSeconds)
        speak("第\(index)段，\(zone)，\(duration)，目標心率\(interval.targetHeartRate)")
    }

    /// Speak countdown digit ("3" / "2" / "1") during final seconds of an interval.
    func playCountdown(_ seconds: Int) {
        guard seconds >= 1, seconds <= 3 else { return }
        speak("\(seconds)")
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    // MARK: - Private helpers

    private func speak(_ text: String) {
        guard !isMuted else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice           = AVSpeechSynthesisVoice(language: "zh-TW")
        utterance.rate            = 0.55
        utterance.volume          = 1.0
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    private func zoneName(_ bpm: Int) -> String {
        switch bpm {
        case ..<115: return "恢復"
        case ..<138: return "有氧基礎"
        case ..<155: return "有氧"
        case ..<171: return "臨界"
        default:     return "最大強度"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 && s > 0 { return "\(m)分\(s)秒" }
        if m > 0           { return "\(m)分鐘" }
        return "\(s)秒"
    }
}
