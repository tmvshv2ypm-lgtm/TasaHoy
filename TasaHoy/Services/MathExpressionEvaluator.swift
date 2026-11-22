import Foundation

/// Safe recursive-descent arithmetic evaluator supporting `+`, `-`, `*`, `/`, and smart shopping percentages
/// (e.g. `100+16%` = `116` for IVA, `50-10%` = `45` for discounts, `200*15%` = `30`).
enum MathExpressionEvaluator {
    static func evaluate(_ raw: String) -> Double? {
        let cleaned = sanitize(raw)
        guard !cleaned.isEmpty else { return nil }
        var parser = Parser(tokens: tokenize(cleaned))
        guard let value = parser.parseExpression(), value.isFinite else { return nil }
        return max(0, value)
    }

    static func containsOperator(_ raw: String) -> Bool {
        raw.contains(where: { "+-*/%".contains($0) })
    }

    private static func sanitize(_ raw: String) -> String {
        var s = raw
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: " ", with: "")
        // Trim trailing dangling operators so partial expressions like "15+" still evaluate cleanly to 15!
        while let last = s.last, "+-*/.".contains(last) {
            s.removeLast()
        }
        return s
    }

    private enum Token {
        case number(Double)
        case op(Character)
        case percent
    }

    private static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var buffer = ""

        func flush() {
            if !buffer.isEmpty, let num = Double(buffer) {
                tokens.append(.number(num))
            }
            buffer = ""
        }

        for ch in text {
            if ch.isNumber || ch == "." {
                buffer.append(ch)
            } else if ch == "%" {
                flush()
                tokens.append(.percent)
            } else if "+-*/".contains(ch) {
                flush()
                tokens.append(.op(ch))
            }
        }
        flush()
        return tokens
    }

    private struct Parser {
        let tokens: [Token]
        var index: Int = 0

        mutating func parseExpression() -> Double? {
            guard var lhs = parseTerm() else { return nil }
            while index < tokens.count {
                if case .op(let op) = tokens[index], op == "+" || op == "-" {
                    index += 1
                    let termStart = index
                    guard let rhsRaw = parseTerm() else { break }
                    // Smart shopping percent: if the rhs ended with a `%` token directly on a single value
                    // e.g. `100 + 16%` -> `100 + (100 * 0.16)`!
                    let isDirectPercent = isSinglePercentTerm(from: termStart, to: index)
                    let rhs = isDirectPercent ? (lhs * rhsRaw) : rhsRaw
                    lhs = (op == "+") ? (lhs + rhs) : (lhs - rhs)
                } else {
                    break
                }
            }
            return lhs
        }

        private func isSinglePercentTerm(from start: Int, to end: Int) -> Bool {
            guard end - start == 2,
                  case .number = tokens[start],
                  case .percent = tokens[start + 1] else {
                return false
            }
            return true
        }

        mutating func parseTerm() -> Double? {
            guard var lhs = parsePrimary() else { return nil }
            while index < tokens.count {
                if case .op(let op) = tokens[index], op == "*" || op == "/" {
                    index += 1
                    guard let rhs = parsePrimary() else { break }
                    if op == "*" {
                        lhs *= rhs
                    } else if abs(rhs) > 1e-12 {
                        lhs /= rhs
                    } else {
                        return nil
                    }
                } else {
                    break
                }
            }
            return lhs
        }

        mutating func parsePrimary() -> Double? {
            guard index < tokens.count else { return nil }
            if case .op(let op) = tokens[index], op == "-" || op == "+" {
                index += 1
                guard let val = parsePrimary() else { return nil }
                return op == "-" ? -val : val
            }
            guard case .number(var value) = tokens[index] else { return nil }
            index += 1
            while index < tokens.count, case .percent = tokens[index] {
                value /= 100.0
                index += 1
            }
            return value
        }
    }
}
