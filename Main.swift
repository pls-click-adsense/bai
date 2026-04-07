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
            Text("Power Sync Vibe")
                .font(.system(size: 30, weight: .black))
            
            Text(statusMessage)
                .font(.caption)
                .multilineTextAlignment(.center)

            Button(action: toggleMusicVibe) {
                Circle()
                    .fill(isRunning ? Color.red : (audioPlayer == nil ? Color.gray : Color.blue))
                    .frame(width: 140, height: 140)
                    .overlay(Text(isRunning ? "STOP" : "START").foregroundColor(.white).bold())
            }
            .disabled(audioPlayer == nil)
            
            Button("ファイルを再読み込み") { setupAudio() }
        }
        .onAppear {
            setupAudio()
            prepareHaptics()
        }
    }

    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            // マナーモードでも振動させるためのオーディオセッション設定
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            engine = try CHHapticEngine()
            // サーバーが停止しても自動再起動するように設定
            engine?.resetHandler = {
                try? self.engine?.start()
            }
            try engine?.start()
        } catch {
            print("Haptic Engine Error: \(error)")
        }
    }

    func setupAudio() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("music.mp3")

        if FileManager.default.fileExists(atPath: url.path) {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.isMeteringEnabled = true
                audioPlayer?.prepareToPlay()
                statusMessage = "music.mp3 を認識しました\n(マナーモードを解除して試してね)"
            } catch {
                statusMessage = "読み込み失敗: \(error.localizedDescription)"
            }
        } else {
            statusMessage = "ファイルなし: Documents/music.mp3"
        }
    }

    func toggleMusicVibe() {
        if isRunning { stopAll() } else { startAll() }
    }

    func startAll() {
        guard let ap = audioPlayer, let eng = engine else { return }
        
        try? eng.start()
        isRunning = true
        ap.currentTime = 0
        ap.play()
        
        // 連続振動イベントを作成
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 3600) // 1時間
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            player = try eng.makeAdvancedPlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Haptic Play Error: \(error)")
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            ap.updateMeters()
            let level = ap.averagePower(forChannel: 0)
            
            // 感度を大幅にアップ（-35dB〜0dBを 0.1〜1.0に変換）
            let power = max(0, (Float(level) + 35) / 35)
            let normalizedLevel = min(1.0, max(0.1, power))
            
            let iControl = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: normalizedLevel, relativeTime: 0)
            let sControl = CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: normalizedLevel, relativeTime: 0)
            try? player?.sendParameters([iControl, sControl], atTime: 0)
        }
    }

    func stopAll() {
        isRunning = false
        audioPlayer?.stop()
        timer?.invalidate()
        try? player?.stop(atTime: 0)
        player = nil
    }
}
