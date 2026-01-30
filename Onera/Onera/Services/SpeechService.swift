//
//  SpeechService.swift
//  Onera
//
//  Text-to-Speech service using AVSpeechSynthesizer
//

import AVFoundation

// MARK: - Protocol

protocol SpeechServiceProtocol: Sendable {
    func speak(_ text: String) async
    func stop()
    var isSpeaking: Bool { get }
}

// MARK: - Implementation

@MainActor
final class SpeechService: NSObject, SpeechServiceProtocol, AVSpeechSynthesizerDelegate {
    
    // MARK: - Properties
    
    private let synthesizer = AVSpeechSynthesizer()
    private(set) var isSpeaking = false
    
    private var speakingContinuation: CheckedContinuation<Void, Never>?
    
    // MARK: - Settings
    
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    var pitch: Float = 1.0
    var volume: Float = 1.0
    var voiceIdentifier: String?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }
    
    // MARK: - Audio Session
    
    private func configureAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true)
        } catch {
            print("[SpeechService] Failed to configure audio session: \(error)")
        }
        #endif
        // macOS handles audio routing automatically
    }
    
    // MARK: - Public Methods
    
    func speak(_ text: String) async {
        // Stop any current speech
        if isSpeaking {
            stop()
        }
        
        // Clean text for speech (remove markdown, code blocks, etc.)
        let cleanedText = cleanTextForSpeech(text)
        
        guard !cleanedText.isEmpty else { return }
        
        let utterance = AVSpeechUtterance(string: cleanedText)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        
        // Use preferred voice or default
        if let voiceId = voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            // Use default enhanced voice for current language
            utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        }
        
        isSpeaking = true
        
        await withCheckedContinuation { continuation in
            self.speakingContinuation = continuation
            self.synthesizer.speak(utterance)
        }
    }
    
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        speakingContinuation?.resume()
        speakingContinuation = nil
    }
    
    // MARK: - Text Cleaning
    
    private func cleanTextForSpeech(_ text: String) -> String {
        var cleaned = text
        
        // Remove code blocks
        let codeBlockPattern = "```[\\s\\S]*?```"
        if let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(location: 0, length: cleaned.utf16.count),
                withTemplate: " code block "
            )
        }
        
        // Remove inline code
        let inlineCodePattern = "`[^`]+`"
        if let regex = try? NSRegularExpression(pattern: inlineCodePattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(location: 0, length: cleaned.utf16.count),
                withTemplate: " "
            )
        }
        
        // Remove markdown links but keep text
        let linkPattern = "\\[([^\\]]+)\\]\\([^)]+\\)"
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(location: 0, length: cleaned.utf16.count),
                withTemplate: "$1"
            )
        }
        
        // Remove markdown formatting characters
        let markdownChars = ["**", "*", "__", "_", "~~", "#"]
        for char in markdownChars {
            cleaned = cleaned.replacingOccurrences(of: char, with: "")
        }
        
        // Clean up extra whitespace
        let whitespacePattern = "\\s+"
        if let regex = try? NSRegularExpression(pattern: whitespacePattern, options: []) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                options: [],
                range: NSRange(location: 0, length: cleaned.utf16.count),
                withTemplate: " "
            )
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingContinuation?.resume()
            self.speakingContinuation = nil
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakingContinuation?.resume()
            self.speakingContinuation = nil
        }
    }
    
    // MARK: - Available Voices
    
    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { voice in
            // Filter for quality voices
            voice.quality == .enhanced || voice.quality == .premium
        }.sorted { $0.name < $1.name }
    }
    
    static var currentLanguageVoices: [AVSpeechSynthesisVoice] {
        let currentLanguage = AVSpeechSynthesisVoice.currentLanguageCode()
        return AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix(currentLanguage.prefix(2))
        }.sorted { $0.name < $1.name }
    }
}

// MARK: - Mock Implementation

#if DEBUG
@MainActor
final class MockSpeechService: SpeechServiceProtocol, @unchecked Sendable {
    var isSpeaking = false
    var lastSpokenText: String?
    
    func speak(_ text: String) async {
        lastSpokenText = text
        isSpeaking = true
        // Simulate speaking
        try? await Task.sleep(for: .milliseconds(100))
        isSpeaking = false
    }
    
    func stop() {
        isSpeaking = false
    }
}
#endif
