---
name: ios-swiftui-mvvm
description: Rules for building a modern iOS app using SwiftUI, MVVM, and Apple Human Interface Guidelines
---

# Overview

This project follows modern iOS development best practices using **SwiftUI**, **MVVM architecture**, and **Apple’s Human Interface Guidelines (HIG)**.  
All code should prioritize clarity, accessibility, performance, and testability.

---

# Architecture

- Use **MVVM (Model–View–ViewModel)** as the primary architecture.
- Views must be **stateless** and driven entirely by ViewModels.
- Business logic and state management belong in ViewModels, not Views.
- Use `ObservableObject` for ViewModels and `@Published` for state.
- Avoid fat ViewModels—extract logic into services when needed.

---

# UI & SwiftUI

- All new UI **must use SwiftUI**.
- Follow **Apple Human Interface Guidelines** for layout, spacing, typography, and interaction.
- Use system components (`NavigationStack`, `List`, `Form`, `Button`) before custom UI.
- Support **Dynamic Type**, **Dark Mode**, and **Accessibility** by default.
- Avoid hardcoded sizes—use adaptive layouts (`Spacer`, `LayoutPriority`, `GeometryReader` sparingly).

---

# State Management

- Use `@State` for local view state.
- Use `@StateObject` for ViewModel ownership.
- Use `@ObservedObject` only when injected from a parent.
- Prefer `@Environment` and `@EnvironmentObject` for app-wide dependencies.
- Keep state minimal and single‑source‑of‑truth.

---

# Models

- Prefer **structs over classes** for data models.
- Models should be immutable whenever possible.
- Conform to `Identifiable`, `Codable`, and `Equatable` when appropriate.
- Do not include business logic in models.

---

# Concurrency & Networking

- Use **Swift Concurrency (`async/await`)** for all asynchronous work.
- Avoid completion handlers unless required by legacy APIs.
- Mark UI‑updating ViewModels with `@MainActor`.
- Handle errors explicitly and expose user‑friendly error states.

---

# Performance

- Use `lazy var` for **expensive computed properties** in classes.
- Avoid unnecessary view recomputation—break large views into smaller ones.
- Prefer value types and avoid reference cycles (`[weak self]` when needed).

---

# Navigation

- Use `NavigationStack` with strongly typed navigation paths.
- Avoid navigation logic inside Views—delegate to ViewModels or Coordinators if needed.
- Keep navigation predictable and reversible.

---

# Testing

- ViewModels must be **unit testable** without SwiftUI dependencies.
- Use protocol‑based abstractions for services and networking.
- Prefer XCTest with clear Arrange–Act–Assert structure.

---

# Folder Structure

- `App/` – App entry point and root configuration
- `Features/` – Feature‑based grouping (View, ViewModel, Model)
- `Services/` – Networking, persistence, system services
- `Core/` – Shared utilities, extensions, design system
- `Resources/` – Assets, localization, fonts

---

# Code Style

- Follow Swift API Design Guidelines.
- Keep files focused and under ~300 lines when possible.
- Use meaningful naming—avoid abbreviations.
- Document complex logic with concise comments.

---

# Accessibility & Localization

- All user‑facing text must use `LocalizedStringKey`.
- Provide accessibility labels, hints, and traits.
- Ensure tappable areas meet minimum size requirements.

---

# Summary

Build for **clarity, accessibility, and scalability**.  
Let SwiftUI handle UI, MVVM handle state, and the system handle behavior wherever possible.