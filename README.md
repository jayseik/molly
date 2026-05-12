# Molly

Native macOS menu bar + dashboard app: **Awake** lane (IOPower idle-sleep assertions, display may sleep) and optional **Connectivity** lane (jittered gateway TCP + HTTPS `HEAD` fallbacks for hotspot idle drops). Product intent and acceptance shorthand are in [`spec/molly-v1-frozen-spec.md`](spec/molly-v1-frozen-spec.md).

## Build (macOS 14+)

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. From the repo root run `xcodegen generate`.
3. Open `Molly.xcodeproj`, select the **Molly** scheme, and run.

`project.yml` passes `-D MOLLY_SKU_DIRECT` so the bundle is configured for **direct/Developer ID** distribution (not Mac App Store). Release builds are constrained to **`arm64` only** (Apple Silicon installers). Debug still follows the active architecture for day-to-day work on Intel or Apple Silicon.

## Direct install for Apple Silicon (Developer ID)

Use this flow when you are **not** shipping through the Mac App Store: archive, export as `developer-id`, then notarize the zip or stapler the `.app`.

1. Ensure Xcode is logged into an Apple ID that has **Developer ID Application** certificates and appropriate team access.

2. One-shot script (recommended after Xcode can sign Molly successfully from the GUI once):

```bash
chmod +x Scripts/build-direct-arm64.sh   # once
./Scripts/build-direct-arm64.sh
```

This runs `xcodegen generate`, creates a **Release archive** targeting **arm64**, exports a signed **`dist/export/Molly.app`** using [`Supporting/ExportOptions-direct-developer-id.plist`](Supporting/ExportOptions-direct-developer-id.plist), and zips **`dist/Molly-<version>-arm64-direct.zip`** for Hosting + `notarytool submit`.

If automatic export fails because you have multiple teams, open the plist (or Xcode Organizer) and set the signing team **Developer ID Application** explicitly, or duplicate the plist and point `Scripts/build-direct-arm64.sh` at your variant.

**Notarize** before asking others to download (Gatekeeper). Apple documents `notarytool` and stapler; the script echoes example commands when it finishes.

On GitHub, the workflow [.github/workflows/verify-macos-build.yml](.github/workflows/verify-macos-build.yml) smoke-builds Release `arm64` with **ad hoc** signing and uploads **`Molly.app`** as an artifact; use that ZIP for sanity checks only, **not** as a substitute for Developer ID signing plus notarization.

**Mac App Store later:** remove `-D MOLLY_SKU_DIRECT` from [`project.yml`](project.yml), switch entitlements/signing for App Store distribution, and **drop or override** Release `ARCHS` (store builds are often universal or follow Xcode defaults).

## Layout

- [`Sources/MollyApp/`](Sources/MollyApp/) — SwiftUI dashboard, `NSStatusItem` menu, `ConnectivityLaneEngine`, `AwakeLanePowerManager`, JSONL log store.
- [`Supporting/MollySandbox.entitlements`](Supporting/MollySandbox.entitlements) — sandbox template (outbound network + user-selected export).
- [`Supporting/Assets.xcassets`](Supporting/Assets.xcassets) — accent color asset for Xcode.
- [`Scripts/build-direct-arm64.sh`](Scripts/build-direct-arm64.sh) — Apple Silicon Developer ID archive + export + zip.