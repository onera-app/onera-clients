# Changelog

All notable changes to Onera will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2026-02-06

### Fixed
- Added LSApplicationCategoryType for Mac App Store compliance (ITMS-90242)
- Added ITSAppUsesNonExemptEncryption to bypass export compliance dialog

## [1.0.1] - 2026-02-06

### Fixed
- iPad model selector now opens properly (was a non-functional button)
- Chat messages left-aligned on iPad instead of centered during streaming
- Microphone crash fixed - app now properly requests mic and speech recognition permissions
- Camera permission added to Info.plist to prevent crash on photo capture
- Speech recognition stop button now correctly places transcribed text in input field
- Sidebar selection highlight on iPad uses rounded corners instead of clipped rectangles
- Duplicate sidebar buttons on iPad reduced to a single toggle
- Toolbar no longer overlaps window controls in Stage Manager multitasking

### Added
- Send button changes color to accent when active, muted when disabled
- macOS sandbox entitlements for audio input and camera
- PrivacyInfo.xcprivacy for App Store compliance
- Xcode Cloud CI/CD pipeline with tag-triggered builds
- App Store metadata files in repository
- CHANGELOG.md for version tracking
- Shared Xcode schemes for Onera and watchOS targets

### Changed
- Updated all sub-agent models to Claude Opus 4.6
- Updated xcconfig example files with correct bundle IDs and missing keys

## [1.0.0] - 2025-02-06

### Added
- End-to-end encrypted AI chat with multiple model providers
- Support for OpenAI, Anthropic, Google, Mistral, Groq, DeepSeek, xAI, and more
- Voice input with speech-to-text
- Photo and file attachments in conversations
- Folder organization for chats
- Notes feature for quick reference
- Rich markdown rendering with syntax highlighting
- Response branching and regeneration
- Text-to-speech for assistant messages
- Passkey authentication with Face ID / Touch ID
- Private inference with Trusted Execution Environments (TEE)
- iPad split view with 3-column navigation
- macOS native app with sidebar and keyboard shortcuts
- Apple Watch companion app with quick replies
- Cross-device sync
