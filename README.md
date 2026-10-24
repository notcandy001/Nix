# Nix

Nix is a privacy-first, customizable browser project. The current prototype explores a native macOS browsing experience using SwiftUI and WebKit, with a Rust core planned for reusable privacy and filtering logic.

## Purpose

The goal is to build a browser that gives users control over tracking, page clutter, browser layout, and site-specific behavior without sacrificing a polished native experience.

## Why this is being built

- Learn and implement native macOS browser architecture with SwiftUI, AppKit, and WKWebView.
- Build a portable Rust core for URL cleaning and content-filter rule compilation.
- Add privacy protections that are transparent and user-configurable.
- Explore a customizable browser interface with a native macOS look and feel.
- Keep platform-specific rendering behind an adapter boundary so other platforms can be considered later.

## Current prototype

- Native macOS window and WebKit page rendering.
- Basic tab creation, switching, closing, address/search field, and navigation controls.
- Safari-inspired top toolbar and glass-like tab surfaces using system materials.
- Initial Rust ABP-subset parser and WebKit JSON emitter, not yet connected to the app.

## Important status

This is an early development prototype. The Shields UI is not yet enforcing blocking rules; Rust-to-Swift integration, full filter-list compatibility, persistence, sync, and iOS support are not implemented. Build and test on macOS with Xcode before relying on any feature.

## Build

Open `apps/Nix.xcodeproj` in Xcode, choose the Nix scheme and **My Mac**, then press `⌘R`.

Rust core tests can be run from the repository root where Rust is installed:

```sh
cargo test --workspace
```

