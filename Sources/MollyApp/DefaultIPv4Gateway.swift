import Foundation

enum DefaultIPv4Gateway {
    /// Best-effort default gateway resolver via `/sbin/route` (sandbox allows typical macOS executions of system route helper).
    static func lookup(timeoutSeconds: Double = 2.0) async -> String? {
        await Task.detached {
            let pipe = Pipe()
            let err = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/route")
            process.arguments = ["-n", "get", "default"]
            process.standardOutput = pipe
            process.standardError = err

            do {
                try process.run()
            } catch {
                return nil
            }

            let deadline = Date().addingTimeInterval(timeoutSeconds)

            while process.isRunning {
                if Date() > deadline {
                    process.terminate()
                    return nil
                }
                Thread.sleep(forTimeInterval: 0.02)
            }

            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let raw = String(data: data, encoding: .utf8) else { return nil }

            for line in raw.split(separator: "\n") where line.contains("gateway:") {
                let comps = line.split(separator: " ")
                guard let gwIndex = comps.firstIndex(where: { $0 == "gateway:" }) else { continue }
                let next = comps.index(after: gwIndex)
                if next < comps.endIndex {
                    return String(comps[next])
                }
            }
            return nil
        }.value
    }
}
