import SwiftUI

struct ScanGuide: View {
    let kind: DocType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = 0
    @State private var paperIn = false
    @State private var phoneIn = false
    @State private var scanning = false
    @State private var progress: CGFloat = 0
    @State private var done = false

    private var isCheck: Bool { kind == .check }

    private var captions: [String] {
        isCheck
            ? ["Lay the check flat", "Turn your phone sideways", "Hold still while it scans", "Got it"]
            : ["Lay the receipt flat", "Hold your phone above it", "Hold still while it scans", "Got it"]
    }

    var body: some View {
        VStack(spacing: ds(14)) {
            GeometryReader { g in
                let k = min(g.size.width / 354, g.size.height / 300)
                let paper = isCheck ? CGSize(width: 210 * k, height: 96 * k) : CGSize(width: 120 * k, height: 168 * k)
                let phone = isCheck ? CGSize(width: 282 * k, height: 148 * k) : CGSize(width: 150 * k, height: 238 * k)
                ZStack {
                    Group {
                        if isCheck { CheckPaper(k: k) } else { ReceiptPaper(k: k) }
                    }
                    .frame(width: paper.width, height: paper.height)
                    .opacity(paperIn ? 1 : 0)
                    .offset(y: paperIn ? 0 : -18 * k)

                    CornerBrackets(length: 16 * k)
                        .stroke(done ? Color.fsGreen : Color.fsAccent, style: StrokeStyle(lineWidth: 3.5 * k, lineCap: .round, lineJoin: .round))
                        .frame(width: paper.width + 14 * k, height: paper.height + 14 * k)
                        .opacity(scanning ? 1 : 0)
                        .scaleEffect(scanning ? 1 : 1.1)

                    Capsule()
                        .fill(Color.fsAccent)
                        .frame(width: paper.width + 4 * k, height: 2.5 * k)
                        .shadow(color: Color.fsAccent.opacity(0.6), radius: 5 * k)
                        .offset(y: (progress - 0.5) * paper.height)
                        .opacity(scanning && !done ? 1 : 0)

                    PhoneOutline(k: k, landscape: isCheck, scanning: scanning && !done)
                        .frame(width: phone.width, height: phone.height)
                        .rotationEffect(.degrees(phoneIn ? 0 : (isCheck ? -90 : 14)))
                        .offset(x: phoneIn ? 0 : g.size.width * 0.9, y: phoneIn ? 0 : 24 * k)

                    ZStack {
                        Circle().fill(Color.fsGreen)
                        Image(systemName: "checkmark").font(.system(size: 24 * k, weight: .bold)).foregroundStyle(.white)
                    }
                    .frame(width: 54 * k, height: 54 * k)
                    .scaleEffect(done ? 1 : 0.4)
                    .opacity(done ? 1 : 0)
                }
                .frame(width: g.size.width, height: g.size.height)
            }
            .frame(minHeight: ds(240), maxHeight: ds(400))
            .background(Color.fsSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.fsHairline, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(reduceMotion ? (isCheck ? "Lay the check flat and scan it sideways" : "Lay the receipt flat and hold your phone above it") : captions[phase])
                .font(.fs(ds(17), .semibold))
                .foregroundStyle(Color.fsText)
                .id(phase)
                .transition(.blurReplace)
                .frame(height: ds(24))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isCheck ? "Lay the check flat, turn your phone sideways and hold still while it scans." : "Lay the receipt flat, hold your phone above it and hold still while it scans.")
        .task(id: kind) { await run() }
    }

    @MainActor
    private func run() async {
        if reduceMotion {
            paperIn = true; phoneIn = true; scanning = true; progress = 0.5
            return
        }
        var reset = Transaction()
        reset.disablesAnimations = true
        withTransaction(reset) { phase = 0; paperIn = false; phoneIn = false; scanning = false; done = false; progress = 0 }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { paperIn = true }

        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(1250))
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.35)) { phase = 1 }
            withAnimation(.spring(response: 0.75, dampingFraction: 0.84)) { phoneIn = true }

            try? await Task.sleep(for: .milliseconds(1300))
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.35)) { phase = 2 }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { scanning = true }
            withAnimation(.easeInOut(duration: 1.2)) { progress = 1 }

            try? await Task.sleep(for: .milliseconds(1450))
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.35)) { phase = 3 }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.62)) { done = true }

            try? await Task.sleep(for: .milliseconds(1400))
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.35)) { phase = 0 }
            withAnimation(.easeIn(duration: 0.45)) { phoneIn = false; scanning = false; done = false }
            withTransaction(reset) { progress = 0 }
        }
    }
}

// MARK: - Pieces

private let paperFill = Color(light: Color(hex: 0xFCFCFB), dark: Color(hex: 0xE6E6E2))
private let inkDark = Color(hex: 0x3D3D42)
private let inkMid = Color(hex: 0xBEBEB9)
private let inkLight = Color(hex: 0xD8D8D3)

private func bar(_ w: CGFloat, _ h: CGFloat, _ c: Color, _ k: CGFloat) -> some View {
    Capsule().fill(c).frame(width: w * k, height: h * k)
}

