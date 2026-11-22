import Foundation
import SwiftUI

// MARK: - Selectable Currency / Rate Identifiers

enum RateSourceID: Hashable, Codable, Sendable, Identifiable {
    case bcvUSD
    case bcvEUR
    case usdt
    case averageBCVUSDT
    case cop
    case world(code: String)
    case custom(id: UUID)

    var id: String { storageKey }

    var storageKey: String {
        switch self {
        case .bcvUSD: return "bcv_usd"
        case .bcvEUR: return "bcv_eur"
        case .usdt: return "usdt_p2p"
        case .averageBCVUSDT: return "avg_bcv_usdt"
        case .cop: return "world_COP"
        case .world(let code): return "world_\(code.uppercased())"
        case .custom(let id): return "custom_\(id.uuidString)"
        }
    }

    init(storageKey: String) {
        switch storageKey {
        case "bcv_usd": self = .bcvUSD
        case "bcv_eur": self = .bcvEUR
        case "usdt_p2p": self = .usdt
        case "avg_bcv_usdt": self = .averageBCVUSDT
        case "world_COP": self = .cop
        default:
            if storageKey.hasPrefix("world_") {
                let code = String(storageKey.dropFirst("world_".count)).uppercased()
                self = code == "COP" ? .cop : .world(code: code)
            } else if storageKey.hasPrefix("custom_"),
                      let uuid = UUID(uuidString: String(storageKey.dropFirst("custom_".count))) {
                self = .custom(id: uuid)
            } else {
                self = .bcvUSD
            }
        }
    }

    /// Standard display unit multiplier (e.g. COP is commonly quoted per 1.000 COP or 1 COP;
    /// converter inputs are always 1:1 exact currency units, while rate cards can show helpful unit context).
    var isSmallUnitCurrency: Bool {
        switch self {
        case .cop: return true
        case .world(let code): return ["COP", "CLP", "PYG", "JPY", "ARS"].contains(code.uppercased())
        default: return false
        }
    }
}

// MARK: - Rate Data Structures

struct HistoricalPoint: Identifiable, Codable, Hashable, Sendable {
    var id: String { dateKey }
    let dateKey: String // "yyyy-MM-dd"
    let value: Double

    var date: Date {
        VenezuelaDateHelper.date(fromDayKey: dateKey) ?? Date()
    }
}

struct RateEntry: Codable, Hashable, Sendable {
    let value: Double
    let previousValue: Double?
    let effectiveDateKey: String // "yyyy-MM-dd"
    let updatedAt: Date

    var delta: Double? {
        guard let previousValue, previousValue > 0 else { return nil }
        return value - previousValue
    }

    var deltaPercent: Double? {
        guard let previousValue, previousValue > 0 else { return nil }
        return ((value - previousValue) / previousValue) * 100.0
    }

    var effectiveDate: Date {
        VenezuelaDateHelper.date(fromDayKey: effectiveDateKey) ?? updatedAt
    }
}

struct USDTSnapshot: Codable, Hashable, Sendable {
    let buy: Double
    let sell: Double
    let average: Double
    let previousAverage: Double?
    let updatedAt: Date
    let sourceLabel: String
    let adCountBuy: Int
    let adCountSell: Int

    var delta: Double? {
        guard let previousAverage, previousAverage > 0 else { return nil }
        return average - previousAverage
    }

    var deltaPercent: Double? {
        guard let previousAverage, previousAverage > 0 else { return nil }
        return ((average - previousAverage) / previousAverage) * 100.0
    }

    var spreadPercent: Double? {
        guard sell > 0 else { return nil }
        return abs(buy - sell) / ((buy + sell) / 2.0) * 100.0
    }
}

struct BCVExtraRates: Codable, Hashable, Sendable {
    let cny: Double?
    let tryRate: Double?
    let rub: Double?
    let isDirectBCV: Bool

