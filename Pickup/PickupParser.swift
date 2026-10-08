import Foundation

struct PickupParseResult: Sendable {
    let stationName: String
    let stationAddress: String
    let courierName: String
    let codes: [String]
    let confidence: Double
}

enum PickupParser {
    static let stationKeywords = ["菜鸟驿站", "妈妈驿站", "兔喜生活", "兔喜", "丰巢", "快递驿站", "驿站", "快递柜"]
    static let courierKeywords = ["顺丰", "中通", "圆通", "申通", "韵达", "极兔", "京东", "邮政", "菜鸟"]
    private static let pickupTerms = [
        "取件码", "取货码", "提货码", "提取码", "自提码", "取件密码", "取件凭证",
        "取货凭证", "领取码", "柜门密码", "开箱码", "开柜码", "凭码", "请凭", "验证码"
    ]
    private static let deliveryTerms = [
        "包裹", "快递", "快件", "驿站", "取件", "取货", "自提", "丰巢",
        "菜鸟", "妈妈驿站", "兔喜", "中通", "圆通", "申通", "韵达", "极兔", "顺丰", "京东", "邮政"
    ]
    private static let sensitiveTerms = ["登录", "支付", "银行", "身份证", "付款", "转账", "银行卡"]
    // 连字符属于码的一部分，两侧边界禁止从完整码内部再次匹配。
    private static let codePattern = #"(?<![A-Za-z0-9-])[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*(?![A-Za-z0-9-])"#

    /// 先确认短信具有取件语义，再从候选数字中排除订单号、日期和无关验证码。
    static func parse(_ message: String) -> PickupParseResult? {
        let text = normalize(message)
        guard !text.isEmpty,
              pickupTerms.contains(where: { text.localizedCaseInsensitiveContains($0) }),
              deliveryTerms.contains(where: { text.localizedCaseInsensitiveContains($0) }) else { return nil }

        let codes = extractCodes(from: text)
        var seenCodes = Set<String>()
        let uniqueCodes = codes.filter { seenCodes.insert($0).inserted }
        guard !uniqueCodes.isEmpty else { return nil }

        let station = stationKeywords.first { text.localizedCaseInsensitiveContains($0) }
        let address = extractAddress(from: text, station: station)
        let courier = courierKeywords.first { text.localizedCaseInsensitiveContains($0) } ?? ""
        guard !sensitiveTerms.contains(where: { text.localizedCaseInsensitiveContains($0) }) else { return nil }
        let confidence = (station == nil ? 0.62 : 0.82) + (address.isEmpty ? 0 : 0.1) + 0.08
        return PickupParseResult(
            stationName: station ?? "其他驿站",
            stationAddress: address,
            courierName: courier,
            codes: uniqueCodes,
            confidence: min(confidence, 0.98)
        )
    }

    private static func extractCodes(from text: String) -> [String] {
        let candidates = regexMatches(codePattern, in: text).compactMap { match -> (value: String, range: Range<String.Index>)? in
            guard let range = Range(match.range, in: text) else { return nil }
            return (String(text[range]).uppercased(), range)
        }

        var accepted: [String] = []
        var acceptedRanges: [Range<String.Index>] = []
        let negativeTerms = ["订单号", "订单编号", "运单号", "手机号", "身份证", "有效期", "金额", "到期"]

        for candidate in candidates.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            let prefixStart = text.index(candidate.range.lowerBound, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex
            let prefix = text[prefixStart..<candidate.range.lowerBound]
            let termRange = pickupTerms
                .compactMap { prefix.range(of: $0, options: .backwards) }
                .max { $0.upperBound < $1.upperBound }
            // 码必须紧跟取件关键词或上一个码的列表分隔符，避免吸入楼号、地址和订单号。
            let followsKeyword = termRange.map { range in
                let bridge = String(prefix[range.upperBound...])
                return bridge.count <= 12 && bridge.allSatisfy { " ：:为是【】[]()（）".contains($0) }
            } ?? false
            let followsCode = acceptedRanges.last.map { previousRange in
                let separator = text[previousRange.upperBound..<candidate.range.lowerBound]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return !separator.isEmpty && separator.count <= 8
                    && separator.allSatisfy { "、,，和或及/ ".contains($0) }
            } ?? false
            guard followsKeyword || followsCode else { continue }

            let localContext = String(prefix.suffix(22))
            guard !negativeTerms.contains(where: { localContext.localizedCaseInsensitiveContains($0) }) else { continue }
            let value = candidate.value
            let validLength = value.contains("-") ? (3...32).contains(value.count) : (4...12).contains(value.count)
            guard validLength,
                  !(value.allSatisfy(\.isNumber) && value.count > 8),
                  !accepted.contains(value) else { continue }
            accepted.append(value)
            acceptedRanges.append(candidate.range)
        }
        return accepted
    }

    private static func extractAddress(from text: String, station: String?) -> String {
        let addressPatterns = [
            #"(?:取件地址|地址|地点|位置)[：:\s]*(.{2,60}?)(?=领取|取件码|取货码|提货码|请凭|[，,。\n；;]|$)"#,
            #"(?:存放于|放置在|送至|到达|存入|位于|前往|请到|至)\s*(.{2,60}?)(?=领取|取件码|取货码|提货码|取件号|领取码|请凭|取件|取货|[，,。\n；;]|$)"#
        ]
        for pattern in addressPatterns {
            guard let match = regexMatches(pattern, in: text).first,
                  match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else { continue }
            let candidate = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if candidate.count >= 2 { return candidate }
        }
        guard let station, let range = text.range(of: station, options: .caseInsensitive) else { return "" }
        let suffix = text[range.upperBound...]
        let trimmed = suffix.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "：:，,。")))
        let end = trimmed.firstIndex(where: { "，,。\n；;请".contains($0) }) ?? trimmed.endIndex
        let candidate = String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        // 没有明确地址引导词时，只接受带位置特征的后缀，不把领取提示当地址。
        let actionTerms = ["领取", "取件", "取货", "包裹", "快递", "取货码", "取件码"]
        let locationTerms = ["路", "街", "巷", "号", "楼", "栋", "层", "室", "小区", "花园", "门", "柜"]
        if (2...40).contains(candidate.count),
           !actionTerms.contains(where: candidate.contains),
           locationTerms.contains(where: candidate.contains) {
            return candidate
        }
        return ""
    }

    private static func regexMatches(_ pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    }

    /// 将常见全角数字和标点统一为半角，减少运营商短信模板差异造成的漏识别。
    private static func normalize(_ message: String) -> String {
        let normalizedScalars = message.unicodeScalars.map { scalar -> UnicodeScalar in
            if (0xFF01...0xFF5E).contains(scalar.value), let ascii = UnicodeScalar(scalar.value - 0xFEE0) {
                return ascii
            }
            switch scalar.value {
            case 0x3000: return " "
            case 0x2010, 0x2011, 0x2012, 0x2013, 0x2014, 0x2212: return "-"
            default: return scalar
            }
        }
        let text = String(String.UnicodeScalarView(normalizedScalars))
        return text
            .replacingOccurrences(of: #"\s*-\s*"#, with: "-", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
