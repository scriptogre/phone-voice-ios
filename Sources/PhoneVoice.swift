import SwiftUI
import AVFoundation

// Streams the mic as 16-bit PCM to the thinkcentre voice server; it transcribes, Jev drives the phone.
@main struct PhoneVoiceApp: App { var body: some Scene { WindowGroup { ContentView() } } }

final class Mic: ObservableObject {
    @Published var status = "connecting"
    @Published var heard = ""
    private let engine = AVAudioEngine()
    private var ws: URLSessionWebSocketTask?
    private var rate = 48000

    // Server restarts or network switches drop the socket; reconnect forever, mic keeps running.
    private func connect() {
        ws?.cancel()
        ws = URLSession.shared.webSocketTask(with: URL(string: "wss://phone.christiantanul.com/ws")!)
        ws?.resume()
        ws?.send(.string("{\"rate\":\(rate)}")) { _ in }
        receive()
    }

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .mixWithOthers])
        try? session.setActive(true)
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        let out = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: fmt.sampleRate, channels: 1, interleaved: true)!
        let conv = AVAudioConverter(from: fmt, to: out)!
        rate = Int(fmt.sampleRate)
        connect()
        input.installTap(onBus: 0, bufferSize: 4096, format: fmt) { [weak self] buf, _ in
            let pcm = AVAudioPCMBuffer(pcmFormat: out, frameCapacity: buf.frameLength)!
            var given = false
            conv.convert(to: pcm, error: nil) { _, st in
                st.pointee = given ? .noDataNow : .haveData
                defer { given = true }
                return given ? nil : buf
            }
            self?.ws?.send(.data(Data(bytes: pcm.int16ChannelData![0], count: Int(pcm.frameLength) * 2))) { _ in }
        }
        try? engine.start()
        status = "Listening"
    }

    private func receive() {
        ws?.receive { [weak self] r in
            guard case .success(.string(let s)) = r,
                  let m = try? JSONSerialization.jsonObject(with: Data(s.utf8)) as? [String: Any] else {
                DispatchQueue.main.async { self?.status = "reconnecting" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self?.connect(); self?.status = "Listening" }
                return
            }
            DispatchQueue.main.async {
                if let h = m["heard"] as? String { self?.heard = h }
                if let g = m["go"] as? String { self?.status = "doing: \(g)" }
                if let t = m["step"] as? String { self?.status = t }
                if let e = m["error"] as? String { self?.status = "error: \(e)" }
                if m["done"] != nil { self?.status = "Listening" }
            }
            self?.receive()
        }
    }
}

struct ContentView: View {
    @StateObject private var mic = Mic()
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mic.status).foregroundStyle(.green)
            Text(mic.heard).font(.title2)
            Spacer()
        }.padding().onAppear(perform: mic.start)
    }
}