    static let empty = BCVExtraRates(cny: nil, tryRate: nil, rub: nil, isDirectBCV: false)
}

struct MarketSnapshot: Codable, Hashable, Sendable {
    let bcvUSD: RateEntry
    let bcvUSDUpcoming: RateEntry?
    let bcvEUR: RateEntry
    let bcvEURUpcoming: RateEntry?
    let bcvExtras: BCVExtraRates
    let usdt: USDTSnapshot
    let worldRatesPerUSD: [String: Double]
    let worldRatesUpdatedAt: Date?
    let historyBCVUSD: [HistoricalPoint]
    let historyBCVEUR: [HistoricalPoint]
    let historyUSDT: [HistoricalPoint]
    let lastSyncedAt: Date
    let bcvSourceIsDirect: Bool

    /// Exact midpoint average between official BCV USD and live USDT P2P.
    func averageBCVUSDT(useUpcomingBCV: Bool) -> Double {
        let usd = activeBCVUSD(useUpcoming: useUpcomingBCV).value
        let u = usdt.average
        guard usd > 0, u > 0 else { return max(usd, u) }
        return (usd + u) / 2.0
    }

    func activeBCVUSD(useUpcoming: Bool) -> RateEntry {
        if useUpcoming, let upcoming = bcvUSDUpcoming {
            return upcoming
        }
        return bcvUSD
    }

    func activeBCVEUR(useUpcoming: Bool) -> RateEntry {
        if useUpcoming, let upcoming = bcvEURUpcoming {
            return upcoming
        }
        return bcvEUR
    }

    /// Percentage gap between USDT P2P and Official BCV USD.
    func bcvUsdtGapPercent(useUpcomingBCV: Bool) -> Double? {
        let usd = activeBCVUSD(useUpcoming: useUpcomingBCV).value
        guard usd > 0, usdt.average > 0 else { return nil }
        return ((usdt.average - usd) / usd) * 100.0
    }

    func bcvUsdtGapBolivares(useUpcomingBCV: Bool) -> Double {
        let usd = activeBCVUSD(useUpcoming: useUpcomingBCV).value
        return usdt.average - usd
    }

    /// Computes how many VES (Bs) equal 1 unit of a world currency code (e.g. COP, BRL, GBP).
    func vesPerUnit(worldCode: String, anchor: FXAnchorMode, useUpcomingBCV: Bool) -> Double? {
        let code = worldCode.uppercased()
        if code == "USD" {
            return anchorBaseUSDInVES(anchor: anchor, useUpcomingBCV: useUpcomingBCV)
        }
        if code == "EUR" {
            return activeBCVEUR(useUpcoming: useUpcomingBCV).value
        }
        if anchor == .bcv {
            if code == "CNY", let direct = bcvExtras.cny, direct > 0 { return direct }
            if code == "TRY", let direct = bcvExtras.tryRate, direct > 0 { return direct }
            if code == "RUB", let direct = bcvExtras.rub, direct > 0 { return direct }
        }
        guard let unitsPerUSD = worldRatesPerUSD[code], unitsPerUSD > 0 else { return nil }
        let baseUSD = anchorBaseUSDInVES(anchor: anchor, useUpcomingBCV: useUpcomingBCV)
        guard baseUSD > 0 else { return nil }
        return baseUSD / unitsPerUSD
    }

    func anchorBaseUSDInVES(anchor: FXAnchorMode, useUpcomingBCV: Bool) -> Double {
        switch anchor {
        case .bcv:
            return activeBCVUSD(useUpcoming: useUpcomingBCV).value
        case .usdt:
            return usdt.average
        case .average:
            return averageBCVUSDT(useUpcomingBCV: useUpcomingBCV)
        }
    }

    var hasUpcomingBCVRate: Bool {
        bcvUSDUpcoming != nil || bcvEURUpcoming != nil
    }
}

// MARK: - User Preferences & Extra Currencies

