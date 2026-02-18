//
//  SpaceFloatingPanel.swift
//  Spaceman
//

import Cocoa
import SwiftUI

// MARK: - ViewModel

final class FloatingPanelViewModel: ObservableObject {
    @Published var spaces: [Space] = []
}

// MARK: - SpaceFloatingPanel

final class SpaceFloatingPanel: NSPanel {

    private var hostingView: NSHostingView<FloatingPanelView>?
    let viewModel = FloatingPanelViewModel()

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
        isMovableByWindowBackground = true

        setupView()
        positionDefault()
    }

    private func setupView() {
        let view = FloatingPanelView(viewModel: viewModel)
        let hosting = NSHostingView(rootView: view)
        contentView = hosting
        hostingView = hosting
    }

    func update(spaces: [Space]) {
        viewModel.spaces = spaces
        if let size = contentView?.fittingSize {
            setContentSize(size)
        }
        if !isVisible {
            orderFrontRegardless()
        }
    }

    func toggle() {
        if isVisible {
            orderOut(nil)
        } else {
            orderFrontRegardless()
        }
    }

    private func positionDefault() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - 100
        let y = visibleFrame.minY + 16
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - SwiftUI View

struct FloatingPanelView: View {
    @ObservedObject var viewModel: FloatingPanelViewModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(viewModel.spaces.enumerated()), id: \.offset) { _, space in
                FloatingChipView(space: space)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
        .environment(\.colorScheme, .dark)
    }
}

struct FloatingChipView: View {
    let space: Space

    var body: some View {
        Text(space.spaceName)
            .font(.system(size: 12, weight: space.isCurrentSpace ? .bold : .medium, design: .rounded))
            .foregroundColor(space.isCurrentSpace ? .white : .white.opacity(0.5))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                if space.isCurrentSpace {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.2))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: space.isCurrentSpace)
    }
}
