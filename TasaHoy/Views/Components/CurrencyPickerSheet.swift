import SwiftUI
import UIKit

/// Clean native sheet opened from the main Currency Pill on Home:
/// Displays Dólar BCV, Euro BCV, USDT, Promedio (BCV+USDT), Peso Colombiano (COP),
/// any added World Currencies, Custom Rates, and a prominent "+ Agregar otra moneda o tasa" button.
struct CurrencyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TasaHoyViewModel
    @ObservedObject private var themeManager = TasaThemeManager.shared

    @State private var editingCustom: CustomCurrencyItem?

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientLiquidBackdrop(activeAccent: themeManager.primaryAccent)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        // MARK: - Primary Currencies
                        sectionHeader(L10n.pickerPrimarySection)
                        VStack(spacing: 10) {
                            ForEach(viewModel.primarySources) { source in
                                rateOptionRow(source: source, removable: false)
                            }
                        }

                        // MARK: - Added Extra World Currencies
                        if !viewModel.extraWorldCodes.isEmpty {
                            sectionHeader(L10n.pickerWorldSection)
                            VStack(spacing: 10) {
                                ForEach(viewModel.extraWorldCodes, id: \.self) { code in
                                    rateOptionRow(source: .world(code: code), removable: true) {
                                        viewModel.toggleWorldCurrency(code: code)
                                    }
                                }
                            }
                        }

                        // MARK: - Custom User Rates
                        if !viewModel.customCurrencies.isEmpty {
                            sectionHeader(L10n.pickerCustomSection)
                            VStack(spacing: 10) {
                                ForEach(viewModel.customCurrencies) { item in
                                    rateOptionRow(
                                        source: .custom(id: item.id),
                                        removable: true,
                                        onEdit: { editingCustom = item },
                                        onRemove: { viewModel.deleteCustomCurrency(item) }
                                    )
                                }
                            }
                        }

                        // MARK: - Add Currency / Custom Rate CTA
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                viewModel.showAddCurrency = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 19, weight: .semibold))
                                Text(L10n.pickerAddCurrency)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .opacity(0.6)
                            }
                            .foregroundStyle(themeManager.primaryAccent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                            .tasaCardSurface(cornerRadius: 18, tint: themeManager.primaryAccent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle(L10n.pickerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.close) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(item: $editingCustom) { item in
                EditCustomCurrencySheet(item: item) { updated in
                    viewModel.updateCustomCurrency(updated)
                }
                .preferredColorScheme(themeManager.appearance.preferredColorScheme)
                .tint(themeManager.primaryAccent)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private func rateOptionRow(
        source: RateSourceID,
        removable: Bool,
        onEdit: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) -> some View {
        let isSelected = viewModel.selectedSource == source
        let accent = themeManager.accent(for: source, customColorHex: viewModel.customColorHex(for: source))
        let rate = viewModel.rateInVES(for: source)
        let delta = viewModel.deltaInfo(for: source)

        return Button {
            viewModel.selectSource(source)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                // Crisp icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Text(badgeText(for: source))
                        .font(.system(size: badgeText(for: source).count > 2 ? 11 : 17, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(viewModel.title(for: source))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(accent)
                        }
                    }

                    Text(viewModel.subtitle(for: source))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    if rate > 0 {
                        if source.isSmallUnitCurrency {
                            let per1000 = NumberFormatHelper.format(rate * 1000.0, decimals: 2, style: viewModel.numberStyle)
                            Text("\(per1000) Bs")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(.primary)
                            Text("1.000 \(viewModel.symbol(for: source))")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        } else {
                            let formatted = NumberFormatHelper.formatRate(rate, precision: viewModel.precision, style: viewModel.numberStyle)
                            Text("\(formatted) Bs")
                                .font(.subheadline.weight(.bold).monospacedDigit())
                                .foregroundStyle(.primary)

                            if let delta {
                                let isUp = delta.delta >= 0
                                Text(NumberFormatHelper.formatDelta(delta: delta.delta, percent: delta.percent, style: viewModel.numberStyle))
                                    .font(.caption2.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(isUp ? Color(hex: "#10B981") : Color(hex: "#EF4444"))
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Text("—")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .tasaCardSurface(cornerRadius: 18, tint: isSelected ? accent : nil)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? accent.opacity(0.65) : .clear, lineWidth: 1.4)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label(L10n.edit, systemImage: "pencil")
                }
            }
            if removable, let onRemove {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label(L10n.delete, systemImage: "trash")
                }
            }
        }
    }

    private func badgeText(for source: RateSourceID) -> String {
        switch source {
        case .bcvUSD: return "$"
        case .bcvEUR: return "€"
        case .usdt: return "₮"
        case .averageBCVUSDT: return "≈"
        case .cop: return "🇨🇴"
        case .world(let code):
            return WorldCurrencyPreset.preset(for: code)?.flag ?? code
        case .custom(let id):
            let sym = viewModel.customCurrencies.first(where: { $0.id == id })?.symbol ?? "★"
            return sym.isEmpty ? "★" : String(sym.prefix(3))
        }
    }
}

private struct EditCustomCurrencySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: CustomCurrencyItem
    @State private var rateText: String
    let onSave: (CustomCurrencyItem) -> Void

    private let colorPalette = ["#10B981", "#3B82F6", "#06B6D4", "#F59E0B", "#EC4899", "#8B5CF6", "#F97316", "#E11D48"]

    init(item: CustomCurrencyItem, onSave: @escaping (CustomCurrencyItem) -> Void) {
        self._item = State(initialValue: item)
        self._rateText = State(initialValue: String(format: "%.2f", item.rateInVES))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.addCurrencyNamePlaceholder, text: $item.name)
                    TextField("$", text: $item.symbol)
                    TextField("950.00", text: $rateText)
                        .keyboardType(.decimalPad)
                }

                Section(L10n.addCurrencyColorLabel) {
                    HStack(spacing: 12) {
                        ForEach(colorPalette, id: \.self) { hex in
                            Button {
                                item.colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.white, lineWidth: item.colorHex == hex ? 2.5 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(L10n.edit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        let normalized = rateText.replacingOccurrences(of: ",", with: ".")
                        if let val = Double(normalized), val > 0, !item.name.trimmingCharacters(in: .whitespaces).isEmpty {
                            item.rateInVES = val
                            onSave(item)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
