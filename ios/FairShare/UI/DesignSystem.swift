import SwiftUI

// MARK: - Device scaling

enum DeviceMetrics {
    static let referenceWidth: CGFloat = 402
    static let scale: CGFloat = {
        let w = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        return min(max(w / referenceWidth, 0.8), 1.0)
    }()
}

@inline(__always) func ds(_ v: CGFloat) -> CGFloat { v * DeviceMetrics.scale }

extension Font {
    static func fs(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(FSType.face(weight), fixedSize: size)
    }
}

extension Text {
    static func tightApostrophes(_ string: String, size: CGFloat) -> Text {
        var text = AttributedString(string)
        var rest = text.startIndex..<text.endIndex
        while let r = text[rest].range(of: "’") {
            text[r].kern = -size * 0.08
            rest = r.upperBound..<text.endIndex
        }
        return Text(text)
    }
}

enum FSType {
    static func face(_ weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: "PlusJakartaSans-Bold"
        case .semibold: "PlusJakartaSans-SemiBold"
        case .medium: "PlusJakartaSans-Medium"
        default: "PlusJakartaSans-Regular"
        }
    }
}

// MARK: - Color

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
    init(light: Color, dark: Color) {
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }

    static let fsBackground = Color(light: Color(hex: 0xF3F3F1), dark: Color(hex: 0x0B0B0C))
    static let fsSurface = Color(light: Color(hex: 0xFCFCFB), dark: Color(hex: 0x161618))
    static let fsSurface2 = Color(light: Color(hex: 0xEFEFEC), dark: Color(hex: 0x1F1F22))
    static let fsSurface3 = Color(light: Color(hex: 0xE5E5E1), dark: Color(hex: 0x2A2A2E))
    static let fsText = Color(light: Color(hex: 0x151517), dark: Color(hex: 0xF4F4F2))
    static let fsText2 = Color(light: Color(hex: 0x5D5D63), dark: Color(hex: 0xA4A4AA))
    static let fsText3 = Color(light: Color(hex: 0x8F8F95), dark: Color(hex: 0x6F6F76))
    static let fsHairline = Color(light: Color(hex: 0x151517, alpha: 0.08), dark: Color.white.opacity(0.08))

    static let fsAccent = Color(light: Color(hex: 0x2453E6), dark: Color(hex: 0x5B80FF))
    static let fsAccentText = Color(light: Color(hex: 0x1F49CF), dark: Color(hex: 0x86A2FF))
    static let fsAccentSoft = Color(light: Color(hex: 0x2453E6, alpha: 0.09), dark: Color(hex: 0x5B80FF, alpha: 0.15))
    static let fsGreen = Color(light: Color(hex: 0x1E9E5A), dark: Color(hex: 0x2FBF71))
    static let fsGreenText = Color(light: Color(hex: 0x157A45), dark: Color(hex: 0x4FD68C))
    static let fsGreenSoft = Color(light: Color(hex: 0x1E9E5A, alpha: 0.11), dark: Color(hex: 0x2FBF71, alpha: 0.15))
    static let fsAmber = Color(light: Color(hex: 0xE0A100), dark: Color(hex: 0xE8AB2C))
    static let fsAmberText = Color(light: Color(hex: 0x8F6400), dark: Color(hex: 0xF2C15C))
    static let fsAmberSoft = Color(light: Color(hex: 0xE0A100, alpha: 0.14), dark: Color(hex: 0xE8AB2C, alpha: 0.17))
    static let fsRed = Color(light: Color(hex: 0xD93B30), dark: Color(hex: 0xFF5A4F))
    static let fsRedText = Color(light: Color(hex: 0xB8291F), dark: Color(hex: 0xFF7D73))
    static let fsRedSoft = Color(light: Color(hex: 0xD93B30, alpha: 0.1), dark: Color(hex: 0xFF5A4F, alpha: 0.15))
    static let fsTrack = Color(light: Color(hex: 0xE7E7E3), dark: Color(hex: 0x26262A))
}

// MARK: - Type

extension Font {
    static let fsHero = Font.fs(ds(40), .bold)
    static let fsLarge = Font.fs(ds(32), .bold)
    static let fsTitle = Font.fs(ds(20), .semibold)
    static let fsHead = Font.fs(ds(17), .semibold)
    static let fsBody = Font.fs(ds(16))
    static let fsCaption = Font.fs(ds(13.5))
    static let fsMicro = Font.fs(ds(11.5), .semibold)
}

struct MicroLabel: View {
    let text: String
    var color: Color = .fsText3
    var body: some View {
        Text(text.uppercased()).font(.fsMicro).tracking(0.8).foregroundStyle(color)
    }
}

// MARK: - Surfaces

