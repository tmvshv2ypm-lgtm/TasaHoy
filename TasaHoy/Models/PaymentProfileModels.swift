import Foundation
import SwiftUI

// MARK: - Payment Profile Types

enum PaymentProfileType: String, CaseIterable, Identifiable, Codable, Sendable {
    case pagoMovil
    case bankAccount
    case zelle
    case binancePay

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .pagoMovil: return L10n.paymentPagoMovil
        case .bankAccount: return L10n.paymentBankAccount
        case .zelle: return L10n.paymentZelle
        case .binancePay: return L10n.paymentBinancePay
        }
    }

    var systemImage: String {
        switch self {
        case .pagoMovil: return "iphone.gen3"
        case .bankAccount: return "building.columns.fill"
        case .zelle: return "bolt.circle.fill"
        case .binancePay: return "bitcoinsign.circle.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .pagoMovil: return Color(hex: "#10B981")
        case .bankAccount: return Color(hex: "#3B82F6")
        case .zelle: return Color(hex: "#8B5CF6")
        case .binancePay: return Color(hex: "#F59E0B")
        }
    }
}

// MARK: - Official Venezuelan Bank Directory (SUDEBAN)

struct VenezuelanBank: Identifiable, Hashable, Codable, Sendable {
    var id: String { code }
    let code: String
    let name: String

    var displayLabel: String { "\(code) · \(name)" }

    static let all: [VenezuelanBank] = [
        VenezuelanBank(code: "0102", name: "Banco de Venezuela"),
        VenezuelanBank(code: "0134", name: "Banesco"),
        VenezuelanBank(code: "0105", name: "Mercantil"),
        VenezuelanBank(code: "0108", name: "BBVA Provincial"),
        VenezuelanBank(code: "0172", name: "Bancamiga"),
        VenezuelanBank(code: "0191", name: "BNC"),
        VenezuelanBank(code: "0114", name: "Bancaribe"),
        VenezuelanBank(code: "0115", name: "Banco Exterior"),
        VenezuelanBank(code: "0163", name: "Banco del Tesoro"),
        VenezuelanBank(code: "0174", name: "Banplus"),
        VenezuelanBank(code: "0151", name: "BFC Banco Fondo Común"),
        VenezuelanBank(code: "0175", name: "BDT (Bicentenario)"),
        VenezuelanBank(code: "0104", name: "Venezolano de Crédito"),
        VenezuelanBank(code: "0138", name: "Banco Plaza"),
        VenezuelanBank(code: "0128", name: "Banco Caroní"),
        VenezuelanBank(code: "0137", name: "Sofitasa"),
        VenezuelanBank(code: "0156", name: "100% Banco"),
        VenezuelanBank(code: "0157", name: "DelSur"),
        VenezuelanBank(code: "0168", name: "Bancrecer"),
        VenezuelanBank(code: "0169", name: "R4 (Mi Banco)"),
        VenezuelanBank(code: "0171", name: "Banco Activo"),
        VenezuelanBank(code: "0177", name: "BANFANB"),
        VenezuelanBank(code: "0166", name: "Banco Agrícola"),
        VenezuelanBank(code: "0146", name: "Bangente"),
        VenezuelanBank(code: "0178", name: "N58 Banco Digital")
    ]

    static func bank(forCode code: String) -> VenezuelanBank? {
        all.first { $0.code == code }
    }
}

enum VenezuelanPhonePrefix: String, CaseIterable, Identifiable, Codable, Sendable {
    case p0412 = "0412"
    case p0414 = "0414"
    case p0424 = "0424"
    case p0416 = "0416"
    case p0426 = "0426"

    var id: String { rawValue }
}

enum VenezuelanDocumentPrefix: String, CaseIterable, Identifiable, Codable, Sendable {
    case v = "V"
    case e = "E"
    case j = "J"
    case p = "P"
    case g = "G"

    var id: String { rawValue }
}

// MARK: - Payment Profile Model

