# Molly v1 frozen specification

Authoritative conversational context lives in the Cursor plan artifact; this file is the **repo-hosted implementation snapshot** extracted for engineers who only clone `/workspace`.

## v1 frozen spec sheet (**baseline for Xcode implementation**)

Questionnaire-plus-planner backlog translated for engineering. Closed-lid / agent-heavy scenarios stay **best effort under macOS + hardware**.

### Locked product framing

| Field | Freeze |
|---|---|
| Elevator sentence | Helping developer Macs keep working through long agent jobs with **lid closed / display asleep** wherever macOS allows. |
| Hotspot pillar | Secondary **Connectivity** lane layered to trim **idle hotspot Wi‑Fi drops**, nothing stronger than honest best-effort language. |
| Audience | Terminal-comfy peers; UX still hides **CLI requirements** (`caffeinate` never part of onboarding). |

### SKU matrix (**`fork_helpers_ok`**)

| SKU | Packaging | Connectivity lane expectation |
|---|---|---|
| `Molly.direct` | Developer ID + **Sparkle** auto-updates | Full ladder: routed IPv4 default gateway probe plus HTTPS/TCP fallback; optional ICMP/privileged helper tracked as backlog item only after TCP path stable. Label advanced capabilities in Settings. |
| `Molly.mas` | Mac App Store sandbox | Same awake lane parity; Connectivity ships **sandbox-safe** transports only (ICMP helper **off** v1). In-app SKU comparison rows explain gaps. |

### Release engineering constraints

| Item | Freeze |
|---|---|
| macOS floor | **14.0 Sonoma+** baseline. |
| Source visibility | **`closed_private` v1** with explicit privacy/export docs and optional roadmap to selectively open Networking/Power modules later. |

### Independent lane state machines

| Lane | Intent | Behavioral notes |
|---|---|---|
| **Awake** | Block idle-class sleep disruptions for agent workloads while **display may sleep**. | Driven by IOPowerAssertions / `ProcessInfo.performExpiringActivity`/activity tokens finalized during coding spike. Never implicitly toggled by lid open/close. |
| **Connectivity** | When armed, jittered probes keep network stack exercised to reduce idle hotspot disconnect symptom. | Start/stop tied to lane toggle + aggregated timer linkage (see timers). Respect `NWPath` unsatisfied states; backoff on repeated failures. |

**Timers:** Provide countdown auto-off presets (**30 m / 2 h / 4 h / custom**) for Awake lane. Optional **mirror timer** checkbox (default **on** whenever Connectivity enabled simultaneously) aligns shutdown of both lanes to reduce surprise background probes.

### Awake presets (v1 roster)

| ID | Summary |
|---|---|
| `agents.closed_lid.display_sleep_ok` (**default**) | Ships set-and-forget behavior described above. |
| _(Future)_ | Additional presets wait for instrumentation after MVP soak; document extension hook in-engineering notes. |

**No shipping “never let display sleep” mode** (per Q10 **`not_needed`**).

### Connectivity probe ladder (**planner numerical defaults baked in**)

| Stage | Transport | Timing | Detail |
|---|---|---|---|
| A | Routable IPv4 default gateway handshake (TCP `:443` connect or HTTPS `HEAD`) | Mean **120 s**, stochastic **±25 % jitter** per cycle | Prefer single-digit KB frames; escalate logging before multiplying frequency. |
| B | Fallback HTTPS HEAD to resilient public endpoint list curated in-repo (e.g., operator-neutral stable hosts avoiding captive pitfalls) after repeated stage A misses. |

ICMP / privileged pings sit behind **direct-SKU backlog** gated on helper design review.

Low Power interplay: Insights injects unobtrusive badge referencing `ProcessInfo.isLowPowerModeEnabled` reminding radios may throttle sooner.

### Menu bar `NSMenu` skeleton

| Cluster | Entries |
|---|---|
| Presence | Lightweight status line summarizing awake/connectivity booleans plus remaining timer. |
| Controls | Toggle Awake, Toggle Connectivity, Timer submenu (reuse preset list). |
| Navigation | Show Dashboard window… (**⌘0** tentative). |
| Help | Offline privacy blurb linking to Logs export FAQ. |
| Quit | Quit Molly (**⌘Q**). |

### Dashboard (`NavigationSplitView`) page obligations

| Section | Mandatory UI |
|---|---|
| Session | Awake lane controls + timer UX + succinct limitations copy anchored to questionnaire row 12/35. |
| Connectivity | Connectivity controls, rolling counters (success streak, fail streak), next probe ETA, LPM contextual chip. |
| Insights | Consolidated KPI + qualitative route summary referencing VPN/routing parity decision Q25. |
| Logs | Structured local rolling log (JSONL), configurable retention default **7d**, `.zip` export. |
| Settings | Launch at login toggle, SKU capability parity table (MAS vs Direct), Sparkle channel (direct), notification switches, Appearance token previews (no hard-coded palette literals). |
| About | Credits, redistribution notices, probing privacy affirmation (no outbound analytics v1—per Q38). |

### Notification policy

| Situation | Rule |
|---|---|
| Timer expires gracefully | Notify once summarizing lanes disabled. |
| Connectivity ≥**5** consecutive probe failures spanning **≥3 min** wall | Notify at most once per rolling **60 min** unless user clears alert state. |

### Explicit v1 non-goals

Cross-editor “agents finished detection,” calendars, differentiated battery confirmations, kiosk display pinning, undocumented CLI dependency.

### MVP acceptance shorthand

Awake preset survives scripted **≥60 min** workload soak with display sleeping on Apple Silicon notebook (manual QA). Connectivity lane exhibits measurably lower idle-disconnect tally vs control in scripted hotspot soak (publish repro steps). SKU builds compile & sign—even if CI host here lacks Xcode binaries.

---
