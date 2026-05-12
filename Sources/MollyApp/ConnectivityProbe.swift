import Foundation
import Network

enum ConnectivityProbe {

    enum Outcome {
        case success(duration: Swift.Duration)
        case failure(String)

        var rttSeconds: Double {
            switch self {
            case .success(let duration):
                Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
            case .failure:
                .nan
            }
        }
    }

    static func tcpHandshake(host: String, port: UInt16, timeout: Swift.Duration) async -> Outcome {
        await withCheckedContinuation { continuation in
            let nwHost = NWEndpoint.Host(host)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: .failure("Bad port \(port)"))
                return
            }

            let connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)

            final class Box {
                var finished = false
                let lock = NSLock()

                func complete(_ outcome: Outcome, continuation: CheckedContinuation<Outcome, Never>) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !finished else { return }
                    finished = true
                    continuation.resume(returning: outcome)
                }
            }

            let box = Box()
            let start = ContinuousClock.now

            let timeoutSeconds =
                Double(timeout.components.seconds)
                + Double(timeout.components.attoseconds) / 1e18

            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
            timer.schedule(deadline: .now() + timeoutSeconds)
            timer.setEventHandler {
                connection.cancel()
                box.complete(.failure("TCP handshake timeout \(host):\(port)"), continuation: continuation)
            }
            timer.resume()

            connection.stateUpdateHandler = { nwState in
                switch nwState {
                case .ready:
                    timer.cancel()
                    connection.cancel()
                    let elapsed = ContinuousClock.now - start
                    box.complete(.success(duration: elapsed), continuation: continuation)

                case .failed(let error):
                    timer.cancel()
                    connection.cancel()
                    box.complete(.failure(error.localizedDescription), continuation: continuation)

                default:
                    break
                }
            }

            connection.start(queue: DispatchQueue.global(qos: .utility))
        }
    }

    static func httpsHEAD(url: URL, timeoutSeconds: TimeInterval) async -> Outcome {
        await withCheckedContinuation { continuation in
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeoutSeconds)
            request.httpMethod = "HEAD"
            let start = ContinuousClock.now

            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error {
                    continuation.resume(returning: .failure(error.localizedDescription))
                    return
                }

                guard let http = response as? HTTPURLResponse else {
                    continuation.resume(returning: .failure("No HTTP response"))
                    return
                }

                guard (200 ..< 600).contains(http.statusCode) else {
                    continuation.resume(returning: .failure("Unexpected HTTP \(http.statusCode)"))
                    return
                }

                continuation.resume(returning: .success(duration: ContinuousClock.now - start))
            }
            .resume()
        }
    }
}
