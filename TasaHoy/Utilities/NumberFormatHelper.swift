import Foundation

enum NumberFormatHelper {
    /// Formats a Double according to the user's preferred separator style (`1.234,56` vs `1,234.56`).
    static func format(
        _ value: Double,
        decimals: Int = 2,
        minDecimals: Int? = nil,
        style: NumberStylePreference = .venezuela
    ) -> String {
        guard value.isFinite else { return "0\(style.decimalSeparator)00" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = style.groupingSeparator
        formatter.decimalSeparator = style.decimalSeparator
        formatter.minimumFractionDigits = minDecimals ?? decimals
        formatter.maximumFractionDigits = decimals
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimals)f", value)
    }

    /// Formats a smart exchange rate: automatically uses 4 decimals for very small rates (like 1 COP in Bs ≈ 0,2749)
    /// so precision is never lost, otherwise respects the user's chosen precision (2 or 4 decimals).
    static func formatRate(
        _ value: Double,
        precision: DecimalPrecisionMode,
        style: NumberStylePreference
    ) -> String {
        let effectiveDecimals: Int
        if value > 0 && value < 1.0 {
            effectiveDecimals = 4
        } else {
            effectiveDecimals = precision.rawValue
        }
        return format(value, decimals: effectiveDecimals, style: style)
    }

    /// Formats a clean copyable number without currency symbols, ready to paste into banking apps.
    static func formatCopyable(_ value: Double, decimals: Int = 2, style: NumberStylePreference) -> String {
        guard value.isFinite else { return "0" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.decimalSeparator = style.decimalSeparator
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals
        formatter.roundingMode = .halfUp
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(decimals)f", value)
    }

    /// Formats delta string like "+0,99 Bs (+0,11%)" or "-0,11 Bs (-0,01%)".
    static func formatDelta(
        delta: Double,
        percent: Double?,
        style: NumberStylePreference
    ) -> String {
        let sign = delta >= 0 ? "+" : "-"
        let absDelta = format(abs(delta), decimals: 2, style: style)
        if let percent {
            let pctSign = percent >= 0 ? "+" : "-"
            let absPct = format(abs(percent), decimals: 2, style: style)
            return "\(sign)\(absDelta) Bs (\(pctSign)\(absPct)%)"
        }
        return "\(sign)\(absDelta) Bs"
    }

    /// Formats an editable raw input string (which uses `.` internally as decimal separator) with visual grouping.
    static func formatRawExpressionForDisplay(_ raw: String, style: NumberStylePreference) -> String {
        guard !raw.isEmpty else { return "0" }
        var result = ""
        var numberBuffer = ""

        func flushNumber() {
            guard !numberBuffer.isEmpty else { return }
            let parts = numberBuffer.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
            let intPart = String(parts[0])
            let formattedInt = groupIntegerDigits(intPart, separator: style.groupingSeparator)
            if parts.count == 2 {
                result += formattedInt + style.decimalSeparator + String(parts[1])
            } else {
                result += formattedInt
            }
            numberBuffer = ""
        }

        for ch in raw {
            if ch.isNumber || ch == "." {
                numberBuffer.append(ch)
            } else {
                flushNumber()
                switch ch {
                case "+": result += " + "
                case "-": result += " − "
                case "*": result += " × "
                case "/": result += " ÷ "
                case "%": result += "%"
                default: result.append(ch)
                }
            }
        }
        flushNumber()
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func groupIntegerDigits(_ digits: String, separator: String) -> String {
        guard digits.count > 3 else { return digits.isEmpty ? "0" : digits }
        var out = ""
        let rev = Array(digits.reversed())
        for (i, ch) in rev.enumerated() {
            if i > 0 && i % 3 == 0 {
                out.append(separator)
            }
            out.append(ch)
        }
        return String(out.reversed())
    }
}
