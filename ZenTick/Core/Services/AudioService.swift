import AVFoundation
import Foundation

enum BellSound: String, CaseIterable, Identifiable, Sendable {
    case deepBowl = "Deep Bowl"
    case brightBell = "Bright Bell"
    case softChime = "Soft Chime"
    case warmBowl = "Warm Bowl"
    case crystalBowl = "Crystal Bowl"

    var id: String { rawValue }

    var frequencies: [Double] {
        switch self {
        case .deepBowl: [220, 440, 660]
        case .brightBell: [523.25, 659.25, 783.99]
        case .softChime: [392, 523.25, 784]
        case .warmBowl: [261.63, 392, 523.25]
        case .crystalBowl: [880, 1320, 1760]
        }
    }

    var decayRate: Double {
        switch self {
        case .deepBowl: 1.5
        case .brightBell: 2.0
        case .softChime: 2.5
        case .warmBowl: 1.8
        case .crystalBowl: 3.0
        }
    }
}

@Observable
final class AudioService {
    private var audioPlayer: AVAudioPlayer?
    private var cachedAudioData: [String: Data] = [:]

    func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("Audio session configuration failed: \(error)")
        }
        #endif
    }

    func playBell(_ sound: BellSound, strikes: Int = 1) {
        for i in 0..<strikes {
            if i > 0 {
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    playSingleBell(sound)
                }
            } else {
                playSingleBell(sound)
            }
        }
    }

    private func playSingleBell(_ sound: BellSound) {
        let data: Data
        if let cached = cachedAudioData[sound.rawValue] {
            data = cached
        } else {
            data = generateBellAudio(sound: sound)
            cachedAudioData[sound.rawValue] = data
        }

        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            print("Failed to play bell: \(error)")
        }
    }

    private func generateBellAudio(sound: BellSound, duration: Double = 3.0) -> Data {
        let sampleRate: Double = 44100
        let numSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: numSamples)

        for freq in sound.frequencies {
            let amplitude: Float = 1.0 / Float(sound.frequencies.count)
            for i in 0..<numSamples {
                let t = Double(i) / sampleRate
                let envelope = Float(exp(-t * sound.decayRate))
                let sample = amplitude * envelope * sin(Float(2.0 * .pi * freq * t))
                samples[i] += sample
            }
        }

        let maxSample = samples.map { abs($0) }.max() ?? 1.0
        if maxSample > 0 {
            for i in 0..<numSamples {
                samples[i] = samples[i] / maxSample * 0.8
            }
        }

        return createWAVData(samples: samples, sampleRate: Int(sampleRate))
    }

    private func createWAVData(samples: [Float], sampleRate: Int) -> Data {
        var data = Data()
        let numSamples = samples.count
        let bitsPerSample: Int16 = 16
        let numChannels: Int16 = 1
        let byteRate = Int32(sampleRate) * Int32(numChannels) * Int32(bitsPerSample) / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = Int32(numSamples * Int(blockAlign))
        let fileSize = 36 + dataSize

        // RIFF header
        data.append(contentsOf: Array("RIFF".utf8))
        withUnsafeBytes(of: fileSize.littleEndian) { data.append(contentsOf: $0) }
        data.append(contentsOf: Array("WAVE".utf8))

        // fmt chunk
        data.append(contentsOf: Array("fmt ".utf8))
        withUnsafeBytes(of: Int32(16).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: Int16(1).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: numChannels.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: Int32(sampleRate).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: byteRate.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: blockAlign.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: bitsPerSample.littleEndian) { data.append(contentsOf: $0) }

        // data chunk
        data.append(contentsOf: Array("data".utf8))
        withUnsafeBytes(of: dataSize.littleEndian) { data.append(contentsOf: $0) }

        for sample in samples {
            let intSample = Int16(max(-1, min(1, sample)) * Float(Int16.max))
            withUnsafeBytes(of: intSample.littleEndian) { data.append(contentsOf: $0) }
        }

        return data
    }
}
