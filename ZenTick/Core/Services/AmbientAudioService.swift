import AVFoundation
import Foundation

enum AmbientSound: String, CaseIterable, Identifiable, Sendable {
    case none = "None"
    case rain = "Rain"
    case stream = "Stream"
    case brownNoise = "Brown Noise"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: String(localized: "ambient_none")
        case .rain: String(localized: "ambient_rain")
        case .stream: String(localized: "ambient_stream")
        case .brownNoise: String(localized: "ambient_brown")
        }
    }
}

@Observable
final class AmbientAudioService {
    private var audioPlayer: AVAudioPlayer?
    private var cachedAudioData: [String: Data] = [:]
    private var currentSound: AmbientSound?

    func play(_ sound: AmbientSound) {
        guard sound != .none else { stop(); return }

        let data: Data
        if let cached = cachedAudioData[sound.rawValue] {
            data = cached
        } else {
            data = generateAmbientAudio(sound: sound)
            cachedAudioData[sound.rawValue] = data
        }

        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0.3
            audioPlayer?.play()
            currentSound = sound
        } catch {
            print("Failed to play ambient sound: \(error)")
        }
    }

    func pause() {
        audioPlayer?.pause()
    }

    func resume() {
        audioPlayer?.play()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        currentSound = nil
    }

    // MARK: - Audio Generation

    private func generateAmbientAudio(sound: AmbientSound, duration: Double = 30.0) -> Data {
        let sampleRate: Double = 44100
        let numSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: numSamples)

        switch sound {
        case .none:
            break
        case .rain:
            generateRain(into: &samples, sampleRate: sampleRate)
        case .stream:
            generateStream(into: &samples, sampleRate: sampleRate)
        case .brownNoise:
            generateBrownNoise(into: &samples, sampleRate: sampleRate)
        }

        normalize(&samples, peak: 0.7)
        return createWAVData(samples: samples, sampleRate: Int(sampleRate))
    }

    /// Rain: filtered white noise with LFO volume modulation
    private func generateRain(into samples: inout [Float], sampleRate: Double) {
        var lastOut: Float = 0
        let filterCoeff: Float = 0.98 // Low-pass strength

        for i in 0..<samples.count {
            let t = Double(i) / sampleRate
            // White noise source
            let white = Float.random(in: -1...1)
            // Brown noise filter (6dB/oct rolloff)
            lastOut = filterCoeff * lastOut + (1.0 - filterCoeff) * white
            // LFO for subtle volume variation (simulates wind gusts)
            let lfo = Float(1.0 + 0.15 * sin(2.0 * .pi * 0.08 * t))
            // Add some higher frequency "patter" for rain drops
            let patter = Float.random(in: -0.3...0.3) * Float(exp(-2.0 * abs(sin(2.0 * .pi * 3.7 * t))))
            samples[i] = (lastOut * 3.0 + patter) * lfo
        }
    }

    /// Stream: layered brown noise at different cutoffs + babbling modulation
    private func generateStream(into samples: inout [Float], sampleRate: Double) {
        var lastOut1: Float = 0
        var lastOut2: Float = 0

        for i in 0..<samples.count {
            let t = Double(i) / sampleRate
            let white = Float.random(in: -1...1)
            // Deep base flow
            lastOut1 = 0.99 * lastOut1 + 0.01 * white
            // Higher frequency babbling
            lastOut2 = 0.93 * lastOut2 + 0.07 * white
            // Modulate babbling with irregular rhythm
            let babble = Float(0.5 + 0.5 * sin(2.0 * .pi * 0.5 * t) * sin(2.0 * .pi * 1.3 * t))
            samples[i] = lastOut1 * 2.5 + lastOut2 * babble * 1.5
        }
    }

    /// Brown noise: classic 1/f^2 spectrum, very soothing
    private func generateBrownNoise(into samples: inout [Float], sampleRate: Double) {
        var lastOut: Float = 0

        for i in 0..<samples.count {
            let white = Float.random(in: -1...1)
            lastOut = lastOut + (0.02 * white)
            lastOut = lastOut / 1.02 // Prevent drift
            samples[i] = lastOut * 3.5
        }
    }

    private func normalize(_ samples: inout [Float], peak: Float) {
        let maxSample = samples.map { abs($0) }.max() ?? 1.0
        guard maxSample > 0 else { return }
        let scale = peak / maxSample
        for i in 0..<samples.count {
            samples[i] *= scale
        }
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

        data.append(contentsOf: Array("RIFF".utf8))
        withUnsafeBytes(of: fileSize.littleEndian) { data.append(contentsOf: $0) }
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        withUnsafeBytes(of: Int32(16).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: Int16(1).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: numChannels.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: Int32(sampleRate).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: byteRate.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: blockAlign.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: bitsPerSample.littleEndian) { data.append(contentsOf: $0) }

        data.append(contentsOf: Array("data".utf8))
        withUnsafeBytes(of: dataSize.littleEndian) { data.append(contentsOf: $0) }

        for sample in samples {
            let intSample = Int16(max(-1, min(1, sample)) * Float(Int16.max))
            withUnsafeBytes(of: intSample.littleEndian) { data.append(contentsOf: $0) }
        }

        return data
    }
}
