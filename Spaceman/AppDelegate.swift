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

    // Track the last active space ID to detect actual space changes
    private var lastActiveSpaceID: String?

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

        // Show overlay only when the active space actually changes (not on launch)
        if lastActiveSpaceID != nil, currentActiveID != lastActiveSpaceID {
            spaceOverlay.show(spaces: spaces)
        }

        lastActiveSpaceID = currentActiveID

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
