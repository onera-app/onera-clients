//
//  SpeechRecognitionService.swift
//  Onera
//
//  Speech-to-Text service using SFSpeechRecognizer
//

import Foundation
import Speech
import AVFoundation

// MARK: - Protocol

@MainActor
protocol SpeechRecognitionServiceProtocol: Sendable {
    func requestAuthorization() async -> Bool
    func startRecording() async throws
    func stopRecording() -> String?
    var isRecording: Bool { get }
    var isAuthorized: Bool { get }
    var transcribedText: String { get }
    var onTranscriptionUpdate: ((String) -> Void)? { get set }
}

// MARK: - Errors

enum SpeechRecognitionError: LocalizedError {
    case notAuthorized
    case audioEngineError
    case recognizerUnavailable
    case recordingInProgress
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized. Please enable it in Settings."
        case .audioEngineError:
            return "Failed to start audio engine."
        case .recognizerUnavailable:
            return "Speech recognizer is not available."
        case .recordingInProgress:
            return "Recording is already in progress."
        }
    }
}

// MARK: - Implementation

@MainActor
final class SpeechRecognitionService: SpeechRecognitionServiceProtocol {
    
    // MARK: - Properties
    
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private(set) var isRecording = false
    private(set) var isAuthorized = false
    private(set) var transcribedText = ""
    
    var onTranscriptionUpdate: ((String) -> Void)?
    
    // MARK: - Initialization
    
    init(locale: Locale = .current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        // Check initial authorization status
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    private func checkAuthorizationStatus() {
        let status = SFSpeechRecognizer.authorizationStatus()
        isAuthorized = status == .authorized
    }
    
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    self?.isAuthorized = status == .authorized
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    // MARK: - Recording
    
    func startRecording() async throws {
        guard isAuthorized else {
            throw SpeechRecognitionError.notAuthorized
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw SpeechRecognitionError.recognizerUnavailable
        }
        
        guard !isRecording else {
            throw SpeechRecognitionError.recordingInProgress
        }
        
        // Configure audio session
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.audioEngineError
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.addsPunctuation = true
        
        // Get the audio input node
        let inputNode = audioEngine.inputNode
        
        // Clear previous transcription
        transcribedText = ""
        
        // Start recognition task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.onTranscriptionUpdate?(self.transcribedText)
                }
                
                if error != nil || result?.isFinal == true {
                    self.stopAudioEngine()
                }
            }
        }
        
        // Configure audio format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        isRecording = true
    }
    
    func stopRecording() -> String? {
        guard isRecording else { return nil }
        
        stopAudioEngine()
        
        let finalText = transcribedText
        return finalText.isEmpty ? nil : finalText
    }
    
    private func stopAudioEngine() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        
        // Deactivate audio session
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[SpeechRecognition] Failed to deactivate audio session: \(error)")
        }
        #endif
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Clean up on dealloc (called from main actor context)
        Task { @MainActor [audioEngine, recognitionTask, recognitionRequest] in
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
        }
    }
}

// MARK: - Mock Implementation

#if DEBUG
@MainActor
final class MockSpeechRecognitionService: SpeechRecognitionServiceProtocol {
    var isRecording = false
    var isAuthorized = true
    var transcribedText = ""
    var onTranscriptionUpdate: ((String) -> Void)?
    
    var mockTranscription = "Hello, this is a test transcription"
    
    func requestAuthorization() async -> Bool {
        return isAuthorized
    }
    
    func startRecording() async throws {
        guard isAuthorized else {
            throw SpeechRecognitionError.notAuthorized
        }
        
        isRecording = true
        
        // Simulate transcription after a delay
        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                self.transcribedText = self.mockTranscription
                self.onTranscriptionUpdate?(self.transcribedText)
            }
        }
    }
    
    func stopRecording() -> String? {
        isRecording = false
        return transcribedText.isEmpty ? nil : transcribedText
    }
}
#endif
