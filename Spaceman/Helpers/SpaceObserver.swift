//
//  SpaceObserver.swift
//  Spaceman
//
//  Created by Sasindu Jayasinghe on 23/11/20.
//

import Cocoa
import Foundation

class SpaceObserver {
    private struct DisplayInfo {
        let activeSpaceID: Int
        let spaces: [[String: Any]]
        let displayID: String
    }

    private struct SpaceBuildResult {
        let spaces: [Space]
        let updatedNames: [String: SpaceNameInfo]
        let nextIndex: Int
    }

    private let workspace = NSWorkspace.shared
    private let conn = _CGSDefaultConnection()
    private let defaults = UserDefaults.standard
    weak var delegate: SpaceObserverDelegate?

    // Debounce mechanism for notification-triggered updates
    private var pendingDebounceWorkItem: DispatchWorkItem?
    private var pendingDelayedCheckWorkItem: DispatchWorkItem?

    // Polling timer to detect space additions/removals (no system notification exists)
    private var configPollTimer: Timer?
    private var lastKnownSpaceIDs = Set<Int>()
    private var lastKnownActiveSpaceID: Int?

    init() {
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(handleSpaceNotification),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: workspace)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSpaceNotification),
            name: NSNotification.Name("ButtonPressed"),
            object: nil)
        startConfigPolling()
    }

    // Polls every 2 seconds to detect space config changes (additions/removals)
    private func startConfigPolling() {
        configPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForConfigChanges()
        }
    }

    private func checkForConfigChanges() {
        guard let displays = CGSCopyManagedDisplaySpaces(conn) as? [[String: Any]] else { return }

        var currentIDs = Set<Int>()
        var currentActiveID: Int?
        for display in displays {
            guard let spaces = display["Spaces"] as? [[String: Any]] else { continue }
            if let currentSpace = display["Current Space"] as? [String: Any],
               let activeID = currentSpace["ManagedSpaceID"] as? Int {
                currentActiveID = activeID
            }
            for space in spaces {
                if let sid = space["ManagedSpaceID"] as? Int { currentIDs.insert(sid) }
            }
        }

        let configChanged = currentIDs != lastKnownSpaceIDs
        let activeChanged = currentActiveID != lastKnownActiveSpaceID

        if configChanged || activeChanged {
            lastKnownSpaceIDs = currentIDs
            lastKnownActiveSpaceID = currentActiveID
            performUpdate()
        }
    }

    // Called directly from keyboard shortcuts and app launch - executes immediately without debounce
    @objc public func updateSpaceInformation() {
        // Cancel any pending debounced or delayed updates to execute immediately
        pendingDebounceWorkItem?.cancel()
        pendingDebounceWorkItem = nil
        pendingDelayedCheckWorkItem?.cancel()
        pendingDelayedCheckWorkItem = nil

        performUpdate()
    }

    // Called from notifications - debounces rapid calls and schedules delayed re-check
    @objc private func handleSpaceNotification() {
        // Cancel the previous debounce timer if one exists
        pendingDebounceWorkItem?.cancel()

        // Schedule a debounced update after 0.1 seconds
        let workItem = DispatchWorkItem { [weak self] in
            self?.performUpdate()
            self?.scheduleDelayedRecheck()
        }

        pendingDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    // Schedules a delayed re-fetch after 0.3 seconds to catch stale data from macOS
    private func scheduleDelayedRecheck() {
        // Cancel the previous delayed check if one exists
        pendingDelayedCheckWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.performUpdate()
        }

        pendingDelayedCheckWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    // Actual space information update logic
    private func performUpdate() {
        guard let displays = CGSCopyManagedDisplaySpaces(conn) as? [[String: Any]] else {
            return
        }

        let savedSpaceNames = loadSavedSpaceNames()
        var spacesIndex = 0
        var allSpaces = [Space]()
        var updatedDict = [String: SpaceNameInfo]()
        var currentIDs = Set<Int>()

        for display in displays {
            guard let parsedDisplay = parseDisplay(display) else {
                continue
            }

            if parsedDisplay.activeSpaceID == -1 {
                DispatchQueue.main.async {
                    print("Can't find current space")
                }
                return
            }

            // Track space IDs for polling sync
            for spaceInfo in parsedDisplay.spaces {
                if let sid = spaceInfo["ManagedSpaceID"] as? Int { currentIDs.insert(sid) }
            }

            let builtSpaces = appendSpaces(
                for: parsedDisplay,
                savedSpaceNames: savedSpaceNames,
                startIndex: spacesIndex)
            allSpaces.append(contentsOf: builtSpaces.spaces)
            updatedDict.merge(builtSpaces.updatedNames) { _, new in new }
            spacesIndex = builtSpaces.nextIndex
        }

        // Sync polling state so the poll timer doesn't re-trigger for the same change
        lastKnownSpaceIDs = currentIDs
        let activeID = allSpaces.first(where: { $0.isCurrentSpace }).flatMap { Int($0.spaceID) }
        lastKnownActiveSpaceID = activeID

        defaults.set(try? PropertyListEncoder().encode(updatedDict), forKey: "spaceNames")
        delegate?.didUpdateSpaces(spaces: allSpaces)
    }

    private func parseDisplay(_ display: [String: Any]) -> DisplayInfo? {
        guard let currentSpaceInfo = display["Current Space"] as? [String: Any],
              let spaces = display["Spaces"] as? [[String: Any]],
              let displayID = display["Display Identifier"] as? String,
              let activeSpaceID = currentSpaceInfo["ManagedSpaceID"] as? Int
        else {
            return nil
        }

        return DisplayInfo(activeSpaceID: activeSpaceID, spaces: spaces, displayID: displayID)
    }

    private func appendSpaces(
        for display: DisplayInfo,
        savedSpaceNames: [String: SpaceNameInfo],
        startIndex: Int
    ) -> SpaceBuildResult {
        var spacesIndex = startIndex
        var lastDesktopNumber = 0
        var spaces = [Space]()
        var updatedNames = [String: SpaceNameInfo]()

        for spaceInfo in display.spaces {
            guard let managedSpaceID = spaceInfo["ManagedSpaceID"] as? Int else {
                continue
            }

            let spaceID = String(managedSpaceID)
            let spaceNumber: Int = spacesIndex + 1
            let isCurrentSpace = display.activeSpaceID == managedSpaceID
            let isFullScreen = spaceInfo["TileLayoutManager"] is [String: Any]
            let desktopNumber: Int?

            if isFullScreen {
                desktopNumber = nil
            } else {
                lastDesktopNumber += 1
                desktopNumber = lastDesktopNumber
            }

            let space = Space(
                displayID: display.displayID,
                spaceID: spaceID,
                spaceName: savedSpaceNames[spaceID]?.spaceName
                    ?? defaultSpaceName(for: spaceInfo, isFullScreen: isFullScreen),
                spaceNumber: spaceNumber,
                desktopNumber: desktopNumber,
                isCurrentSpace: isCurrentSpace,
                isFullScreen: isFullScreen)

            updatedNames[spaceID] = SpaceNameInfo(spaceNum: spaceNumber, spaceName: space.spaceName)
            spaces.append(space)
            spacesIndex += 1
        }

        return SpaceBuildResult(spaces: spaces, updatedNames: updatedNames, nextIndex: spacesIndex)
    }

    private func defaultSpaceName(for spaceInfo: [String: Any], isFullScreen: Bool) -> String {
        guard isFullScreen else {
            return "N/A"
        }

        if let pid = spaceInfo["pid"] as? pid_t,
           let app = NSRunningApplication(processIdentifier: pid),
           let name = app.localizedName {
            return name.prefix(5).uppercased()
        }

        return "FUL"
    }

    private func loadSavedSpaceNames() -> [String: SpaceNameInfo] {
        guard let data = defaults.value(forKey: "spaceNames") as? Data else {
            return [:]
        }

        return (try? PropertyListDecoder().decode([String: SpaceNameInfo].self, from: data)) ?? [:]
    }
}

protocol SpaceObserverDelegate: AnyObject {
    func didUpdateSpaces(spaces: [Space])
}
