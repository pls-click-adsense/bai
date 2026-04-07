import SwiftUI
import CoreHaptics
import AVFoundation

@main
struct MyVibeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var engine: CHHapticEngine?
    @State private var player: CHHapticAdvancedPatternPlayer?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var statusMessage: String = "music.mp3を配置してください"

    var body: some View {
        VStack(spacing: 50) {
            Text("Auto Sync Vibe")
                .font(.system(size: 30, weight: .black))
            
            Text(statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: toggleMusicVibe) {
                Circle()
                    .fill(isRunning ? Color.red : (audioPlayer == nil ? Color.gray : Color.blue))
                    .frame(width: 130, height: 130)
                    .overlay(Text(isRunning ? "STOP" : "START").foregroundColor(.white).bold())
            }
            .disabled(audioPlayer == nil)
            
            // 再読み込みボタン（ファイルを入れた後に押す用）
            Button("ファイルを再スキャン") { setupAudio() }
                .font(.footnote)
        }
        .onAppear {
            prepareHaptics()
            setupAudio()
        }
    }

    func prepareHaptics() {
        engine = try? CHHapticEngine()
        try? engine?.start()
    }

    func setupAudio() {
        // アプリのDocumentsフォルダのパスを取得
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("music.mp3")

        if FileManager.default.fileExists(atPath: url.path) {
            audioPlayer = try? AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            statusMessage = "music.mp3 を認識しました"
        } else {
            statusMessage = "ファイルが見つかりません:\nDocuments/music.mp3"
        }
    }

    func toggleMusicVibe() {
        if isRunning { stopAll() } else { startAll() }
    }

    func startAll() {
        guard let ap = audioPlayer else { return }
        isRunning = true
        ap.isMeteringEnabled = true
        ap.play()
        
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        ], relativeTime: 0, duration: 1000)
        
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []) else { return }
        player = try? engine?.makeAdvancedPlayer(with: pattern)
        try? player?.start(atTime: 0)

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            ap.updateMeters()
            let level = ap.averagePower(forChannel: 0)
            let normalizedLevel = max(0.1, min(1.0, (Float(level) + 40) / 40))
            let iControl = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: normalizedLevel, relativeTime: 0)
            try? player?.sendParameters([iControl], atTime: 0)
        }
    }

    func stopAll() {
        isRunning = false
        audioPlayer?.stop()
        timer?.invalidate()
        try? player?.stop(atTime: 0)
    }
}
