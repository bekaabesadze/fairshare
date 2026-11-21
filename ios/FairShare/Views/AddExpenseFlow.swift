import SwiftUI
import PhotosUI
import VisionKit

struct AddExpenseFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(ShellState.self) private var shell
    enum Step { case type, capture, scan, review, done }

    @State private var step: Step = .type
    @State private var docType: DocType = .receipt
    @State private var image: UIImage?
    @State private var imagePath: String?
    @State private var found: [String] = []
    @State private var scanned: [String] = []
    @State private var scanError: String?
    @State private var mismatch: DocType?
    @State private var photo: PhotosPickerItem?
    @State private var showCamera = false
    @State private var noCamera = false
    @State private var submitted: Expense?

    @State private var vendor = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var category: CategoryId?
    @State private var details = ""
    @State private var tax = ""
    @State private var items: [LineItem] = []
    @State private var checkNumber = ""
    @State private var memo = ""
    @State private var tried = false

    var body: some View {
        NavigationStack {
            container
        }
        .onChange(of: step) { _, newStep in updateBar(newStep) }
        .onChange(of: shell.selected) { _, _ in resetIfDone() }
        .onChange(of: shell.addStart) { _, t in start(t) }
        .onAppear { start(shell.addStart) }
        .fullScreenCover(isPresented: $showCamera) { camera }
        .alert("No camera on this device", isPresented: $noCamera) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Choose a photo from your library instead.")
        }
    }

    private func updateBar(_ s: Step) {
        let focused: Set<Step> = [.capture, .scan, .review]
        shell.addFocused = focused.contains(s)
    }

    private func start(_ type: DocType?) {
        guard let type else { return }
        shell.addStart = nil
        reset()
        docType = type
        step = .capture
    }

    private func resetIfDone() {
        if step == Step.done { reset() }
    }

    private var container: some View {
        VStack(spacing: 0) {
            if step != .done {
                progressHeader
            }
            stepContent
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: step)
        .background(Color.fsBackground)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .type: typeStep
        case .capture: captureStep
        case .scan: scanStep
        case .review: reviewStep
        case .done: doneStep
        }
    }

    private var camera: some View {
        DocumentCamera { img in
            showCamera = false
            if let img { Task { await scan(img, path: nil) } }
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var progressHeader: some View {
        let idx: Double = step == .type ? 1 : step == .capture ? 2 : 3
        return HStack(spacing: 12) {
            Button {
                switch step {
                case .capture: step = .type
                case .review, .scan: step = .capture
                default: shell.selected = 0
                }
            } label: {
                Image(systemName: step == .type ? "xmark" : "chevron.left").font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.fsText2).frame(width: 44, height: 44)
            }
            .accessibilityLabel(step == .type ? "Close" : "Back")
            GeometryReader { g in
                HStack(spacing: 6) {
                    ForEach(1...3, id: \.self) { i in
                        Capsule().fill(Double(i) <= idx ? Color.fsAccent : Color.fsSurface3).frame(height: 5)
                    }
                }
                .frame(width: g.size.width, height: g.size.height)
            }
            .frame(height: 8)
            Text("\(Int(idx))/3").font(.fs(13, .medium)).monospacedDigit().foregroundStyle(Color.fsText3).frame(width: 30)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: Step 1

    private var typeStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("What are you adding?").font(.fsLarge).tracking(-0.5)
                VStack(spacing: 12) {
                    ChoiceTile(symbol: "receipt", title: "A receipt", selected: false) {
                        docType = .receipt; step = .capture
                    }
                    ChoiceTile(symbol: "building.columns", title: "A check or payment document", selected: false) {
                        docType = .check; step = .capture
                    }
                }
                .padding(.top, 24)
                BarClearance()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }

    // MARK: Step 2

    private var captureStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(docType == .check ? "Scan your check" : "Scan your receipt").font(.fsLarge).tracking(-0.5)

            ScanGuide(kind: docType)
                .padding(.top, ds(18))
                .layoutPriority(1)

            Spacer(minLength: ds(20))

            VStack(spacing: 10) {
                Button {
                    if VNDocumentCameraViewController.isSupported { showCamera = true } else { noCamera = true }
                } label: { Label("Take a photo", systemImage: "camera.fill") }
                    .buttonStyle(FSButtonStyle())
                PhotosPicker(selection: $photo, matching: .images) {
                    Label("Choose from library", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(FSButtonStyle(kind: .secondary))
                .onChange(of: photo) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) { await scan(img, path: nil) }
                        photo = nil
                    }
                }
            }

            HStack {
                Button {
                    let name = docType == .check ? "check-uptous" : "bookshop"
                    if let img = UIImage(named: "sample-\(name)") { Task { await scan(img, path: "/samples/\(name).png") } }
                } label: {
                    Label("Try a sample", systemImage: "sparkles")
                        .font(.fs(ds(15), .semibold))
                        .foregroundStyle(Color.fsAccentText)
                        .frame(height: 44)
                }
                .buttonStyle(PressableStyle())
                Spacer()
                Button {
                    resetForm()
                    image = nil; imagePath = nil; scanned = []; scanError = nil
                    step = .review
                } label: {
                    Text("Enter manually").font(.fs(ds(15), .medium)).foregroundStyle(Color.fsText2).frame(height: 44)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: Step 3a

    private var scanStep: some View {
        VStack(spacing: 24) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.fsSurface2)
                if let image { Image(uiImage: image).resizable().scaledToFit().padding(18) }
                ScanLine()
            }
            .frame(height: ds(360))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            VStack(alignment: .leading, spacing: 10) {
                MicroLabel(text: "Scanning on this iPhone", color: .fsAccentText)
                Text("Reading your \(docType.rawValue)…").font(.fsTitle)
                ForEach(found, id: \.self) { k in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(Color.fsGreen)
                        Text("Found the \(label(k))").font(.fs(ds(16), .medium))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if found.isEmpty { ProgressView().padding(.top, 4) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: Step 3b

    private var reviewStep: some View {
        let org = store.officerOrg
        let s = org.map { store.state.summary($0.id) }
        let amt = Double(amount) ?? 0
        let after = (s?.available ?? 0) - amt
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Check the details").font(.fsLarge).tracking(-0.5)
                if let img = image ?? imagePath.flatMap(ReceiptImage.localImage) {
                    Image(uiImage: img).resizable().scaledToFit()
                        .frame(maxWidth: .infinity).frame(height: ds(170))
                        .padding(12)
                        .background(Color.fsSurface2, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                if let scanError {
                    note(scanError, symbol: "exclamationmark.triangle.fill", tint: .fsAmberText, bg: .fsAmberSoft)
                } else if !scanned.isEmpty {
                    note("Filled in \(scanned.count) details from the scan", symbol: "sparkles", tint: .fsAccent, bg: .fsAccentSoft)
                }
                if let mismatch {
                    HStack {
                        note("This looks like a \(mismatch.rawValue), not a \(docType.rawValue).", symbol: "exclamationmark.triangle.fill", tint: .fsAmberText, bg: .fsAmberSoft)
                        Button("Switch") {
                            docType = mismatch
                            if let img = image ?? imagePath.flatMap(ReceiptImage.localImage) { Task { await scan(img, path: imagePath) } }
                        }
                        .font(.fs(14, .semibold))
                    }
                }

                field("Total amount", key: "amount", error: tried && amt <= 0 ? "Enter the total amount." : nil) {
                    HStack(spacing: 2) {
                        Text("$").foregroundStyle(amount.isEmpty ? Color.fsText3 : Color.fsText)
                        TextField("0.00", text: $amount).keyboardType(.decimalPad)
                    }
                    .font(.fs(ds(30), .semibold)).monospacedDigit()
                    .padding(.horizontal, 14).frame(height: ds(64))
                    .background(Color.fsSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                field(docType == .check ? "Paid to" : "Store or vendor", key: "vendor", error: tried && vendor.trimmingCharacters(in: .whitespaces).isEmpty ? "Where did you buy it?" : nil) {
                    input($vendor, docType == .check ? "Who received the check" : "e.g. Luther Book Shop")
                }
                field("Date", key: "date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if docType == .check {
                    HStack(spacing: 12) {
                        field("Check no.", key: "checkNumber") { input($checkNumber, "1042").keyboardType(.numberPad) }.frame(width: ds(160))
                        field("Memo", key: "memo") { input($memo, "Memo line") }
                    }
                }
                field("Category", key: "category", error: tried && category == nil ? "Pick a category." : nil) {
                    FlowChips(selected: $category)
                }
                field("What was it for?", key: "", error: tried && details.trimmingCharacters(in: .whitespaces).count < 3 ? "Add a few words about what it was for." : nil) {
                    input($details, "e.g. Prizes for the Up to Us Day of Action")
                }
                if docType == .receipt && !items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { Text("Items & tax").font(.fs(13, .semibold)).foregroundStyle(Color.fsText2); scannedTag("items") }
                        ForEach(items, id: \.self) { it in
                            HStack { Text(it.name); Spacer(); Text(Fmt.usd(it.amount)).monospacedDigit() }.font(.fs(ds(14.5)))
                        }
                        if !tax.isEmpty { HStack { Text("Tax").foregroundStyle(Color.fsText2); Spacer(); Text("$\(tax)").monospacedDigit() }.font(.fs(ds(14.5))) }
                    }
                    .padding(14)
                    .background(Color.fsSurface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if let s {
                    VStack(spacing: 8) {
                        HStack { Text("Safe to spend now").foregroundStyle(Color.fsText2); Spacer(); Text(Fmt.usd(s.available)).fontWeight(.semibold).monospacedDigit() }
                        HStack { Text("After this expense").foregroundStyle(Color.fsText2); Spacer(); Text(Fmt.usd(after)).fontWeight(.semibold).monospacedDigit().foregroundStyle(after < 0 ? Color.fsRedText : Color.fsText) }
                        if after < 0 { Text("More than you can safely spend").font(.fsCaption).foregroundStyle(Color.fsRedText) }
                    }
                    .font(.fs(ds(14.5)))
                    .card(padding: 16)
                }
                Button("Submit for review", action: submit).buttonStyle(FSButtonStyle())
                Color.clear.frame(height: 30)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Step 4

    private var doneStep: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle().fill(Color.fsGreen).frame(width: ds(92), height: ds(92))
                Image(systemName: "checkmark").font(.system(size: ds(42), weight: .bold)).foregroundStyle(.white)
            }
            Text("Sent for review").font(.fsLarge).padding(.top, 22)
            Text("We’ll let you know when it’s approved.")
                .font(.fsBody).foregroundStyle(Color.fsText2).multilineTextAlignment(.center).padding(.top, 8).padding(.horizontal, 32)
            if let e = submitted {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.vendor).font(.fsHead)
                            Text(Fmt.longDate(e.date)).font(.fsCaption).foregroundStyle(Color.fsText2)
                        }
                        Spacer()
                        Text(Fmt.usd(e.amount)).font(.fsTitle).monospacedDigit()
                    }
                    if e.image != nil, let img = image ?? imagePath.flatMap(ReceiptImage.localImage) {
                        Image(uiImage: img).resizable().scaledToFill()
                            .frame(height: ds(120)).frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .accessibilityLabel("Receipt photo attached")
                    }
                    Divider()
                    HStack {
                        StatusPill(status: .pending)
                        Spacer(minLength: 0)
                        let delivered = store.deliveredExpenses.contains(e.id)
                        HStack(spacing: 6) {
                            if delivered {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.fsGreen)
                            } else {
                                ProgressView().controlSize(.small)
                            }
                            Text(delivered ? "Delivered" : "Sending…")
                                .font(.fs(13, .semibold))
                                .foregroundStyle(delivered ? Color.fsGreenText : Color.fsText2)
                        }
                        .animation(fsSpring, value: delivered)
                    }
                }
                .card()
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }
            Spacer()
            VStack(spacing: 10) {
                Button("Back to Home") { reset(); shell.selected = 0 }.buttonStyle(FSButtonStyle())
                Button("Add another") { reset() }.buttonStyle(FSButtonStyle(kind: .secondary))
            }
            .padding(.horizontal, 24)
            BarClearance()
        }
    }

    // MARK: Logic

    @MainActor
    private func scan(_ img: UIImage, path: String?) async {
        image = img
        imagePath = path
        found = []
        scanError = nil
        mismatch = nil
        step = .scan
        let started = Date()
        do {
            let text = try await ReceiptScanner.recognize(img)
            let parsed = ReceiptScanner.parse(text, as: docType)
            let detected = ReceiptScanner.detectType(text)
            if detected != docType && !text.isEmpty { mismatch = detected }
            let wait = 0.9 - Date().timeIntervalSince(started)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            for k in ["vendor", "date", "amount", "tax", "items", "checkNumber", "memo"] where parsed.found.contains(k) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { found.append(k) }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                try? await Task.sleep(for: .seconds(0.17))
            }
            resetForm()
            vendor = parsed.vendor ?? ""
            amount = parsed.amount.map { String(format: "%.2f", $0) } ?? ""
            if let d = parsed.date { date = Fmt.date(d) }
            category = parsed.category
            tax = parsed.tax.map { String(format: "%.2f", $0) } ?? ""
            items = parsed.items
            checkNumber = parsed.checkNumber ?? ""
            memo = parsed.memo ?? ""
            details = parsed.memo ?? ""
            scanned = parsed.found + (parsed.category != nil ? ["category"] : [])
            if parsed.found.isEmpty { scanError = "We couldn’t read this one clearly. Please fill in the details." }
            try? await Task.sleep(for: .seconds(0.45))
            step = .review
        } catch {
            scanError = "Scanning isn’t available right now. Please fill in the details."
            step = .review
        }
    }

    private func submit() {
        tried = true
        let amt = Double(amount) ?? 0
        guard let org = store.officerOrg, let uid = store.userId, amt > 0, let category,
              !vendor.trimmingCharacters(in: .whitespaces).isEmpty, details.trimmingCharacters(in: .whitespaces).count >= 3 else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        let now = Fmt.nowISO()
        let e = Expense(
            id: newId("ex"), orgId: org.id, docType: docType, vendor: vendor.trimmingCharacters(in: .whitespaces), category: category,
            description: details.trimmingCharacters(in: .whitespaces), amount: amt.rounded2, tax: Double(tax), date: Fmt.dayString(date),
            items: items.isEmpty ? nil : items, checkNumber: docType == .check && !checkNumber.isEmpty ? checkNumber : nil,
            memo: docType == .check && !memo.isEmpty ? memo : nil,
            image: imagePath ?? image?.dataURL(), scanned: scanned, status: .pending, submittedBy: uid, submittedAt: now,
            reviewNote: nil, reviewedBy: nil, reviewedAt: nil, history: [ExpenseEvent(at: now, by: uid, action: "submitted", note: nil)])
        store.dispatch(WireAction(type: "expense/submit", expense: e))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        submitted = e
        step = .done
    }

    private func resetForm() {
        vendor = ""; amount = ""; date = Date(); category = nil; details = ""; tax = ""; items = []; checkNumber = ""; memo = ""; tried = false
    }

    private func reset() {
        resetForm()
        image = nil; imagePath = nil; scanned = []; found = []; scanError = nil; mismatch = nil; submitted = nil
        step = .type
    }

    private func label(_ k: String) -> String {
        switch k {
        case "vendor": docType == .check ? "payee" : "store"
        case "amount": "total"
        case "checkNumber": "check number"
        default: k
        }
    }

    // MARK: Pieces

    private func note(_ text: String, symbol: String, tint: Color, bg: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(text).font(.fsCaption).foregroundStyle(Color.fsText)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder private func scannedTag(_ key: String) -> some View {
        if scanned.contains(key) {
            Label("Scanned", systemImage: "sparkles").font(.fs(11, .semibold)).foregroundStyle(Color.fsAccentText)
                .padding(.horizontal, 7).padding(.vertical, 2).background(Color.fsAccentSoft, in: Capsule())
                .fixedSize()
        }
    }

    private func field<C: View>(_ title: String, key: String, error: String? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(title).font(.fs(13, .semibold)).foregroundStyle(Color.fsText2).lineLimit(1).fixedSize()
                scannedTag(key)
            }
            content()
            if let error { Text(error).font(.fsCaption).foregroundStyle(Color.fsRedText) }
        }
    }

    private func input(_ text: Binding<String>, _ placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .font(.fs(ds(16)))
            .padding(.horizontal, 14).frame(height: ds(50))
            .background(Color.fsSurface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.fsHairline, lineWidth: 1))
    }
}

private struct FlowChips: View {
    @Binding var selected: CategoryId?
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(CategoryId.allCases) { c in
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(fsSpring) { selected = c }
                } label: {
                    Label(c.short, systemImage: c.symbol)
                        .font(.fs(ds(14), .medium))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(selected == c ? Color.fsBackground : Color.fsText)
                        .padding(.horizontal, 12).frame(height: ds(36))
                        .background(selected == c ? Color.fsText : Color.fsSurface, in: Capsule())
                        .overlay(Capsule().stroke(Color.fsHairline, lineWidth: selected == c ? 0 : 1))
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(selected == c ? .isSelected : [])
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, width: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxW { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: min(width, maxW), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

private struct ScanLine: View {
    @State private var down = false
    var body: some View {
        GeometryReader { g in
            Rectangle().fill(Color.fsAccent).frame(height: 2)
                .shadow(color: Color.fsAccent.opacity(0.6), radius: 8)
                .offset(y: down ? g.size.height - 12 : 12)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: down)
                .onAppear { down = true }
        }
    }
}

struct DocumentCamera: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: (UIImage?) -> Void
        init(_ f: @escaping (UIImage?) -> Void) { onFinish = f }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil)
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { onFinish(nil) }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { onFinish(nil) }
    }
}