private struct ReceiptPaper: View {
    let k: CGFloat
    var body: some View {
        ZStack(alignment: .top) {
            ReceiptShape(teeth: 8, depth: 6 * k)
                .fill(paperFill)
                .shadow(color: .black.opacity(0.10), radius: 6 * k, y: 3 * k)
            VStack(spacing: 7 * k) {
                bar(54, 7, inkDark, k)
                bar(34, 4, inkLight, k)
                VStack(spacing: 7 * k) {
                    ForEach([62.0, 48, 56, 40], id: \.self) { w in
                        HStack { bar(w, 5, inkMid, k); Spacer(); bar(18, 5, inkMid, k) }
                    }
                }
                .padding(.top, 6 * k)
                Line().stroke(inkLight, style: StrokeStyle(lineWidth: 1.2 * k, dash: [3 * k, 3 * k])).frame(height: 1)
                HStack { bar(32, 7, inkDark, k); Spacer(); bar(26, 7, inkDark, k) }
            }
            .padding(.horizontal, 14 * k)
            .padding(.top, 16 * k)
        }
    }
}

private struct CheckPaper: View {
    let k: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5 * k, style: .continuous)
                .fill(paperFill)
                .shadow(color: .black.opacity(0.10), radius: 6 * k, y: 3 * k)
            RoundedRectangle(cornerRadius: 5 * k, style: .continuous)
                .stroke(inkLight, lineWidth: 1 * k)
            VStack(alignment: .leading, spacing: 0) {
                HStack { bar(52, 6, inkDark, k); Spacer(); bar(24, 5, inkMid, k) }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 6 * k) {
                    bar(30, 4, inkLight, k)
                    Rectangle().fill(inkMid).frame(height: 1.2 * k)
                    RoundedRectangle(cornerRadius: 3 * k).stroke(inkMid, lineWidth: 1.2 * k)
                        .frame(width: 40 * k, height: 16 * k)
                        .overlay(Text("$").font(.system(size: 9 * k, weight: .bold)).foregroundStyle(inkDark))
                }
                Spacer(minLength: 0)
                Rectangle().fill(inkMid).frame(height: 1.2 * k).padding(.trailing, 50 * k)
                Spacer(minLength: 0)
                HStack(alignment: .bottom) {
                    HStack(spacing: 4 * k) { ForEach(0..<3, id: \.self) { _ in bar(18, 4, inkDark, k) } }
                    Spacer()
                    ZStack(alignment: .bottom) {
                        Signature().stroke(inkDark, style: StrokeStyle(lineWidth: 1.4 * k, lineCap: .round, lineJoin: .round))
                            .padding(.bottom, 3 * k)
                        Rectangle().fill(inkMid).frame(height: 1 * k)
                    }
                    .frame(width: 58 * k, height: 18 * k)
                }
            }
            .padding(12 * k)
        }
    }
}

private struct PhoneOutline: View {
    let k: CGFloat
    let landscape: Bool
    let scanning: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26 * k, style: .continuous)
                .fill(Color.fsAccent.opacity(scanning ? 0.06 : 0))
            RoundedRectangle(cornerRadius: 26 * k, style: .continuous)
                .strokeBorder(Color.fsText, lineWidth: 5 * k)
            Capsule()
                .fill(Color.fsText)
                .frame(width: (landscape ? 9 : 34) * k, height: (landscape ? 34 : 9) * k)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: landscape ? .leading : .top)
                .padding(landscape ? .leading : .top, 12 * k)
        }
    }
}

private struct CornerBrackets: Shape {
    var length: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        let l = min(length, r.width / 3, r.height / 3)
        p.move(to: CGPoint(x: r.minX, y: r.minY + l)); p.addLine(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + l, y: r.minY))
        p.move(to: CGPoint(x: r.maxX - l, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY + l))
        p.move(to: CGPoint(x: r.maxX, y: r.maxY - l)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.maxX - l, y: r.maxY))
        p.move(to: CGPoint(x: r.minX + l, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY - l))
        return p
    }
}

private struct ReceiptShape: Shape {
    var teeth: Int
    var depth: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        let w = r.width / CGFloat(teeth)
        for i in 0..<teeth {
            let x = r.maxX - CGFloat(i) * w
            p.addLine(to: CGPoint(x: x - w / 2, y: r.maxY - depth))
            p.addLine(to: CGPoint(x: x - w, y: r.maxY))
        }
        p.closeSubpath()
        return p
    }
}

private struct Line: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        return p
    }
}

private struct Signature: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.minX + w * 0.04, y: r.minY + h * 0.75))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.30, y: r.minY + h * 0.30), control1: CGPoint(x: r.minX + w * 0.12, y: r.minY + h * 0.05), control2: CGPoint(x: r.minX + w * 0.22, y: r.minY + h * 0.95))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.58, y: r.minY + h * 0.55), control1: CGPoint(x: r.minX + w * 0.38, y: r.minY - h * 0.1), control2: CGPoint(x: r.minX + w * 0.48, y: r.minY + h * 1.0))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.96, y: r.minY + h * 0.35), control1: CGPoint(x: r.minX + w * 0.70, y: r.minY + h * 0.15), control2: CGPoint(x: r.minX + w * 0.82, y: r.minY + h * 0.70))
        return p
    }
}
