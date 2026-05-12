import SwiftUI

struct MainDashboard: View {

    @ObservedObject var surface: MollySessionController

    @SceneStorage("molly.sidebar") private var selection: DetailPane = .session

    @Environment(\.colorScheme) private var scheme

    var body: some View {

        NavigationSplitView {

            List(DetailPane.allCases, selection: $selection) { pane in

                Label(pane.title, systemImage: pane.glyph)

                    .tag(pane)

            }

            .navigationTitle("Molly")

            .listStyle(.sidebar)

        } detail: {

            Group {

                switch selection {

                case .session:

                    SessionPane(surface: surface)

                case .connectivity:

                    ConnectivityPane(probes: surface.probes, pilot: surface)

                case .insights:

                    InsightPane(surface: surface)

                case .logs:

                    LogsPane(journal: surface.logs)

                case .settings:

                    SettingsPane(surface: surface)

                case .about:

                    AboutPane()

                }

            }

            .padding(20)

            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            .background(MollyTheme.ColorToken.background.resolve(for: scheme))

        }

    }

}

private enum DetailPane: String, CaseIterable, Identifiable {

    case session

    case connectivity

    case insights

    case logs

    case settings

    case about

    var id: String { rawValue }

    var title: String {

        switch self {

        case .session: return "Session"

        case .connectivity: return "Connectivity"

        case .insights: return "Insights"

        case .logs: return "Logs"

        case .settings: return "Settings"

        case .about: return "About"

        }

    }

    var glyph: String {

        switch self {

        case .session: return "dot.radiowaves.left.and.right"

        case .connectivity: return "antenna.radiowaves.left.and.right"

        case .insights: return "rectangle.grid.3x2"

        case .logs: return "text.alignleft"

        case .settings: return "gearshape"

        case .about: return "star.circle"

        }

    }

}

private struct SessionPane: View {

    @ObservedObject var surface: MollySessionController

    @Environment(\.colorScheme) private var scheme

    var body: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 18) {

                Text("Lanes")

                    .font(.largeTitle.bold())

                Text("""
                Molly never promises impossible lid states—everything here is bounded by hardware + thermal policy.
                What we do is articulate which sleep behaviors we're actively inhibiting.
                """)

                .foregroundStyle(.secondary)

                laneToggle(copy: "Awake lane inhibits idle sleeps while respecting display-off ergonomics",

                           active: surface.awakeEnabled) {

                    surface.toggleAwakeLane()

                }

                laneToggle(copy: "Connectivity lane adds sparse probes to coax idle hotspots to stay routed",

                           active: surface.connectivityEnabled) {

                    surface.toggleConnectivityLane()

                }

                timersCard

            }

            .frame(maxWidth: .infinity, alignment: .leading)

        }

    }

    private func laneToggle(copy: String, active: Bool, mutate: @escaping () -> Void) -> some View {

        Toggle(isOn: Binding(get: { active }, set: { _ in mutate() })) {

            Text(copy)

        }

        .toggleStyle(.switch)

        .tint(MollyTheme.ColorToken.accent.resolve(for: scheme))

        .mollyCard()

    }

    private var timersCard: some View {

        VStack(alignment: .leading, spacing: 10) {

            Text("Timers")

                .font(.title3.bold())

            Picker("Preset", selection: Binding<MollyTimerPreset>(

                        get: { surface.timerPreset },

                        set: { surface.applyTimerPreset($0)

                        })) {

                ForEach(MollyTimerPreset.allCases) {

                    Text($0.menuTitle)

                        .tag($0)

                }

            }

            .pickerStyle(.segmented)

            Toggle("Mirror Connectivity timer with Awake", isOn:

                    Binding(get: {

                        surface.mirrorTimers

                    }, set: {

                        surface.mirrorTimers = $0

                    }))

            Text(surface.countdownSubtitle)

                .font(.callout)

                .foregroundStyle(.secondary)

        }

        .mollyCard()

    }

}

private struct ConnectivityPane: View {

    @ObservedObject var probes: ConnectivityLaneEngine

    @ObservedObject var pilot: MollySessionController

    @Environment(\.colorScheme) private var scheme

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text("Connectivity detail")

                .font(.largeTitle.bold())

            Group {

                datumRow(title: "Summary", detail: probes.summary)

                datumRow(title: "Armed",

                         detail: probes.laneEnabled ? "YES" :

                            "NO")

                datumRow(title: "Success streak", detail: "\(probes.successes)")

                datumRow(title: "Failure streak", detail: "\(probes.failures)")

                if let ms = probes.lastRTTmilliseconds {

                    datumRow(title: "Last RTT (ms ≈)", detail: String(format: "%.1f",

                                                                      ms))

                }

                datumRow(title: "Route healthy",

                         detail:

                            probes.networkPathHealthy ? "Satisfied NWPath"

                            :

                              "Unavailable")

                if let next = probes.nextScheduledAt {

                    datumRow(title: "Next probe ETA",

                             detail:

                                RelativeDateTimeFormatter()

                                .localizedString(for: next,

                                                    relativeTo: Date()))

                }

            }

