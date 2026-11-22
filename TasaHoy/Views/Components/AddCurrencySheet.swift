import SwiftUI

struct AddCurrencySheet: View {
    enum Mode: Int, CaseIterable, Identifiable {
        case world = 0
        case custom = 1
        var id: Int { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TasaHoyViewModel
    @ObservedObject private var themeManager = TasaThemeManager.shared

    @State private var mode: Mode = .world
    @State private var searchText: String = ""

    // Custom currency fields
    @State private var customName: String = ""
    @State private var customSymbol: String = "$"
    @State private var customRateText: String = ""
    @State private var customColorHex: String = "#EC4899"

    private let colorPalette = ["#10B981", "#3B82F6", "#06B6D4", "#F59E0B", "#EC4899", "#8B5CF6", "#F97316", "#E11D48"]

    private var filteredPresets: [WorldCurrencyPreset] {
        let catalog = WorldCurrencyPreset.catalog.filter { $0.code != "COP" }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return catalog }
        return catalog.filter {
            $0.code.lowercased().contains(q)
            || $0.localizedName.lowercased().contains(q)
            || $0.defaultNameES.lowercased().contains(q)
            || $0.defaultNameEN.lowercased().contains(q)
        }
    }

    private var parsedCustomRate: Double? {
        let normalized = customRateText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let val = Double(normalized), val > 0 else { return nil }
        return val
    }

    private var canSaveCustom: Bool {
        !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parsedCustomRate != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $mode) {
                    Text(L10n.addCurrencyModeWorld).tag(Mode.world)
                    Text(L10n.addCurrencyModeCustom).tag(Mode.custom)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)

                if mode == .world {
                    worldCatalogList
                } else {
                    customCurrencyForm
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(L10n.addCurrencyTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
                if mode == .custom {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.save) {
                            guard let rate = parsedCustomRate else { return }
                            viewModel.addCustomCurrency(
                                name: customName,
                                symbol: customSymbol,
                                rateInVES: rate,
                                colorHex: customColorHex
                            )
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(!canSaveCustom)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var worldCatalogList: some View {
        List {
            ForEach(filteredPresets) { preset in
                let isAdded = viewModel.extraWorldCodes.contains(preset.code)
                let rate = viewModel.snapshot?.vesPerUnit(
                    worldCode: preset.code,
                    anchor: viewModel.fxAnchor,
                    useUpcomingBCV: viewModel.useUpcomingBCV
                )

                Button {
                    viewModel.toggleWorldCurrency(code: preset.code)
                    if viewModel.extraWorldCodes.contains(preset.code) {
                        viewModel.selectSource(.world(code: preset.code))
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text(preset.flag)
                            .font(.title2)
                            .frame(width: 34)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.localizedName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("\(preset.code) · \(preset.symbol)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let rate, rate > 0 {
                            let formatted = NumberFormatHelper.formatRate(rate, precision: viewModel.precision, style: viewModel.numberStyle)
                            Text("\(formatted) Bs")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                            .font(.title3)
                            .foregroundStyle(isAdded ? themeManager.primaryAccent : .secondary)
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: L10n.addCurrencySearchPlaceholder)
    }

    private var customCurrencyForm: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.addCurrencyNameLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField(L10n.addCurrencyNamePlaceholder, text: $customName)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.addCurrencySymbolLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("$", text: $customSymbol)
                        .autocorrectionDisabled()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.addCurrencyRateLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("Ej: 980,00", text: $customRateText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold).monospacedDigit())
                }
            }

            Section(L10n.addCurrencyColorLabel) {
                HStack(spacing: 12) {
                    ForEach(colorPalette, id: \.self) { hex in
                        Button {
                            customColorHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: customColorHex == hex ? 2.5 : 0)
                                )
                                .shadow(color: Color(hex: hex).opacity(0.35), radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
}
