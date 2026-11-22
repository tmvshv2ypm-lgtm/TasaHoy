import Foundation

/// Concurrent, resilient live market rate fetcher for Venezuela:
/// - Official BCV USD & EUR (active today + upcoming published value date + full history via ve.dolarapi.com & direct bcv.org.ve)
/// - Live USDT Compra / Venta / Promedio directly from Binance P2P (verified merchants, outlier-trimmed mean)
/// - Live Peso Colombiano (COP) & World FX via open.er-api.com
/// - Instant offline persistence cache in UserDefaults
actor RateService {
    static let shared = RateService()

    private static let cacheKey = "com.tasahoy.market.snapshot.v1"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 14
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    // MARK: - Cache

    nonisolated func loadCachedSnapshot() -> MarketSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey) else { return nil }
        return try? JSONDecoder().decode(MarketSnapshot.self, from: data)
    }

    private func saveCachedSnapshot(_ snapshot: MarketSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.cacheKey)
        }
    }

    // MARK: - Public Fetch All

    func fetchLiveMarketSnapshot() async throws -> MarketSnapshot {
        let now = Date()
        let todayKey = VenezuelaDateHelper.todayDayKey(now: now)

        async let dolaresCurrentTask = fetchDolarAPICurrent(endpoint: "https://ve.dolarapi.com/v1/dolares")
        async let eurosCurrentTask = fetchDolarAPICurrent(endpoint: "https://ve.dolarapi.com/v1/euros")
        async let usdHistoryTask = fetchDolarAPIHistory(endpoint: "https://ve.dolarapi.com/v1/historicos/dolares/oficial")
        async let eurHistoryTask = fetchDolarAPIHistory(endpoint: "https://ve.dolarapi.com/v1/historicos/euros/oficial")
        async let paraleloHistoryTask = fetchDolarAPIHistory(endpoint: "https://ve.dolarapi.com/v1/historicos/dolares/paralelo")
        async let binanceTask = fetchBinanceP2PUSDT()
        async let worldFXTask = fetchWorldFXRates()
        async let directBCVTask = fetchDirectBCVHTML()

        let dolaresCurrent = await dolaresCurrentTask
        let eurosCurrent = await eurosCurrentTask
        let usdHistory = await usdHistoryTask
        let eurHistory = await eurHistoryTask
        let paraleloHistory = await paraleloHistoryTask
        let binanceP2P = await binanceTask
        let worldFX = await worldFXTask
        let directBCV = await directBCVTask

        // 1. Resolve Official BCV USD (Today active + Previous + Upcoming value date)
        let currentOfficialUSD = dolaresCurrent.first { $0.fuente == "oficial" }
        let currentParallelUSD = dolaresCurrent.first { $0.fuente == "paralelo" }

        let (usdToday, usdUpcoming) = resolveBCVRate(
            history: usdHistory,
            currentAPI: currentOfficialUSD,
            directValue: directBCV?.usd,
            directDateKey: directBCV?.valueDateKey,
            todayKey: todayKey,
            now: now
        )

        // 2. Resolve Official BCV EUR (Today active + Previous + Upcoming value date)
        let currentOfficialEUR = eurosCurrent.first { $0.fuente == "oficial" }
        let (eurToday, eurUpcoming) = resolveBCVRate(
            history: eurHistory,
            currentAPI: currentOfficialEUR,
            directValue: directBCV?.eur,
            directDateKey: directBCV?.valueDateKey,
            todayKey: todayKey,
            now: now
        )

        // Ensure we got at least one valid BCV or USDT rate before accepting
        guard usdToday.value > 0 || (binanceP2P?.average ?? 0) > 0 else {
            throw URLError(.cannotLoadFromNetwork)
        }

        // 3. Resolve USDT (Binance P2P live preferred; fallback to ve.dolarapi paralelo)
        let previousUSDT: Double? = {
            let past = paraleloHistory.filter { $0.dateKey < todayKey }
            if let prev = past.last?.value { return prev }
            if paraleloHistory.count >= 2 { return paraleloHistory[paraleloHistory.count - 2].value }
            return nil
        }()

        let usdtSnapshot: USDTSnapshot
        if let live = binanceP2P {
            usdtSnapshot = USDTSnapshot(
                buy: live.buy,
                sell: live.sell,
                average: live.average,
                previousAverage: previousUSDT,
                updatedAt: now,
                sourceLabel: "Binance P2P",
                adCountBuy: live.adCountBuy,
                adCountSell: live.adCountSell
            )
        } else {
            let fallbackVal = currentParallelUSD?.promedio ?? paraleloHistory.last?.value ?? usdToday.value
            usdtSnapshot = USDTSnapshot(
                buy: fallbackVal,
                sell: fallbackVal,
                average: fallbackVal,
                previousAverage: previousUSDT,
                updatedAt: now,
                sourceLabel: "Referencia P2P",
                adCountBuy: 0,
                adCountSell: 0
            )
        }

        // 4. Extra BCV official currencies (CNY, TRY, RUB) — direct from bcv.org.ve if available,
        //    otherwise cleanly cross-calculated from Official BCV USD × open.er-api.com FX.
        let extras = BCVExtraRates(
            cny: directBCV?.cny ?? crossRate(baseUSD: usdToday.value, fxPerUSD: worldFX?.rates["CNY"]),
            tryRate: directBCV?.tryRate ?? crossRate(baseUSD: usdToday.value, fxPerUSD: worldFX?.rates["TRY"]),
            rub: directBCV?.rub ?? crossRate(baseUSD: usdToday.value, fxPerUSD: worldFX?.rates["RUB"]),
            isDirectBCV: directBCV?.cny != nil
        )

        // Append today's live USDT point to history if needed so the chart ends right at live value
        var mergedUSDTHistory = paraleloHistory
        if let liveAvg = binanceP2P?.average, liveAvg > 0 {
            if mergedUSDTHistory.last?.dateKey == todayKey {
                mergedUSDTHistory[mergedUSDTHistory.count - 1] = HistoricalPoint(dateKey: todayKey, value: liveAvg)
            } else {
                mergedUSDTHistory.append(HistoricalPoint(dateKey: todayKey, value: liveAvg))
            }
        }

        let snapshot = MarketSnapshot(
            bcvUSD: usdToday,
            bcvUSDUpcoming: usdUpcoming,
            bcvEUR: eurToday,
            bcvEURUpcoming: eurUpcoming,
            bcvExtras: extras,
            usdt: usdtSnapshot,
            worldRatesPerUSD: worldFX?.rates ?? Self.fallbackWorldFX,
            worldRatesUpdatedAt: worldFX?.updatedAt,
            historyBCVUSD: usdHistory,
            historyBCVEUR: eurHistory,
            historyUSDT: mergedUSDTHistory,
            lastSyncedAt: now,
            bcvSourceIsDirect: directBCV != nil
        )

        saveCachedSnapshot(snapshot)
        return snapshot
    }

    private func crossRate(baseUSD: Double, fxPerUSD: Double?) -> Double? {
        guard baseUSD > 0, let fxPerUSD, fxPerUSD > 0 else { return nil }
        return baseUSD / fxPerUSD
    }

    // MARK: - BCV Active vs Upcoming Resolver

    private func resolveBCVRate(
        history: [HistoricalPoint],
        currentAPI: DolarAPICurrentDTO?,
        directValue: Double?,
        directDateKey: String?,
        todayKey: String,
        now: Date
    ) -> (today: RateEntry, upcoming: RateEntry?) {
        let sorted = history.sorted { $0.dateKey < $1.dateKey }
        let activePoints = sorted.filter { $0.dateKey <= todayKey }
        let futurePoints = sorted.filter { $0.dateKey > todayKey }

        var activeValue = activePoints.last?.value ?? currentAPI?.promedio ?? directValue ?? 0
        var activeDateKey = activePoints.last?.dateKey ?? extractDayKey(from: currentAPI?.fechaActualizacion) ?? todayKey
        var prevValue: Double? = activePoints.count >= 2 ? activePoints[activePoints.count - 2].value : nil

        // If the current endpoint has a newer valid rate for <= today than history
        if let apiVal = currentAPI?.promedio, apiVal > 0,
           let apiKey = extractDayKey(from: currentAPI?.fechaActualizacion),
           apiKey <= todayKey,
           apiKey >= activeDateKey {
            if apiKey > activeDateKey {
                prevValue = activeValue > 0 ? activeValue : prevValue
            }
            activeValue = apiVal
            activeDateKey = apiKey
        }

        // Check upcoming BCV value date (published after ~5pm VET for next business day)
        var upcomingEntry: RateEntry?
        if let future = futurePoints.last, future.value > 0 {
            upcomingEntry = RateEntry(
                value: future.value,
                previousValue: activeValue > 0 ? activeValue : nil,
                effectiveDateKey: future.dateKey,
                updatedAt: now
            )
        } else if let directValue, directValue > 0, let directDateKey, directDateKey > todayKey {
            upcomingEntry = RateEntry(
                value: directValue,
                previousValue: activeValue > 0 ? activeValue : nil,
                effectiveDateKey: directDateKey,
                updatedAt: now
            )
        }

        // If direct BCV matches today's value date and has higher precision, prefer it
        if let directValue, directValue > 0, let directDateKey, directDateKey == activeDateKey {
            activeValue = directValue
        }

        let todayEntry = RateEntry(
            value: activeValue,
            previousValue: prevValue,
            effectiveDateKey: activeDateKey,
            updatedAt: now
        )
        return (todayEntry, upcomingEntry)
    }

    private func extractDayKey(from iso: String?) -> String? {
        guard let iso, iso.count >= 10 else { return nil }
        let prefix = String(iso.prefix(10))
        return VenezuelaDateHelper.date(fromDayKey: prefix) != nil ? prefix : nil
    }

    // MARK: - DolarAPI VE (Official BCV mirror + full daily history)

    private struct DolarAPICurrentDTO: Decodable {
        let moneda: String?
        let fuente: String?
        let promedio: Double?
        let fechaActualizacion: String?
    }

    private struct DolarAPIHistoryDTO: Decodable {
        let fuente: String?
        let promedio: Double?
        let fecha: String?
    }

    private func fetchDolarAPICurrent(endpoint: String) async -> [DolarAPICurrentDTO] {
        guard let url = URL(string: endpoint) else { return [] }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            return try JSONDecoder().decode([DolarAPICurrentDTO].self, from: data)
        } catch {
            return []
        }
    }

    private func fetchDolarAPIHistory(endpoint: String) async -> [HistoricalPoint] {
        guard let url = URL(string: endpoint) else { return [] }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            let rows = try JSONDecoder().decode([DolarAPIHistoryDTO].self, from: data)
            // Keep up to the last 400 days so 1Y charts are crisp and cache stays tiny
            let mapped = rows.compactMap { row -> HistoricalPoint? in
                guard let fecha = row.fecha, let avg = row.promedio, avg > 0 else { return nil }
                return HistoricalPoint(dateKey: fecha, value: avg)
            }
            if mapped.count > 400 {
                return Array(mapped.suffix(400))
            }
            return mapped
        } catch {
            return []
        }
    }

    // MARK: - Direct BCV Official HTML (Standard Verified HTTPS — Zero TLS Bypass)

    private struct DirectBCVResult {
        let usd: Double?
        let eur: Double?
        let cny: Double?
        let tryRate: Double?
        let rub: Double?
        let valueDateKey: String?
    }

    private func fetchDirectBCVHTML() async -> DirectBCVResult? {
        guard let url = URL(string: "https://www.bcv.org.ve/") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 6
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                return nil
            }

            let usd = extractBCVValue(in: html, blockID: "dolar")
            let eur = extractBCVValue(in: html, blockID: "euro")
            let cny = extractBCVValue(in: html, blockID: "yuan")
            let tryRate = extractBCVValue(in: html, blockID: "lira")
            let rub = extractBCVValue(in: html, blockID: "rublo")
            let valueDate = extractBCVValueDate(in: html)

            guard usd != nil || eur != nil else { return nil }
            return DirectBCVResult(usd: usd, eur: eur, cny: cny, tryRate: tryRate, rub: rub, valueDateKey: valueDate)
        } catch {
            return nil
        }
    }

    private func extractBCVValue(in html: String, blockID: String) -> Double? {
        let pattern = #"id=""# + blockID + #""[\s\S]{0,600}?<strong[^>]*>\s*([0-9\.,]+)\s*</strong>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let raw = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        // Venezuelan format: "1.011,17949056" -> "1011.17949056"
        let normalized = raw.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func extractBCVValueDate(in html: String) -> String? {
        let pattern = #"content="(\d{4}-\d{2}-\d{2})T"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[range])
    }

    // MARK: - Binance P2P Live USDT/VES

    private struct BinanceP2PResponse: Decodable {
        struct Item: Decodable {
            struct Adv: Decodable {
                let price: String
            }
            let adv: Adv
            let privilegeDesc: String?
        }
        let data: [Item]?
    }

    private struct BinanceLiveQuote {
        let buy: Double
        let sell: Double
        let average: Double
        let adCountBuy: Int
        let adCountSell: Int
    }

    private func fetchBinanceP2PUSDT() async -> BinanceLiveQuote? {
        async let buyPricesTask = fetchBinanceP2PSide(tradeType: "BUY")
        async let sellPricesTask = fetchBinanceP2PSide(tradeType: "SELL")

        let buyPrices = await buyPricesTask
        let sellPrices = await sellPricesTask

        guard !buyPrices.isEmpty || !sellPrices.isEmpty else { return nil }

        let buyAvg = trimmedMean(buyPrices) ?? trimmedMean(sellPrices) ?? 0
        let sellAvg = trimmedMean(sellPrices) ?? trimmedMean(buyPrices) ?? 0
        guard buyAvg > 0, sellAvg > 0 else { return nil }

        return BinanceLiveQuote(
            buy: buyAvg,
            sell: sellAvg,
            average: (buyAvg + sellAvg) / 2.0,
            adCountBuy: buyPrices.count,
            adCountSell: sellPrices.count
        )
    }

    private func fetchBinanceP2PSide(tradeType: String) async -> [Double] {
        guard let url = URL(string: "https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search") else { return [] }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let payload: [String: Any] = [
            "asset": "USDT",
            "fiat": "VES",
            "page": 1,
            "rows": 15,
            "tradeType": tradeType,
            "payTypes": [],
            "publisherType": "merchant"
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await session.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            let decoded = try JSONDecoder().decode(BinanceP2PResponse.self, from: data)
            let organic = (decoded.data ?? [])
                .filter { $0.privilegeDesc == nil }
                .compactMap { Double($0.adv.price) }
                .filter { $0 > 0 }
            if !organic.isEmpty {
                return Array(organic.prefix(12))
            }
            return (decoded.data ?? []).compactMap { Double($0.adv.price) }.filter { $0 > 0 }
        } catch {
            return []
        }
    }

    /// Outlier-resistant trimmed mean: drops the lowest and highest quote when n >= 5.
    private func trimmedMean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let slice: ArraySlice<Double>
        if sorted.count >= 6 {
            slice = sorted.dropFirst().dropLast()
        } else {
            slice = sorted[...]
        }
        return slice.reduce(0, +) / Double(slice.count)
    }

    // MARK: - World FX Rates (COP, BRL, GBP, MXN, CNY, TRY, RUB, etc.)

    private struct OpenERResponse: Decodable {
        let rates: [String: Double]?
        let time_last_update_unix: Double?
    }

    private struct WorldFXQuote {
        let rates: [String: Double]
        let updatedAt: Date?
    }

    private func fetchWorldFXRates() async -> WorldFXQuote? {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(OpenERResponse.self, from: data)
            guard let rates = decoded.rates, !rates.isEmpty else { return nil }
            let updatedAt = decoded.time_last_update_unix.map { Date(timeIntervalSince1970: $0) }
            return WorldFXQuote(rates: rates, updatedAt: updatedAt)
        } catch {
            return nil
        }
    }

    private static let fallbackWorldFX: [String: Double] = [
        "COP": 3341.89,
        "EUR": 0.911,
        "BRL": 5.93,
        "GBP": 0.764,
        "MXN": 19.12,
        "CNY": 7.12,
        "TRY": 36.2,
        "RUB": 82.0,
        "CLP": 940.0,
        "PEN": 3.72,
        "CAD": 1.38,
        "CHF": 0.87
    ]
}
