import Foundation
import AVFoundation

/// Manages interactive sound effects for ImagePet.
/// Synthesizes and plays a lightweight, AirDrop-style Done success chime in memory.
final class SoundManager {
    static let shared = SoundManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var cachedDoneWavData: Data?

    private init() {
        self.cachedDoneWavData = generateDoneSoundWavData()
    }

    /// Plays the custom-synthesized Done success sound if the player can be initialized.
    func playSuccessSound() {
        guard let data = cachedDoneWavData else { return }
        do {
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            player.play()
            self.audioPlayer = player
        } catch {
            #if DEBUG
            print("[SoundManager] Failed to play success sound: \(error)")
            #endif
        }
    }

    /// Dynamically generates a WAV format Data buffer containing an AirDrop-style chime.
    /// AirDrop style has a signature pleasant, double-note chime with a short attack and exponential-like decay.
    private func generateDoneSoundWavData() -> Data? {
        let sampleRate: Double = 44100.0
        
        // Frequencies for a beautiful major third chime: G5 (783.99 Hz) and C6 (1046.50 Hz)
        let f1: Double = 783.99
        let f2: Double = 1046.50
        
        let tone1Duration = 0.12
        let tone2Start = 0.08
        let tone2Duration = 0.35
        let totalDuration = tone2Start + tone2Duration // 0.43 seconds
        
        let numSamples = Int(totalDuration * sampleRate)
        let bitsPerSample = 16
        let numChannels = 1
        
        var samples = [Int16]()
        samples.reserveCapacity(numSamples)
        
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            
            // Tone 1: G5, starting at t=0
            var tone1Amp: Double = 0.0
            if t >= 0 && t < tone1Duration {
                let env1: Double
                let attack = 0.005
                if t < attack {
                    env1 = t / attack
                } else {
                    env1 = max(0, 1.0 - (t - attack) / (tone1Duration - attack))
                }
                tone1Amp = sin(2.0 * .pi * f1 * t) * env1
            }
            
            // Tone 2: C6, starting at t=0.08s
            var tone2Amp: Double = 0.0
            if t >= tone2Start && t < totalDuration {
                let dt = t - tone2Start
                let env2: Double
                let attack = 0.01
                if dt < attack {
                    env2 = dt / attack
                } else {
                    env2 = max(0, 1.0 - (dt - attack) / (tone2Duration - attack))
                }
                tone2Amp = sin(2.0 * .pi * f2 * dt) * env2
            }
            
            // Mix the two tones (45% Tone 1, 55% Tone 2 to emphasize the second chime)
            let mixed = (tone1Amp * 0.45) + (tone2Amp * 0.55)
            
            // Scale and clamp to Int16 limits
            let sampleVal = Int16(clamping: Int(mixed * Double(Int16.max)))
            samples.append(sampleVal)
        }
        
        // WAV Header construction
        var header = Data()
        
        // ChunkID "RIFF"
        header.append(Data("RIFF".utf8))
        
        // ChunkSize: 36 + subchunk2Size
        let subchunk2Size = samples.count * numChannels * (bitsPerSample / 8)
        let chunkSize = Int32(36 + subchunk2Size)
        withUnsafeBytes(of: chunkSize.littleEndian) { header.append(contentsOf: $0) }
        
        // Format "WAVE"
        header.append(Data("WAVE".utf8))
        
        // Subchunk1ID "fmt "
        header.append(Data("fmt ".utf8))
        
        // Subchunk1Size (16 for PCM)
        let subchunk1Size = Int32(16)
        withUnsafeBytes(of: subchunk1Size.littleEndian) { header.append(contentsOf: $0) }
        
        // AudioFormat (1 for PCM)
        let audioFormat = Int16(1)
        withUnsafeBytes(of: audioFormat.littleEndian) { header.append(contentsOf: $0) }
        
        // NumChannels (1 for Mono)
        let channels = Int16(numChannels)
        withUnsafeBytes(of: channels.littleEndian) { header.append(contentsOf: $0) }
        
        // SampleRate
        let rate = Int32(sampleRate)
        withUnsafeBytes(of: rate.littleEndian) { header.append(contentsOf: $0) }
        
        // ByteRate
        let byteRate = Int32(Int(sampleRate) * numChannels * (bitsPerSample / 8))
        withUnsafeBytes(of: byteRate.littleEndian) { header.append(contentsOf: $0) }
        
        // BlockAlign
        let blockAlign = Int16(numChannels * (bitsPerSample / 8))
        withUnsafeBytes(of: blockAlign.littleEndian) { header.append(contentsOf: $0) }
        
        // BitsPerSample
        let bps = Int16(bitsPerSample)
        withUnsafeBytes(of: bps.littleEndian) { header.append(contentsOf: $0) }
        
        // Subchunk2ID "data"
        header.append(Data("data".utf8))
        
        // Subchunk2Size
        let size2 = Int32(subchunk2Size)
        withUnsafeBytes(of: size2.littleEndian) { header.append(contentsOf: $0) }
        
        // Append all the PCM sample buffers
        samples.withUnsafeBufferPointer { buffer in
            header.append(buffer)
        }
        
        return header
    }
}