enum FXAnchorMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case bcv
    case average
    case usdt

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .bcv: return L10n.rateBCVUSD
        case .average: return L10n.rateAverageShort
        case .usdt: return L10n.rateUSDT
        }
    }
}

enum DecimalPrecisionMode: Int, CaseIterable, Identifiable, Codable, Sendable {
    case two = 2
    case four = 4

    var id: Int { rawValue }

    var localizedTitle: String {
        switch self {
        case .two: return L10n.precisionTwo
        case .four: return L10n.precisionFour
        }
    }
}

enum NumberStylePreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case venezuela // 1.234,56
    case international // 1,234.56

    var id: String { rawValue }

    var decimalSeparator: String {
        self == .venezuela ? "," : "."
    }

    var groupingSeparator: String {
        self == .venezuela ? "." : ","
    }

    var exampleString: String {
        self == .venezuela ? "1.234,56" : "1,234.56"
    }
}

struct CustomCurrencyItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var symbol: String
    var rateInVES: Double
    var colorHex: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        rateInVES: Double,
        colorHex: String = "#EC4899",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.rateInVES = rateInVES
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}

struct WorldCurrencyPreset: Identifiable, Hashable, Sendable {
    var id: String { code }
    let code: String
    let symbol: String
    let flag: String
    let defaultNameES: String
    let defaultNameEN: String
    let colorHex: String

    var localizedName: String {
        if let localized = Locale.current.localizedString(forCurrencyCode: code), !localized.isEmpty {
            return localized.prefix(1).uppercased() + localized.dropFirst()
        }
        return Locale.current.language.languageCode?.identifier == "es" ? defaultNameES : defaultNameEN
    }

    static let catalog: [WorldCurrencyPreset] = [
        WorldCurrencyPreset(code: "COP", symbol: "COP", flag: "🇨🇴", defaultNameES: "Peso colombiano", defaultNameEN: "Colombian Peso", colorHex: "#8B5CF6"),
        WorldCurrencyPreset(code: "BRL", symbol: "R$", flag: "🇧🇷", defaultNameES: "Real brasileño", defaultNameEN: "Brazilian Real", colorHex: "#10B981"),
        WorldCurrencyPreset(code: "GBP", symbol: "£", flag: "🇬🇧", defaultNameES: "Libra esterlina", defaultNameEN: "British Pound", colorHex: "#6366F1"),
        WorldCurrencyPreset(code: "MXN", symbol: "MX$", flag: "🇲🇽", defaultNameES: "Peso mexicano", defaultNameEN: "Mexican Peso", colorHex: "#059669"),
        WorldCurrencyPreset(code: "CNY", symbol: "¥", flag: "🇨🇳", defaultNameES: "Yuan chino", defaultNameEN: "Chinese Yuan", colorHex: "#EF4444"),
        WorldCurrencyPreset(code: "TRY", symbol: "₺", flag: "🇹🇷", defaultNameES: "Lira turca", defaultNameEN: "Turkish Lira", colorHex: "#F43F5E"),
        WorldCurrencyPreset(code: "RUB", symbol: "₽", flag: "🇷🇺", defaultNameES: "Rublo ruso", defaultNameEN: "Russian Ruble", colorHex: "#2563EB"),
        WorldCurrencyPreset(code: "CLP", symbol: "CLP$", flag: "🇨🇱", defaultNameES: "Peso chileno", defaultNameEN: "Chilean Peso", colorHex: "#0284C7"),
        WorldCurrencyPreset(code: "PEN", symbol: "S/", flag: "🇵🇪", defaultNameES: "Sol peruano", defaultNameEN: "Peruvian Sol", colorHex: "#DC2626"),
        WorldCurrencyPreset(code: "ARS", symbol: "AR$", flag: "🇦🇷", defaultNameES: "Peso argentino", defaultNameEN: "Argentine Peso", colorHex: "#0EA5E9"),
        WorldCurrencyPreset(code: "CAD", symbol: "CA$", flag: "🇨🇦", defaultNameES: "Dólar canadiense", defaultNameEN: "Canadian Dollar", colorHex: "#E11D48"),
        WorldCurrencyPreset(code: "CHF", symbol: "CHF", flag: "🇨🇭", defaultNameES: "Franco suizo", defaultNameEN: "Swiss Franc", colorHex: "#EA580C"),
        WorldCurrencyPreset(code: "JPY", symbol: "¥", flag: "🇯🇵", defaultNameES: "Yen japonés", defaultNameEN: "Japanese Yen", colorHex: "#D946EF"),
        WorldCurrencyPreset(code: "DOP", symbol: "RD$", flag: "🇩🇴", defaultNameES: "Peso dominicano", defaultNameEN: "Dominican Peso", colorHex: "#1D4ED8"),
        WorldCurrencyPreset(code: "CRC", symbol: "₡", flag: "🇨🇷", defaultNameES: "Colón costarricense", defaultNameEN: "Costa Rican Colón", colorHex: "#14B8A6"),
        WorldCurrencyPreset(code: "UYU", symbol: "$U", flag: "🇺🇾", defaultNameES: "Peso uruguayo", defaultNameEN: "Uruguayan Peso", colorHex: "#38BDF8"),
        WorldCurrencyPreset(code: "PAB", symbol: "B/.", flag: "🇵🇦", defaultNameES: "Balboa panameño", defaultNameEN: "Panamanian Balboa", colorHex: "#4F46E5"),
        WorldCurrencyPreset(code: "BOB", symbol: "Bs.", flag: "🇧🇴", defaultNameES: "Boliviano", defaultNameEN: "Bolivian Boliviano", colorHex: "#CA8A04")
    ]

