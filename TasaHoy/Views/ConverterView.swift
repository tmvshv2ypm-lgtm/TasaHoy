import SwiftUI
import UIKit

/// Main Home Screen of TasaHoy:
/// Voice Notes-grade Liquid Glass layout with bold left-aligned "TasaHoy" title,
/// floating circular Liquid Glass top controls, Hero Currency Pill, bidirectional converter,
/// BCV Today vs Upcoming value-date switcher, live multi-rate peek strip,
/// and an integrated shopping arithmetic calculator (`+ − × ÷ %`).
struct ConverterView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: TasaHoyViewModel
    @ObservedObject private var themeManager = TasaThemeManager.shared

    private var activeAccent: Color {
        themeManager.accent(
            for: viewModel.selectedSource,
            customColorHex: viewModel.customColorHex(for: viewModel.selectedSource)
        )
    }

    private var hPadding: CGFloat {
        horizontalSizeClass == .regular ? 28 : 16
    }

    private var maxReadableWidth: CGFloat {
        horizontalSizeClass == .regular ? 680 : .infinity
    }

    var body: some View {
        ZStack {
            AmbientLiquidBackdrop(activeAccent: activeAccent)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // MARK: - Title Row (Voice Notes signature bold left-aligned largeTitle)
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(verbatim: "TasaHoy")
                            .font(verticalSizeClass == .compact ? .title2.weight(.bold) : .largeTitle.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Spacer(minLength: 8)

                        // Subtle live status / date badge
                        statusPill
                    }
                    .padding(.top, 2)

                    // MARK: - Upcoming BCV Rate Banner / Switcher (when BCV already published next day)
                    if viewModel.isBCVSourceSelected,
                       let snap = viewModel.snapshot,
                       let upcoming = viewModel.selectedSource == .bcvUSD ? snap.bcvUSDUpcoming : snap.bcvEURUpcoming {
                        upcomingBCVSwitcher(
                            todayKey: (viewModel.selectedSource == .bcvUSD ? snap.bcvUSD : snap.bcvEUR).effectiveDateKey,
                            upcoming: upcoming
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // MARK: - Hero Conversion Card
                    heroConverterCard

                    // MARK: - Live Multi-Rate Comparison Strip (tap any chip to switch!)
                    comparisonStrip

                    // MARK: - Quick Actions Row (Scanner · Calculator Toggle · Share Card)
                    quickActionsBar

                    // MARK: - Integrated Arithmetic Calculator Keypad
                    if viewModel.showCalculatorKeypad {
                        calculatorKeypad
                            .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    }

                    // Subtle transparent source footer (zero ads!)
                    sourceFootnote
                }
                .padding(.horizontal, hPadding)
                .padding(.bottom, 26)
                .frame(maxWidth: maxReadableWidth)
                .frame(maxWidth: .infinity)
            }
            .refreshable {
                await viewModel.refreshRates(forceHaptic: true)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topFloatingGlassBar
                .padding(.horizontal, hPadding)
                .padding(.top, 4)
                .padding(.bottom, 4)
                .frame(maxWidth: maxReadableWidth)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Top Floating Liquid Glass Header Controls

    private var topFloatingGlassBar: some View {
        HStack(spacing: 10) {
            if viewModel.isRefreshing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text(L10n.converterUpdating)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .liquidGlassCapsule(interactive: false)
                .transition(.opacity)
            } else if let err = viewModel.lastError {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(hex: "#F59E0B"))
                    Text(err)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .liquidGlassCapsule(interactive: false)
                .transition(.opacity)
            }

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
                .accessibilityLabel(L10n.refresh)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.showShareCardSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 38, height: 38)
                        .liquidGlassCircle(interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.converterShareRate)

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
                .accessibilityLabel(L10n.settingsTitle)
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(viewModel.snapshot != nil ? activeAccent : Color.secondary)
                .frame(width: 7, height: 7)
            Text(viewModel.activeDateLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), in: Capsule())
    }

    // MARK: - Upcoming BCV Toggle Strip

    private func upcomingBCVSwitcher(todayKey: String, upcoming: RateEntry) -> some View {
        let upcomingFormatted = NumberFormatHelper.formatRate(
            upcoming.value,
            precision: viewModel.precision,
            style: viewModel.numberStyle
        )

        return HStack(spacing: 8) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    viewModel.useUpcomingBCV = false
                }
            } label: {
                HStack(spacing: 5) {
                    Text(L10n.converterSwitchToToday)
                        .font(.caption.weight(.bold))
                    Text("· \(VenezuelaDateHelper.formattedShortDay(todayKey))")
                        .font(.caption2.weight(.medium))
                        .opacity(0.85)
                }
                .foregroundStyle(!viewModel.useUpcomingBCV ? .white : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    !viewModel.useUpcomingBCV ? activeAccent : Color.clear,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    viewModel.useUpcomingBCV = true
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption2.weight(.bold))
                    Text("\(VenezuelaDateHelper.formattedShortDay(upcoming.effectiveDateKey)) · \(upcomingFormatted)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(viewModel.useUpcomingBCV ? .white : Color(hex: "#D97706"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(
                    viewModel.useUpcomingBCV ? Color(hex: "#D97706") : Color(hex: "#F59E0B").opacity(0.14),
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .tasaCardSurface(cornerRadius: 24)
    }

    // MARK: - Hero Conversion Card

    private var heroConverterCard: some View {
        VStack(spacing: 14) {
            // Top bar: Tappable Liquid Glass Currency Pill + Delta indicator
            HStack(spacing: 10) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.showCurrencyPicker = true
                } label: {
                    HStack(spacing: 8) {
                        Text(viewModel.title(for: viewModel.selectedSource))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(activeAccent)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(activeAccent.opacity(0.85))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .liquidGlassCapsule(tint: activeAccent, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint(L10n.converterTapToSwitch)

                Spacer(minLength: 6)

                if let delta = viewModel.deltaInfo(for: viewModel.selectedSource) {
                    let isUp = delta.delta >= 0
                    let deltaColor = isUp ? Color(hex: "#10B981") : Color(hex: "#EF4444")
                    HStack(spacing: 4) {
                        Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(NumberFormatHelper.formatDelta(delta: delta.delta, percent: delta.percent, style: viewModel.numberStyle))
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .foregroundStyle(deltaColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(deltaColor.opacity(colorScheme == .dark ? 0.16 : 0.12), in: Capsule())
                } else {
                    Text(unitReferenceTag)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Bidirectional Input Rows with floating central Swap button
            ZStack {
                VStack(spacing: 10) {
                    currencyFieldRow(
                        badge: viewModel.symbol(for: viewModel.selectedSource),
                        label: viewModel.title(for: viewModel.selectedSource),
                        valueText: viewModel.formattedForeignDisplay,
                        subline: viewModel.activeSide == .foreign ? viewModel.formattedEvaluatedSubline : nil,
                        isActive: viewModel.activeSide == .foreign,
                        accent: activeAccent,
                        onSelect: { viewModel.switchActiveSide(to: .foreign) },
                        onCopy: { viewModel.copyForeignAmount() }
                    )

                    currencyFieldRow(
                        badge: "Bs",
                        label: L10n.bolivaresName,
                        valueText: viewModel.formattedBolivaresDisplay,
                        subline: viewModel.activeSide == .bolivares ? viewModel.formattedEvaluatedSubline : nil,
                        isActive: viewModel.activeSide == .bolivares,
                        accent: activeAccent,
                        onSelect: { viewModel.switchActiveSide(to: .bolivares) },
                        onCopy: { viewModel.copyBolivaresAmount() }
                    )
                }

                // Centered Swap Direction Button
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                        viewModel.swapActiveSide()
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(activeAccent)
                        .frame(width: 34, height: 34)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(activeAccent.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.08), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.converterSwapAccessibility)
            }

            // Quick amount preset pills (1, 5, 10, 20, 50, 100 — or 5k, 10k, 20k, 50k, 100k for COP)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(quickPresets, id: \.self) { amount in
                        Button {
                            viewModel.applyPresetAmount(amount)
                        } label: {
                            Text(presetLabel(amount))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background(
                                    Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .tasaCardSurface(cornerRadius: 26, tint: activeAccent)
    }

    private var unitReferenceTag: String {
        let rate = viewModel.currentRateInVES
        guard rate > 0 else { return "—" }
        if viewModel.selectedSource.isSmallUnitCurrency {
            let p = NumberFormatHelper.format(rate * 1000.0, decimals: 2, style: viewModel.numberStyle)
            return "1.000 \(viewModel.symbol(for: viewModel.selectedSource)) = \(p) Bs"
        }
        let p = NumberFormatHelper.formatRate(rate, precision: viewModel.precision, style: viewModel.numberStyle)
        return "1 \(viewModel.symbol(for: viewModel.selectedSource)) = \(p) Bs"
    }

    private var quickPresets: [Double] {
        if viewModel.activeSide == .bolivares {
            return [100, 500, 1000, 5000, 10000, 50000]
        }
        if viewModel.selectedSource.isSmallUnitCurrency {
            return [1000, 5000, 10000, 20000, 50000, 100000]
        }
        return [1, 5, 10, 20, 50, 100]
    }

    private func presetLabel(_ amount: Double) -> String {
        let unit = viewModel.activeSide == .bolivares ? "Bs" : viewModel.symbol(for: viewModel.selectedSource)
        if amount >= 1000 {
            let k = Int(amount / 1000)
            return "\(k)k \(unit)"
        }
        return "\(Int(amount)) \(unit)"
    }

    private func currencyFieldRow(
        badge: String,
        label: String,
        valueText: String,
        subline: String?,
        isActive: Bool,
        accent: Color,
        onSelect: @escaping () -> Void,
        onCopy: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Text(badge)
                        .font(.system(size: badge.count > 2 ? 12 : 17, weight: .bold, design: .rounded))
                        .foregroundStyle(isActive ? .white : accent)
                        .frame(minWidth: 42, minHeight: 38)
                        .padding(.horizontal, badge.count > 2 ? 6 : 0)
                        .background(
                            isActive ? accent : accent.opacity(colorScheme == .dark ? 0.18 : 0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(valueText)
                            .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.48)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        if let subline {
                            Text(subline)
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(accent)
                                .lineLimit(1)
                        } else {
                            Text(label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(
                        Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.copy)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isActive
                        ? accent.opacity(colorScheme == .dark ? 0.12 : 0.07)
                        : Color.primary.opacity(colorScheme == .dark ? 0.045 : 0.03)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isActive ? accent.opacity(0.60) : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05),
                    lineWidth: isActive ? 1.4 : 0.8
                )
        )
    }

    // MARK: - Live Multi-Rate Comparison Strip

    private var comparisonStrip: some View {
        let others = viewModel.primarySources.filter { $0 != viewModel.selectedSource }

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(others) { source in
                    let rate = viewModel.rateInVES(for: source)
                    let tint = themeManager.accent(for: source)

                    Button {
                        viewModel.selectSource(source)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(tint)
                                .frame(width: 7, height: 7)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(viewModel.title(for: source))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)

                                if rate > 0 {
                                    let displayVal: String = {
                                        if source.isSmallUnitCurrency {
                                            return "\(NumberFormatHelper.format(rate * 1000.0, decimals: 2, style: viewModel.numberStyle)) Bs/1k"
                                        }
                                        return "\(NumberFormatHelper.format(rate, decimals: 2, style: viewModel.numberStyle)) Bs"
                                    }()
                                    Text(displayVal)
                                        .font(.caption.weight(.bold).monospacedDigit())
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                } else {
                                    Text("—")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .tasaCardSurface(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                }

                // Quick "+ Agregar" pill at end of strip
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    viewModel.showAddCurrency = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                        Text(L10n.add)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(themeManager.primaryAccent)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 12)
                    .tasaCardSurface(cornerRadius: 16, tint: themeManager.primaryAccent)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Quick Actions Bar (Escáner · Calculadora)

    private var quickActionsBar: some View {
        HStack(spacing: 10) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                viewModel.showScanner = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(activeAccent)
                    Text(L10n.converterScanner)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .tasaCardSurface(cornerRadius: 16)
            }
            .buttonStyle(.plain)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
                    viewModel.showCalculatorKeypad.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus.forwardslash.minus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(viewModel.showCalculatorKeypad ? .white : activeAccent)
                    Text(L10n.converterCalculator)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewModel.showCalculatorKeypad ? .white : .primary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    viewModel.showCalculatorKeypad
                        ? AnyShapeStyle(activeAccent)
                        : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground).opacity(colorScheme == .dark ? 0.90 : 0.96)),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            viewModel.showCalculatorKeypad ? activeAccent.opacity(0.3) : Color.primary.opacity(0.08),
                            lineWidth: 0.8
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Integrated Arithmetic Calculator Keypad (+ − × ÷ %)

    private var calculatorKeypad: some View {
        let dec = viewModel.numberStyle.decimalSeparator
        let rows: [[KeyItem]] = [
            [
                KeyItem(label: "C", value: "C", role: .utility),
                KeyItem(label: "⌫", value: "⌫", systemImage: "delete.left.fill", role: .utility),
                KeyItem(label: "%", value: "%", role: .utility),
                KeyItem(label: "÷", value: "/", role: .op)
            ],
            [
                KeyItem(label: "7", value: "7", role: .digit),
                KeyItem(label: "8", value: "8", role: .digit),
                KeyItem(label: "9", value: "9", role: .digit),
                KeyItem(label: "×", value: "*", role: .op)
            ],
            [
                KeyItem(label: "4", value: "4", role: .digit),
                KeyItem(label: "5", value: "5", role: .digit),
                KeyItem(label: "6", value: "6", role: .digit),
                KeyItem(label: "−", value: "-", role: .op)
            ],
            [
                KeyItem(label: "1", value: "1", role: .digit),
                KeyItem(label: "2", value: "2", role: .digit),
                KeyItem(label: "3", value: "3", role: .digit),
                KeyItem(label: "+", value: "+", role: .op)
            ],
            [
                KeyItem(label: "00", value: "00", role: .digit),
                KeyItem(label: "0", value: "0", role: .digit),
                KeyItem(label: dec, value: ".", role: .digit),
                KeyItem(label: "=", value: "=", role: .equals)
            ]
        ]

        return VStack(spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { rIndex in
                HStack(spacing: 8) {
                    ForEach(rows[rIndex]) { key in
                        keypadButton(key)
                    }
                }
            }
        }
        .padding(10)
        .tasaCardSurface(cornerRadius: 24)
    }

    private struct KeyItem: Identifiable {
        enum Role { case digit, utility, op, equals }
        var id: String { value }
        let label: String
        let value: String
        var systemImage: String? = nil
        let role: Role
    }

    private func keypadButton(_ item: KeyItem) -> some View {
        let bgColor: Color = {
            switch item.role {
            case .digit:
                return colorScheme == .dark
                    ? Color.white.opacity(0.085)
                    : Color.black.opacity(0.045)
            case .utility:
                return colorScheme == .dark
                    ? Color.white.opacity(0.14)
                    : Color.black.opacity(0.09)
            case .op:
                return activeAccent.opacity(colorScheme == .dark ? 0.22 : 0.15)
            case .equals:
                return activeAccent
            }
        }()

        let fgColor: Color = {
            switch item.role {
            case .digit: return .primary
            case .utility: return .primary
            case .op: return activeAccent
            case .equals: return .white
            }
        }()

        return Button {
            viewModel.keypadTap(item.value)
        } label: {
            Group {
                if let systemImage = item.systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                } else {
                    Text(item.label)
                        .font(.system(size: item.role == .op || item.role == .equals ? 22 : 20, weight: .semibold, design: .rounded))
                }
            }
            .foregroundStyle(fgColor)
            .frame(maxWidth: .infinity)
            .frame(height: verticalSizeClass == .compact ? 42 : 48)
            .background(bgColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var sourceFootnote: some View {
        Text(viewModel.subtitle(for: viewModel.selectedSource))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 2)
    }
}
