import SwiftUI
import UIKit

/// Crisp, zero-ads Liquid Glass Rate Card rendered at 3× resolution for WhatsApp / Instagram sharing.
struct ShareRateCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var viewModel: TasaHoyViewModel
    @ObservedObject private var themeManager = TasaThemeManager.shared

    @State private var cardStyleDark: Bool = true
    @State private var shareActivityItems: [Any] = []
    @State private var showActivity: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientLiquidBackdrop(activeAccent: activeAccent)

                ScrollView {
                    VStack(spacing: 20) {
                        Picker("", selection: $cardStyleDark) {
                            Text(L10n.appearanceDark).tag(true)
                            Text(L10n.appearanceLight).tag(false)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)

                        rateCardArtwork
                            .padding(.horizontal, 16)

                        HStack(spacing: 12) {
                            Button {
                                shareAsImage()
                            } label: {
                                Label(L10n.share, systemImage: "square.and.arrow.up")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(activeAccent, in: Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                viewModel.copyToClipboard(plainTextSummary(), feedback: L10n.copied)
                            } label: {
                                Label(L10n.copy, systemImage: "doc.on.doc")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                    .liquidGlassCapsule(interactive: true)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle(L10n.shareCardPreviewTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.close) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                cardStyleDark = (colorScheme == .dark)
            }
            .sheet(isPresented: $showActivity) {
                ActivityShareSheet(items: shareActivityItems)
                    .ignoresSafeArea()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var activeAccent: Color {
        themeManager.accent(
            for: viewModel.selectedSource,
            customColorHex: viewModel.customColorHex(for: viewModel.selectedSource)
        )
    }

    private var rateCardArtwork: some View {
        RateCardRenderView(
            title: viewModel.title(for: viewModel.selectedSource),
            subtitle: viewModel.subtitle(for: viewModel.selectedSource),
            rateFormatted: formattedMainRate,
            unitCaption: viewModel.selectedSource.isSmallUnitCurrency ? "1.000 \(viewModel.symbol(for: viewModel.selectedSource))" : "1 \(viewModel.symbol(for: viewModel.selectedSource))",
            deltaText: deltaText,
            deltaPositive: (viewModel.deltaInfo(for: viewModel.selectedSource)?.delta ?? 0) >= 0,
            dateText: viewModel.activeDateLabel,
            secondarySummary: secondaryRows,
            accent: activeAccent,
            isDark: cardStyleDark
        )
    }

    private var formattedMainRate: String {
        let rate = viewModel.currentRateInVES
        guard rate > 0 else { return "—" }
        if viewModel.selectedSource.isSmallUnitCurrency {
            return "\(NumberFormatHelper.format(rate * 1000.0, decimals: 2, style: viewModel.numberStyle)) Bs"
        }
        return "\(NumberFormatHelper.formatRate(rate, precision: viewModel.precision, style: viewModel.numberStyle)) Bs"
    }

    private var deltaText: String? {
        guard let d = viewModel.deltaInfo(for: viewModel.selectedSource) else { return nil }
        return NumberFormatHelper.formatDelta(delta: d.delta, percent: d.percent, style: viewModel.numberStyle)
    }

    private var secondaryRows: [(String, String)] {
        guard let snap = viewModel.snapshot else { return [] }
        let style = viewModel.numberStyle
        let usd = NumberFormatHelper.format(snap.activeBCVUSD(useUpcoming: viewModel.useUpcomingBCV).value, decimals: 2, style: style)
        let eur = NumberFormatHelper.format(snap.activeBCVEUR(useUpcoming: viewModel.useUpcomingBCV).value, decimals: 2, style: style)
        let usdt = NumberFormatHelper.format(snap.usdt.average, decimals: 2, style: style)
        return [
            ("BCV USD", "\(usd) Bs"),
            ("BCV EUR", "\(eur) Bs"),
            ("USDT", "\(usdt) Bs")
        ]
    }

    private func plainTextSummary() -> String {
        let title = viewModel.title(for: viewModel.selectedSource)
        var lines = [
            "TasaHoy · \(title)",
            "1 \(viewModel.symbol(for: viewModel.selectedSource)) = \(formattedMainRate)",
            viewModel.activeDateLabel
        ]
        if let deltaText {
            lines.insert("Variación: \(deltaText)", at: 2)
        }
        return lines.joined(separator: "\n")
    }

    private func shareAsImage() {
        let renderer = ImageRenderer(content: rateCardArtwork.frame(width: 360))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            shareActivityItems = [uiImage]
            showActivity = true
        }
    }
}

struct RateCardRenderView: View {
    let title: String
    let subtitle: String
    let rateFormatted: String
    let unitCaption: String
    let deltaText: String?
    let deltaPositive: Bool
    let dateText: String
    let secondarySummary: [(String, String)]
    let accent: Color
    let isDark: Bool

    var body: some View {
        let bgColors: [Color] = isDark
            ? [Color(hex: "#0A1718"), Color(hex: "#050A0C")]
            : [Color(hex: "#F6FBF9"), Color(hex: "#E8F3F0")]
        let fgPrimary: Color = isDark ? .white : Color(hex: "#0B1717")
        let fgSecondary: Color = isDark ? Color.white.opacity(0.68) : Color(hex: "#0B1717").opacity(0.60)
        let innerFill: Color = isDark ? Color.white.opacity(0.07) : Color.white.opacity(0.82)

        VStack(alignment: .leading, spacing: 18) {
            // Header with TasaHoy mark
            HStack(spacing: 10) {
                TasaMarkView(size: 36, accent: accent, secondary: Color(hex: "#06B6D4"))
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "TasaHoy")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(fgPrimary)
                    Text(dateText)
                        .font(.caption)
                        .foregroundStyle(fgSecondary)
                }
                Spacer()
                Text(unitCaption)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accent.opacity(isDark ? 0.20 : 0.14), in: Capsule())
            }

            // Main Rate Hero Pill
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)

                Text(rateFormatted)
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(fgPrimary)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let deltaText {
                        HStack(spacing: 4) {
                            Image(systemName: deltaPositive ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption2.weight(.bold))
                            Text(deltaText)
                                .font(.caption.weight(.semibold).monospacedDigit())
                        }
                        .foregroundStyle(deltaPositive ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            (deltaPositive ? Color(hex: "#10B981") : Color(hex: "#EF4444")).opacity(0.16),
                            in: Capsule()
                        )
                    }
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(fgSecondary)
                        .lineLimit(1)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(innerFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(accent.opacity(isDark ? 0.28 : 0.22), lineWidth: 1)
            )

            // Secondary Trio Bar (BCV USD · BCV EUR · USDT)
            if !secondarySummary.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(secondarySummary.enumerated()), id: \.offset) { _, row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.0)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(fgSecondary)
                            Text(row.1)
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(fgPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(innerFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
        .padding(22)
        .background(
            ZStack {
                LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(
                    colors: [accent.opacity(isDark ? 0.28 : 0.18), .clear],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 240
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(accent.opacity(isDark ? 0.32 : 0.20), lineWidth: 1.1)
        )
    }
}
