//
//  AudioSettingsView.swift
//  Onera
//
//  Settings for Text-to-Speech and Speech-to-Text
//

import SwiftUI
import AVFoundation

struct AudioSettingsView: View {
    
    @Environment(\.theme) private var theme
    
    // TTS Settings
    @AppStorage("tts.enabled") private var ttsEnabled = true
    @AppStorage("tts.rate") private var ttsRate = Double(AVSpeechUtteranceDefaultSpeechRate)
    @AppStorage("tts.pitch") private var ttsPitch = 1.0
    @AppStorage("tts.volume") private var ttsVolume = 1.0
    @AppStorage("tts.voiceIdentifier") private var ttsVoiceIdentifier = ""
    @AppStorage("tts.autoPlay") private var ttsAutoPlay = false
    
    // STT Settings
    @AppStorage("stt.enabled") private var sttEnabled = true
    @AppStorage("stt.autoSend") private var sttAutoSend = false
    
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    
    var body: some View {
        Form {
            ttsSection
            sttSection
        }
        .formStyle(.grouped)
        .navigationTitle("Audio")
        .task {
            loadVoices()
        }
    }
    
    // MARK: - TTS Section
    
    private var ttsSection: some View {
        Section("Text-to-Speech") {
            Toggle(isOn: $ttsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable TTS")
                    Text("Read assistant responses aloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if ttsEnabled {
                // Voice picker
                Picker("Voice", selection: $ttsVoiceIdentifier) {
                    Text("System Default").tag("")
                    ForEach(availableVoices, id: \.identifier) { voice in
                        Text("\(voice.name) (\(voice.language))")
                            .tag(voice.identifier)
                    }
                }
                
                // Rate
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Speed")
                        Spacer()
                        Text(String(format: "%.2f", ttsRate))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $ttsRate, in: 0.0...1.0, step: 0.05)
                    Text("Speaking rate (0.0 = slowest, 1.0 = fastest)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                
                // Pitch
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Pitch")
                        Spacer()
                        Text(String(format: "%.2f", ttsPitch))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $ttsPitch, in: 0.5...2.0, step: 0.1)
                }
                .padding(.vertical, 4)
                
                // Volume
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Volume")
                        Spacer()
                        Text(String(format: "%.0f%%", ttsVolume * 100))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $ttsVolume, in: 0.0...1.0, step: 0.1)
                }
                .padding(.vertical, 4)
                
                Toggle(isOn: $ttsAutoPlay) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-play Responses")
                        Text("Automatically read new assistant responses aloud")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - STT Section
    
    private var sttSection: some View {
        Section("Speech-to-Text") {
            Toggle(isOn: $sttEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable STT")
                    Text("Use voice input to dictate messages")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if sttEnabled {
                Toggle(isOn: $sttAutoSend) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-send on Speech")
                        Text("Automatically send message when speech ends")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Text("Speech recognition uses the system language. Change it in System Settings > Language & Region.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadVoices() {
        // Get premium/enhanced voices sorted by name
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.quality == .enhanced || $0.quality == .premium }
            .sorted { $0.name < $1.name }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AudioSettingsView()
    }
}
#endif