    static func preset(for code: String) -> WorldCurrencyPreset? {
        catalog.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }
}

// MARK: - Chart Configuration

enum ChartRange: String, CaseIterable, Identifiable, Sendable {
    case week = "7D"
    case twoWeeks = "15D"
    case month = "30D"
    case quarter = "90D"
    case year = "1A"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .week: return "7D"
        case .twoWeeks: return "15D"
        case .month: return "30D"
        case .quarter: return "90D"
        case .year: return L10n.chartYearShort
        }
    }

    var dayCount: Int {
        switch self {
        case .week: return 7
        case .twoWeeks: return 15
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

enum ChartSeriesKind: String, CaseIterable, Identifiable, Sendable {
    case bcvUSD
    case bcvEUR
    case usdt

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .bcvUSD: return L10n.rateBCVUSD
        case .bcvEUR: return L10n.rateBCVEUR
        case .usdt: return L10n.rateUSDT
        }
    }

    var accentColor: Color {
        switch self {
        case .bcvUSD: return Color(hex: "#10B981")
        case .bcvEUR: return Color(hex: "#3B82F6")
        case .usdt: return Color(hex: "#06B6D4")
        }
    }
}

// MARK: - Venezuela Timezone Date Helper (VET = UTC-4)

enum VenezuelaDateHelper {
    static let timeZone = TimeZone(identifier: "America/Caracas") ?? TimeZone(secondsFromGMT: -4 * 3600)!

    static func todayDayKey(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: now)
    }

    static func date(fromDayKey key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    static func formattedValueDate(_ dayKey: String, style: DateFormatter.Style = .medium) -> String {
        guard let date = date(fromDayKey: dayKey) else { return dayKey }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = timeZone
        if style == .full {
            formatter.setLocalizedDateFormatFromTemplate("EEEEdMMM")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        }
        let raw = formatter.string(from: date)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    static func formattedShortDay(_ dayKey: String) -> String {
        guard let date = date(fromDayKey: dayKey) else { return dayKey }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEdMM")
        let raw = formatter.string(from: date)
        return raw.prefix(1).uppercased() + raw.dropFirst()
    }

    static func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
