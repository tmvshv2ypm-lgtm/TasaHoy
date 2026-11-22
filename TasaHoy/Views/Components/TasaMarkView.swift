import SwiftUI

/// Crisp vector SwiftUI emblem mirroring TasaHoy's Liquid Glass AppIcon for Settings & Share Cards.
struct TasaMarkView: View {
    var size: CGFloat = 44
    var accent: Color = Color(hex: "#10B981")
    var secondary: Color = Color(hex: "#06B6D4")

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#082722"), Color(hex: "#041114")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [accent.opacity(0.65), secondary.opacity(0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(0.8, size * 0.025)
                        )
                )

            // Subtle dual exchange arcs
            Circle()
                .trim(from: 0.56, to: 0.94)
                .stroke(accent, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
                .frame(width: size * 0.68, height: size * 0.68)

            Circle()
                .trim(from: 0.06, to: 0.44)
                .stroke(secondary, style: StrokeStyle(lineWidth: size * 0.085, lineCap: .round))
                .frame(width: size * 0.68, height: size * 0.68)

            // Center glass lens & currency glyph
            Circle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.85), secondary.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.46, height: size * 0.46)

            Image(systemName: "dollarsign")
                .font(.system(size: size * 0.27, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
