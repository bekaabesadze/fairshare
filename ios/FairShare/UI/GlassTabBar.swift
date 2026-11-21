import SwiftUI

// MARK: - Floating glass tab bar

@Observable
final class FSTabBarLeadIn {
    var value: CGFloat = 0
}

@Observable
final class FSTabBarMetrics {
    var bottomPadding: CGFloat?
}

struct FSTabBarItem {
    enum Glyph {
        case symbol(outline: String, filled: String)
    }

    let glyph: Glyph
    let hint: String
    var badge: Int = 0
}

struct FSGlassTabBar: View {
    let items: [FSTabBarItem]
    let selectedIndex: Int
    let isMinimized: Bool
    let onSelect: (Int) -> Void
    let onInteraction: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(FSTabBarLeadIn.self) private var leadIn: FSTabBarLeadIn?

    @GestureState private var isTouching = false
    @State private var isPressed = false
    @State private var fingerX: CGFloat?
    @State private var touchDownX: CGFloat = 0
    @State private var isDragging = false

    static let barHeight: CGFloat = ds(58)
    static let horizontalMargin: CGFloat = ds(22)

    private static let coordinateSpaceName = "FSGlassTabBar"
    private static let minimizedScale: CGFloat = 0.837
    private static let pressedScale: CGFloat = 1.037
    private static let shrinkLeadInFraction: CGFloat = 0.2
    private static let growLeadInFraction: CGFloat = 0.25
    private static let dragThreshold: CGFloat = ds(6)
    private static let contentPadding: CGFloat = ds(10)
    private static let lensInset: CGFloat = ds(5)
    private static let maxStretch: CGFloat = ds(26)

    var body: some View {
        GeometryReader { proxy in
            let layout = layout(for: proxy.size.width)

            ZStack(alignment: .leading) {
                FSGlassCapsule()

                lens(layout: layout)
                    .clipShape(Capsule(style: .continuous))

                icons(layout: layout)
            }
            .frame(width: layout.width, height: Self.barHeight)
            .contentShape(Capsule(style: .continuous))
            .gesture(dragGesture(baseWidth: proxy.size.width))
            .offset(x: -layout.stretchLeading)
            .scaleEffect(barScale, anchor: .center)
            .animation(isPressed ? pressAnimation : barReleaseAnimation, value: isPressed)
            .animation(minimizeAnimation, value: isEffectivelyMinimized)
            .animation(isPressed ? trackingAnimation : barReleaseAnimation, value: layout.width)
        }
        .frame(height: Self.barHeight)
        .coordinateSpace(name: Self.coordinateSpaceName)
        .onChange(of: isTouching) { _, touching in
            if !touching && isPressed {
                withAnimation(glideAnimation) {
                    isPressed = false
                    isDragging = false
                    fingerX = nil
                }
            }
        }
    }

    // MARK: Layout

    private func layout(for baseWidth: CGFloat) -> GlassTabBarLayout {
        let resting = GlassTabBarLayout(
            baseWidth: baseWidth, count: items.count, padding: Self.contentPadding
        )
        guard let fingerX, isPressed, !reduceMotion else { return resting }

        let overLeading = max(0, resting.center(0) - fingerX)
        let overTrailing = max(0, fingerX - resting.center(items.count - 1))
        return GlassTabBarLayout(
            baseWidth: baseWidth,
            count: items.count,
            padding: Self.contentPadding,
            stretchLeading: Self.rubberBand(overLeading),
            stretchTrailing: Self.rubberBand(overTrailing)
        )
    }

    private static func rubberBand(_ distance: CGFloat) -> CGFloat {
        guard distance > 0 else { return 0 }
        return maxStretch * (1 - 1 / (distance / maxStretch * 0.6 + 1))
    }

    private var isEffectivelyMinimized: Bool {
        isMinimized && !isPressed
    }

    private var barScale: CGFloat {
        if isPressed { return reduceMotion ? 1 : Self.pressedScale }
        return Self.scrollScale(
            minimized: isEffectivelyMinimized,
            lead: leadIn?.value ?? 0,
            reduceMotion: reduceMotion
        )
    }

    // MARK: Shared with other floating controls

    static func bottomPadding(safeBottom: CGFloat) -> CGFloat {
        safeBottom > 0 ? max(safeBottom - ds(6), ds(14)) : ds(18)
    }

