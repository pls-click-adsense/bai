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
                Image(systemName: "music.quaver.app.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.pink)
                Text(fileName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }

            Button(action: { showPicker = true }) {
                Label("曲を読み込む", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(15)
            }
            .padding(.horizontal)

            Spacer()

            Button(action: toggleMusicVibe) {
                ZStack {
                    Circle()
                        .fill(isRunning ? Color.red : (audioPlayer == nil ? Color.gray : Color.blue))
                        .frame(width: 140, height: 140)
                    Text(isRunning ? "STOP" : "START")
                        .foregroundColor(.white)
                        .font(.title2).bold()
                }
                .shadow(radius: 15)
            }
            .disabled(audioPlayer == nil)
            .padding(.bottom, 60)
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
        if isRunning { stopAll() } else { startAll() }
    }

    func startAll() {
        guard let ap = audioPlayer else { return }
        isRunning = true
        ap.isMeteringEnabled = true
        ap.play()
        
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 1000)
        
        // 修正ポイント：安全にアンラップ
        guard let pattern = try? CHHapticPattern(events: [event], parameters: []) else { return }
        
        do {
            player = try engine?.makeAdvancedPlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Haptic Error: \(error)")
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            ap.updateMeters()
            let level = ap.averagePower(forChannel: 0)
            // 感度調整 (-40dBを基準に正規化)
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

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var audioPlayer: AVAudioPlayer?
    @Binding var fileName: String

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            if url.startAccessingSecurityScopedResource() {
                parent.audioPlayer = try? AVAudioPlayer(contentsOf: url)
                parent.fileName = url.lastPathComponent
            }
        }
    }
}
