import SwiftUI
import CoreHaptics

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
    
    // パラメータ：強さと鋭さ
    @State private var intensity: Float = 0.5
    @State private var sharpness: Float = 0.5
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Vibe Controller")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .padding(.top, 50)

            VStack(alignment: .leading) {
                Text("強度 (Intensity): \(String(format: "%.2f", intensity))")
                Slider(value: $intensity, in: 0...1, onEditingChanged: { _ in updateParams() })
            }
            .padding()

            VStack(alignment: .leading) {
                Text("鋭さ (Sharpness): \(String(format: "%.2f", sharpness))")
                Slider(value: $sharpness, in: 0...1, onEditingChanged: { _ in updateParams() })
            }
            .padding()

            Spacer()

            Button(action: toggleVibe) {
                Circle()
                    .fill(isRunning ? Color.red : Color.blue)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text(isRunning ? "STOP" : "START")
                            .foregroundColor(.white)
                            .bold()
                    )
                    .shadow(radius: 10)
            }
            .padding(.bottom, 50)
        }
        .onAppear(perform: prepareHaptics)
    }

    // 振動の準備
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch { print("Error: \(error)") }
    }

    // 開始・停止の切り替え
    func toggleVibe() {
        if isRunning {
            try? player?.stop(atTime: 0)
            player = nil
            isRunning = false
        } else {
            startVibe()
            isRunning = true
        }
    }

    func startVibe() {
        let iParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
        let sParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [iParam, sParam], relativeTime: 0, duration: 100)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            player = try engine?.makeAdvancedPlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch { print("Play Error: \(error)") }
    }

    // スライダーを動かした時にリアルタイム反映
    func updateParams() {
        let iControl = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0)
        let sControl = CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: sharpness, relativeTime: 0)
        try? player?.sendParameters([iControl, sControl], atTime: 0)
    }
}
