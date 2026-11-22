import Foundation
import SwiftUI
import UIKit

enum ConversionSide: Sendable {
    case foreign
    case bolivares
}

enum AppTab: Int, CaseIterable, Identifiable, Sendable {
    case converter = 0
    case rates = 1
    case payments = 2

    var id: Int { rawValue }
}

@MainActor
final class TasaHoyViewModel: ObservableObject {
    // MARK: - Persistence Keys
    private static let defaultCurrencyKey = "com.tasahoy.pref.defaultCurrency"
    private static let precisionKey = "com.tasahoy.pref.precision"
    private static let numberStyleKey = "com.tasahoy.pref.numberStyle"
    private static let fxAnchorKey = "com.tasahoy.pref.fxAnchor"
    private static let extraWorldCodesKey = "com.tasahoy.data.extraWorldCodes"
    private static let customCurrenciesKey = "com.tasahoy.data.customCurrencies"
    private static let paymentProfilesKey = "com.tasahoy.data.paymentProfiles"

    // MARK: - Navigation & Sheets
    @Published var selectedTab: AppTab = .converter
    @Published var showCurrencyPicker: Bool = false
    @Published var showAddCurrency: Bool = false
    @Published var showScanner: Bool = false
    @Published var showSettings: Bool = false
    @Published var showShareCardSheet: Bool = false
    @Published var shareItems: [Any] = []
    @Published var showSystemShareSheet: Bool = false
    @Published var toastMessage: String?

    // MARK: - Market Data
    @Published var snapshot: MarketSnapshot?
    @Published var isRefreshing: Bool = false
    @Published var lastError: String?
    @Published var useUpcomingBCV: Bool = false

    // MARK: - Converter & Calculator State
    @Published var selectedSource: RateSourceID
    @Published var activeSide: ConversionSide = .foreign
    @Published var rawExpression: String = "1"
    @Published var showCalculatorKeypad: Bool = true

    // MARK: - User Preferences
    @Published var defaultSource: RateSourceID {
        didSet {
            UserDefaults.standard.set(defaultSource.storageKey, forKey: Self.defaultCurrencyKey)
        }
    }

    @Published var precision: DecimalPrecisionMode {
        didSet {
            UserDefaults.standard.set(precision.rawValue, forKey: Self.precisionKey)
        }
    }

    @Published var numberStyle: NumberStylePreference {
        didSet {
            UserDefaults.standard.set(numberStyle.rawValue, forKey: Self.numberStyleKey)
        }
    }

    @Published var fxAnchor: FXAnchorMode {
        didSet {
            UserDefaults.standard.set(fxAnchor.rawValue, forKey: Self.fxAnchorKey)
        }
    }

    // MARK: - User Currencies & Payment Profiles
    @Published var extraWorldCodes: [String] {
        didSet {
            UserDefaults.standard.set(extraWorldCodes, forKey: Self.extraWorldCodesKey)
        }
    }

    @Published var customCurrencies: [CustomCurrencyItem] {
        didSet {
            if let data = try? JSONEncoder().encode(customCurrencies) {
                UserDefaults.standard.set(data, forKey: Self.customCurrenciesKey)
            }
        }
    }

    @Published var paymentProfiles: [PaymentProfile] {
        didSet {
            if let data = try? JSONEncoder().encode(paymentProfiles) {
                UserDefaults.standard.set(data, forKey: Self.paymentProfilesKey)
            }
        }
    }

    private var lastAutoRefreshDate: Date?
    private var toastTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        let savedDefaultKey = UserDefaults.standard.string(forKey: Self.defaultCurrencyKey) ?? "bcv_usd"
        let resolvedDefault = RateSourceID(storageKey: savedDefaultKey)
        self.defaultSource = resolvedDefault
        self.selectedSource = resolvedDefault

        let savedPrecision = UserDefaults.standard.integer(forKey: Self.precisionKey)
        self.precision = DecimalPrecisionMode(rawValue: savedPrecision) ?? .two

        let savedStyle = UserDefaults.standard.string(forKey: Self.numberStyleKey)
        self.numberStyle = savedStyle.flatMap(NumberStylePreference.init(rawValue:)) ?? .venezuela

        let savedAnchor = UserDefaults.standard.string(forKey: Self.fxAnchorKey)
        self.fxAnchor = savedAnchor.flatMap(FXAnchorMode.init(rawValue:)) ?? .bcv

