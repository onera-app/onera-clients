//
//  Icons.swift
//  Onera
//
//  Centralized icon size, spacing tokens, and Hugeicons integration
//

import SwiftUI

// MARK: - Icon Size Tokens

/// Onera Design System — Icon Tokens
///
/// Consistent icon dimensions used throughout the app.
/// All sizes are designed to pair with their typography counterparts.
enum OneraIconSize {
    
    /// 14pt — Inline indicators, badges, status dots
    static let xs: CGFloat = 14
    
    /// 16pt — Caption-level icons, secondary actions, metadata
    static let sm: CGFloat = 16
    
    /// 20pt — Standard icons: navigation items, list rows, toolbar
    static let md: CGFloat = 20
    
    /// 24pt — Primary action icons: toolbar buttons, prominent controls
    static let lg: CGFloat = 24
    
    /// 32pt — Feature/hero icons: empty state, section headers
    static let xl: CGFloat = 32
    
    /// 48pt — Display icons: onboarding illustrations, splash
    static let xxl: CGFloat = 48
}

// MARK: - Icon Spacing Tokens

/// Spacing between icons and adjacent content
enum OneraIconSpacing {
    
    /// 4pt — Tight icon-to-text: inline badges, compact chips
    static let xs: CGFloat = 4
    
    /// 8pt — Standard icon-to-text: buttons, nav items, list rows
    static let sm: CGFloat = 8
    
    /// 12pt — Generous icon-to-text: section headers, feature rows
    static let md: CGFloat = 12
}

// MARK: - Scaled Icon Sizes (Accessibility)

/// @ScaledMetric versions of icon sizes for Dynamic Type support.
/// Use in views where icons should grow with the user's text size preference.
struct ScaledIconSizes {
    @ScaledMetric(relativeTo: .caption2) var xs: CGFloat = 14
    @ScaledMetric(relativeTo: .caption) var sm: CGFloat = 16
    @ScaledMetric(relativeTo: .body) var md: CGFloat = 20
    @ScaledMetric(relativeTo: .body) var lg: CGFloat = 24
    @ScaledMetric(relativeTo: .title) var xl: CGFloat = 32
    @ScaledMetric(relativeTo: .largeTitle) var xxl: CGFloat = 48
    
    init() {}
}

// MARK: - Hugeicons Icon Names

/// Semantic icon mapping for the Onera app.
///
/// Each case maps to a Hugeicons icon name.
/// Use `.stroke` for default/inactive state and `.solid` for active/selected state.
///
/// Usage:
///     OneraIcon.send.image          // Stroke variant (default)
///     OneraIcon.send.solidImage     // Solid variant (active)
///     OneraIcon.send.image(size: .lg)  // With explicit size
///
enum OneraIcon: String, CaseIterable {
    
    // MARK: - Navigation
    case sidebar = "sidebar-left"
    case search = "search-01"
    case settings = "settings-01"
    case home = "home-01"
    case back = "arrow-left-01"
    case forward = "arrow-right-02"
    case chevronRight = "chevron-right"
    case chevronDown = "chevron-down"
    case chevronUp = "chevron-up"
    case more = "more-horizontal"
    
    // MARK: - Chat
    case chat = "bubble-chat"
    case chatAdd = "bubble-chat-add"
    case send = "sent"
    case stop = "stop"
    case mic = "mic-01"
    case micOff = "mic-off-01"
    case speaker = "volume-high"
    case speakerOff = "volume-off"
    case regenerate = "refresh"
    case edit = "edit-02"
    case copy = "copy-01"
    case paste = "clipboard"
    case branchPrev = "arrow-left-02"
    case branchNext = "arrow-right-03"
    case brain = "brain-02"
    case sparkle = "stars-02"
    case globe = "globe-02"
    
    // MARK: - Content
    case note = "note-01"
    case noteAdd = "note-add"
    case document = "file-02"
    case code = "source-code"
    case textAlign = "text"
    case quote = "quote-down"
    case prompt = "command"
    case link = "link-01"
    case photo = "image-01"
    case camera = "camera-01"
    case attachment = "attachment-01"
    
