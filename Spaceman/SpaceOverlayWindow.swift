//
//  SpaceOverlayWindow.swift
//  Spaceman
//

import Cocoa
import SwiftUI

// MARK: - ViewModel

final class OverlayViewModel: ObservableObject {
    @Published var spaces: [Space] = []
    @Published var isEditing = false
}

// MARK: - EditInputWindow
// 별도 NSWindow: canBecomeKey=true override가 핵심
// NSPanel + nonactivatingPanel은 키 이벤트 독점 불가 → 일반 NSWindow 사용

final class EditInputWindow: NSWindow {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private let textField = NSTextField()
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true
        )
        level = .floating + 1
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        setupTextField()
    }

    private func setupTextField() {
        textField.font = .boldSystemFont(ofSize: 52)
        textField.textColor = .white
        textField.backgroundColor = .clear
        textField.isBordered = false
        textField.isBezeled = false
        textField.alignment = .center
        textField.focusRingType = .none
        textField.cell?.wraps = false
        textField.cell?.isScrollable = true
        textField.delegate = self
        textField.autoresizingMask = [.width, .height]
        contentView?.addSubview(textField)
    }

    func startEditing(name: String, over overlayFrame: NSRect, previousApp: NSRunningApplication?) {
        textField.stringValue = name

        // overlay card의 name text 위치 계산 (AppKit: y는 아래서 위)
        // card layout: paddingTop(24) + navRow(20) + spacing(16) = 60pt from card top
        let w = overlayFrame.width - 72  // 좌우 패딩 36씩 제외
        let x = overlayFrame.minX + 36
        let h: CGFloat = 72
        let nameTop = overlayFrame.maxY - 24 - 20 - 16
        let y = nameTop - h
        textField.frame = NSRect(x: 0, y: 0, width: w, height: h)
        setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)

        // canBecomeKey=true override로 이제 실제로 key window 가능
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(textField)
        textField.currentEditor()?.selectAll(nil)
    }
}

extension EditInputWindow: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        switch sel {
        case #selector(NSResponder.insertNewline(_:)):
            onCommit?(textField.stringValue)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            onCancel?()
            return true
        default:
            return false
        }
    }
}

// MARK: - SpaceOverlayWindow (display only)

final class SpaceOverlayWindow: NSPanel {

    private var hostingView: NSHostingView<SpaceOverlayView>?
    private var dismissTimer: Timer?
    private var trackingArea: NSTrackingArea?
    private var previousApp: NSRunningApplication?

    private let editWindow = EditInputWindow()
    let viewModel = OverlayViewModel()

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = false

        editWindow.onCommit = { [weak self] name in self?.commitEdit(name: name) }
        editWindow.onCancel = { [weak self] in self?.cancelEdit() }
    }

    func show(spaces: [Space]) {
        viewModel.spaces = spaces

        if viewModel.isEditing {
            viewModel.isEditing = false
            editWindow.orderOut(nil)
            cleanupAfterEdit()
        }

        if hostingView == nil {
            let view = SpaceOverlayView(
                viewModel: viewModel,
                onEditRequested: { [weak self] in self?.beginEdit() }
            )
            let hosting = NSHostingView(rootView: view)
            contentView = hosting
            hostingView = hosting
            setupTrackingArea()
        }

        if let size = contentView?.fittingSize { setContentSize(size) }
        positionOnScreen()
        scheduleDismiss()
        alphaValue = 1
        orderFrontRegardless()
    }

    private func beginEdit() {
        guard let space = viewModel.spaces.first(where: { $0.isCurrentSpace }) else { return }
        dismissTimer?.invalidate()

        // NSAlert: 항상 키 이벤트 수신 보장 (macOS 표준 방식)
        let alert = NSAlert()
        alert.messageText = "Space 이름 변경"
        alert.informativeText = "현재: \(space.spaceName)"
        alert.addButton(withTitle: "저장")
        alert.addButton(withTitle: "취소")

        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        tf.stringValue = space.spaceName
        tf.placeholderString = "Space 이름"
        alert.accessoryView = tf
        alert.window.initialFirstResponder = tf

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            saveName(spaceID: space.spaceID, spaceNumber: space.spaceNumber, name: tf.stringValue)
        }
        scheduleDismiss()
    }

    private func commitEdit(name: String) {
        guard let space = viewModel.spaces.first(where: { $0.isCurrentSpace }) else { return }
        saveName(spaceID: space.spaceID, spaceNumber: space.spaceNumber, name: name)
        editWindow.orderOut(nil)
        viewModel.isEditing = false
        cleanupAfterEdit()
        scheduleDismiss()
    }

    private func cancelEdit() {
        editWindow.orderOut(nil)
        viewModel.isEditing = false
        cleanupAfterEdit()
        scheduleDismiss()
    }

    private func cleanupAfterEdit() {
        NSApp.setActivationPolicy(.prohibited)
        previousApp?.activate(options: .activateIgnoringOtherApps)
        previousApp = nil
    }

    // MARK: - Hover

    private func setupTrackingArea() {
        guard let cv = contentView else { return }
        if let old = trackingArea { cv.removeTrackingArea(old) }
        let area = NSTrackingArea(
            rect: cv.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil
        )
        cv.addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { dismissTimer?.invalidate() }

    override func mouseExited(with event: NSEvent) {
        guard !viewModel.isEditing else { return }
        scheduleDismiss()
    }

    // MARK: - Timer

    func scheduleDismiss() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            guard let self, !self.viewModel.isEditing else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                self.animator().alphaValue = 0
            } completionHandler: {
                self.orderOut(nil)
                self.alphaValue = 1
            }
        }
    }

    // MARK: - Save

    private func saveName(spaceID: String, spaceNumber: Int, name: String) {
        let defaults = UserDefaults.standard
        guard let data = defaults.value(forKey: "spaceNames") as? Data,
              var dict = try? PropertyListDecoder().decode([String: SpaceNameInfo].self, from: data)
        else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        dict[spaceID] = SpaceNameInfo(spaceNum: spaceNumber, spaceName: trimmed.isEmpty ? "N/A" : trimmed)
        if let encoded = try? PropertyListEncoder().encode(dict) {
            defaults.set(encoded, forKey: "spaceNames")
        }
        NotificationCenter.default.post(name: NSNotification.Name("ButtonPressed"), object: nil)
    }

    private func positionOnScreen() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - frame.width / 2
        let y = visible.midY - frame.height / 2 + visible.height * 0.1
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - SwiftUI (display only)

