# Nix initial STRIDE threat model (draft)

**Status:** Draft; must be reviewed before shipping. Scope: macOS v0 with WKWebView and local Rust filter compiler.

| Threat | Asset / trust boundary | Example | Initial mitigations | Remaining work |
|---|---|---|---|---|
| Spoofing | Site identity / navigation | Phishing site imitates login | Show canonical host; HTTPS indicators | Safe Browsing provider and IDN review |
| Tampering | Filter lists and user rules | Malicious list uses pathological patterns | Size limits, parser warnings, no arbitrary execution | Fuzz parser; signature/update policy |
| Repudiation | Local user actions | User cannot tell why a request was blocked | Local Shields event counters where feasible | Auditable explanation UI without URL telemetry |
| Information disclosure | History, cookies, sync | Private data leaks through logs or crash reports | No telemetry by default; nonpersistent private store | Verify all logs, caches, crash paths |
| Denial of service | Renderer / compiler | Huge filter list or expensive regex | Input limits; compile off main thread; WebKit process isolation | Fuzzing, performance budgets, rule caps |
| Elevation of privilege | WKScriptMessageHandler / user scripts | Page sends malformed message or escapes sandbox | Strict schemas; no privileged generic bridge; no eval in app shell | Audit every handler and extension API |

## Trust boundaries
1. Web page ↔ WebKit web-content process.
2. WebKit ↔ native shell navigation/delegate callbacks.
3. Rust parser ↔ downloaded filter-list text.
4. App process ↔ local database/Keychain.
5. App ↔ CloudKit transport (future).

## Non-negotiable controls
- Never execute page-supplied code in the app process.
- Treat filter lists, imported rules, themes, and extensions as untrusted.
- Private tabs use `WKWebsiteDataStore.nonPersistent()` and must not write history.
- No analytics or query logging by default.
- Secrets and signing material must never be committed.
