import AppKit
import Combine
import Foundation

/// Coordinates persisted lanes, IOPowerAssertions, jittered Connectivity probes, and countdown timers.
@MainActor
final class MollySessionController: ObservableObject {

    // MARK: Published surface

    @Published private(set) var awakeEnabled = false

    @Published private(set) var connectivityEnabled = false

    /// When countdown fires, Connectivity turns off simultaneously if mirrored.
    @Published var mirrorTimers: Bool {
        didSet { defaults.set(mirrorTimers, forKey: MollyPreferenceKeys.mirrorTimer) }
    }

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: MollyPreferenceKeys.notifications)
            if notificationsEnabled == false {
                NotificationThrottleCoordinator.shared.resetFailureTimeline()
            }
        }
    }

    @Published private(set) var timerPreset: MollyTimerPreset

    @Published private(set) var sessionExpiry: Date?

    @Published private(set) var lowPowerModeActive = false

    let logs = MollyLogStore()

    let power = AwakeLanePowerManager()

    let probes: ConnectivityLaneEngine

    weak var menuBridge: MenuCoordinator?

    private let defaults = UserDefaults.standard

    private var countdownWorkItem: DispatchWorkItem?

    private var bag = Set<AnyCancellable>()

    init() {
        probes = ConnectivityLaneEngine(logging: logs)

        mirrorTimers =
            defaults.object(forKey: MollyPreferenceKeys.mirrorTimer) as? Bool ?? true

        notificationsEnabled =
            defaults.object(forKey: MollyPreferenceKeys.notifications) as? Bool ?? true

        if let presetRaw = defaults.string(forKey: "molly.preference.timerpreset"),

           let matched = MollyTimerPreset(rawValue: presetRaw) {
            timerPreset = matched

        } else {

            timerPreset = .manual

        }

        bindProbePublishing()

        watchLowPowerMode()

        applyDiskBootstrap()

    }

    // MARK: Lifecycle

    func beginStartupHousekeeping() {
        probes.bootstrapInfrastructureIfNeeded()
    }

    func shutdownBeforeTermination() {

        countdownWorkItem?.cancel()

        power.release()

        probes.shutdownHard()

    }

    // MARK: User intents

    func toggleAwakeLane() {

        setAwakeEnabled(!awakeEnabled)

    }



    func toggleConnectivityLane() {

        setConnectivityEnabled(!connectivityEnabled)

    }



    func applyTimerPreset(_ preset: MollyTimerPreset) {


        timerPreset = preset



        defaults.set(preset.rawValue, forKey: "molly.preference.timerpreset")


        rescheduleCountdownIfNeeded()


        menuBridge?.rebuild()


        objectWillChange.send()


    }



    func applyLaunchRegistrationToggle(_ enabled: Bool) {


        do {


            try LaunchRegistration.apply(enabled)


        } catch {


            logs.append(level: .error,

                        message: "Unable to mutate login item",

                        meta: ["reason": "\(error)"])



        }



    }



    // MARK: Formatting helpers

    var countdownSubtitle: String {

        guard awakeEnabled,

              timerPreset.durationSeconds != nil,

              let deadline = sessionExpiry else {

            return "Manual"

        }

        guard deadline.timeIntervalSinceNow > 0 else {

            return "Completing…"

        }



        let formatter = DateComponentsFormatter()


        formatter.allowedUnits = [.hour,.minute,.second]


        formatter.unitsStyle = .abbreviated


        let textual = formatter.string(from: Date(), to: deadline) ?? "soon"


        return "Ends ~ \(textual)"


    }



    // MARK: Internals



    func setAwakeEnabled(_ enabled: Bool) {


        guard awakeEnabled != enabled else {


            menuBridge?.rebuild()


            return


        }



        awakeEnabled = enabled



        defaults.set(enabled, forKey: MollyPreferenceKeys.awakeLane)


        if enabled {


            let ok = power.acquire(reason: "Molly — prevent idle sleep for agent workloads")



            logs.append(level: ok ? .info : .error,

                         message:

                            ok ?
                            "Awake lane asserted (display may sleep — system stays reachable when macOS allows)"
                            :

                            "Could not acquire idle sleep assertion",

                         meta: [:])



            rescheduleCountdownIfNeeded()


        } else {


            countdownWorkItem?.cancel()


            countdownWorkItem = nil


            sessionExpiry = nil


            power.release()


            logs.append(level: .info, message: "Awake lane released", meta: [:])


        }



        menuBridge?.rebuild()


        objectWillChange.send()


    }



    func setConnectivityEnabled(_ enabled: Bool) {


        guard connectivityEnabled != enabled else {


            menuBridge?.rebuild()


            return


        }



        connectivityEnabled = enabled



        defaults.set(enabled, forKey: MollyPreferenceKeys.connectivityLane)


        probes.setConnectivityLane(enabled: enabled, log: logs)


        logs.append(level: .info,

                    message:

                        enabled ?
                        "Connectivity keepalive armed (best‑effort for hotspot idle drops)"
                            :

                            "Connectivity keepalive halted",

                     meta: [:])



        menuBridge?.rebuild()


        objectWillChange.send()


    }



    private func applyDiskBootstrap() {


        awakeEnabled = defaults.bool(forKey: MollyPreferenceKeys.awakeLane)


        connectivityEnabled =
            defaults.bool(forKey: MollyPreferenceKeys.connectivityLane)


        if awakeEnabled {


            let ok =
                power.acquire(reason: "Molly — resumed idle sleep prevention")


            logs.append(level: ok ? .info : .warn,

                         message:


                            ok ?
                            "Restored awake lane session"
                            :

                            "Unable to reclaim awake assertion on launch",

                         meta: [:])


            rescheduleCountdownIfNeeded()


        }



        if connectivityEnabled {


            probes.setConnectivityLane(enabled:

                                        true,

                                        log: logs)


        }



        menuBridge?.rebuild()


    }



    private func rescheduleCountdownIfNeeded() {


        countdownWorkItem?.cancel()


        countdownWorkItem = nil


        sessionExpiry = nil



        guard awakeEnabled else {


            menuBridge?.rebuild()


            return


        }



        guard let seconds = timerPreset.durationSeconds else {


            menuBridge?.rebuild()


            return


        }



        sessionExpiry = Date().addingTimeInterval(seconds)


        let work = DispatchWorkItem { [weak self] in


            guard let self else { return }



            Task { @MainActor in


                self.handleTimerExpiration()


            }


        }



        countdownWorkItem = work


        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)


        menuBridge?.rebuild()


    }



    private func handleTimerExpiration() {


        countdownWorkItem = nil



        awakeEnabled = false


        connectivityEnabled =
            mirrorTimers ? false : connectivityEnabled


        defaults.set(awakeEnabled, forKey: MollyPreferenceKeys.awakeLane)



        defaults.set(connectivityEnabled, forKey: MollyPreferenceKeys.connectivityLane)



        sessionExpiry = nil



        power.release()



        if mirrorTimers {


            probes.setConnectivityLane(enabled: false,

                                        log: logs)


        }



        logs.append(level: .info,

                    message:

                      "Timed session elapsed — Molly turned lanes off",

                    meta: [:])



        if notificationsEnabled {


            NotificationThrottleCoordinator.shared.notifyTimerExpiredPlainCopy()


        }



        menuBridge?.rebuild()


        objectWillChange.send()


    }



    private func bindProbePublishing() {


        probes.objectWillChange


            .sink { [weak self] _ in


                self?.objectWillChange.send()


            }


            .store(in: &bag)


    }



    private func watchLowPowerMode() {


        Timer.publish(every: 20,

                      tolerance: 4,

                       on: .main,

                         in: .common)


            .autoconnect()


            .sink { [weak self] _ in


                guard let self else {


                    return


                }



                lowPowerModeActive =
                    ProcessInfo.processInfo.isLowPowerModeEnabled


                self.objectWillChange.send()


            }


            .store(in: &bag)


    }



}


