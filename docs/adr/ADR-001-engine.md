# ADR-001: Browser rendering engine

- **Status:** Accepted for Apple v1; revisit cross-platform implementation before Phase 4.
- **Date:** 2026-10-24

## Context
Apple App Store browsers on iOS/iPadOS must use WebKit under the applicable platform rules. Sharing an engine between macOS and iOS also lowers maintenance cost.

## Decision
Use WKWebView on macOS and iOS/iPadOS for v1. Keep engine-specific code behind `EngineAdapter`; page content remains inside WebKit's web-content process. The Rust core must not depend on WebKit types. For non-Apple platforms, evaluate Chromium/CEF or Gecko as separate adapters without changing portable rule and privacy logic.

## Options considered

| Option | Complexity | Cost | Scalability | Familiarity |
|---|---:|---:|---|---|
| WebKit on Apple | Low | Low | Apple-first | High |
| Chromium on every platform | High; not valid for iOS App Store path | High | Broad | High |
| Gecko on Apple and others | High | High | Broad but integration-heavy | Medium |

## Trade-offs
WebKit has platform limits: content blocker APIs do not expose all Chromium internals, and extension compatibility is not universal. We gain native integration and lower initial footprint but must document feature gaps.

## Consequences
- All Apple pages render in WKWebView.
- `EngineAdapter` is the boundary for future engines.
- No Chromium is embedded in iOS.

## Action items
- [x] Add `EngineAdapter` protocol.
- [ ] Validate current App Store rules before iOS submission.
- [ ] Maintain `docs/LIMITATIONS.md`.
