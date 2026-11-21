import UIKit
import Vision

struct ParsedDocument {
    var docType: DocType
    var vendor: String?
    var date: String?
    var amount: Double?
    var tax: Double?
    var items: [LineItem] = []
    var checkNumber: String?
    var memo: String?
    var category: CategoryId?
    var found: [String] = []
}

enum ReceiptScanner {
    static func recognize(_ image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { return "" }
        return try await withCheckedThrowingContinuation { cont in
            let req = VNRecognizeTextRequest { req, err in
                if let err { cont.resume(throwing: err); return }
                let obs = (req.results as? [VNRecognizedTextObservation]) ?? []
                let pieces = obs.compactMap { o -> (box: CGRect, text: String)? in
                    guard let t = o.topCandidates(1).first?.string else { return nil }
                    return (o.boundingBox, t)
                }
                let sorted = pieces.sorted { $0.box.midY > $1.box.midY }
                var rows: [[(box: CGRect, text: String)]] = []
                for p in sorted {
                    if let last = rows.last?.first, abs(last.box.midY - p.box.midY) < max(last.box.height, p.box.height) * 0.55 {
                        rows[rows.count - 1].append(p)
                    } else {
                        rows.append([p])
                    }
                }
                let text = rows.map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: "  ") }.joined(separator: "\n")
                cont.resume(returning: text)
            }
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            let orientation = CGImagePropertyOrientation(image.imageOrientation)
            DispatchQueue.global(qos: .userInitiated).async {
                do { try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([req]) } catch { cont.resume(throwing: error) }
            }
        }
    }

    // MARK: Parsing

    static func detectType(_ text: String) -> DocType {
        let t = text.lowercased()
        let hits = ["pay\\s*to\\s*the", "order\\s*of", "\\bmemo\\b", "\\bdollars\\b", "authorized\\s*signature", "\\bno\\.\\s*\\d{3,6}"].filter { t.range(of: $0, options: .regularExpression) != nil }.count
        return hits >= 2 ? .check : .receipt
    }

    static func parse(_ text: String, as forced: DocType? = nil) -> ParsedDocument {
        let type = forced ?? detectType(text)
        return type == .check ? parseCheck(text) : parseReceipt(text)
    }

    private static func money(in line: String) -> [Double] {
        matches("\\$?\\s?(\\d{1,4}(?:,\\d{3})*\\.\\d{2})\\b", in: line).compactMap { Double($0.replacingOccurrences(of: ",", with: "")) }
    }

    private static func matches(_ pattern: String, in s: String, group: Int = 1) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { m in
            Range(m.range(at: group), in: s).map { String(s[$0]) }
        }
    }

    private static func firstMatch(_ pattern: String, in s: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
        return (0..<m.numberOfRanges).map { i in Range(m.range(at: i), in: s).map { String(s[$0]) } ?? "" }
    }

    static func findDate(_ s: String) -> String? {
        if let m = firstMatch("\\b(\\d{1,2})[/.-](\\d{1,2})[/.-](\\d{2,4})\\b", in: s), let mo = Int(m[1]), let d = Int(m[2]), mo >= 1, mo <= 12, d >= 1, d <= 31 {
            let y = m[3].count == 2 ? "20\(m[3])" : m[3]
            return String(format: "%@-%02d-%02d", y, mo, d)
        }
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        if let m = firstMatch("\\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\\.?\\s+(\\d{1,2}),?\\s+(\\d{4})", in: s),
           let i = months.firstIndex(of: m[1].lowercased()), let d = Int(m[2]) {
            return String(format: "%@-%02d-%02d", m[3], i + 1, d)
        }
        return nil
    }

    static func guessCategory(_ s: String) -> CategoryId? {
        let t = s.lowercased()
        let rules: [(CategoryId, String)] = [
            (.printing, "print|poster|flyer|copies|document center|banner"),
            (.food, "pizza|food|snack|drink|soda|coffee|catering|grocery|cookie|bagel|dining|co-?op"),
            (.transport, "\\bbus\\b|\\bvan\\b|fuel|\\bgas\\b|transport|jefferson lines|mileage"),
            (.prizes, "gift card|prize|giveaway|sticker|lanyard|water bottle|t-?shirt|book shop|bookshop|mug"),
            (.supplies, "tape|plates|cups|napkin|\\bdecorations?\\b|balloon|glow|party"),
            (.equipment, "kit|tool|cable|equipment|makerspace|solder|raspberry|gear"),
        ]
        return rules.first { t.range(of: $0.1, options: .regularExpression) != nil }?.0
    }

    private static func titleCase(_ s: String) -> String {
        s.lowercased().split(separator: " ").enumerated().map { i, w in
            let word = String(w)
            if i > 0, ["of", "and", "the", "at"].contains(word) { return word }
            return word.prefix(1).uppercased() + word.dropFirst()
        }.joined(separator: " ").replacingOccurrences(of: "'S ", with: "'s ")
    }

    static func parseReceipt(_ raw: String) -> ParsedDocument {
        var out = ParsedDocument(docType: .receipt)
        let lines = raw.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        func nameLike(_ l: String) -> Bool {
            l.range(of: "[a-z]{3,}", options: [.regularExpression, .caseInsensitive]) != nil &&
                l.range(of: "\\d{2,}", options: .regularExpression) == nil &&
                l.range(of: "^(date|time|tel|phone|www|http)", options: [.regularExpression, .caseInsensitive]) == nil && l.count <= 34
        }
        if let i = lines.firstIndex(where: nameLike) {
            var v = lines[i]
            if !v.contains(" "), i + 1 < lines.count, nameLike(lines[i + 1]), lines[i + 1] == lines[i + 1].uppercased() { v += " " + lines[i + 1] }
            out.vendor = titleCase(v.components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "'&.-")).inverted).joined())
            out.found.append("vendor")
        }
        if let d = findDate(raw) { out.date = d; out.found.append("date") }
        let totalLine = lines.first { $0.range(of: "\\btotal\\b", options: [.regularExpression, .caseInsensitive]) != nil && $0.range(of: "sub\\s*-?\\s*total", options: [.regularExpression, .caseInsensitive]) == nil && !money(in: $0).isEmpty }
        if let t = totalLine { out.amount = money(in: t).last }
        if out.amount == nil { out.amount = money(in: raw).max() }
        if out.amount != nil { out.found.append("amount") }
        if let t = lines.first(where: { $0.range(of: "\\btax\\b", options: [.regularExpression, .caseInsensitive]) != nil && !money(in: $0).isEmpty }) {
            out.tax = money(in: t).last
            out.found.append("tax")
        }
        let stop = lines.firstIndex { $0.range(of: "sub\\s*-?\\s*total|\\btotal\\b", options: [.regularExpression, .caseInsensitive]) != nil } ?? lines.count
        for l in lines.prefix(stop) {
            guard let price = money(in: l).last,
                  l.range(of: "total|tax|change|cash|visa|master|amex|debit|credit|paid|balance|auth|approved|tip|date|trans|order|store|reg", options: [.regularExpression, .caseInsensitive]) == nil else { continue }
            var name = l.replacingOccurrences(of: "\\$?\\s?\\d{1,4}(,\\d{3})*\\.\\d{2}", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            if let m = firstMatch("^(.*?)\\s+(\\d+)\\s*[@x]\\s*[\\d.]*$", in: name) { name = "\(m[1].trimmingCharacters(in: .whitespaces)) ×\(m[2])" }
            name = name.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            if name.count >= 3 { out.items.append(LineItem(name: name, amount: price)) }
        }
        if !out.items.isEmpty { out.found.append("items") }
        out.category = guessCategory("\(out.vendor ?? "")\n\(raw)")
        return out
    }

    static func parseCheck(_ raw: String) -> ParsedDocument {
        var out = ParsedDocument(docType: .check)
        let lines = raw.components(separatedBy: .newlines)
        if let line = lines.first(where: { $0.range(of: "\\$\\s?[\\d,]+\\.\\d{2}", options: .regularExpression) != nil && $0.components(separatedBy: "$")[0].range(of: "[a-z]{3,}", options: [.regularExpression, .caseInsensitive]) != nil }) {
            var tokens = line.components(separatedBy: "$")[0]
                .replacingOccurrences(of: "pay\\s*to\\s*the|order\\s*of", with: " ", options: [.regularExpression, .caseInsensitive])
                .split(separator: " ").map(String.init)
            while tokens.count > 1, tokens[0].range(of: "^[A-Z][a-zA-Z'&.-]+$", options: .regularExpression) == nil { tokens.removeFirst() }
            let payee = tokens.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if payee.count >= 3 { out.vendor = payee; out.found.append("vendor") }
        }
        if let m = firstMatch("\\$\\s?([\\d,]+\\.\\d{2})", in: raw), let v = Double(m[1].replacingOccurrences(of: ",", with: "")) { out.amount = v; out.found.append("amount") }
        if let m = firstMatch("\\bno\\.?\\s*(\\d{3,6})\\b", in: raw) { out.checkNumber = m[1]; out.found.append("checkNumber") }
        if let d = findDate(raw) { out.date = d; out.found.append("date") }
        if let m = firstMatch("memo[:\\s]+([^\\n]{3,60})", in: raw) {
            let memo = m[1].replacingOccurrences(of: "\\s{2,}.*$", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            if !memo.isEmpty { out.memo = memo; out.found.append("memo") }
        }
        out.category = guessCategory("\(out.vendor ?? "") \(out.memo ?? "")")
        return out
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

extension UIImage {
    func dataURL(maxSide: CGFloat = 1400, quality: CGFloat = 0.75) -> String? {
        let k = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * k, height: size.height * k)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let img = UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return img.jpegData(compressionQuality: quality).map { "data:image/jpeg;base64,\($0.base64EncodedString())" }
    }
}