    // MARK: - Organization
    case folder = "folder-01"
    case folderAdd = "folder-add"
    case pin = "pin"
    case pinOff = "pin-off"
    case archive = "archive"
    case trash = "delete-02"
    case filter = "filter"
    case sort = "sort-by-down-02"
    case tag = "tag-01"
    
    // MARK: - Actions
    case plus = "add-01"
    case close = "cancel-01"
    case closeFilled = "cancel-circle"
    case check = "checkmark-circle-02"
    case checkSimple = "tick-02"
    case download = "download-02"
    case share = "share-08"
    case expand = "arrow-expand"
    case collapse = "arrow-shrink"
    
    // MARK: - User & Auth
    case user = "user"
    case userCircle = "user-circle"
    case login = "login-01"
    case logout = "logout-01"
    case key = "key-01"
    case passkey = "finger-print"
    case lock = "lock"
    case lockOpen = "lock-unlocked"
    case shield = "shield-01"
    case shieldCheck = "shield-tick"
    
    // MARK: - System
    case info = "information-circle"
    case warning = "alert-02"
    case error = "alert-circle"
    case success = "checkmark-circle-01"
    case loading = "loading-01"
    case paintbrush = "paint-board"
    case sun = "sun-03"
    case moon = "moon-02"
    case device = "laptop-phone"
    case watch = "watch-01"
    case keyboard = "keyboard"
    
    // MARK: - Formatting (Rich Text Editor)
    case bold = "text-bold"
    case italic = "text-italic"
    case strikethrough = "text-strikethrough"
    case heading = "heading"
    case listBullet = "bullet-list"
    case listNumber = "number-list"
    case listCheck = "task-01"
    case codeBlock = "source-code-square"
    case paragraph = "text-wrap"
    
    // MARK: - Time & Status
    case clock = "clock-01"
    case calendar = "calendar-01"
    case verified = "seal-check"
    case lightbulb = "idea-01"
    case update = "upload-circle-02"
    
    // MARK: - Devices & Platform
    case cloud = "cloud"
    case icloud = "cloud-upload"
    case window = "browser"
    case openExternal = "link-square-02"
    case openInApp = "arrow-up-right"
    case saveLocal = "download-square-02"
    case inbox = "inbox-01"
    
    // MARK: - Drawing
    case undo = "undo-01"
    case redo = "redo-01"
    case draw = "pencil-edit-01"
    
    // MARK: - Mentions & Inline
    case mention = "at"
    
    // MARK: - Security & Auth Detail
    case eye = "eye"
    case eyeOff = "eye-off"
    case passkeySolid = "finger-print-scan"
    case faceId = "face-id"
    case shieldAlert = "shield-alert"
    case shieldVerified = "shield-check"
    case encryptedDoc = "file-security"
    case scanKey = "scan"
    case manualEntry = "note-edit"
    case recoveryGrid = "grid"
    case securityShield = "security-check"
    case devicePhone = "smart-phone-01"
    case deviceLaptop = "laptop"
    
    // MARK: - Chat Variants
    case chatFilled = "bubble-chat-favourite"
    case chatWithText = "bubble-chat-translate"
    case sidebarExpanded = "sidebar-left-01"
    
    // MARK: - More/Overflow Menu
    case ellipsis = "more-horizontal-circle-01"
    case ellipsisCircle = "more-horizontal-circle-02"
    
    // MARK: - Settings
    case slider = "preference-horizontal"
    case tool = "wrench"
    case audio = "headphones"
    case appearance = "palette"
    case density = "paragraph-spacing"
    case privacy = "hand-pointing-right"
    case terms = "file-validation"
    
    // MARK: - Apple (keep SF Symbols for Apple branding)
    // Apple logo and FaceID must remain as SF Symbols per Apple guidelines
    
    /// The Hugeicons asset name for the stroke variant.
    /// When you add Hugeicons SVGs to Assets.xcassets, name them
    /// with a "hugeicon-" prefix, e.g. "hugeicon-sidebar-left".
    var strokeAssetName: String { "hugeicon-\(rawValue)" }
    
    /// The Hugeicons asset name for the solid variant.
    var solidAssetName: String { "hugeicon-\(rawValue)-solid" }
    
    /// Whether to use Hugeicons asset catalog or SF Symbol fallbacks.
    /// Flip this to `true` once Hugeicons SVGs are added to Assets.xcassets.
    private static let useHugeicons = false
    