struct CardModifier: ViewModifier {
    var padding: CGFloat = ds(20)
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.fsSurface, in: RoundedRectangle(cornerRadius: ds(22), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ds(22), style: .continuous).stroke(Color.fsHairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func card(padding: CGFloat = ds(20)) -> some View { modifier(CardModifier(padding: padding)) }
}

// MARK: - Buttons

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct FSButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, tonal, approve, danger }
    var kind: Kind = .primary
    var height: CGFloat = ds(54)
    @Environment(\.isEnabled) private var enabled

    func makeBody(configuration: Configuration) -> some View {
        let (bg, fg): (Color, Color) = {
            switch kind {
            case .primary: (.fsAccent, .white)
            case .secondary: (.fsSurface2, .fsText)
            case .tonal: (.fsAccentSoft, .fsAccentText)
            case .approve: (.fsGreen, .white)
            case .danger: (.fsRedSoft, .fsRedText)
            }
        }()
        configuration.label
            .font(.fs(ds(16.5), .semibold))
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(bg, in: RoundedRectangle(cornerRadius: ds(15), style: .continuous))
            .opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Brand

struct LogoMark: View {
    var size: CGFloat = 40

    var body: some View {
        Image("brand-emblem")
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.74, height: size * 0.74)
            .frame(width: size, height: size)
            .background(.white, in: RoundedRectangle(cornerRadius: size * 0.225))
            .overlay(RoundedRectangle(cornerRadius: size * 0.225).strokeBorder(Color.fsHairline))
            .accessibilityHidden(true)
    }
}

// MARK: - Badges & pills

struct StatusPill: View {
    let status: ExpenseStatus
    var short = false
    var body: some View {
        let (icon, fg, bg): (String, Color, Color) = {
            switch status {
            case .approved: ("checkmark.circle.fill", .fsGreenText, .fsGreenSoft)
            case .pending: ("clock.fill", .fsAmberText, .fsAmberSoft)
            case .needsInfo: ("exclamationmark.circle.fill", .fsAccentText, .fsAccentSoft)
            case .rejected: ("xmark.circle.fill", .fsRedText, .fsRedSoft)
            }
        }()
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: ds(11.5), weight: .semibold))
            Text(short ? status.short : status.label).font(.fs(ds(12.5), .semibold))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 8)
        .frame(height: ds(24))
        .background(bg, in: Capsule())
        .fixedSize()
    }
}

struct CategoryBadge: View {
    let category: CategoryId
    var size: CGFloat = ds(44)
    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.42, weight: .regular))
            .foregroundStyle(Color.fsText2)
            .frame(width: size, height: size)
            .background(Color.fsSurface2, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
    }
}

enum ProfileImages {
    static let avatars: [String: String] = [
        "abessa01@luther.edu": "avatar-abessa01",
        "abesbe01@luther.edu": "avatar-abesbe01",
    ]
    static let orgLogos: [String: String] = [
        "uptous": "org-uptous",
    ]

    static func avatar(_ email: String?) -> String? {
        guard let email else { return nil }
        return avatars[email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }
}

struct OrgBadge: View {
    var orgId: String? = nil
    let initials: String
    var size: CGFloat = ds(44)
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
        if let id = orgId, let logo = ProfileImages.orgLogos[id] {
            Image(logo)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .background(Color.white)
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.fsHairline, lineWidth: 1))
                .accessibilityHidden(true)
        } else {
            Text(initials)
                .font(.fs(size * 0.34, .bold))
                .foregroundStyle(Color.fsBackground)
                .frame(width: size, height: size)
                .background(Color.fsText, in: shape)
        }
    }
}

struct AvatarView: View {
    let name: String
    var email: String? = nil
    var size: CGFloat = ds(36)
    var body: some View {
        if let photo = ProfileImages.avatar(email) {
            Image(photo)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .accessibilityLabel(name)
        } else {
            let initials = name.replacingOccurrences(of: "Prof. ", with: "").replacingOccurrences(of: "Dr. ", with: "").split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined()
            Text(initials)
                .font(.fs(size * 0.36, .semibold))
                .foregroundStyle(Color.fsText)
                .frame(width: size, height: size)
                .background(Color.fsSurface3, in: Circle())
        }
    }
}

// MARK: - Budget ring

struct BudgetRing<Center: View>: View {
    var allocated: Double
    var approved: Double
    var pending: Double
    var lineWidth: CGFloat = ds(18)
    @ViewBuilder var center: Center

