# ADR-004: Content blocking strategy

- **Status:** Accepted for v0 subset; full compatibility not claimed
- **Date:** 2026-10-24

## Context
WebKit provides `WKContentRuleList` compiled from Apple's content-blocker JSON and `WKUserScript` for document-start scripts. ABP/uBO syntax is much broader than WebKit's native rule schema.

## Decision
Build a Rust parser/compiler with explicit supported syntax, warnings for unsupported directives, deterministic output, golden tests, and rule-list chunking before production. Use WebKit network rules for supported requests and separately implement cosmetic CSS rules via tightly scoped document-start scripts. Downloaded lists are untrusted input and must be size-limited, parsed offline, validated, and updated atomically. Do not describe the initial subset as EasyList-compatible until a real corpus passes.

## Options considered

| Option | Complexity | Cost | Scalability | Familiarity |
|---|---:|---:|---|---|
| WebKit content rules | Medium | Low | Limited by WebKit constraints | High |
| Request interception in app | High; incomplete/fragile | Medium | Poor | Medium |
| Full Chromium extension engine | Not available in Apple v1 | High | High | High |

## Trade-offs
WebKit rules are fast and native but do not support all ABP features, procedural cosmetics, arbitrary scriptlets, or every uBO feature. Multiple rule lists require careful limit accounting.

## Consequences
- Rust crate reports unsupported syntax rather than silently accepting it.
- The first app Shields panel is explicitly a stub until the bridge is wired.
- Rule compiler limits must be tested against actual Apple OS versions.

## Action items
- [ ] Add real filter-list fixtures and license metadata.
- [ ] Implement content-rule list store bridge.
- [ ] Implement cosmetic rule handling and per-site exceptions.
- [ ] Measure rule limits on supported OS versions.
