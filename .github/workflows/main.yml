import SwiftUI
import CoreHaptics
import AVFoundation
import UIKit

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
    @State private var fileName: String = "曲を選択してください"
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 40) {
            Text("Music Sync Vibe")
                .font(.system(size: 28, weight: .black, design: .rounded))
            
            VStack {
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                Text(fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .padding()
            }

            Button(action: { showPicker = true }) {
                Label("ファイルを選択", systemImage: "doc.badge.plus")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Button(action: toggleMusicVibe) {
                Circle()
                    .fill(isRunning ? Color.red : (audioPlayer == nil ? Color.gray : Color.blue))
                    .frame(width: 120, height: 120)
                    .overlay(Text(isRunning ? "STOP" : "PLAY").foregroundColor(.white).bold())
                    .shadow(radius: 10)
            }
            .disabled(audioPlayer == nil)
        }
        .sheet(isPresented: $showPicker) {
            DocumentPicker(audioPlayer: $audioPlayer, fileName: $fileName)
        }
        .onAppear(perform: prepareHaptics)
    }

    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        try? engine?.start()
    }

    func toggleMusicVibe() {
        if isRunning {
            stopAll()
        } else {
            startAll()
        }
    }

    func startAll() {
        guard let ap = audioPlayer else { return }
        isRunning = true
        ap.isMeteringEnabled = true
        ap.play()
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 1000)
        
        let pattern = try? CHHapticPattern(events: [event], parameters: [])
        player = try? engine?.makeAdvancedPlayer(with: pattern)
        try? player?.start(atTime: 0)

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            ap.updateMeters()
            let level = ap.averagePower(forChannel: 0)
            // 音量感度調整：ここの数値をいじると振動のノリが変わるよ
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
        player = nil
    }
}

// ファイル選択用のピッカー
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var fileName: String

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            // セキュリティ上のアクセス許可
            if url.startAccessingSecurityScopedResource() {
                parent.audioPlayer = try? AVAudioPlayer(contentsOf: url)
                parent.fileName = url.lastPathComponent
                // url.stopAccessingSecurityScopedResource() // 再生中に止めるとエラーになるので注意
            }
        }
    }
}
