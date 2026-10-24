# Nix

Privacy-first, highly customizable browser. Initial target: macOS using SwiftUI/AppKit + WKWebView, with portable privacy logic in Rust.

## Current status

This repository is a foundation/scaffold, not a production-ready browser. The Rust `core-shields` crate parses a deliberately limited, documented subset of ABP rules and emits WebKit content-blocker JSON. The Swift macOS shell includes a native window, tabs, address field, navigation, per-tab `WKWebView`, and a Shields status panel. Full ABP/uBO compatibility, production list ingestion, hardened user scripts, sync, and the rest of the master specification remain future work.

## Requirements

- macOS 14+ (minimum OS policy is latest major minus one; update deployment target when validating the release target)
- Xcode with Swift 5.9+
- Rust stable toolchain and Cargo
- Git

## Build and test

```sh
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
open apps/Nix.xcodeproj
```

Open the Xcode project and run the `Nix` macOS scheme. This scaffold does not claim to have been built on macOS in this environment.

## Layout

- `apps/macos/` — SwiftUI macOS application source
- `packages/` — reserved for reusable Swift packages
- `crates/core-shields/` — portable ABP subset parser and WebKit JSON emitter
- `docs/adr/` — architecture decision records
- `docs/threat-model/` — initial STRIDE threat model
- `docs/design/` — design principles
- `docs/licenses/` — third-party list/license tracking
- `.github/workflows/` — Rust CI starter