    static func scrollScale(minimized: Bool, lead: CGFloat, reduceMotion: Bool) -> CGFloat {
        let lead = reduceMotion ? 0 : min(max(lead, 0), 1)
        let range = 1 - minimizedScale
        return minimized
            ? minimizedScale + range * growLeadInFraction * lead
            : 1 - range * shrinkLeadInFraction * lead
    }

    static func minimizeSpring(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.37, dampingFraction: 0.73)
    }

    // MARK: Lens

    private func lens(layout: GlassTabBarLayout) -> some View {
        let lifted = isPressed
        let restingWidth = layout.slotWidth + Self.lensInset * 2
        let width = restingWidth * (lifted ? 1.14 : 1)
        let height = Self.barHeight - (lifted ? ds(4) : Self.lensInset * 2)
        let center = lensCenter(layout: layout)

        return Capsule(style: .continuous)
            .fill(lensFill(lifted: lifted))
            .overlay {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(colorScheme == .dark ? 0.12 : 0.5), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(lifted ? 1 : 0)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        .white.opacity(colorScheme == .dark ? 0.2 : 0.75),
                        lineWidth: ds(0.7)
                    )
                    .opacity(lifted ? 1 : 0)
            }
            .shadow(
                color: .black.opacity(lifted ? (colorScheme == .dark ? 0.3 : 0.14) : 0),
                radius: ds(8), x: 0, y: ds(2)
            )
            .frame(width: width, height: height)
            .position(x: center, y: Self.barHeight / 2)
            .animation(lifted && isDragging ? trackingAnimation : glideAnimation, value: center)
            .animation(pressAnimation, value: lifted)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func lensCenter(layout: GlassTabBarLayout) -> CGFloat {
        guard isPressed, let fingerX else {
            return layout.center(min(max(selectedIndex, 0), items.count - 1))
        }
        let local = fingerX + layout.stretchLeading
        return min(max(local, layout.center(0)), layout.center(items.count - 1))
    }

    private func lensFill(lifted: Bool) -> Color {
        if colorScheme == .dark {
            return .white.opacity(lifted ? 0.22 : 0.13)
        }
        return lifted ? .white.opacity(0.62) : .black.opacity(0.07)
    }

    // MARK: Icons

    private func icons(layout: GlassTabBarLayout) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isSelected = selectedIndex == index
                FSTabGlyph(glyph: item.glyph, isSelected: isSelected)
                    .overlay(alignment: .topTrailing) {
                        if item.badge > 0 {
                            Text("\(item.badge)")
                                .font(.fs(ds(10.5), .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, ds(4.5))
                                .frame(minWidth: ds(17), minHeight: ds(17))
                                .background(Color.fsRed, in: Capsule())
                                .offset(x: ds(11), y: ds(-7))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(width: layout.slotWidth, height: Self.barHeight)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(item.badge > 0 ? "\(item.hint), \(item.badge) waiting" : item.hint)
                    .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                    .accessibilityAction {
                        onInteraction()
                        onSelect(index)
                    }
            }
        }
        .padding(.horizontal, Self.contentPadding)
        .foregroundStyle(Color.primary)
    }

    // MARK: Gesture

    private func dragGesture(baseWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpaceName))
            .updating($isTouching) { _, state, _ in
                state = true
            }
            .onChanged { value in
                var x = value.location.x
                if !isPressed {
                    if isMinimized {
                        x = baseWidth / 2 + (x - baseWidth / 2) / Self.minimizedScale
                    }
                    onInteraction()
                    leadIn?.value = 0
                    touchDownX = x
                    isDragging = false
                    isPressed = true
                } else if !isDragging, abs(x - touchDownX) > Self.dragThreshold {
                    isDragging = true
                }
                fingerX = x
            }
            .onEnded { value in
                let resting = GlassTabBarLayout(
                    baseWidth: baseWidth, count: items.count, padding: Self.contentPadding
                )
                let index = resting.index(at: fingerX ?? value.location.x)
                withAnimation(glideAnimation) {
                    isPressed = false
                    isDragging = false
                    fingerX = nil
                }
                onInteraction()
                onSelect(index)
            }
    }

    // MARK: Animation

    private var trackingAnimation: Animation {
        reduceMotion ? .linear(duration: 0.01) : .interactiveSpring(response: 0.2, dampingFraction: 0.8)
    }

    private var pressAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.26, dampingFraction: 0.7)
    }

    private var glideAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.39, dampingFraction: 0.72)
    }

    private var barReleaseAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.32, dampingFraction: 0.72)
    }

    private var minimizeAnimation: Animation {
        Self.minimizeSpring(reduceMotion: reduceMotion)
    }
}