struct SpaceOverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel
    let onEditRequested: () -> Void

    @State private var nameHovered = false

    private var currentIndex: Int?   { viewModel.spaces.firstIndex(where: { $0.isCurrentSpace }) }
    private var currentSpace: Space? { currentIndex.map { viewModel.spaces[$0] } }
    private var prevSpace: Space?    { currentIndex.flatMap { $0 > 0 ? viewModel.spaces[$0 - 1] : nil } }
    private var nextSpace: Space?    { currentIndex.flatMap { $0 < viewModel.spaces.count - 1 ? viewModel.spaces[$0 + 1] : nil } }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                if let prev = prevSpace {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold))
                        Text(prev.spaceName).font(.system(size: 16, weight: .medium, design: .rounded)).fixedSize()
                    }.foregroundColor(.white.opacity(0.65))
                }
                Spacer()
                if let next = nextSpace {
                    HStack(spacing: 6) {
                        Text(next.spaceName).font(.system(size: 16, weight: .medium, design: .rounded)).fixedSize()
                        Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold))
                    }.foregroundColor(.white.opacity(0.65))
                }
            }

            // 이름 영역: 편집 중이면 텍스트 숨김 (EditInputWindow가 위에 덮음)
            HStack(spacing: 8) {
                Text(viewModel.isEditing ? "" : (currentSpace?.spaceName ?? ""))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize()

                if !viewModel.isEditing {
                    Image(systemName: "pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(nameHovered ? 0.7 : 0))
                        .animation(.easeInOut(duration: 0.15), value: nameHovered)
                }
            }
            .frame(minHeight: 64)
            .contentShape(Rectangle())
            .onHover { nameHovered = $0 }
            .onTapGesture { if !viewModel.isEditing { onEditRequested() } }

            if viewModel.isEditing {
                Text("Enter 저장  ·  Esc 취소")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }

            HStack(spacing: 10) {
                ForEach(Array(viewModel.spaces.enumerated()), id: \.offset) { _, space in
                    SpaceChipView(space: space)
                }
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
        .background { RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.ultraThinMaterial) }
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.45), radius: 28, x: 0, y: 10)
        .environment(\.colorScheme, .dark)
    }
}

struct SpaceChipView: View {
    let space: Space
    var body: some View {
        VStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(space.isCurrentSpace ? Color.white : Color.white.opacity(0.22))
                .frame(width: space.isCurrentSpace ? 44 : 28, height: space.isCurrentSpace ? 30 : 20)
            Text(space.spaceName)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(space.isCurrentSpace ? .white : Color.white.opacity(0.45))
                .fixedSize()
        }
    }
}