        self.extraWorldCodes = UserDefaults.standard.stringArray(forKey: Self.extraWorldCodesKey) ?? []

        if let data = UserDefaults.standard.data(forKey: Self.customCurrenciesKey),
           let decoded = try? JSONDecoder().decode([CustomCurrencyItem].self, from: data) {
            self.customCurrencies = decoded
        } else {
            self.customCurrencies = []
        }

        if let data = UserDefaults.standard.data(forKey: Self.paymentProfilesKey),
           let decoded = try? JSONDecoder().decode([PaymentProfile].self, from: data) {
            self.paymentProfiles = decoded
        } else {
            self.paymentProfiles = []
        }

        // Load cached market snapshot synchronously so the UI renders instantly in 0ms!
        self.snapshot = RateService.shared.loadCachedSnapshot()
        if resolvedDefault == .cop {
            self.rawExpression = "1000"
        }
    }

    // MARK: - Refresh Logic

    func refreshIfNeededOnForeground() async {
        if let last = lastAutoRefreshDate, Date().timeIntervalSince(last) < 60, snapshot != nil {
            return
        }
        await refreshRates(forceHaptic: false)
    }

    func refreshRates(forceHaptic: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        if forceHaptic {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        do {
            let fresh = try await RateService.shared.fetchLiveMarketSnapshot()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                self.snapshot = fresh
                if !fresh.hasUpcomingBCVRate {
                    self.useUpcomingBCV = false
                }
            }
            self.lastAutoRefreshDate = Date()
            if forceHaptic {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } catch {
            self.lastError = L10n.converterOfflineCache
            if forceHaptic {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        isRefreshing = false
    }

    // MARK: - Rate Resolution Helpers

    func rateInVES(for source: RateSourceID) -> Double {
        if case .custom(let id) = source {
            return customCurrencies.first(where: { $0.id == id })?.rateInVES ?? 0
        }
        guard let snapshot else { return 0 }
        switch source {
        case .bcvUSD:
            return snapshot.activeBCVUSD(useUpcoming: useUpcomingBCV).value
        case .bcvEUR:
            return snapshot.activeBCVEUR(useUpcoming: useUpcomingBCV).value
        case .usdt:
            return snapshot.usdt.average
        case .averageBCVUSDT:
            return snapshot.averageBCVUSDT(useUpcomingBCV: useUpcomingBCV)
        case .cop:
            return snapshot.vesPerUnit(worldCode: "COP", anchor: fxAnchor, useUpcomingBCV: useUpcomingBCV) ?? 0
        case .world(let code):
            return snapshot.vesPerUnit(worldCode: code, anchor: fxAnchor, useUpcomingBCV: useUpcomingBCV) ?? 0
        case .custom:
            return 0
        }
    }

    var currentRateInVES: Double {
        rateInVES(for: selectedSource)
    }

    func title(for source: RateSourceID) -> String {
        switch source {
        case .bcvUSD: return L10n.rateBCVUSD
        case .bcvEUR: return L10n.rateBCVEUR
        case .usdt: return L10n.rateUSDT
        case .averageBCVUSDT: return L10n.rateAverageShort
        case .cop: return L10n.rateCOP
        case .world(let code):
            return WorldCurrencyPreset.preset(for: code)?.localizedName ?? code
        case .custom(let id):
            return customCurrencies.first(where: { $0.id == id })?.name ?? L10n.rateCustom
        }
    }

    func subtitle(for source: RateSourceID) -> String {
        switch source {
        case .bcvUSD, .bcvEUR: return L10n.subtitleBCVOfficial
        case .usdt: return snapshot?.usdt.sourceLabel ?? L10n.subtitleBinanceP2P
        case .averageBCVUSDT: return L10n.subtitleAverage
        case .cop: return "\(L10n.subtitleCOP) · \(fxAnchor.localizedTitle)"
        case .world(let code): return "\(code) · \(fxAnchor.localizedTitle)"
        case .custom: return L10n.subtitleCustom
        }
    }

    func symbol(for source: RateSourceID) -> String {
        switch source {
        case .bcvUSD: return "$"
        case .bcvEUR: return "€"
        case .usdt: return "USDT"
        case .averageBCVUSDT: return "$"
        case .cop: return "COP"
        case .world(let code):
            return WorldCurrencyPreset.preset(for: code)?.symbol ?? code
        case .custom(let id):
            return customCurrencies.first(where: { $0.id == id })?.symbol ?? "$"
        }
    }

    func badgeCode(for source: RateSourceID) -> String {
        switch source {
        case .bcvUSD: return "USD"
        case .bcvEUR: return "EUR"
        case .usdt: return "USDT"
        case .averageBCVUSDT: return "PROM"
        case .cop: return "COP"
        case .world(let code): return code.uppercased()
        case .custom(let id):
            let sym = customCurrencies.first(where: { $0.id == id })?.symbol ?? "★"
            return sym.isEmpty ? "★" : sym
        }
    }

    func customColorHex(for source: RateSourceID) -> String? {
        if case .custom(let id) = source {
            return customCurrencies.first(where: { $0.id == id })?.colorHex
        }
        return nil
    }

    func deltaInfo(for source: RateSourceID) -> (delta: Double, percent: Double?)? {
        guard let snapshot else { return nil }
        switch source {
        case .bcvUSD:
            let entry = snapshot.activeBCVUSD(useUpcoming: useUpcomingBCV)
            guard let d = entry.delta else { return nil }
            return (d, entry.deltaPercent)
        case .bcvEUR:
            let entry = snapshot.activeBCVEUR(useUpcoming: useUpcomingBCV)
            guard let d = entry.delta else { return nil }
            return (d, entry.deltaPercent)
        case .usdt:
            guard let d = snapshot.usdt.delta else { return nil }
            return (d, snapshot.usdt.deltaPercent)
        case .averageBCVUSDT:
            let usd = snapshot.activeBCVUSD(useUpcoming: useUpcomingBCV)
            if let prevUSD = usd.previousValue, let prevUSDT = snapshot.usdt.previousAverage {
                let prevAvg = (prevUSD + prevUSDT) / 2.0
                let currAvg = snapshot.averageBCVUSDT(useUpcomingBCV: useUpcomingBCV)
                let delta = currAvg - prevAvg
                let pct = prevAvg > 0 ? (delta / prevAvg) * 100.0 : nil
                return (delta, pct)
            }
            return nil
        default:
            return nil
        }
    }

    /// Date label shown on the Converter hero card for the selected currency.
    var activeDateLabel: String {
        guard let snapshot else { return "—" }
        switch selectedSource {
        case .bcvUSD:
            let key = snapshot.activeBCVUSD(useUpcoming: useUpcomingBCV).effectiveDateKey
            return VenezuelaDateHelper.formattedValueDate(key)
        case .bcvEUR:
            let key = snapshot.activeBCVEUR(useUpcoming: useUpcomingBCV).effectiveDateKey
            return VenezuelaDateHelper.formattedValueDate(key)
        case .usdt:
            return "\(L10n.converterUpdatedAt) · \(VenezuelaDateHelper.formattedTime(snapshot.usdt.updatedAt))"
        case .averageBCVUSDT:
            return "\(L10n.converterUpdatedAt) · \(VenezuelaDateHelper.formattedTime(snapshot.lastSyncedAt))"
        case .cop, .world:
            return "\(L10n.converterUpdatedAt) · \(VenezuelaDateHelper.formattedTime(snapshot.lastSyncedAt))"
        case .custom:
            return L10n.subtitleCustom
        }
    }

    var isBCVSourceSelected: Bool {
        selectedSource == .bcvUSD || selectedSource == .bcvEUR
    }

    // MARK: - Evaluated Converter Amounts

    var evaluatedInputValue: Double {
        MathExpressionEvaluator.evaluate(rawExpression) ?? 0
    }

    var hasActiveExpression: Bool {
        MathExpressionEvaluator.containsOperator(rawExpression)
    }

    var foreignAmount: Double {
        switch activeSide {
        case .foreign:
            return evaluatedInputValue
        case .bolivares:
            let rate = currentRateInVES
            guard rate > 0 else { return 0 }
            return evaluatedInputValue / rate
        }
    }

    var bolivaresAmount: Double {
        switch activeSide {
        case .foreign:
            return evaluatedInputValue * currentRateInVES
        case .bolivares:
            return evaluatedInputValue
        }
    }

    var formattedForeignDisplay: String {
        if activeSide == .foreign {
            return NumberFormatHelper.formatRawExpressionForDisplay(rawExpression, style: numberStyle)
        }
        let decimals = selectedSource.isSmallUnitCurrency ? 0 : 2
        return NumberFormatHelper.format(foreignAmount, decimals: decimals, style: numberStyle)
    }

    var formattedBolivaresDisplay: String {
        if activeSide == .bolivares {
            return NumberFormatHelper.formatRawExpressionForDisplay(rawExpression, style: numberStyle)
        }
        return NumberFormatHelper.format(bolivaresAmount, decimals: 2, style: numberStyle)
    }

    var formattedEvaluatedSubline: String? {
        guard hasActiveExpression else { return nil }
        let val = evaluatedInputValue
        let formatted = NumberFormatHelper.format(val, decimals: 2, style: numberStyle)
        let unit = activeSide == .foreign ? symbol(for: selectedSource) : "Bs"
        return "= \(formatted) \(unit)"
    }

    /// Clean Bs amount string ready to append to a Payment Profile share text!
    var currentBolivaresAmountLine: String? {
        guard bolivaresAmount > 0 else { return nil }
        let bs = NumberFormatHelper.format(bolivaresAmount, decimals: 2, style: numberStyle)
        return "\(bs) Bs"
    }

    // MARK: - Converter Interaction & Arithmetic Keypad

    func selectSource(_ source: RateSourceID) {
        let wasSmall = selectedSource.isSmallUnitCurrency
        let isSmall = source.isSmallUnitCurrency
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            selectedSource = source
            // Make COP default cleanly to 1.000 COP when switching from 1 USD so user immediately sees useful Bs value
            if activeSide == .foreign {
                if !wasSmall && isSmall && rawExpression == "1" {
                    rawExpression = "1000"
                } else if wasSmall && !isSmall && rawExpression == "1000" {
                    rawExpression = "1"
                }
            }
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func switchActiveSide(to side: ConversionSide) {
        guard activeSide != side else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Carry over the computed numeric value cleanly onto the newly focused side
        let carriedValue = (side == .foreign) ? foreignAmount : bolivaresAmount
        activeSide = side
        if carriedValue > 0 {
            let decimals = (side == .foreign && selectedSource.isSmallUnitCurrency) ? 0 : 2
            rawExpression = canonicalInputString(carriedValue, maxDecimals: decimals)
        } else {
            rawExpression = "1"
        }
    }

    func swapActiveSide() {
        switchActiveSide(to: activeSide == .foreign ? .bolivares : .foreign)
    }

    func applyPresetAmount(_ amount: Double) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        rawExpression = canonicalInputString(amount, maxDecimals: 2)
    }

    func applyScannedAmount(_ amount: Double, asBolivares: Bool) {
        activeSide = asBolivares ? .bolivares : .foreign
        rawExpression = canonicalInputString(amount, maxDecimals: 2)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func keypadTap(_ key: String) {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        switch key {
        case "C":
            rawExpression = "0"
        case "⌫":
            if rawExpression.count <= 1 {
                rawExpression = "0"
            } else {
                rawExpression.removeLast()
            }
        case "=":
            if let result = MathExpressionEvaluator.evaluate(rawExpression) {
                rawExpression = canonicalInputString(result, maxDecimals: 4)
            }
        case "+", "-", "*", "/":
            if rawExpression.isEmpty {
                rawExpression = "0"
            }
            if let last = rawExpression.last, "+-*/".contains(last) {
                rawExpression.removeLast()
            }
            if rawExpression.last == "." {
                rawExpression.removeLast()
            }
            rawExpression.append(key)
        case "%":
            guard let last = rawExpression.last, last.isNumber else { return }
            rawExpression.append("%")
        case ".":
            let currentNum = currentTrailingNumberSegment()
            if !currentNum.contains(".") {
                if currentNum.isEmpty {
                    rawExpression.append("0.")
                } else {
                    rawExpression.append(".")
                }
            }
        case "00":
            if rawExpression == "0" { return }
            if currentTrailingNumberSegment().count <= 11 {
                rawExpression.append("00")
            }
        default:
            // Digits 0-9
            guard key.count == 1, let digit = key.first, digit.isNumber else { return }
            if rawExpression == "0" {
                rawExpression = String(digit)
            } else {
                let seg = currentTrailingNumberSegment()
                if seg == "0" {
                    rawExpression.removeLast()
                }
                if seg.count <= 12 {
                    rawExpression.append(digit)
                }
            }
        }
    }

    private func currentTrailingNumberSegment() -> String {
        var chars: [Character] = []
        for ch in rawExpression.reversed() {
            if ch.isNumber || ch == "." {
                chars.append(ch)
            } else {
                break
            }
        }
        return String(chars.reversed())
    }

    private func canonicalInputString(_ value: Double, maxDecimals: Int) -> String {
        guard value.isFinite else { return "0" }
        let rounded = (value * pow(10.0, Double(maxDecimals))).rounded() / pow(10.0, Double(maxDecimals))
        if abs(rounded.rounded() - rounded) < 1e-6 {
            return String(format: "%.0f", rounded)
        }
        var str = String(format: "%.\(maxDecimals)f", rounded)
        while str.contains(".") && (str.hasSuffix("0") || str.hasSuffix(".")) {
            str.removeLast()
        }
        return str.isEmpty ? "0" : str
    }

    // MARK: - Copy & Toast Feedback

    func copyForeignAmount() {
        let decimals = selectedSource.isSmallUnitCurrency ? 0 : 2
        let text = NumberFormatHelper.formatCopyable(foreignAmount, decimals: decimals, style: numberStyle)
        copyToClipboard(text, feedback: "\(text) \(symbol(for: selectedSource)) \(L10n.copied.lowercased())")
    }

    func copyBolivaresAmount() {
        let text = NumberFormatHelper.formatCopyable(bolivaresAmount, decimals: 2, style: numberStyle)
        copyToClipboard(text, feedback: "\(text) Bs \(L10n.copied.lowercased())")
    }

    func copyToClipboard(_ text: String, feedback: String? = nil) {
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showToast(feedback ?? L10n.copied)
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
            toastMessage = message
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.22)) {
                    self?.toastMessage = nil
                }
            }
        }
    }

    // MARK: - Extra World Currencies & Custom Rates CRUD

    func toggleWorldCurrency(code: String) {
        let upper = code.uppercased()
        guard upper != "COP" else { return }
        if let idx = extraWorldCodes.firstIndex(of: upper) {
            extraWorldCodes.remove(at: idx)
            if selectedSource == .world(code: upper) {
                selectedSource = .bcvUSD
            }
        } else {
            extraWorldCodes.append(upper)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func addCustomCurrency(name: String, symbol: String, rateInVES: Double, colorHex: String) {
        let item = CustomCurrencyItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            symbol: symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "$" : symbol.trimmingCharacters(in: .whitespacesAndNewlines),
            rateInVES: rateInVES,
            colorHex: colorHex
        )
        customCurrencies.append(item)
        selectedSource = .custom(id: item.id)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func updateCustomCurrency(_ item: CustomCurrencyItem) {
        if let idx = customCurrencies.firstIndex(where: { $0.id == item.id }) {
            customCurrencies[idx] = item
        }
    }

    func deleteCustomCurrency(_ item: CustomCurrencyItem) {
        customCurrencies.removeAll { $0.id == item.id }
        if selectedSource == .custom(id: item.id) {
            selectedSource = .bcvUSD
        }
        if defaultSource == .custom(id: item.id) {
            defaultSource = .bcvUSD
        }
    }

    // MARK: - Payment Profiles CRUD

    func savePaymentProfile(_ profile: PaymentProfile) {
        if let idx = paymentProfiles.firstIndex(where: { $0.id == profile.id }) {
            paymentProfiles[idx] = profile
        } else {
            paymentProfiles.insert(profile, at: 0)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func deletePaymentProfile(_ profile: PaymentProfile) {
        paymentProfiles.removeAll { $0.id == profile.id }
    }

    // MARK: - Share Visual Rate Card

    func presentShareItems(_ items: [Any]) {
        shareItems = items
        showSystemShareSheet = true
    }

    /// All selectable sources in clean order for Settings default picker & comparison strip.
    var primarySources: [RateSourceID] {
        [.bcvUSD, .bcvEUR, .usdt, .averageBCVUSDT, .cop]
    }

    var allSelectableSources: [RateSourceID] {
        primarySources
        + extraWorldCodes.map { .world(code: $0) }
        + customCurrencies.map { .custom(id: $0.id) }
    }
}
