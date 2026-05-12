import Foundation
import Network

/// Connectivity lane jittered probe ladder — gateway TCP first, HTTPS HEAD fallback.
@MainActor
final class ConnectivityLaneEngine: ObservableObject {

    @Published private(set) var laneEnabled: Bool = false
    @Published private(set) var summary: String = "Idle"
    @Published private(set) var successes: Int = 0
    @Published private(set) var failures: Int = 0
    @Published private(set) var lastEndedAt: Date?
    @Published private(set) var nextScheduledAt: Date?
    @Published private(set) var lastRTTmilliseconds: Double?

    struct ProbeConfiguration: Sendable {
        var nominalIntervalSeconds: Double = 120
        var jitterFraction: Double = 0.25
        var tcpTimeoutSeconds: TimeInterval = 5
        var headTimeoutSeconds: TimeInterval = 5

        func sleepDurationUntilNextProbe() -> Swift.Duration {
            let band = nominalIntervalSeconds * jitterFraction
            let offset = Double.random(in: (-band) ..< band)
            let seconds = max(45, nominalIntervalSeconds + offset)
            return .milliseconds(Int(seconds * 1000))
        }
    }

    var configuration = ProbeConfiguration()

    private weak var sink: MollyLogging?

    private let queue = DispatchQueue(label: "molly.conn.path")
    private var monitor: NWPathMonitor?

    /// True while `NWPath` reports a satisfied routed interface.
    @Published private var pathReachable: Bool = false

    private var probeTask: Task<Void, Never>?

    init(logging: MollyLogging?) {
        sink = logging
    }

    func attachLogging(_ logger: MollyLogging?) {
        sink = logger
    }

    private func millis(for duration: Swift.Duration) -> Double {
        let secs = Double(duration.components.seconds)
        let atto = Double(duration.components.attoseconds) / 1e18
        return (secs + atto) * 1000
    }

    func bootstrapInfrastructureIfNeeded() {
        guard probeTask == nil else { return }
        let mon = NWPathMonitor()
        monitor = mon
        mon.pathUpdateHandler = { path in
            Task { @MainActor in
                self.pathReachable = path.status == .satisfied
            }
        }
        mon.start(queue: queue)
        probeTask = Task(priority: .utility) {
            await self.probeLoopMain()
        }
    }

    func shutdownHard() {
        probeTask?.cancel()
        probeTask = nil
        monitor?.cancel()
        monitor = nil
    }

    func setConnectivityLane(enabled: Bool, log: MollyLogging) {
        laneEnabled = enabled
        bootstrapInfrastructureIfNeeded()
        if enabled {
            successes = failures = 0
            NotificationThrottleCoordinator.shared.resetFailureTimeline()
            log.append(level: .info, message: "Connectivity lane armed", meta: [:])
        } else {
            successes = failures = 0
            NotificationThrottleCoordinator.shared.resetFailureTimeline()
            summary = "Idle"
            lastRTTmilliseconds = nil
            nextScheduledAt = nil
            log.append(level: .info, message: "Connectivity lane disarmed", meta: [:])
        }
    }

    private func probeLoopMain() async {
        do {
            while true {
                try Task.checkCancellation()
                if laneEnabled == false {
                    try await Task.sleep(for: .seconds(1))
                    continue
                }

                guard pathReachable else {
                    summary = "Paused — no routed network path"
                    nextScheduledAt = Date().addingTimeInterval(5)
                    try await Task.sleep(for: .seconds(5))
                    continue
                }

                let sleepDuration = configuration.sleepDurationUntilNextProbe()

                nextScheduledAt = Date().addingTimeInterval(sleepDuration.approxSeconds)
                try await Task.sleep(for: sleepDuration)

                guard laneEnabled else {
                    continue
                }

                await iterateProbeStages()
                lastEndedAt = Date()
            }
        } catch {
            MollyDiagnostics.write("Connectivity probe loop ended: \(error.localizedDescription)")
        }
    }

    /// Gateway TCP then curated HTTPS HEAD fallbacks.
    private func iterateProbeStages() async {

        sink?.append(level: .debug, message: "Probe ladder start", meta: [:])

        summary = "Probing…"

        nextScheduledAt = nil

        /// Stage A
        let gatewayMaybe = await DefaultIPv4Gateway.lookup()

        sink?.append(level: .debug, message: "Default gateway lookup",

                      meta: ["gateway": gatewayMaybe ?? "nil"])


        if let gatewayStr = gatewayMaybe {


            let timeoutDuration = Duration.milliseconds(Int(configuration.tcpTimeoutSeconds * 1000))



            switch await ConnectivityProbe.tcpHandshake(host: gatewayStr,

                                                        port: 443,

                                                         timeout: timeoutDuration) {


            case .success(let duration):



                finalizeSuccess("Gateway handshake ok (\(gatewayStr))", elapsed: duration)



                return




            case .failure(let failure):



                sink?.append(level: .warn, message: "Gateway TCP failed",

                              meta: ["error": failure])



            }


        }



        /// Stage B
        let fallbacks: [URL] = ConnectivityLaneEngine.probeFallbackURLs()

        for fallback in fallbacks {

            switch await ConnectivityProbe.httpsHEAD(url: fallback,

                                                       timeoutSeconds: configuration.headTimeoutSeconds) {

            case .success(let duration):

                finalizeSuccess("HEAD ok (\(fallback.host ?? ""))", elapsed: duration)


                return

            case .failure(let err):

                sink?.append(level: .warn,

                                message: "HEAD fallback failed",

                                 meta: ["host": fallback.host ?? "", "error": err])

            }



        }



        finalizeFailure("All Connectivity ladder probes failed")



    }



    static func probeFallbackURLs() -> [URL] {


        guard

            
                let a = URL(string: "https://captive.apple.com/hotspot-detect.html"),

            
                let b = URL(string: "https://example.com"),

            
                let c = URL(string: "https://one.one.one.one")

            
        else {


            return []


        }



        return [a, b, c]


    }



    private func finalizeSuccess(_ line: String, elapsed: Swift.Duration) {
        successes += 1
        failures = 0
        NotificationThrottleCoordinator.shared.resetFailureTimeline()

        summary = line
        lastRTTmilliseconds = millis(for: elapsed)

        sink?.append(level: .info,

                        message: line,

                         meta: ["ms": "\(lastRTTmilliseconds ?? 0)"])

    }



    private func finalizeFailure(_ line: String) {

        successes = 0


        failures += 1



        summary = line


        lastRTTmilliseconds = nil



        sink?.append(level: .warn,

                        message: line,

                         meta: ["failures": "\(failures)"])

        let notifyPref = UserDefaults.standard.object(forKey: MollyPreferenceKeys.notifications) as? Bool ?? true
        NotificationThrottleCoordinator.shared.failureConnectivityProbeTick(
            currentFailures: failures,
            notificationsAllowed: notifyPref)


    }

    /// Exposes whether `NWPath` currently believes the default route is usable (for Insights cards).
    var networkPathHealthy: Bool { pathReachable }


}



private extension Swift.Duration {


    var approxSeconds: TimeInterval {


        Double(components.seconds) + Double(components.attoseconds) / 1e18


    }



}
