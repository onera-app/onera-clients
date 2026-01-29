//
//  PlatformEnvironment.swift
//  Onera
//
//  Platform-agnostic abstractions for screen, haptics, and device capabilities
//

import SwiftUI

// MARK: - Platform Detection

enum Platform {
    case iPhone
    case iPad
    case mac
    case watch
    
    static var current: Platform {
        #if os(watchOS)
        return .watch
        #elseif os(macOS)
        return .mac
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        } else {
            return .iPhone
        }
        #endif
    }
    
    var isCompact: Bool {
        self == .iPhone || self == .watch
    }
    
    var supportsMultipleWindows: Bool {
        self == .iPad || self == .mac
    }
    
    var supportsKeyboardShortcuts: Bool {
        self == .iPad || self == .mac
    }
    
    var supportsPencil: Bool {
        self == .iPad
    }
    
    var supportsHaptics: Bool {
        self == .iPhone || self == .watch
    }
}

// MARK: - Screen Service

protocol ScreenServiceProtocol {
    var screenWidth: CGFloat { get }
    var screenHeight: CGFloat { get }
    var safeAreaInsets: EdgeInsets { get }
    var isLandscape: Bool { get }
}

#if os(iOS)
final class ScreenService: ScreenServiceProtocol {
    static let shared = ScreenService()
    
    var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }
    
    var safeAreaInsets: EdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return EdgeInsets()
        }
        let insets = window.safeAreaInsets
        return EdgeInsets(
            top: insets.top,
            leading: insets.left,
            bottom: insets.bottom,
            trailing: insets.right
        )
    }
    
    var isLandscape: Bool {
        screenWidth > screenHeight
    }
}
#elseif os(macOS)
final class ScreenService: ScreenServiceProtocol {
    static let shared = ScreenService()
    
    var screenWidth: CGFloat {
        NSScreen.main?.frame.width ?? 1440
    }
    
    var screenHeight: CGFloat {
        NSScreen.main?.frame.height ?? 900
    }
    
    var safeAreaInsets: EdgeInsets {
        EdgeInsets() // macOS doesn't have safe area insets like iOS
    }
    
    var isLandscape: Bool {
        true // macOS is always "landscape"
    }
}
#elseif os(watchOS)
final class ScreenService: ScreenServiceProtocol {
    static let shared = ScreenService()
    
    var screenWidth: CGFloat {
        WKInterfaceDevice.current().screenBounds.width
    }
    
    var screenHeight: CGFloat {
        WKInterfaceDevice.current().screenBounds.height
    }
    
    var safeAreaInsets: EdgeInsets {
        EdgeInsets()
    }
    
    var isLandscape: Bool {
        false
    }
}
#endif

// MARK: - Haptic Service

enum HapticType {
    case light
    case medium
    case heavy
    case success
    case warning
    case error
    case selection
}

protocol HapticServiceProtocol {
    func trigger(_ type: HapticType)
}

#if os(iOS)
final class HapticService: HapticServiceProtocol {
    static let shared = HapticService()
    
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    func trigger(_ type: HapticType) {
        switch type {
        case .light:
            lightGenerator.impactOccurred()
        case .medium:
            mediumGenerator.impactOccurred()
        case .heavy:
            heavyGenerator.impactOccurred()
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        case .selection:
            selectionGenerator.selectionChanged()
        }
    }
}
#elseif os(watchOS)
import WatchKit

final class HapticService: HapticServiceProtocol {
    static let shared = HapticService()
    
    func trigger(_ type: HapticType) {
        switch type {
        case .light, .selection:
            WKInterfaceDevice.current().play(.click)
        case .medium:
            WKInterfaceDevice.current().play(.directionUp)
        case .heavy:
            WKInterfaceDevice.current().play(.directionDown)
        case .success:
            WKInterfaceDevice.current().play(.success)
        case .warning:
            WKInterfaceDevice.current().play(.retry)
        case .error:
            WKInterfaceDevice.current().play(.failure)
        }
    }
}
#else
// macOS - no haptics
final class HapticService: HapticServiceProtocol {
    static let shared = HapticService()
    
    func trigger(_ type: HapticType) {
        // No-op on macOS
    }
}
#endif

// MARK: - Keyboard Service

protocol KeyboardServiceProtocol {
    func dismiss()
}

#if os(iOS)
final class KeyboardService: KeyboardServiceProtocol {
    static let shared = KeyboardService()
    
    func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
#else
final class KeyboardService: KeyboardServiceProtocol {
    static let shared = KeyboardService()
    
    func dismiss() {
        // macOS/watchOS handle this differently
        #if os(macOS)
        NSApp.keyWindow?.makeFirstResponder(nil)
        #endif
    }
}
#endif

// MARK: - SwiftUI Environment Keys

private struct PlatformKey: EnvironmentKey {
    static let defaultValue: Platform = Platform.current
}

private struct HapticServiceKey: EnvironmentKey {
    static let defaultValue: HapticServiceProtocol = HapticService.shared
}

private struct KeyboardServiceKey: EnvironmentKey {
    static let defaultValue: KeyboardServiceProtocol = KeyboardService.shared
}

private struct ScreenServiceKey: EnvironmentKey {
    static let defaultValue: ScreenServiceProtocol = ScreenService.shared
}

extension EnvironmentValues {
    var platform: Platform {
        get { self[PlatformKey.self] }
        set { self[PlatformKey.self] = newValue }
    }
    
    var hapticService: HapticServiceProtocol {
        get { self[HapticServiceKey.self] }
        set { self[HapticServiceKey.self] = newValue }
    }
    
    var keyboardService: KeyboardServiceProtocol {
        get { self[KeyboardServiceKey.self] }
        set { self[KeyboardServiceKey.self] = newValue }
    }
    
    var screenService: ScreenServiceProtocol {
        get { self[ScreenServiceKey.self] }
        set { self[ScreenServiceKey.self] = newValue }
    }
}

// MARK: - Convenience View Extensions

extension View {
    /// Dismiss keyboard in a platform-agnostic way
    func dismissKeyboard() {
        KeyboardService.shared.dismiss()
    }
    
    /// Trigger haptic feedback in a platform-agnostic way
    func triggerHaptic(_ type: HapticType) {
        HapticService.shared.trigger(type)
    }
}
