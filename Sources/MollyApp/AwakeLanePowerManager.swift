import Foundation
import IOKit.pwr_mgt

/// Holds an idle-sleep avoidance assertion (`PreventUserIdleSystemSleep`) — display may sleep.
/// Dev-only subprocess harness guarded below (never shipped in onboarding UI paths).
final class AwakeLanePowerManager: @unchecked Sendable {

    private var assertionID: IOPMAssertionID = 0

    func isActive() -> Bool { assertionID != 0 }

    @discardableResult
    func acquire(reason: String) -> Bool {
        release()
        var id = IOPMAssertionID(0)

        /// Use string literal assertion type compatible with IOPMLib.
        let assertionType = "PreventUserIdleSystemSleep" as CFString

        let result = IOPMAssertionCreateWithName(
            assertionType,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &id
        )

        guard result == kIOReturnSuccess else {
            assertionID = 0
            return false
        }
        assertionID = id
        return true
    }

    func release() {
        guard assertionID != 0 else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }

    deinit { release() }
}

#if DEBUG
/// Comparison harness mentioned in architecture notes — intentionally not surfaced in production UI flows.
final class CaffeinateDevHarness {

    func sampleProcessActivityTag() -> String {
        "(debug) Harness reference only — IOPowerAssertions preferred"
    }
}
#endif
