import SwiftUI

struct Boleto: Codable, Identifiable, Hashable {
    let id: String
    let competencia: String
    let descricao: String
    let valor: Double
    let vencimento: String
    let status: String
    let linhaDigitavel: String?
    let pdfUrl: String?
    let pagoEm: String?
    let moradorNome: String?
    let bloco: String?
    let apartamento: String?
}

extension Boleto {
    enum Situacao {
        case pendente, vencido, pago

        var titulo: String {
            switch self {
            case .pendente: "Em aberto"
            case .vencido: "Vencido"
            case .pago: "Pago"
            }
        }

        var cor: Color {
            switch self {
            case .pendente: .orange
            case .vencido: .red
            case .pago: .green
            }
        }

        var icone: String {
            switch self {
            case .pendente: "clock.fill"
            case .vencido: "exclamationmark.triangle.fill"
            case .pago: "checkmark.circle.fill"
            }
        }
    }

    var situacao: Situacao {
        switch status {
        case "pago": .pago
        case "vencido": .vencido
        default: .pendente
        }
    }

    var estaPago: Bool { situacao == .pago }

    var valorFormatado: String {
        valor.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
    }

    var vencimentoFormatado: String { Self.dataBR(vencimento) }

    var pagoEmFormatado: String? { pagoEm.map(Self.dataBR) }

    var competenciaFormatada: String {
        let partes = competencia.split(separator: "-")
        guard partes.count == 2, let mes = Int(partes[1]), (1...12).contains(mes) else { return competencia }
        let meses = ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
                     "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
        return "\(meses[mes - 1])/\(partes[0])"
    }

    var codigoSomenteNumeros: String? {
        linhaDigitavel.map { $0.filter(\.isNumber) }
    }

    var unidade: String? {
        switch (bloco, apartamento) {
        case let (b?, a?): "Bloco \(b) • \(a)"
        case let (nil, a?): "Apto \(a)"
        case let (b?, nil): "Bloco \(b)"
        default: nil
        }
    }

    private static func dataBR(_ iso: String) -> String {
        let p = iso.prefix(10).split(separator: "-")
        guard p.count == 3 else { return iso }
        return "\(p[2])/\(p[1])/\(p[0])"
    }
}

struct RespostaBoletos: Decodable {
    struct Resumo: Decodable {
        let emAberto: Int
        let totalEmAberto: Double
    }

    let boletos: [Boleto]
    let resumo: Resumo?
}

struct RespostaBoleto: Decodable {
    let boleto: Boleto
}

struct RespostaDemoBoletos: Decodable {
    let ok: Bool
    let criados: Int
}
