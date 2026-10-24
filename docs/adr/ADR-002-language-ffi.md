# ADR-002: Swift shell and portable Rust core

- **Status:** Accepted
- **Date:** 2026-10-24

## Context
Apple UX needs native SwiftUI/AppKit/UIKit while filtering, URL cleaning, ranking clients, and sync cryptographic orchestration should be reusable.

## Decision
Use Swift/SwiftUI for app shell and WebKit integration. Use Rust crates for portable core logic. Start with a versioned C ABI boundary; evaluate UniFFI after API shapes stabilize. Never pass raw page objects across FFI. All inputs crossing FFI are length-bounded UTF-8/byte buffers with explicit ownership and error codes.

## Options considered

| Option | Complexity | Cost | Scalability | Familiarity |
|---|---:|---:|---|---|
| All Swift | Low initially | Low | Limited reuse | High |
| All Rust + web UI | Medium | Medium | Broad | Medium |
| Swift shell + Rust core | Medium | Medium | High | High |

## Trade-offs
FFI adds build and memory-ownership complexity. Rust reduces some memory-safety risks but does not make parsing, policy, or FFI automatically safe.

## Consequences
- `crates/core-shields` is the first portable crate.
- Swift must never assume Rust strings are NUL-terminated unless the ABI says so.
- FFI APIs require fuzzing and ownership tests before production.

## Action items
- [ ] Add C ABI crate and generated header.
- [ ] Add UniFFI spike after initial Rust API stabilizes.
