# Molly

Native macOS menu bar + dashboard app: **Awake** lane (IOPower idle-sleep assertions, display may sleep) and optional **Connectivity** lane (jittered gateway TCP + HTTPS `HEAD` fallbacks for hotspot idle drops). Product intent and acceptance shorthand are in [`spec/molly-v1-frozen-spec.md`](spec/molly-v1-frozen-spec.md).

## Build (macOS 14+)

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. From the repo root run `xcodegen generate`.
3. Open `Molly.xcodeproj`, select the **Molly** scheme, and run.

`project.yml` passes `-D MOLLY_SKU_DIRECT` so the UI labels the Developer ID SKU path. Strip that flag for Mac App Store archives and revise [`Supporting/MollySandbox.entitlements`](Supporting/MollySandbox.entitlements) (and signing) for your distribution.

## Layout

- [`Sources/MollyApp/`](Sources/MollyApp/) — SwiftUI dashboard, `NSStatusItem` menu, `ConnectivityLaneEngine`, `AwakeLanePowerManager`, JSONL log store.
- [`Supporting/MollySandbox.entitlements`](Supporting/MollySandbox.entitlements) — sandbox template (outbound network + user-selected export).
- [`Supporting/Assets.xcassets`](Supporting/Assets.xcassets) — accent color asset for Xcode.