    var body: some View {
        let total = max(allocated, 0.01)
        let available = max(0, allocated - approved - pending)
        let pendingVis = max(0, min(pending, allocated - approved))
        let fA = available / total
        let fP = pendingVis / total
        let low = allocated > 0 && available / allocated < 0.15
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let circumference = .pi * (side - lineWidth)
            let gap = (lineWidth + 4) / circumference
            ZStack {
                ZStack {
                    Circle().stroke(Color.fsTrack, lineWidth: lineWidth)
                    if fP > gap {
                        let from = fA + gap / 2
                        let to = max(from, fA + fP - gap / 2)
                        Circle().trim(from: from, to: to)
                            .stroke(Color.fsAmber.opacity(0.5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                        Circle().trim(from: from, to: to)
                            .stroke(Color.fsAmber, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt, dash: [2.5, 3]))
                            .mask(Circle().trim(from: from, to: to).stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)))
                    }
                    if fA > 0.002 {
                        Circle().trim(from: gap / 2, to: max(gap / 2, fA - gap / 2))
                            .stroke(low ? Color.fsRed : Color.fsAccent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    }
                }
                .padding(lineWidth / 2)
                .rotationEffect(.degrees(-90))
                center
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: approved)
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: pending)
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: allocated)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Fmt.usd(allocated - approved)) remaining of \(Fmt.usd(allocated)). \(Fmt.usd(pending)) pending.")
    }
}

// MARK: - Receipt image

struct ReceiptImage: View {
    @Environment(AppStore.self) private var store
    let path: String?
    var contentMode: ContentMode = .fit
    var compact = false

    var body: some View {
        Group {
            if let path, let local = Self.localImage(path) {
                Image(uiImage: local).resizable().aspectRatio(contentMode: contentMode)
            } else if let path, path.hasPrefix("/api/"), let url = store.fileURL(path) {
                RemoteReceipt(url: url, contentMode: contentMode)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text").font(.system(size: compact ? 20 : 28))
                    if !compact { Text("No document attached").font(.fsCaption) }
                }
                .foregroundStyle(Color.fsText3)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    static func localImage(_ path: String) -> UIImage? {
        if path.hasPrefix("/samples/") {
            let name = path.replacingOccurrences(of: "/samples/", with: "").replacingOccurrences(of: ".png", with: "")
            return UIImage(named: "sample-\(name)")
        }
        if path.hasPrefix("data:image"), let comma = path.firstIndex(of: ","), let data = Data(base64Encoded: String(path[path.index(after: comma)...])) {
            return UIImage(data: data)
        }
        return nil
    }
}

struct RemoteReceipt: View {
    let url: URL
    var contentMode: ContentMode = .fit
    @State private var image: UIImage?

    static let cache = NSCache<NSURL, UIImage>()

    var body: some View {
        Group {
            if let image = image ?? Self.cache.object(forKey: url as NSURL) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: url) {
            if let hit = Self.cache.object(forKey: url as NSURL) { image = hit; return }
            for attempt in 0..<20 {
                var req = URLRequest(url: url)
                req.timeoutInterval = 15
                if let (data, resp) = try? await URLSession.shared.data(for: req),
                   (resp as? HTTPURLResponse)?.statusCode == 200, let img = UIImage(data: data) {
                    Self.cache.setObject(img, forKey: url as NSURL)
                    image = img
                    return
                }
                if Task.isCancelled { return }
                try? await Task.sleep(for: .seconds(attempt < 3 ? 0.5 : 1.5))
            }
        }
    }
}

// MARK: - Misc

struct SectionHeader: View {
    let title: String
    var action: String?
    var onAction: (() -> Void)?
    var body: some View {
        HStack {
            Text(title).font(.fsHead).foregroundStyle(Color.fsText)
            Spacer()
            if let action, let onAction {
                Button(action: onAction) {
                    HStack(spacing: 3) {
                        Text(action)
                        Image(systemName: "chevron.right").font(.system(size: ds(11), weight: .semibold))
                    }
                    .font(.fs(ds(14), .medium))
                    .foregroundStyle(Color.fsText2)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.fsCaption).foregroundStyle(Color.fsText2)
            Spacer(minLength: 16)
            Text(value).font(.fs(ds(14), .medium)).foregroundStyle(Color.fsText).multilineTextAlignment(.trailing)
        }
        .padding(.vertical, ds(10))
    }
}

extension Text {
    init(rich: String) {
        if let a = try? AttributedString(markdown: rich, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            self.init(a)
        } else {
            self.init(rich)
        }
    }
}

let fsSpring = Animation.spring(response: 0.35, dampingFraction: 0.86)

struct FSSearchField: View {
    @Binding var text: String
    var prompt: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: ds(15), weight: .medium)).foregroundStyle(Color.fsText3)
            TextField(prompt, text: $text)
                .font(.fs(ds(16)))
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: ds(16))).foregroundStyle(Color.fsText3)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: ds(42))
        .background(Color.fsSurface2, in: RoundedRectangle(cornerRadius: ds(13), style: .continuous))
    }
}