    /// Create an Image view using the stroke variant (default state).
    /// Tries Hugeicons asset catalog first, falls back to SF Symbol.
    var image: Image {
        if Self.useHugeicons {
            return Image(strokeAssetName)
        }
        return Image(systemName: sfSymbolFallback)
    }
    
    /// Create an Image view using the solid variant (active/selected state).
    var solidImage: Image {
        if Self.useHugeicons {
            return Image(solidAssetName)
        }
        return Image(systemName: sfSymbolFallbackFilled)
    }
    
    /// Render icon at a specific size
    func image(size: CGFloat) -> some View {
        image
            .font(.system(size: size))
    }
    
    /// Render solid icon at a specific size
    func solidImage(size: CGFloat) -> some View {
        solidImage
            .font(.system(size: size))
    }
    
    // MARK: - SF Symbol Fallbacks
    // Used until Hugeicons SPM package is integrated.
    // Maps each semantic icon to its closest SF Symbol equivalent.
    
    private var sfSymbolFallback: String {
        switch self {
        // Navigation
        case .sidebar: return "sidebar.leading"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape"
        case .home: return "house"
        case .back: return "chevron.left"
        case .forward: return "chevron.right"
        case .chevronRight: return "chevron.right"
        case .chevronDown: return "chevron.down"
        case .chevronUp: return "chevron.up"
        case .more: return "ellipsis"
            
        // Chat
        case .chat: return "bubble.left.and.bubble.right"
        case .chatAdd: return "square.and.pencil"
        case .send: return "arrow.up"
        case .stop: return "stop.fill"
        case .mic: return "mic.fill"
        case .micOff: return "mic.slash"
        case .speaker: return "speaker.wave.2"
        case .speakerOff: return "speaker.slash"
        case .regenerate: return "arrow.clockwise"
        case .edit: return "pencil"
        case .copy: return "doc.on.doc"
        case .paste: return "clipboard"
        case .branchPrev: return "chevron.left"
        case .branchNext: return "chevron.right"
        case .brain: return "brain"
        case .sparkle: return "sparkles"
        case .globe: return "globe"
            
        // Content
        case .note: return "note.text"
        case .noteAdd: return "note.text.badge.plus"
        case .document: return "doc.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .textAlign: return "text.alignleft"
        case .quote: return "text.quote"
        case .prompt: return "text.quote"
        case .link: return "link"
        case .photo: return "photo"
        case .camera: return "camera"
        case .attachment: return "paperclip"
            
        // Organization
        case .folder: return "folder"
        case .folderAdd: return "folder.badge.plus"
        case .pin: return "pin"
        case .pinOff: return "pin.slash"
        case .archive: return "archivebox"
        case .trash: return "trash"
        case .filter: return "line.3.horizontal.decrease"
        case .sort: return "arrow.up.arrow.down"
        case .tag: return "tag"
            
        // Actions
        case .plus: return "plus"
        case .close: return "xmark"
        case .closeFilled: return "xmark.circle.fill"
        case .check: return "checkmark.circle"
        case .checkSimple: return "checkmark"
        case .download: return "arrow.down.to.line"
        case .share: return "square.and.arrow.up"
        case .expand: return "arrow.up.left.and.arrow.down.right"
        case .collapse: return "arrow.down.right.and.arrow.up.left"
            
        // User & Auth
        case .user: return "person"
        case .userCircle: return "person.circle"
        case .login: return "rectangle.portrait.and.arrow.forward"
        case .logout: return "rectangle.portrait.and.arrow.right"
        case .key: return "key.horizontal"
        case .passkey: return "person.badge.key"
        case .lock: return "lock.fill"
        case .lockOpen: return "lock.open"
        case .shield: return "lock.shield"
        case .shieldCheck: return "lock.shield.fill"
            
        // System
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "exclamationmark.circle"
        case .success: return "checkmark.circle.fill"
        case .loading: return "arrow.2.circlepath"
        case .paintbrush: return "paintbrush"
        case .sun: return "sun.max"
        case .moon: return "moon"
        case .device: return "laptopcomputer.and.iphone"
        case .watch: return "applewatch"
        case .keyboard: return "keyboard"
            
        // Formatting
        case .bold: return "bold"
        case .italic: return "italic"
        case .strikethrough: return "strikethrough"
        case .heading: return "number"
        case .listBullet: return "list.bullet"
        case .listNumber: return "list.number"
        case .listCheck: return "checklist"
        case .codeBlock: return "chevron.left.forwardslash.chevron.right"
        case .paragraph: return "text.page"
            
        // Time & Status
        case .clock: return "clock"
        case .calendar: return "calendar"
        case .verified: return "checkmark.seal.fill"
        case .lightbulb: return "lightbulb"
        case .update: return "arrow.up.circle.fill"
            
        // Devices & Platform
        case .cloud: return "cloud.fill"
        case .icloud: return "icloud"
        case .window: return "macwindow"
        case .openExternal: return "arrow.up.right.square"
        case .openInApp: return "arrow.up.forward.app"
        case .saveLocal: return "square.and.arrow.down"
        case .inbox: return "tray"
            
        // Drawing
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .draw: return "pencil.tip.crop.circle"
            
        // Mentions
        case .mention: return "at"
            
        // Security & Auth Detail
        case .eye: return "eye"
        case .eyeOff: return "eye.slash"
        case .passkeySolid: return "person.badge.key.fill"
        case .faceId: return "faceid"
        case .shieldAlert: return "exclamationmark.shield.fill"
        case .shieldVerified: return "checkmark.shield.fill"
        case .encryptedDoc: return "lock.doc.fill"
        case .scanKey: return "key.viewfinder"
        case .manualEntry: return "pencil.and.list.clipboard"
        case .recoveryGrid: return "rectangle.grid.3x2"
        case .securityShield: return "shield.checkered"
        case .devicePhone: return "iphone"
        case .deviceLaptop: return "laptopcomputer"
            
        // Chat Variants
        case .chatFilled: return "bubble.left.fill"
        case .chatWithText: return "bubble.left.and.text.bubble.right"
        case .sidebarExpanded: return "sidebar.squares.leading"
            
        // More/Overflow Menu
        case .ellipsis: return "ellipsis"
        case .ellipsisCircle: return "ellipsis.circle"
            
        // Settings
        case .slider: return "slider.horizontal.3"
        case .tool: return "wrench.and.screwdriver"
        case .audio: return "speaker.wave.2"
        case .appearance: return "paintbrush"
        case .density: return "text.line.spacing"
        case .privacy: return "hand.raised"
        case .terms: return "doc.text"
        }
    }
    
