# Known limitations

- `core-shields` supports only a conservative subset of ABP syntax. It is not full EasyList/uBlock Origin compatibility.
- The Swift shell does not yet call the Rust crate through FFI.
- The Shields panel is a visual stub; no blocking counter is currently authoritative.
- No downloaded filter list is bundled. Add list source, license, pinned revision, and update policy before integration.
- Cosmetic rules are parsed but not yet injected into WKWebView.
- URL cleaning is implemented in Rust but not yet connected to navigation.
- No sync, password manager, Safe Browsing, anti-fingerprinting farbling, cookie-banner automation, extension host, or iOS target exists yet.
- Private mode currently selects a nonpersistent WebKit data store when a private tab is constructed; private-tab UI and no-history guarantees need dedicated tests.
- The 400 ms startup and 100 ms rule compilation budgets are targets, not measured results.
- No macOS build was run in this generation environment.
