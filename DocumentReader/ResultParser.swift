import UIKit


struct FieldRow {
    let key: String
    let value: String
    let source: String
}


struct SecurityRow {
    let page: String
    let check: String
    let status: String
}


struct IdentityStats {
    let type: String
    let country: String
    let score: String
}

struct IdentityLine {
    let title: String
    let status: String
    let counts: String
    let ok: Bool
}

struct OverallResult {
    let kind: String
    let result: String
}

struct FieldItem {
    let id: String
    let value: String
    let score: String
}

struct FieldGroup {
    let source: String
    let items: [FieldItem]
}

struct CheckItem {
    let id: String
    let result: String
    let extra: String
}

struct CheckGroup {
    let kind: String
    let items: [CheckItem]
}


struct ResultImage {
    let category: String
    let source: String
    let image: UIImage
}


/**
 * Maps DocumentReader process JSON into UI fields.
 * Customer body: identity, readings[], tests[], images[], session.
 * Locate overlay still uses score / position.
 */
enum ResultParser {
    private static let longValue = 300


    static func pretty(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "(empty response)" }
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return summarizeLong(trimmed)
        }
        let sanitized = sanitize(obj)
        guard let out = try? JSONSerialization.data(withJSONObject: sanitized, options: [.prettyPrinted]),
              let text = String(data: out, encoding: .utf8) else {
            return summarizeLong(trimmed)
        }
        return text
    }


    private static func sanitize(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            return dict.mapValues { sanitize($0) }
        }
        if let arr = value as? [Any] {
            return arr.map { sanitize($0) }
        }
        if let s = value as? String, s.count > longValue {
            return summarizeLong(s)
        }
        return value
    }


    static func summarizeLong(_ value: String) -> String {
        let type: String
        if value.hasPrefix("/9j/") || value.hasPrefix("data:image/jpeg") {
            type = "jpeg"
        } else if value.hasPrefix("iVBOR") || value.hasPrefix("data:image/png") {
            type = "png"
        } else if value.hasPrefix("R0lGOD") || value.hasPrefix("data:image/gif") {
            type = "gif"
        } else if value.hasPrefix("Qk"), value.count > 100 {
            type = "bmp"
        } else if value.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "+" || $0 == "/" || $0 == "=" }) {
            type = "base64"
        } else {
            type = "string"
        }
        return "\(type), \(value.count) chars"
    }


    private static func jsonObject(_ raw: String) -> [String: Any]? {
        guard let data = raw.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return obj
    }


    private static func identity(_ obj: [String: Any]) -> [String: Any] {
        obj["identity"] as? [String: Any] ?? obj["document"] as? [String: Any] ?? [:]
    }

    private static func session(_ obj: [String: Any]) -> [String: Any] {
        obj["session"] as? [String: Any] ?? obj["metadata"] as? [String: Any] ?? [:]
    }

    private static func readings(_ obj: [String: Any]) -> [[String: Any]] {
        obj["readings"] as? [[String: Any]] ?? obj["fields"] as? [[String: Any]] ?? []
    }

    private static func tests(_ obj: [String: Any]) -> [[String: Any]] {
        obj["tests"] as? [[String: Any]] ?? obj["checks"] as? [[String: Any]] ?? []
    }

    private static func pick(_ obj: [String: Any], _ keys: [String], fallback: String = "") -> String {
        for key in keys {
            guard let value = obj[key] else { continue }
            if let s = value as? String {
                if !s.isEmpty { return s }
                continue
            }
            let text = "\(value)"
            if !text.isEmpty && text != "null" { return text }
        }
        return fallback
    }

    private static func remapName(_ value: String) -> String {
        switch value {
        case "surname": return "familyName"
        case "givenNames": return "firstNames"
        case "documentNumber": return "docNumber"
        case "hologramIntegrity": return "foilCheck"
        case "portrait": return "face"
        default: return value
        }
    }

    private static func remapOrigin(_ value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ocr": return "visual"
        case "mrz": return "zone"
        case "barcode": return "code"
        case "rfid": return "chip"
        default: return value
        }
    }

    private static func remapGroup(_ value: String) -> String {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "verify": return "validity"
        case "quality": return "capture"
        case "security", "liveness": return "authenticity"
        default: return value
        }
    }

    private static func remapOutcome(_ value: String) -> String {
        let s = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return s == "skip" ? "hold" : s
    }

    private static func remapDetail(_ value: String) -> String {
        if value == "ok" { return "ready" }
        if value == "processing failed" { return "failed" }
        return value
    }

    private static func identClass(_ ident: [String: Any]) -> String {
        pick(ident, ["class", "type"])
    }

    private static func fieldName(_ row: [String: Any]) -> String {
        remapName(pick(row, ["name", "id"]))
    }

    private static func originOf(_ row: [String: Any]) -> String {
        remapOrigin(pick(row, ["origin", "source"], fallback: "field"))
    }

    private static func groupOf(_ row: [String: Any]) -> String {
        remapGroup(pick(row, ["group", "kind"], fallback: "check"))
    }

    private static func outcomeOf(_ row: [String: Any]) -> String {
        remapOutcome(pick(row, ["outcome", "result"], fallback: "hold"))
    }

    private static func noteOf(_ row: [String: Any]) -> String {
        pick(row, ["note", "reason"])
    }

    private static func imageName(_ row: [String: Any]) -> String {
        remapName(pick(row, ["name", "id"], fallback: "image"))
    }

    private static func imageData(_ row: [String: Any]) -> String {
        pick(row, ["data", "image"])
    }

    private static func statusOf(_ obj: [String: Any]) -> Int {
        let meta = session(obj)
        if let n = meta["code"] as? NSNumber { return n.intValue }
        if let n = meta["status"] as? NSNumber { return n.intValue }
        if let n = obj["code"] as? NSNumber { return n.intValue }
        if let n = obj["errorCode"] as? NSNumber { return n.intValue }
        return 0
    }

    private static func messageOf(_ obj: [String: Any]) -> String {
        let detail = pick(session(obj), ["detail", "message"])
        if !detail.isEmpty { return remapDetail(detail) }
        if let s = obj["message"] as? String, !s.isEmpty { return remapDetail(s) }
        return ""
    }


    private static func scoreText(_ value: Any?) -> String {
        let n: Double?
        if let num = value as? NSNumber { n = num.doubleValue }
        else if let s = value as? String { n = Double(s) }
        else { n = nil }
        guard let n else { return "" }
        return String(format: "%.6f", n)
    }


    private static func pageSide(_ value: Any?) -> String {
        let n = (value as? NSNumber)?.intValue ?? (value as? Int) ?? 0
        if n == 0 { return "Front" }
        if n == 1 { return "Back" }
        return "Page \(n)"
    }


    static func summary(_ raw: String) -> String {
        guard let obj = jsonObject(raw) else { return String(raw.prefix(200)) }
        if let msg = obj["msg"] as? String { return msg }
        let ident = identity(obj)
        let code = statusOf(obj)
        let message = messageOf(obj)
        let score = scoreText(ident["score"])
        let title = identClass(ident)
        var s = "\(code == 0 ? "ok" : "failed") · status=\(code)"
        if !message.isEmpty { s += " · \(message)" }
        s += "\n\(title.isEmpty ? "—" : title) · \(ident["country"] as? String ?? "—")"
        s += "\nscore: \(score.isEmpty ? "—" : score)"
        return s
    }


    static func identity(_ raw: String) -> IdentityStats {
        guard let obj = jsonObject(raw) else {
            return IdentityStats(type: "—", country: "—", score: "—")
        }
        let ident = identity(obj)
        let scoreRaw = scoreText(ident["score"])
        let score: String
        if scoreRaw.isEmpty {
            score = "—"
        } else if let n = ident["score"] as? NSNumber {
            score = String(format: "%.2f", n.doubleValue)
        } else {
            score = scoreRaw.contains(".") ? String(scoreRaw.prefix(4)) : scoreRaw
        }
        let type = identClass(ident)
        let country = (ident["country"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "—"
        return IdentityStats(
            type: type.isEmpty ? "—" : type,
            country: country,
            score: score
        )
    }


    /// Same three-line card as the web `ix-ident` block.
    static func identityLine(_ raw: String) -> IdentityLine {
        guard let obj = jsonObject(raw) else {
            return IdentityLine(
                title: "— · — · —",
                status: "failed · status=— · —",
                counts: "0 fields · 0 checks · 0 pass · 0 fail · 0 skip",
                ok: false
            )
        }
        let stats = identity(raw)
        let code = statusOf(obj)
        let ok = code == 0
        let message = messageOf(obj).trimmingCharacters(in: .whitespacesAndNewlines)
        let messageText = message.isEmpty ? "—" : message
        let codeDisplay = "\(code)"
        let fields = readings(obj)
        let checkItems = tests(obj)
        var pass = 0
        var fail = 0
        for item in checkItems {
            switch outcomeOf(item) {
            case "pass": pass += 1
            case "fail": fail += 1
            default: break
            }
        }
        let skip = max(0, checkItems.count - pass - fail)
        return IdentityLine(
            title: "\(stats.type) · \(stats.country) · \(stats.score)",
            status: "\(ok ? "ok" : "failed") · status=\(codeDisplay) · \(messageText)",
            counts: "\(fields.count) fields · \(checkItems.count) checks · \(pass) pass · \(fail) fail · \(skip) skip",
            ok: ok
        )
    }

    private static let overallKinds = ["validity", "capture", "authenticity"]
    private static let fieldSourceOrder = ["visual", "zone", "code"]
    private static let checkResultRank = ["fail": 0, "pass": 1, "hold": 2, "skip": 2]

    static func sourceLabel(_ source: String) -> String {
        switch source.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "visual": return "VISUAL"
        case "zone": return "ZONE"
        case "code": return "CODE"
        case "chip": return "CHIP"
        default:
            let key = source.trimmingCharacters(in: .whitespacesAndNewlines)
            return key.isEmpty ? "FIELD" : key.uppercased()
        }
    }

    static func kindLabel(_ kind: String) -> String {
        switch kind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "validity", "verify": return "Validity"
        case "capture", "quality": return "Capture"
        case "security", "authenticity", "liveness": return "Liveness"
        default:
            let key = kind.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return "Check" }
            return key.prefix(1).uppercased() + key.dropFirst()
        }
    }

    /// Kind-level roll-up: any fail → fail, else any pass → pass, else skip.
    static func overallResults(_ raw: String) -> [OverallResult] {
        let checks = jsonObject(raw).map { tests($0) } ?? []
        return overallKinds.map { kind in
            OverallResult(kind: kind, result: overallResult(checks, kind: kind))
        }
    }

    private static func overallResult(_ checks: [[String: Any]], kind: String) -> String {
        var anyPass = false
        for row in checks {
            guard groupOf(row) == kind else { continue }
            switch outcomeOf(row) {
            case "fail": return "fail"
            case "pass": anyPass = true
            default: break
            }
        }
        return anyPass ? "pass" : "skip"
    }

    static func fieldGroups(_ raw: String) -> [FieldGroup] {
        guard let obj = jsonObject(raw) else { return [] }
        let fields = readings(obj)
        var buckets: [String: [FieldItem]] = [:]
        var extra: [String] = []
        for row in fields {
            let value = "\(row["value"] ?? "")"
            if value.isEmpty || value == "null" { continue }
            let source = originOf(row)
            if buckets[source] == nil {
                buckets[source] = []
                if !fieldSourceOrder.contains(source) { extra.append(source) }
            }
            buckets[source]?.append(FieldItem(
                id: fieldName(row),
                value: value,
                score: scoreText(row["score"])
            ))
        }
        return (fieldSourceOrder + extra).compactMap { source in
            guard let items = buckets[source], !items.isEmpty else { return nil }
            return FieldGroup(source: source, items: items)
        }
    }

    static func checkGroups(_ raw: String) -> [CheckGroup] {
        let checks = jsonObject(raw).map { tests($0) } ?? []
        var buckets: [String: [CheckItem]] = Dictionary(uniqueKeysWithValues: overallKinds.map { ($0, []) })
        var extra: [String] = []
        for row in checks {
            let kind = groupOf(row)
            var extraBits: [String] = []
            let reason = noteOf(row)
            if !reason.isEmpty { extraBits.append(reason) }
            let score = scoreText(row["score"])
            if !score.isEmpty { extraBits.append(score) }
            if buckets[kind] == nil {
                buckets[kind] = []
                extra.append(kind)
            }
            buckets[kind]?.append(CheckItem(
                id: fieldName(row),
                result: outcomeOf(row),
                extra: extraBits.joined(separator: " · ")
            ))
        }
        return (overallKinds + extra).compactMap { kind in
            guard var items = buckets[kind], !items.isEmpty else { return nil }
            items.sort { (checkResultRank[$0.result] ?? 9) < (checkResultRank[$1.result] ?? 9) }
            return CheckGroup(kind: kind, items: items)
        }
    }

    static func fieldRows(_ raw: String) -> [FieldRow] {
        guard let obj = jsonObject(raw) else { return [] }
        var out: [FieldRow] = []
        for row in readings(obj) {
            let value = "\(row["value"] ?? "")"
            let extra = scoreText(row["score"])
            out.append(FieldRow(
                key: fieldName(row),
                value: extra.isEmpty ? value : "\(value) · \(extra)",
                source: originOf(row)
            ))
        }
        return out.filter { !$0.value.isEmpty && $0.value != "null" }
    }


    static func checkRows(_ raw: String) -> [SecurityRow] {
        guard let obj = jsonObject(raw) else { return [] }
        var out: [SecurityRow] = []
        for row in tests(obj) {
            var label = outcomeOf(row)
            let extra = scoreText(row["score"])
            if !extra.isEmpty { label += " · \(extra)" }
            let reason = noteOf(row)
            if !reason.isEmpty {
                label += " — \(reason)"
            }
            out.append(SecurityRow(
                page: groupOf(row),
                check: fieldName(row),
                status: label
            ))
        }
        return out
    }


    static func rows(_ raw: String) -> [FieldRow] {
        guard let obj = jsonObject(raw) else { return [] }
        let ident = identity(obj)
        var out: [FieldRow] = []
        let cls = identClass(ident)
        if !cls.isEmpty {
            out.append(FieldRow(key: "class", value: cls, source: "identity"))
        }
        if let country = ident["country"] as? String, !country.isEmpty {
            out.append(FieldRow(key: "country", value: country, source: "identity"))
        }
        let score = scoreText(ident["score"])
        if !score.isEmpty {
            out.append(FieldRow(key: "score", value: score, source: "identity"))
        }
        for row in readings(obj) {
            let value = "\(row["value"] ?? "")"
            let extra = scoreText(row["score"])
            out.append(FieldRow(
                key: fieldName(row),
                value: extra.isEmpty ? value : "\(value) · \(extra)",
                source: originOf(row)
            ))
        }
        for row in tests(obj) {
            if groupOf(row) == "authenticity" { continue }
            var label = outcomeOf(row)
            let extra = scoreText(row["score"])
            if !extra.isEmpty { label += " · \(extra)" }
            let reason = noteOf(row)
            if !reason.isEmpty {
                label += " — \(reason)"
            }
            out.append(FieldRow(
                key: fieldName(row),
                value: label,
                source: groupOf(row)
            ))
        }
        return out.filter { !$0.value.isEmpty && $0.value != "null" }
    }


    static func extractName(_ obj: [String: Any]) -> String {
        let ident = identity(obj)
        let cls = identClass(ident)
        if !cls.isEmpty { return cls }
        if let name = obj["documentName"] as? String, !name.isEmpty { return name }
        var surname = ""
        var given = ""
        for row in readings(obj) {
            switch fieldName(row) {
            case "familyName", "surname":
                surname = "\(row["value"] ?? "")"
            case "firstNames", "givenNames", "givenName":
                given = "\(row["value"] ?? "")"
            case "surnameAndGivenNames", "name", "fullName":
                let value = "\(row["value"] ?? "")"
                if !value.isEmpty { return value }
            default:
                break
            }
        }
        return [surname, given].filter { !$0.isEmpty }.joined(separator: " ")
    }


    static func decodePortrait(_ obj: [String: Any]) -> UIImage? {
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let raw = String(data: data, encoding: .utf8) else { return nil }
        let imgs = images(raw)
        return imgs.first(where: {
            $0.category.range(of: "face", options: .caseInsensitive) != nil
                || $0.category.range(of: "portrait", options: .caseInsensitive) != nil
        })?.image ?? imgs.first?.image
    }


    static func images(_ raw: String) -> [ResultImage] {
        guard let obj = jsonObject(raw), let arr = obj["images"] as? [Any] else { return [] }
        var out: [ResultImage] = []
        var seenKey = Set<String>()
        for item in arr {
            guard let d = item as? [String: Any] else { continue }
            let b64 = imageData(d)
            if b64.count < 32 { continue }
            let id = imageName(d)
            let key = "\(id)|\(b64.count):\(b64.prefix(48))"
            if !seenKey.insert(key).inserted { continue }
            guard let image = decodeBase64Image(b64) else { continue }
            let page = d["page"]
            let category = page == nil ? id : "\(id) (page \(page!))"
            out.append(ResultImage(category: category, source: "", image: image))
        }
        return out
    }


    static func decodeBase64Image(_ b64: String) -> UIImage? {
        var clean = b64
        if let range = b64.range(of: "base64,") {
            clean = String(b64[range.upperBound...])
        }
        guard let data = Data(base64Encoded: clean, options: [.ignoreUnknownCharacters]) else { return nil }
        return UIImage(data: data)
    }


    static func documentPercent(_ raw: String) -> Int {
        guard let obj = jsonObject(raw) else { return 0 }
        let ident = identity(obj)
        let rawScore = ident["score"] ?? obj["score"]
        guard let n = rawScore as? NSNumber else { return 0 }
        let s = n.doubleValue
        let pct = s <= 1.0 ? s * 100.0 : s
        return max(0, min(100, Int(pct)))
    }


    static func documentFillPercent(_ raw: String) -> Int {
        guard let obj = jsonObject(raw),
              let pos = obj["position"] as? [String: Any] else { return 0 }
        let area: Int
        if let n = pos["objArea"] as? NSNumber {
            area = n.intValue
        } else if let n = pos["ObjArea"] as? NSNumber {
            area = n.intValue
        } else {
            return 0
        }
        return (0...100).contains(area) ? area : 0
    }


    static func documentCorners(_ raw: String) -> [CGPoint]? {
        guard let obj = jsonObject(raw),
              let pos = obj["position"] as? [String: Any] else { return nil }
        if let arr = pos["corners"] as? [[String: Any]], arr.count >= 4 {
            var out: [CGPoint] = []
            for i in 0..<4 {
                let p = arr[i]
                let x = (p["x"] as? NSNumber)?.doubleValue ?? .nan
                let y = (p["y"] as? NSNumber)?.doubleValue ?? .nan
                if x.isNaN || y.isNaN { return nil }
                out.append(CGPoint(x: x, y: y))
            }
            return out
        }
        let l = (pos["left"] as? NSNumber)?.doubleValue ?? .nan
        let t = (pos["top"] as? NSNumber)?.doubleValue ?? .nan
        let r = (pos["right"] as? NSNumber)?.doubleValue ?? .nan
        let b = (pos["bottom"] as? NSNumber)?.doubleValue ?? .nan
        if l.isNaN || t.isNaN || r.isNaN || b.isNaN { return nil }
        if r <= l || b <= t { return nil }
        return [
            CGPoint(x: l, y: t),
            CGPoint(x: r, y: t),
            CGPoint(x: r, y: b),
            CGPoint(x: l, y: b),
        ]
    }


    static func isPlausibleCardQuad(_ corners: [CGPoint]) -> Bool {
        guard corners.count >= 4 else { return false }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        var off = 0
        for p in corners {
            if !p.x.isFinite || !p.y.isFinite { return false }
            if p.x < -8 || p.y < -8 { off += 1 }
            minX = min(minX, p.x)
            minY = min(minY, p.y)
            maxX = max(maxX, p.x)
            maxY = max(maxY, p.y)
        }
        if off >= 2 { return false }
        return (maxX - minX) >= 40 && (maxY - minY) >= 24
    }


    static func securitySummary(_ raw: String) -> String {
        guard let obj = jsonObject(raw) else {
            return "No liveness checks in this response. If you expected checks, this license may not include liveness."
        }
        var pass = 0
        var fail = 0
        var skip = 0
        var any = false
        for row in tests(obj) {
            guard groupOf(row) == "authenticity" else { continue }
            any = true
            switch outcomeOf(row) {
            case "pass": pass += 1
            case "fail": fail += 1
            default: skip += 1
            }
        }
        guard any else {
            return "No liveness checks in this response. If you expected checks, this license may not include liveness."
        }
        let title = identClass(identity(obj))
        return "\(title.isEmpty ? "Document" : title)\n\(pass) pass · \(fail) fail · \(skip) skip"
    }


    static func securityRows(_ raw: String) -> [SecurityRow] {
        guard let obj = jsonObject(raw) else { return [] }
        var out: [SecurityRow] = []
        for row in tests(obj) {
            guard groupOf(row) == "authenticity" else { continue }
            var label = outcomeOf(row)
            let extra = scoreText(row["score"])
            if !extra.isEmpty { label += " · \(extra)" }
            out.append(SecurityRow(
                page: pageSide(row["page"] ?? 0),
                check: fieldName(row),
                status: label
            ))
        }
        return out
    }
}