// MARK: - Layout maths

private struct GlassTabBarLayout {
    let baseWidth: CGFloat
    let count: Int
    let padding: CGFloat
    var stretchLeading: CGFloat = 0
    var stretchTrailing: CGFloat = 0

    var width: CGFloat { baseWidth + stretchLeading + stretchTrailing }

    var slotWidth: CGFloat {
        max((width - padding * 2) / CGFloat(max(count, 1)), 1)
    }

    func center(_ index: Int) -> CGFloat {
        padding + slotWidth * (CGFloat(index) + 0.5)
    }

    func index(at x: CGFloat) -> Int {
        let raw = Int(((x - padding) / slotWidth).rounded(.down))
        return min(max(raw, 0), max(count - 1, 0))
    }
}

// MARK: - Glass surface

private struct FSGlassCapsule: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if #available(iOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(tint), in: Capsule(style: .continuous))
        } else {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(tint))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: rimColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: ds(0.8)
                        )
                )
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.34 : 0.14),
                    radius: ds(14), x: 0, y: ds(6)
                )
        }
    }

    private var tint: Color {
        colorScheme == .dark ? .black.opacity(0.42) : .white.opacity(0.18)
    }

    private var rimColors: [Color] {
        colorScheme == .dark
            ? [.white.opacity(0.34), .white.opacity(0.06), .white.opacity(0.2)]
            : [.white.opacity(0.9), .white.opacity(0.35), .white.opacity(0.7)]
    }
}

// MARK: - Icons

private struct FSTabGlyph: View {
    let glyph: FSTabBarItem.Glyph
    let isSelected: Bool

    var body: some View {
        Group {
            switch glyph {
            case .symbol(let outline, let filled):
                ZStack {
                    Image(systemName: outline)
                        .opacity(isSelected ? 0 : 1)
                    Image(systemName: filled)
                        .opacity(isSelected ? 1 : 0)
                }
                .font(.fs(ds(22), .medium))
            }
        }
        .animation(.easeOut(duration: 0.14), value: isSelected)
    }
}


// MARK: - Minimize-on-scroll modifier
private struct MinimizeBarOnScrollModifier: ViewModifier {
    @Binding var minimized: Bool
    @Environment(FSTabBarLeadIn.self) private var leadIn: FSTabBarLeadIn?
    @State private var tracker = MinimizeBarScrollTracker()

    private static let shrinkCommit: CGFloat = 26
    private static let growDeadZone: CGFloat = 175
    private static let growCommit: CGFloat = 240

    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            guard tracker.hasObservedInitialOffset else {
                tracker.hasObservedInitialOffset = true
                tracker.lastY = newValue
                restore()
                return
            }
            let delta = newValue - tracker.lastY
            tracker.lastY = newValue

            if newValue <= 0 {
                restore()
                return
            }
            if tracker.measuredAgainstMinimized != minimized {
                tracker.travel = 0
                tracker.measuredAgainstMinimized = minimized
            }

            if !minimized {
                tracker.travel = max(0, tracker.travel + delta)
                if tracker.travel >= Self.shrinkCommit {
                    commit(minimized: true)
                } else {
                    setLeadIn(tracker.travel / Self.shrinkCommit)
                }
            } else {
                tracker.travel = max(0, tracker.travel - delta)
                if tracker.travel >= Self.growCommit {
                    commit(minimized: false)
                } else {
                    let past = tracker.travel - Self.growDeadZone
                    setLeadIn(max(0, past / (Self.growCommit - Self.growDeadZone)))
                }
            }
        }
    }

    private func commit(minimized newValue: Bool) {
        tracker.travel = 0
        tracker.measuredAgainstMinimized = newValue
        setLeadIn(0)
        minimized = newValue
    }

    private func restore() {
        tracker.travel = 0
        tracker.measuredAgainstMinimized = false
        setLeadIn(0)
        if minimized { minimized = false }
    }

    private func setLeadIn(_ value: CGFloat) {
        guard let leadIn, leadIn.value != value else { return }
        leadIn.value = value
    }
}

private final class MinimizeBarScrollTracker {
    var hasObservedInitialOffset = false
    var lastY: CGFloat = 0
    var travel: CGFloat = 0
    var measuredAgainstMinimized = false
}

extension View {
    func minimizeBarOnScroll(_ minimized: Binding<Bool>) -> some View {
        modifier(MinimizeBarOnScrollModifier(minimized: minimized))
    }
}

