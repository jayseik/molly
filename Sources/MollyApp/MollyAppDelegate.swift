import AppKit

final class MollyAppDelegate: NSObject, NSApplicationDelegate {

    let hub = MollySessionController()

    private var menu: MenuCoordinator?

    func applicationWillFinishLaunching(_ notification: Notification) {

        let coordinator = MenuCoordinator(sessionBrain: hub)

        menu = coordinator

        hub.menuBridge = coordinator

        coordinator.install()

        NSApp.setActivationPolicy(.regular)

    }

    func applicationDidFinishLaunching(_ notification: Notification) {

        hub.beginStartupHousekeeping()

        Task { await NotificationThrottleCoordinator.shared.requestAuthorizationIfNeeded() }

        menu?.rebuild()

    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {

        false

    }

    func applicationWillTerminate(_ notification: Notification) {

        hub.shutdownBeforeTermination()

    }

}