struct PaymentProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var type: PaymentProfileType
    var label: String // e.g. "Mi Pago Móvil", "Tienda", "Personal"
    var holderName: String
    var bankCode: String // "0102"
    var phonePrefix: String // "0412"
    var phoneNumber: String // "1234567"
    var documentPrefix: String // "V"
    var documentNumber: String // "15123123"
    var accountNumber: String // 20 digits for bankAccount
    var zelleContact: String // email or phone for Zelle
    var binanceID: String // Pay ID / email for Binance Pay
    var createdAt: Date

    init(
        id: UUID = UUID(),
        type: PaymentProfileType,
        label: String = "",
        holderName: String = "",
        bankCode: String = "0102",
        phonePrefix: String = "0412",
        phoneNumber: String = "",
        documentPrefix: String = "V",
        documentNumber: String = "",
        accountNumber: String = "",
        zelleContact: String = "",
        binanceID: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.label = label
        self.holderName = holderName
        self.bankCode = bankCode
        self.phonePrefix = phonePrefix
        self.phoneNumber = phoneNumber
        self.documentPrefix = documentPrefix
        self.documentNumber = documentNumber
        self.accountNumber = accountNumber
        self.zelleContact = zelleContact
        self.binanceID = binanceID
        self.createdAt = createdAt
    }

    var bankName: String {
        VenezuelanBank.bank(forCode: bankCode)?.name ?? bankCode
    }

    var fullPhone: String {
        let digits = phoneNumber.filter(\.isNumber)
        return "\(phonePrefix)-\(digits)"
    }

    var compactPhoneDigits: String {
        let digits = phoneNumber.filter(\.isNumber)
        return "\(phonePrefix)\(digits)"
    }

    var formattedDocument: String {
        let digits = documentNumber.filter(\.isNumber)
        return "\(documentPrefix)-\(digits)"
    }

    var formattedAccountNumber: String {
        let digits = accountNumber.filter(\.isNumber)
        guard digits.count == 20 else { return digits }
        let p1 = digits.prefix(4)
        let p2 = digits.dropFirst(4).prefix(4)
        let p3 = digits.dropFirst(8).prefix(2)
        let p4 = digits.dropFirst(10)
        return "\(p1)-\(p2)-\(p3)-\(p4)"
    }

    var displayTitle: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let holder = holderName.trimmingCharacters(in: .whitespacesAndNewlines)
        return holder.isEmpty ? type.localizedTitle : holder
    }

    var summaryLine: String {
        switch type {
        case .pagoMovil:
            return "\(bankCode) \(bankName) · \(fullPhone)"
        case .bankAccount:
            return "\(bankName) · \(formattedAccountNumber)"
        case .zelle:
            return zelleContact
        case .binancePay:
            return "ID: \(binanceID)"
        }
    }

    /// Generates clean copyable text ready to paste in WhatsApp, optionally appending a calculated amount!
    func formattedShareText(amountLine: String? = nil) -> String {
        var lines: [String] = []
        switch type {
        case .pagoMovil:
            lines.append("Pago Móvil")
            if !holderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("Titular: \(holderName.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            lines.append("Banco: \(bankCode) - \(bankName)")
            lines.append("Teléfono: \(compactPhoneDigits)")
            lines.append("Cédula/RIF: \(formattedDocument)")
        case .bankAccount:
            lines.append("Transferencia Bancaria")
            if !holderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("Titular: \(holderName.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            lines.append("Banco: \(bankCode) - \(bankName)")
            lines.append("Cuenta: \(accountNumber.filter(\.isNumber))")
            if !documentNumber.filter(\.isNumber).isEmpty {
                lines.append("Cédula/RIF: \(formattedDocument)")
            }
        case .zelle:
            lines.append("Zelle")
            if !holderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("Titular: \(holderName.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            lines.append("Cuenta: \(zelleContact.trimmingCharacters(in: .whitespacesAndNewlines))")
        case .binancePay:
            lines.append("Binance Pay")
            if !holderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("Titular: \(holderName.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            lines.append("Binance ID: \(binanceID.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        if let amountLine, !amountLine.isEmpty {
            lines.append("Monto: \(amountLine)")
        }
        return lines.joined(separator: "\n")
    }
}
