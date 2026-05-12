import AppKit
import SwiftUI

@main
struct MollyBootstrap: App {

    @NSApplicationDelegateAdaptor(MollyAppDelegate.self) private var conductor

    var body: some Scene {

        WindowGroup {

            MainDashboard(surface: conductor.hub)

                .background(Color(nsColor: .windowBackgroundColor))

                .onReceive(NotificationCenter.default.publisher(for: .mollyRevealDashboard)) { _ in

                    NSApplication.shared.activate(ignoringOtherApps: true)

                }

        }

        .defaultSize(width: 980, height: 640)

        Settings { EmptyView() }

    }

}
