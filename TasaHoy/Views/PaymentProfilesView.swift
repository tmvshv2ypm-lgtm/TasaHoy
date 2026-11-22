import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

/// Payment Profiles screen ("Pagos"):
/// Save and share Pago Móvil, Venezuelan Bank Accounts, Zelle, and Binance Pay with one tap —
/// including an instant "Copiar con monto" shortcut that attaches the currently calculated Bs amount!
struct PaymentProfilesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: TasaHoyViewModel
    @ObservedObject private var themeManager = TasaThemeManager.shared

    @State private var selectedFilter: PaymentProfileType? = nil
    @State private var showEditor: Bool = false
    @State private var editingProfile: PaymentProfile? = nil
    @State private var qrProfile: PaymentProfile? = nil

    private var hPadding: CGFloat {
        horizontalSizeClass == .regular ? 28 : 16
    }

    private var maxReadableWidth: CGFloat {
        horizontalSizeClass == .regular ? 780 : .infinity
    }

    private var filteredProfiles: [PaymentProfile] {
        guard let filter = selectedFilter else { return viewModel.paymentProfiles }
        return viewModel.paymentProfiles.filter { $0.type == filter }
    }

    var body: some View {
        ZStack {
            AmbientLiquidBackdrop(activeAccent: themeManager.primaryAccent)

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text(L10n.paymentsTitle)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.top, 2)

                    // Filter chips (All · Pago Móvil · Banco · Zelle · Binance)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(title: L10n.paymentFilterAll, icon: "square.grid.2x2.fill", isSelected: selectedFilter == nil, tint: themeManager.primaryAccent) {
                                selectedFilter = nil
                            }
                            ForEach(PaymentProfileType.allCases) { type in
                                filterChip(
                                    title: type.localizedTitle,
                                    icon: type.systemImage,
                                    isSelected: selectedFilter == type,
                                    tint: type.tintColor
                                ) {
                                    selectedFilter = type
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if filteredProfiles.isEmpty {
                        emptyStateCard
                    } else {
                        ForEach(filteredProfiles) { profile in
                            profileCard(profile)
                        }
                    }
                }
                .padding(.horizontal, hPadding)
                .padding(.bottom, 30)
                .frame(maxWidth: maxReadableWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        editingProfile = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 38, height: 38)
                            .liquidGlassCircle(tint: themeManager.primaryAccent, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.paymentAddNew)

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
        .sheet(isPresented: $showEditor) {
            PaymentProfileEditorSheet(
                existing: editingProfile,
                defaultType: selectedFilter ?? .pagoMovil
            ) { saved in
                viewModel.savePaymentProfile(saved)
            }
            .preferredColorScheme(themeManager.appearance.preferredColorScheme)
            .tint(themeManager.primaryAccent)
        }
        .sheet(item: $qrProfile) { profile in
            PaymentProfileQRSheet(
                profile: profile,
                amountLine: viewModel.currentBolivaresAmountLine
            ) { items in
                viewModel.presentShareItems(items)
            }
            .preferredColorScheme(themeManager.appearance.preferredColorScheme)
            .tint(themeManager.primaryAccent)
        }
    }

    private func filterChip(title: String, icon: String, isSelected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                Text(title)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                isSelected ? tint : Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyStateCard: some View {
        VStack(spacing: 14) {
            Image(systemName: selectedFilter?.systemImage ?? "wallet.pass.fill")
                .font(.system(size: 38))
                .foregroundStyle(selectedFilter?.tintColor ?? themeManager.primaryAccent)

            Text(L10n.paymentEmptyTitle)
                .font(.headline.weight(.bold))

            Text(L10n.paymentEmptySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button {
                editingProfile = nil
                showEditor = true
            } label: {
                Label(L10n.paymentAddNew, systemImage: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(themeManager.primaryAccent, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .tasaCardSurface(cornerRadius: 24)
    }

    private func profileCard(_ profile: PaymentProfile) -> some View {
        let tint = profile.type.tintColor

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: profile.type.systemImage)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(profile.displayTitle)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(profile.type.localizedTitle)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(tint.opacity(0.14), in: Capsule())
                    }
                    Text(profile.summaryLine)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if profile.type == .pagoMovil && !profile.documentNumber.isEmpty {
                        Text(profile.formattedDocument)
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 4)

                Menu {
                    Button {
                        editingProfile = profile
                        showEditor = true
                    } label: {
                        Label(L10n.edit, systemImage: "pencil")
                    }
                    Button {
                        qrProfile = profile
                    } label: {
                        Label(L10n.paymentShowQR, systemImage: "qrcode")
                    }
                    Button {
                        let text = profile.formattedShareText(amountLine: viewModel.currentBolivaresAmountLine)
                        viewModel.presentShareItems([text])
                    } label: {
                        Label(L10n.share, systemImage: "square.and.arrow.up")
                    }
                    Divider()
                    Button(role: .destructive) {
                        viewModel.deletePaymentProfile(profile)
                    } label: {
                        Label(L10n.delete, systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color.primary.opacity(0.06), in: Circle())
                }
            }

            // 1-Tap Copy Actions
            HStack(spacing: 8) {
                Button {
                    viewModel.copyToClipboard(profile.formattedShareText(), feedback: "\(profile.displayTitle) \(L10n.copied.lowercased())")
                } label: {
                    Label(L10n.paymentCopyData, systemImage: "doc.on.doc")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                if let amountLine = viewModel.currentBolivaresAmountLine, (profile.type == .pagoMovil || profile.type == .bankAccount) {
                    Button {
                        viewModel.copyToClipboard(
                            profile.formattedShareText(amountLine: amountLine),
                            feedback: "\(L10n.copied) (\(amountLine))"
                        )
                    } label: {
                        Label(amountLine, systemImage: "doc.on.doc.fill")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 6)
                            .background(tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    qrProfile = profile
                } label: {
                    Image(systemName: "qrcode")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 38, height: 36)
                        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .tasaCardSurface(cornerRadius: 20, tint: tint)
    }
}

// MARK: - Add / Edit Payment Profile Sheet

private struct PaymentProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var id: UUID
    @State private var type: PaymentProfileType
    @State private var label: String
    @State private var holderName: String
    @State private var bankCode: String
    @State private var phonePrefix: String
    @State private var phoneNumber: String
    @State private var documentPrefix: String
    @State private var documentNumber: String
    @State private var accountNumber: String
    @State private var zelleContact: String
    @State private var binanceID: String

    let isEditing: Bool
    let onSave: (PaymentProfile) -> Void

    init(existing: PaymentProfile?, defaultType: PaymentProfileType, onSave: @escaping (PaymentProfile) -> Void) {
        self.isEditing = existing != nil
        self._id = State(initialValue: existing?.id ?? UUID())
        self._type = State(initialValue: existing?.type ?? defaultType)
        self._label = State(initialValue: existing?.label ?? "")
        self._holderName = State(initialValue: existing?.holderName ?? "")
        self._bankCode = State(initialValue: existing?.bankCode ?? "0102")
        self._phonePrefix = State(initialValue: existing?.phonePrefix ?? "0412")
        self._phoneNumber = State(initialValue: existing?.phoneNumber ?? "")
        self._documentPrefix = State(initialValue: existing?.documentPrefix ?? "V")
        self._documentNumber = State(initialValue: existing?.documentNumber ?? "")
        self._accountNumber = State(initialValue: existing?.accountNumber ?? "")
        self._zelleContact = State(initialValue: existing?.zelleContact ?? "")
        self._binanceID = State(initialValue: existing?.binanceID ?? "")
        self.onSave = onSave
    }

    private var isValid: Bool {
        switch type {
        case .pagoMovil:
            return !phoneNumber.filter(\.isNumber).isEmpty && !documentNumber.filter(\.isNumber).isEmpty
        case .bankAccount:
            return accountNumber.filter(\.isNumber).count >= 10
        case .zelle:
            return !zelleContact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .binancePay:
            return !binanceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isEditing {
                    Section {
                        Picker("", selection: $type) {
                            ForEach(PaymentProfileType.allCases) { t in
                                Text(t.localizedTitle).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section {
                    TextField(L10n.paymentAliasLabel, text: $label)
                    TextField(L10n.paymentHolderLabel, text: $holderName)
                        .textContentType(.name)
                }

                switch type {
                case .pagoMovil:
                    Section(L10n.paymentPagoMovil) {
                        Picker(L10n.paymentBankLabel, selection: $bankCode) {
                            ForEach(VenezuelanBank.all) { bank in
                                Text(bank.displayLabel).tag(bank.code)
                            }
                        }

                        HStack(spacing: 10) {
                            Picker("", selection: $phonePrefix) {
                                ForEach(VenezuelanPhonePrefix.allCases) { p in
                                    Text(p.rawValue).tag(p.rawValue)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 92)

                            TextField("1234567", text: $phoneNumber)
                                .keyboardType(.numberPad)
                        }

                        HStack(spacing: 10) {
                            Picker("", selection: $documentPrefix) {
                                ForEach(VenezuelanDocumentPrefix.allCases) { p in
                                    Text(p.rawValue).tag(p.rawValue)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 68)

                            TextField("15123123", text: $documentNumber)
                                .keyboardType(.numberPad)
                        }
                    }

                case .bankAccount:
                    Section(L10n.paymentBankAccount) {
                        Picker(L10n.paymentBankLabel, selection: $bankCode) {
                            ForEach(VenezuelanBank.all) { bank in
                                Text(bank.displayLabel).tag(bank.code)
                            }
                        }

                        TextField(L10n.paymentAccountLabel, text: $accountNumber)
                            .keyboardType(.numberPad)

                        HStack(spacing: 10) {
                            Picker("", selection: $documentPrefix) {
                                ForEach(VenezuelanDocumentPrefix.allCases) { p in
                                    Text(p.rawValue).tag(p.rawValue)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 68)

                            TextField("15123123", text: $documentNumber)
                                .keyboardType(.numberPad)
                        }
                    }

                case .zelle:
                    Section(L10n.paymentZelle) {
                        TextField(L10n.paymentZelleLabel, text: $zelleContact)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                case .binancePay:
                    Section(L10n.paymentBinancePay) {
                        TextField(L10n.paymentBinanceLabel, text: $binanceID)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }
            }
            .navigationTitle(isEditing ? L10n.paymentEditProfile : L10n.paymentAddNew)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        let profile = PaymentProfile(
                            id: id,
                            type: type,
                            label: label,
                            holderName: holderName,
                            bankCode: bankCode,
                            phonePrefix: phonePrefix,
                            phoneNumber: phoneNumber.filter(\.isNumber),
                            documentPrefix: documentPrefix,
                            documentNumber: documentNumber.filter(\.isNumber),
                            accountNumber: accountNumber.filter(\.isNumber),
                            zelleContact: zelleContact,
                            binanceID: binanceID
                        )
                        onSave(profile)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Crisp QR Code Preview Sheet

private struct PaymentProfileQRSheet: View {
    @Environment(\.dismiss) private var dismiss
    let profile: PaymentProfile
    let amountLine: String?
    let onShare: ([Any]) -> Void

    @State private var includeAmount: Bool = false

    private var payloadText: String {
        profile.formattedShareText(amountLine: includeAmount ? amountLine : nil)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text(profile.displayTitle)
                        .font(.title3.weight(.bold))
                    Text(profile.type.localizedTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(profile.type.tintColor)
                }

                if let qrImage = generateQRCode(from: payloadText) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 210, height: 210)
                        .padding(16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                }

                if let amountLine {
                    Toggle("\(L10n.paymentCopyWithAmount) (\(amountLine))", isOn: $includeAmount)
                        .font(.subheadline)
                        .padding(.horizontal, 24)
                }

                Text(payloadText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onShare([payloadText])
                    }
                } label: {
                    Label(L10n.share, systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(profile.type.tintColor, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 20)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.close) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
