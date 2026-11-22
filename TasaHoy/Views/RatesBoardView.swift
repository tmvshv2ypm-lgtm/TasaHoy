import SwiftUI
import Charts
import UIKit

/// Complete Market Rates & Interactive Historical Charts Screen ("Tasas"):
/// - Official BCV Rates (USD, EUR + expandable CNY, TRY, RUB + Upcoming BCV Value Date)
/// - Live Binance P2P USDT (Compra, Venta, Promedio — zero cooldowns, zero ads!)
/// - Brecha USDT vs BCV & Automatic Promedio (BCV + USDT)
/// - Peso Colombiano (COP) & Added Currencies
/// - Native Apple Swift Charts interactive historical graph (7D / 15D / 30D / 90D / 1A)
struct RatesBoardView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: TasaHoyViewModel
    @ObservedObject private var themeManager = TasaThemeManager.shared

    @State private var showExtraBCV: Bool = false
    @State private var selectedChartSeries: ChartSeriesKind = .bcvUSD
    @State private var selectedChartRange: ChartRange = .month
    @State private var scrubbedPoint: HistoricalPoint?

    private var hPadding: CGFloat {
        horizontalSizeClass == .regular ? 28 : 16
    }

    private var maxReadableWidth: CGFloat {
        horizontalSizeClass == .regular ? 860 : .infinity
    }

    var body: some View {
        ZStack {
            AmbientLiquidBackdrop(activeAccent: themeManager.primaryAccent)

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    // Bold left-aligned title matching Voice Notes
                    HStack(alignment: .firstTextBaseline) {
                        Text(L10n.ratesTitle)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.primary)

                        Spacer()

                        if let snap = viewModel.snapshot {
                            Text("\(L10n.converterUpdatedAt) · \(VenezuelaDateHelper.formattedTime(snap.lastSyncedAt))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), in: Capsule())
                        }
                    }
                    .padding(.top, 2)

                    if let snap = viewModel.snapshot {
                        // MARK: 1. Official BCV Section
                        bcvOfficialSection(snap: snap)

                        // MARK: 2. Live Binance P2P USDT Section
                        usdtLiveSection(snap: snap)

                        // MARK: 3. Brecha & Promedio Section
                        gapAndAverageSection(snap: snap)

                        // MARK: 4. Interactive Swift Charts Historical Section
                        historicalChartSection(snap: snap)

                        // MARK: 5. Peso Colombiano (COP) & Extra Currencies Section
                        copAndWorldSection(snap: snap)
                    } else {
                        loadingPlaceholderCard
                    }
                }
                .padding(.horizontal, hPadding)
                .padding(.bottom, 30)
                .frame(maxWidth: maxReadableWidth)
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                await viewModel.refreshRates(forceHaptic: true)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        Task { await viewModel.refreshRates(forceHaptic: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .rotationEffect(.degrees(viewModel.isRefreshing ? 360 : 0))
                            .animation(
                                viewModel.isRefreshing
                                    ? .linear(duration: 0.85).repeatForever(autoreverses: false)
                                    : .default,
                                value: viewModel.isRefreshing
                            )
                            .frame(width: 38, height: 38)
                            .liquidGlassCircle(interactive: true)
                    }
                    .buttonStyle(.plain)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 38, height: 38)
                            .liquidGlassCircle(interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, hPadding)
            .padding(.vertical, 4)
            .frame(maxWidth: maxReadableWidth)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 1. Official BCV Section

    private func bcvOfficialSection(snap: MarketSnapshot) -> some View {
        let usd = snap.activeBCVUSD(useUpcoming: viewModel.useUpcomingBCV)
        let eur = snap.activeBCVEUR(useUpcoming: viewModel.useUpcomingBCV)
        let emerald = themeManager.accent(for: .bcvUSD)
        let blue = themeManager.accent(for: .bcvEUR)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle(L10n.ratesBCVSection)
                Spacer()
                Text("\(L10n.ratesValueDate): \(VenezuelaDateHelper.formattedShortDay(usd.effectiveDateKey))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(emerald)
            }

            // Upcoming BCV published alert banner
            if let nextUSD = snap.bcvUSDUpcoming {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        viewModel.useUpcomingBCV.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(hex: "#D97706"))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.ratesUpcomingPublished)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)
                            Text("\(VenezuelaDateHelper.formattedValueDate(nextUSD.effectiveDateKey)) · \(NumberFormatHelper.format(nextUSD.value, decimals: 4, style: viewModel.numberStyle)) Bs")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(viewModel.useUpcomingBCV ? L10n.converterSwitchToToday : L10n.converterSwitchToNext)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(hex: "#D97706"), in: Capsule())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .tasaCardSurface(cornerRadius: 18, tint: Color(hex: "#F59E0B"))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                rateDetailRow(
                    symbol: "$",
                    title: L10n.rateBCVUSD,
                    subtitle: "USD · bcv.org.ve",
                    value: usd.value,
                    decimals: 4,
                    delta: usd.delta,
                    deltaPercent: usd.deltaPercent,
                    accent: emerald
                ) {
                    jumpToConverter(source: .bcvUSD)
                }

                Divider().padding(.leading, 64)

                rateDetailRow(
                    symbol: "€",
                    title: L10n.rateBCVEUR,
                    subtitle: "EUR · bcv.org.ve",
                    value: eur.value,
                    decimals: 4,
                    delta: eur.delta,
                    deltaPercent: eur.deltaPercent,
                    accent: blue
                ) {
                    jumpToConverter(source: .bcvEUR)
                }

                if showExtraBCV {
                    if let cny = snap.bcvExtras.cny {
                        Divider().padding(.leading, 64)
                        compactExtraBCVRow(code: "CNY", flag: "🇨🇳", name: WorldCurrencyPreset.preset(for: "CNY")?.localizedName ?? "CNY", value: cny)
                    }
                    if let tryR = snap.bcvExtras.tryRate {
                        Divider().padding(.leading, 64)
                        compactExtraBCVRow(code: "TRY", flag: "🇹🇷", name: WorldCurrencyPreset.preset(for: "TRY")?.localizedName ?? "TRY", value: tryR)
                    }
                    if let rub = snap.bcvExtras.rub {
                        Divider().padding(.leading, 64)
                        compactExtraBCVRow(code: "RUB", flag: "🇷🇺", name: WorldCurrencyPreset.preset(for: "RUB")?.localizedName ?? "RUB", value: rub)
                    }
                }

                Divider()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        showExtraBCV.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(showExtraBCV ? L10n.ratesLessBCV : L10n.ratesMoreBCV)
                            .font(.caption.weight(.semibold))
                        Image(systemName: showExtraBCV ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)
            }
            .tasaCardSurface(cornerRadius: 22, tint: emerald)
        }
    }

    private func compactExtraBCVRow(code: String, flag: String, name: String, value: Double) -> some View {
        HStack(spacing: 12) {
            Text(flag)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                Text(code)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(NumberFormatHelper.format(value, decimals: 4, style: viewModel.numberStyle)) Bs")
                .font(.subheadline.weight(.bold).monospacedDigit())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 2. Live Binance P2P USDT Section

    private func usdtLiveSection(snap: MarketSnapshot) -> some View {
        let teal = themeManager.accent(for: .usdt)
        let u = snap.usdt

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle(L10n.ratesUSDTSection)
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(teal).frame(width: 6, height: 6)
                    Text(L10n.ratesLiveInstant)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(teal)
                }
            }

            VStack(spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(L10n.ratesAverageLabel) · \(u.sourceLabel)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text("\(NumberFormatHelper.format(u.average, decimals: 2, style: viewModel.numberStyle)) Bs")
                            .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.primary)

                        if let delta = u.delta {
                            let isUp = delta >= 0
                            Text(NumberFormatHelper.formatDelta(delta: delta, percent: u.deltaPercent, style: viewModel.numberStyle))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(isUp ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                        }
                    }

                    Spacer()

                    Button {
                        jumpToConverter(source: .usdt)
                    } label: {
                        Text(L10n.ratesUseInConverter)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(teal, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Compra / Venta Clean Split
                HStack(spacing: 10) {
                    usdtSidePill(
                        title: L10n.ratesBuy,
                        value: u.buy,
                        icon: "arrow.up.circle.fill",
                        color: Color(hex: "#10B981")
                    )

                    usdtSidePill(
                        title: L10n.ratesSell,
                        value: u.sell,
                        icon: "arrow.down.circle.fill",
                        color: Color(hex: "#EF4444")
                    )
                }
            }
            .padding(16)
            .tasaCardSurface(cornerRadius: 22, tint: teal)
        }
    }

    private func usdtSidePill(title: String, value: Double, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(NumberFormatHelper.format(value, decimals: 2, style: viewModel.numberStyle)) Bs")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 3. Brecha & Promedio Section

    private func gapAndAverageSection(snap: MarketSnapshot) -> some View {
        let amber = themeManager.accent(for: .averageBCVUSDT)
        let avg = snap.averageBCVUSDT(useUpcomingBCV: viewModel.useUpcomingBCV)
        let gapPct = snap.bcvUsdtGapPercent(useUpcomingBCV: viewModel.useUpcomingBCV) ?? 0
        let gapBs = snap.bcvUsdtGapBolivares(useUpcomingBCV: viewModel.useUpcomingBCV)

        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle(L10n.ratesGapSection)

            HStack(spacing: 10) {
                // Promedio Card
                Button {
                    jumpToConverter(source: .averageBCVUSDT)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L10n.rateAverageShort)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(amber)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        Text("\(NumberFormatHelper.format(avg, decimals: 2, style: viewModel.numberStyle)) Bs")
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(L10n.subtitleAverage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .tasaCardSurface(cornerRadius: 20, tint: amber)
                }
                .buttonStyle(.plain)

                // Brecha % Card
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.ratesGapTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(gapPct >= 0 ? "+" : "")\(NumberFormatHelper.format(gapPct, decimals: 2, style: viewModel.numberStyle))%")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(abs(gapPct) > 20 ? Color(hex: "#F97316") : Color(hex: "#06B6D4"))
                    Text("\(gapBs >= 0 ? "+" : "")\(NumberFormatHelper.format(gapBs, decimals: 2, style: viewModel.numberStyle)) Bs")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tasaCardSurface(cornerRadius: 20)
            }
        }
    }

    // MARK: - 4. Interactive Historical Chart (Apple Swift Charts)

    private func historicalChartSection(snap: MarketSnapshot) -> some View {
        let points = filteredChartPoints(from: snap)
        let accent = selectedChartSeries.accentColor
        let minVal = points.map(\.value).min() ?? 0
        let maxVal = points.map(\.value).max() ?? 0
        let firstVal = points.first?.value ?? 0
        let lastVal = points.last?.value ?? 0
        let periodPct = firstVal > 0 ? ((lastVal - firstVal) / firstVal) * 100.0 : 0
        let yPadding = max(1.0, (maxVal - minVal) * 0.14)

        return VStack(alignment: .leading, spacing: 10) {
            sectionTitle(L10n.ratesChartSection)

            VStack(alignment: .leading, spacing: 14) {
                // Series Picker
                Picker("", selection: $selectedChartSeries) {
                    ForEach(ChartSeriesKind.allCases) { kind in
                        Text(kind.localizedTitle).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedChartSeries) { _, _ in
                    scrubbedPoint = nil
                }

                // Active / Scrubbed Value Header
                HStack(alignment: .firstTextBaseline) {
                    if let active = scrubbedPoint ?? points.last {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(NumberFormatHelper.format(active.value, decimals: 2, style: viewModel.numberStyle)) Bs")
                                .font(.title2.weight(.bold).monospacedDigit())
                                .foregroundStyle(.primary)
                            Text(VenezuelaDateHelper.formattedValueDate(active.dateKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if !points.isEmpty {
                        Text("\(periodPct >= 0 ? "+" : "")\(NumberFormatHelper.format(periodPct, decimals: 2, style: viewModel.numberStyle))%")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(periodPct >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                (periodPct >= 0 ? Color(hex: "#10B981") : Color(hex: "#EF4444")).opacity(0.14),
                                in: Capsule()
                            )
                    }
                }

                if points.count >= 2 {
                    Chart {
                        ForEach(points) { pt in
                            AreaMark(
                                x: .value("Date", pt.date),
                                yStart: .value("Base", max(0, minVal - yPadding)),
                                yEnd: .value("Rate", pt.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accent.opacity(0.28), accent.opacity(0.01)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Date", pt.date),
                                y: .value("Rate", pt.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .foregroundStyle(accent)
                        }

                        if let scrubbed = scrubbedPoint {
                            RuleMark(x: .value("Selected", scrubbed.date))
                                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                                .foregroundStyle(accent.opacity(0.6))

                            PointMark(x: .value("Selected", scrubbed.date), y: .value("Rate", scrubbed.value))
                                .symbolSize(64)
                                .foregroundStyle(accent)
                        }
                    }
                    .chartYScale(domain: max(0, minVal - yPadding)...(maxVal + yPadding))
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                .font(.caption2)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4, dash: [3, 3]))
                                .foregroundStyle(Color.secondary.opacity(0.28))
                            AxisValueLabel()
                                .font(.caption2.monospacedDigit())
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            guard let plotFrame = proxy.plotFrame else { return }
                                            let origin = geo[plotFrame].origin
                                            let x = value.location.x - origin.x
                                            if let date: Date = proxy.value(atX: x) {
                                                if let nearest = points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }) {
                                                    if scrubbedPoint?.id != nearest.id {
                                                        scrubbedPoint = nearest
                                                        UISelectionFeedbackGenerator().selectionChanged()
                                                    }
                                                }
                                            }
                                        }
                                        .onEnded { _ in
                                            scrubbedPoint = nil
                                        }
                                )
                        }
                    }
                    .frame(height: 190)

                    // Min / Max Summary
                    HStack(spacing: 12) {
                        Text("\(L10n.chartMin): \(NumberFormatHelper.format(minVal, decimals: 2, style: viewModel.numberStyle)) Bs")
                        Spacer()
                        Text("\(L10n.chartMax): \(NumberFormatHelper.format(maxVal, decimals: 2, style: viewModel.numberStyle)) Bs")
                    }
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                } else {
                    Text(L10n.chartNoData)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                }

                // Range Pills (7D / 15D / 30D / 90D / 1A)
                HStack(spacing: 6) {
                    ForEach(ChartRange.allCases) { range in
                        let selected = selectedChartRange == range
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedChartRange = range
                                scrubbedPoint = nil
                            }
                        } label: {
                            Text(range.localizedTitle)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(selected ? .white : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(
                                    selected ? accent : Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.045),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .tasaCardSurface(cornerRadius: 22)
        }
    }

    private func filteredChartPoints(from snap: MarketSnapshot) -> [HistoricalPoint] {
        let all: [HistoricalPoint]
        switch selectedChartSeries {
        case .bcvUSD: all = snap.historyBCVUSD
        case .bcvEUR: all = snap.historyBCVEUR
        case .usdt: all = snap.historyUSDT
        }
        guard !all.isEmpty else { return [] }
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedChartRange.dayCount, to: Date()) ?? Date.distantPast
        let filtered = all.filter { $0.date >= cutoff }
        return filtered.count >= 2 ? filtered : Array(all.suffix(min(all.count, 10)))
    }

    // MARK: - 5. Peso Colombiano (COP) & Extra Currencies

    private func copAndWorldSection(snap: MarketSnapshot) -> some View {
        let violet = themeManager.accent(for: .cop)
        let copPerUSD = snap.worldRatesPerUSD["COP"] ?? 0
        let vesPerCOP = snap.vesPerUnit(worldCode: "COP", anchor: viewModel.fxAnchor, useUpcomingBCV: viewModel.useUpcomingBCV) ?? 0
        let bsPer1000COP = vesPerCOP * 1000.0
        let copPer1Bs = vesPerCOP > 0 ? (1.0 / vesPerCOP) : 0

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionTitle(L10n.ratesWorldSection)
                Spacer()
                Button {
                    viewModel.showAddCurrency = true
                } label: {
                    Label(L10n.add, systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(themeManager.primaryAccent)
                }
                .buttonStyle(.plain)
            }

            // Dedicated Peso Colombiano Card
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 10) {
                        Text("🇨🇴")
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(violet.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.rateCOP)
                                .font(.subheadline.weight(.bold))
                            Text("COP · \(viewModel.fxAnchor.localizedTitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        jumpToConverter(source: .cop)
                    } label: {
                        Text(L10n.ratesUseInConverter)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(violet, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    copMetricBox(
                        title: L10n.ratesPer1000COP,
                        value: "\(NumberFormatHelper.format(bsPer1000COP, decimals: 2, style: viewModel.numberStyle)) Bs"
                    )
                    copMetricBox(
                        title: L10n.ratesCOPPerBs,
                        value: "\(NumberFormatHelper.format(copPer1Bs, decimals: 2, style: viewModel.numberStyle)) COP"
                    )
                    copMetricBox(
                        title: L10n.ratesCOPPerUSD,
                        value: "\(NumberFormatHelper.format(copPerUSD, decimals: 0, style: viewModel.numberStyle))"
                    )
                }
            }
            .padding(16)
            .tasaCardSurface(cornerRadius: 22, tint: violet)

            // Added extra world currencies + custom rates
            if !viewModel.extraWorldCodes.isEmpty || !viewModel.customCurrencies.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.extraWorldCodes.enumerated()), id: \.element) { idx, code in
                        if idx > 0 { Divider().padding(.leading, 64) }
                        let preset = WorldCurrencyPreset.preset(for: code)
                        let val = viewModel.rateInVES(for: .world(code: code))
                        rateDetailRow(
                            symbol: preset?.flag ?? code,
                            title: preset?.localizedName ?? code,
                            subtitle: "\(code) · \(viewModel.fxAnchor.localizedTitle)",
                            value: val,
                            decimals: val < 1 ? 4 : 2,
                            delta: nil,
                            deltaPercent: nil,
                            accent: themeManager.accent(for: .world(code: code))
                        ) {
                            jumpToConverter(source: .world(code: code))
                        }
                    }

                    ForEach(Array(viewModel.customCurrencies.enumerated()), id: \.element.id) { idx, item in
                        if idx > 0 || !viewModel.extraWorldCodes.isEmpty {
                            Divider().padding(.leading, 64)
                        }
                        rateDetailRow(
                            symbol: item.symbol,
                            title: item.name,
                            subtitle: L10n.subtitleCustom,
                            value: item.rateInVES,
                            decimals: 2,
                            delta: nil,
                            deltaPercent: nil,
                            accent: Color(hex: item.colorHex)
                        ) {
                            jumpToConverter(source: .custom(id: item.id))
                        }
                    }
                }
                .tasaCardSurface(cornerRadius: 22)
            }
        }
    }

    private func copMetricBox(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.06 : 0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Shared Row & Helpers

    private func rateDetailRow(
        symbol: String,
        title: String,
        subtitle: String,
        value: Double,
        decimals: Int,
        delta: Double?,
        deltaPercent: Double?,
        accent: Color,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(symbol)
                    .font(.system(size: symbol.count > 2 ? 12 : 18, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .frame(width: 40, height: 40)
                    .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(NumberFormatHelper.format(value, decimals: decimals, style: viewModel.numberStyle)) Bs")
                        .font(.subheadline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)

                    if let delta {
                        let isUp = delta >= 0
                        Text(NumberFormatHelper.formatDelta(delta: delta, percent: deltaPercent, style: viewModel.numberStyle))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(isUp ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private var loadingPlaceholderCard: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(L10n.converterUpdating)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .tasaCardSurface(cornerRadius: 22)
    }

    private func jumpToConverter(source: RateSourceID) {
        viewModel.selectSource(source)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            viewModel.selectedTab = .converter
        }
    }
}