    private var sfSymbolFallbackFilled: String {
        let base = sfSymbolFallback
        // For many SF Symbols, the .fill variant is the name + ".fill"
        // but not all have .fill variants, so we handle specific cases
        switch self {
        case .folder: return "folder.fill"
        case .note: return "note.text"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .user: return "person.fill"
        case .userCircle: return "person.circle.fill"
        case .lock: return "lock.fill"
        case .lockOpen: return "lock.open.fill"
        case .shield: return "lock.shield.fill"
        case .shieldCheck: return "lock.shield.fill"
        case .pin: return "pin.fill"
        case .archive: return "archivebox.fill"
        case .trash: return "trash.fill"
        case .mic: return "mic.fill"
        case .speaker: return "speaker.wave.2.fill"
        case .home: return "house.fill"
        case .check: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "exclamationmark.circle.fill"
        case .document: return "doc.fill"
        case .key: return "key.horizontal.fill"
        case .settings: return "gearshape.fill"
        case .sun: return "sun.max.fill"
        case .moon: return "moon.fill"
        default: return base
        }
    }
}

// MARK: - Icon View Helper

/// Convenience view that renders an Onera icon at a standard size
struct IconView: View {
    let icon: OneraIcon
    var size: CGFloat = OneraIconSize.md
    var isFilled: Bool = false
    
    var body: some View {
        (isFilled ? icon.solidImage : icon.image)
            .font(.system(size: size * 0.75)) // SF Symbol sizing compensation
            .frame(width: size, height: size)
    }
}

// MARK: - View Extension

extension View {
    /// Set a standard icon frame size using icon tokens
    func iconFrame(_ size: CGFloat = OneraIconSize.md) -> some View {
        self.frame(width: size, height: size)
    }
}
