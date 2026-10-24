# ADR-003: Local storage and end-to-end sync

- **Status:** Accepted direction; implementation deferred
- **Date:** 2026-10-24

## Context
Bookmarks, settings, rules, history, and tabs require local persistence. Sync should not reveal plaintext to a transport provider.

## Decision
Use SQLite for structured local data; use platform file protection on iOS and Keychain for secrets. Evaluate SQLCipher before storing sensitive browsing history. Use CloudKit as the first Apple-only transport, but encrypt sync payloads with a versioned, independently generated user-controlled key before upload. Never claim E2E encryption until key lifecycle, recovery, device enrollment, and metadata leakage are reviewed.

## Options considered

| Option | Complexity | Cost | Scalability | Familiarity |
|---|---:|---:|---|---|
| Plain SQLite + iCloud | Low | Low | Medium | High |
| SQLCipher + encrypted CloudKit payloads | Medium | Low-to-medium | High | Medium |
| Self-hosted relay from day one | High | Medium-to-high | High | Medium |

## Trade-offs
CloudKit reduces server operations but ties v1 sync to Apple. E2E encryption complicates recovery and multi-device onboarding. Metadata may still be visible to the transport.

## Consequences
- Sync is not in the first macOS slice.
- Never store secrets in source control.
- History sync is opt-in.

## Action items
- [ ] Define schema and migrations.
- [ ] Threat-model recovery and device revocation.
- [ ] Review cryptographic design before enabling sync.
