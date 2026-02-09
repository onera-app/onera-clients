//
//  TTSPlayerOverlay.swift
//  Onera
//
//  TTS (Text-to-Speech) floating player overlay (ChatGPT style)
//

import SwiftUI

/// Floating TTS player overlay shown when speech is playing
struct TTSPlayerOverlay: View {
    
    /// Whether TTS is currently playing
    let isPlaying: Bool
    
    /// Start time of playback for elapsed time tracking
    let startTime: Date?
    
    /// Called when user taps stop/close
    let onStop: () -> Void
    
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?
    
    var body: some View {
        VStack {
            // Floating pill at top
            HStack(spacing: 16) {
                // Speaker icon with animation
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce.byLayer, options: .repeating, isActive: isPlaying)
                
                // Elapsed time display
                Text(formatElapsedTime(elapsedSeconds))
                    .font(.subheadline.weight(.semibold).monospaced())
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Stop button
                Button {
                    stopTimer()
                    onStop()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(8)
                        .background(Circle().fill(Color.white.opacity(0.2)))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.85))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            Spacer()
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue {
                startTimer()
            } else {
                stopTimer()
            }
        }
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        stopTimer()
        
        // Calculate elapsed from start time if available
        if let start = startTime {
            elapsedSeconds = Int(Date().timeIntervalSince(start))
        } else {
            elapsedSeconds = 0
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Formatting
    
    private func formatElapsedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        TTSPlayerOverlay(
            isPlaying: true,
            startTime: Date(),
            onStop: { print("Stop") }
        )
    }
}
