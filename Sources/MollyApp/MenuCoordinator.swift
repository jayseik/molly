import AppKit

final class MenuCoordinator: NSObject {

    private unowned let session: MollySessionController

    private var statusChip: NSStatusItem?

    init(sessionBrain: MollySessionController) {

        session = sessionBrain

        super.init()

    }

    func install() {

        let chip = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        chip.button?.image = NSImage.mollyStatusGlyph()

        chip.button?.toolTip = "Molly — stay awake + hotspot helper"

        statusChip = chip

        rebuildMenuTree()

    }

    func rebuild() {

        rebuildMenuTree()

    }

    private func rebuildMenuTree() {

        let menuConstructed = assembleMenuSkeleton()

        statusChip?.menu = menuConstructed

    }

    private func assembleMenuSkeleton() -> NSMenu {

        let menuRoot = NSMenu()

        prependHeaderSnippet(on: menuRoot)

        prependLaneToggles(on: menuRoot)

        prependNestedTimerShelf(onParent: menuRoot)

        prependWindowShortcut(on: menuRoot)

        prependFooterCopy(on: menuRoot)

        prependQuitDoor(on: menuRoot)

        return menuRoot

    }

    private func prependHeaderSnippet(on menuRoot: NSMenu) {

        let composite = NSMutableString()

        composite.append(session.awakeEnabled ? "Awake lane • ON" : "Awake lane • OFF")

        composite.append("\nConnectivity • ")

        composite.append(session.connectivityEnabled ? "ON" : "OFF")

        composite.append("\nTimers • ")

        composite.append(session.countdownSubtitle)

        let shell = NSMenuItem(title: String(composite), action: nil, keyEquivalent: "")

        shell.isEnabled = false

        menuRoot.addItem(shell)

        menuRoot.addItem(.separator())

    }

    private func prependLaneToggles(on menuRoot: NSMenu) {

        let awakeSentence = session.awakeEnabled ? "Turn Awake lane OFF"

            : "Turn Awake lane ON"

        menuRoot.addItem(factorySimpleRow(titleSentence: awakeSentence,

                                          routing: #selector(handleAwakeIntent)))

        let connectivitySentence = session.connectivityEnabled ? "Turn Connectivity OFF"

            : "Turn Connectivity ON"

        menuRoot.addItem(factorySimpleRow(titleSentence: connectivitySentence,

                                          routing: #selector(handleConnectivityIntent)))

        menuRoot.addItem(.separator())

    }

    private func prependNestedTimerShelf(onParent outer: NSMenu) {

        let timerWrapper = NSMenuItem(title: "Session timer presets", action: nil, keyEquivalent: "")

        let inner = NSMenu()

        MollyTimerPreset.allCases.forEach { preset in

            let row = factorySimpleRow(titleSentence: preset.menuTitle,

                                       routing: #selector(handleTimerIntent(sender:)))

            row.representedObject = preset.rawValue

            row.state = session.timerPreset == preset ? .on : .off

            inner.addItem(row)

        }

        inner.addItem(.separator())

        let mirrorRow = factorySimpleRow(

            titleSentence: session.mirrorTimers ? "Mirror timers — ON" : "Mirror timers — OFF",

            routing: #selector(handleMirrorIntent))

        inner.addItem(mirrorRow)

        timerWrapper.submenu = inner

        outer.addItem(timerWrapper)

    }

    private func prependWindowShortcut(on menuRoot: NSMenu) {

        let dashboard = factorySimpleRow(titleSentence: "Show Dashboard…",

                                         routing: #selector(handleDashboardIntent))

        dashboard.keyEquivalent = "o"

        dashboard.keyEquivalentModifierMask = [.shift, .command]

        menuRoot.addItem(dashboard)

        menuRoot.addItem(.separator())

    }

    private func prependFooterCopy(on menuRoot: NSMenu) {

        footnote(menuRoot, "Offline privacy: Molly never ships logs or probe metadata automatically.")

        footnote(menuRoot, "Distribution mode ▸ \(session.skuSummaryLine)")

    }

    private func prependQuitDoor(on menuRoot: NSMenu) {

        let quitRow = factorySimpleRow(titleSentence: "Quit Molly",

                                       routing: #selector(handleQuitIntent))

        quitRow.keyEquivalent = "q"

        quitRow.keyEquivalentModifierMask = .command

        menuRoot.addItem(.separator())

        menuRoot.addItem(quitRow)

    }

    private func footnote(_ menuRoot: NSMenu, _ text: String) {

        let shell = NSMenuItem(title: text, action: nil, keyEquivalent: "")

        shell.isEnabled = false

        menuRoot.addItem(shell)

    }

    private func factorySimpleRow(titleSentence: String, routing: Selector) -> NSMenuItem {

        let row = NSMenuItem(title: titleSentence, action: routing, keyEquivalent: "")

        row.target = self

        return row

    }

    @objc

    private func handleAwakeIntent() {

        session.toggleAwakeLane()

    }

    @objc

    private func handleConnectivityIntent() {

        session.toggleConnectivityLane()

    }

    @objc

    private func handleTimerIntent(sender: NSMenuItem) {

        guard let raw = sender.representedObject as? String,

              let parsed = MollyTimerPreset(rawValue: raw)

        else { return }

        session.applyTimerPreset(parsed)

    }

    @objc

    private func handleMirrorIntent() {

        session.mirrorTimers.toggle()

        rebuild()

    }

    @objc

    private func handleDashboardIntent() {

        NSApplication.shared.activate(ignoringOtherApps: true)

        NotificationCenter.default.post(name: .mollyRevealDashboard, object: nil)

    }

    @objc

    private func handleQuitIntent() {

        session.shutdownBeforeTermination()

        NSApplication.shared.terminate(nil)

    }

}

extension MollySessionController {

    /// Marketing line for SKU footers (mirrors Xcode compile-time flag).
    var skuSummaryLine: String { MollySKU.displayName }

}