            .mollyCard()

            InsightCallout(kind: pilot.lowPowerModeActive ?

                "Low Power Mode radios may shorten idle budgets—toggle briefly off during diagnostics."

                               :

                               "Radios behaving normally.")

        }

        .frame(maxWidth: .infinity, alignment: .leading)

    }

    private func datumRow(title: String, detail: String) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(title)

                .foregroundStyle(.secondary)

                .font(.subheadline)

            Text(detail)

                .font(.body.monospaced())

        }

    }

}

private struct InsightPane: View {

    @ObservedObject var surface: MollySessionController

    @Environment(\.colorScheme) private var scheme

    var body: some View {

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],

                  spacing: 16) {

            chip(title: "Awake",

                 detail:

                    surface.awakeEnabled ? "asserting idle sleep inhibition" :

                    "released")

            chip(title: "Connectivity",

                 detail:

                    surface.connectivityEnabled ? "jitter probes active"

                    :

                     "paused")

            chip(title: "SKU", detail: surface.skuSummaryLine)

            chip(title: "Timers",

                 detail: surface.countdownSubtitle)

        }

    }

    private func chip(title: String, detail: String) -> some View {

        VStack(alignment: .leading, spacing: 12) {

            Text(title.uppercased())

                .font(.caption)

                .foregroundStyle(.secondary)

            Text(detail)

                .font(.headline)

        }

        .padding()

        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)

        .mollyCard()

    }

}

private struct InsightCallout: View {

    let kind: String

    @Environment(\.colorScheme) private var scheme

    var body: some View {

        Text(kind)

            .foregroundStyle(Color.primary)

            .padding()

            .frame(maxWidth: .infinity, alignment: .leading)

            .background(MollyTheme.ColorToken.card.resolve(for: scheme))

            .cornerRadius(12)

            .overlay(RoundedRectangle(cornerRadius: 12)

                         .stroke(MollyTheme.ColorToken.border.resolve(for: scheme)))

    }

}

private struct LogsPane: View {

    @ObservedObject var journal: MollyLogStore

    @Environment(\.colorScheme) private var scheme

    var body: some View {

        VStack(alignment: .leading) {

            HStack {

                Text("Rolling JSON Lines")

                    .font(.largeTitle.bold())

                Spacer()

                Button("Export…") {

                    journal.exportPlaintextJSONLines()

                }

            }

            List(journal.entries) { row in

                VStack(alignment: .leading) {

                    Text(row.iso8601UTC)

                        .font(.caption.monospaced())

                        .foregroundStyle(.secondary)

                    Text(row.message)

                    Text(row.metaJSON)

                        .font(.caption2.monospaced())

                        .foregroundStyle(.tertiary)

                }

            }

            .scrollContentBackground(.hidden)

            .background(MollyTheme.ColorToken.card.resolve(for: scheme))

        }

        .frame(maxHeight: .infinity)

    }

}

private struct SettingsPane: View {

    @ObservedObject var surface: MollySessionController

    @Environment(\.colorScheme) private var scheme

    @State private var launchAtLoginCached = UserDefaults.standard.bool(forKey: MollyPreferenceKeys.launchAtLogin)

    var body: some View {

        Form {

            Toggle("Deliver notifications",

                   isOn: Binding(get:

                                    { surface.notificationsEnabled },

                                 set:

                                    { surface.notificationsEnabled = $0 }))

            Toggle(isOn:

                    Binding(get: {

                        launchAtLoginCached

                    }, set: {
                        tapped in

                        launchAtLoginCached = tapped

                        surface.applyLaunchRegistrationToggle(tapped)

                    })) {

                Text("Open at login")

            }

            Section("SKU reference") {

                Text(MollySKU.connectivityNarrative)

                    .foregroundStyle(.secondary)

            }

        }

        .formStyle(.grouped)

        .frame(maxWidth: 450)

        .scrollContentBackground(.hidden)

        .background(MollyTheme.ColorToken.background.resolve(for: scheme))

        .cornerRadius(12)

        .task {

            launchAtLoginCached = LaunchRegistration.readSystemFlag()

        }

    }

}

private struct AboutPane: View {

    var body: some View {

        VStack(alignment: .leading, spacing: 14) {

            Text("About Molly")

                .font(.largeTitle.bold())

            Text("""
            Molly is a macOS productivity utility for roaming developers juggling agent workloads plus fragile iPhone hotspot sessions.

            • Local-only probes + rotating JSON Lines.


            • No agent-finished heuristics in v1—they require editor-side signals.


            Capsule glyphs reference medicine packaging—not controlled substances—with App Store SKU using tamer wording if necessary.
            """)

                .foregroundStyle(.secondary)

        }

    }

}
