# Progress

## Done in scaffold
- [x] ADR-001 engine
- [x] ADR-002 Swift/Rust boundary direction
- [x] ADR-003 storage/sync direction
- [x] ADR-004 blocking strategy
- [x] Initial STRIDE threat-model draft
- [x] Design principles and limitations
- [x] Rust ABP-subset parser, WebKit JSON emitter, URL tracking-parameter cleaner, unit tests
- [x] Native SwiftUI macOS shell source with tabs, address bar, navigation buttons, WKWebView per tab, Shields stub
- [x] EngineAdapter protocol and WebKit adapter
- [x] Starter GitHub Actions workflow

## Next
1. Run `cargo test --workspace` and fix any platform/toolchain findings.
2. Create/open the Xcode project on macOS and compile the shell.
3. Add a versioned C ABI/UniFFI bridge and wire Rust output into `WKContentRuleListStore`.
4. Add licensed, pinned filter-list fixtures, golden corpus tests, rule splitting, and compiler limits.
5. Implement cosmetic filtering and per-site Shields state with privacy tests.

## Blocked / not verified
- macOS compilation and UI testing require Apple toolchain.
- Full EasyList compatibility requires broader parser coverage and corpus validation.
- iOS app target, sync, extension APIs, and cross-platform adapters are not implemented.
