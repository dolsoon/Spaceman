//
//  AppDelegate.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {

    private let statusBar = StatusBar()
    private let spaceObserver = SpaceObserver()
    private let iconCreator = IconCreator()
    private let spaceOverlay = SpaceOverlayWindow()
    private let floatingPanel = SpaceFloatingPanel()

    // Track the last active space ID to detect actual space changes
    private var lastActiveSpaceID: String?

    // Track the last space count to detect when spaces are added or removed
    private var lastSpaceCount: Int?

    func applicationDidFinishLaunching(_ aNotification: Notification) {

        spaceObserver.delegate = self
        spaceObserver.updateSpaceInformation()
        NSApp.activate(ignoringOtherApps: true)
        KeyboardShortcuts.onKeyUp(for: .refresh) { [] in
            self.spaceObserver.updateSpaceInformation()
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

extension AppDelegate: SpaceObserverDelegate {
    func didUpdateSpaces(spaces: [Space]) {
        let currentActiveID = spaces.first(where: { $0.isCurrentSpace })?.spaceID
        let currentSpaceCount = spaces.count

        // Show overlay when:
        // 1. The active space changes (not on launch when lastActiveSpaceID is nil)
        // 2. Space count changes (space added or removed)
        let spaceCountChanged = lastSpaceCount != nil && currentSpaceCount != lastSpaceCount
        let activeSpaceChanged = lastActiveSpaceID != nil && currentActiveID != lastActiveSpaceID

        if spaceCountChanged || activeSpaceChanged {
            spaceOverlay.show(spaces: spaces)
        }

        lastActiveSpaceID = currentActiveID
        lastSpaceCount = currentSpaceCount

        floatingPanel.update(spaces: spaces)

        let icon = iconCreator.getIcon(for: spaces)
        statusBar.updateStatusBar(withIcon: icon)
    }
}

@main
struct SpacemanApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {

        Settings {
            EmptyView()
        }

    }

}
