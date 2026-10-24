# Nix design principles

1. Native first: SwiftUI, AppKit, UIKit, SF Symbols, system materials, standard menus and focus behavior.
2. Quiet by default: familiar browser chrome, restrained colors, no decorative gradients, customization behind progressive disclosure.
3. Privacy is visible: show protection state clearly; do not imply a feature is active before it is wired and tested.
4. Accessibility is a feature: VoiceOver labels, keyboard navigation, Dynamic Type, reduced motion, and high contrast.
5. Motion follows the platform: interruptible, purposeful, and disabled or reduced when the system requests it.
6. Consistency across platforms: share Rust policy logic, not platform-specific UI assumptions.
7. Security through boundaries: page code stays in WebKit; native message handlers use strict schemas.
8. Every UI slice gets a Safari/Settings comparison and a documented deviation list.
