import SwiftUI
import UIKit

/// Interactive Liquid Glass Theme Picker with live TasaHoy card preview (matching Voice Notes & PosterCut).
struct ThemePickerView: View {
    @ObservedObject private var themeManager = TasaThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Live Miniature Preview of TasaHoy Hero Card
                miniPreviewCard
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // Theme Options List
                VStack(spacing: 10) {
                    ForEach(TasaVisualTheme.allCases) { theme in
                        themeRow(theme)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(AmbientLiquidBackdrop(activeAccent: themeManager.primaryAccent))
        .navigationTitle(L10n.settingsThemeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var miniPreviewCard: some View {
        let accent = themeManager.primaryAccent
        let swatches = themeManager.currentTheme.swatchColors

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(verbatim: "TasaHoy")
                    .font(.title3.weight(.bold))
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(accent.opacity(0.22)).frame(width: 24, height: 24)
                        .overlay(Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .bold)).foregroundStyle(accent))
                    Circle().fill(Color.primary.opacity(0.08)).frame(width: 24, height: 24)
                        .overlay(Image(systemName: "gearshape.fill").font(.system(size: 10)).foregroundStyle(.secondary))
                }
            }

            HStack {
                Text(L10n.rateBCVUSD)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(accent, in: Capsule())

                Spacer()

                Text("↑ +0,99 Bs")
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(Color(hex: "#10B981"))
            }

            HStack(alignment: .firstTextBaseline) {
                Text("$ 1,00")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("918,77 Bs")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 8) {
                ForEach(Array(swatches.prefix(4).enumerated()), id: \.offset) { idx, col in
                    let labels = ["BCV", "EUR", "USDT", "PROM"]
                    Text(labels[idx])
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(col)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(col.opacity(colorScheme == .dark ? 0.18 : 0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(16)
        .tasaCardSurface(cornerRadius: 24, tint: accent)
        .animation(.spring(response: 0.30, dampingFraction: 0.85), value: themeManager.currentTheme)
    }

    private func themeRow(_ theme: TasaVisualTheme) -> some View {
        let isSelected = themeManager.currentTheme == theme

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                themeManager.currentTheme = theme
            }
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    ForEach(Array(theme.swatchColors.prefix(4).enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 11, height: 11)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.06), in: Capsule())

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.localizedTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(theme.localizedSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? theme.primaryAccent : Color.secondary.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .tasaCardSurface(cornerRadius: 18, tint: isSelected ? theme.primaryAccent : nil)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? theme.primaryAccent.opacity(0.6) : .clear, lineWidth: 1.3)
            )
        }
        .buttonStyle(.plain)
    }
}
