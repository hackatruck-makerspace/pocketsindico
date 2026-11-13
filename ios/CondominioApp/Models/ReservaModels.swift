import Foundation

enum EspacoReserva: String, CaseIterable, Identifiable {
    case churrasqueira
    case salaoFestas = "salao_festas"
    case quadraBasquete = "quadra_basquete"
    case campoFutebol = "campo_futebol"
    case academia

    var id: String { rawValue }
    var nome: String {
        switch self {
        case .churrasqueira: "Churrasqueira"
        case .salaoFestas: "Salão de festas"
        case .quadraBasquete: "Quadra de basquete"
        case .campoFutebol: "Campo de futebol"
        case .academia: "Academia"
        }
    }
    var icone: String {
        switch self {
        case .churrasqueira: "flame.fill"
        case .salaoFestas: "party.popper.fill"
        case .quadraBasquete: "basketball.fill"
        case .campoFutebol: "soccerball"
        case .academia: "dumbbell.fill"
        }
    }

    static let horarios = (8...20).map { String(format: "%02d:00", $0) }
}

struct Reserva: Codable, Identifiable, Hashable {
    let id: String
    var espacoId: String
    var espacoNome: String?
    var data: String
    var horario: String
    var status: String?
    var minha: Bool?
    var moradorId: String?
    var moradorNome: String?
    var bloco: String?
    var apartamento: String?
    var criadoEm: String?

    var ehMinha: Bool { minha ?? false }
    var espaco: EspacoReserva? { EspacoReserva(rawValue: espacoId) }
    var nomeEspaco: String { espacoNome ?? espaco?.nome ?? espacoId }
    var dataDate: Date? { ReservaData.date(data) }
    var unidade: String? {
        guard let b = bloco, let a = apartamento else { return nil }
        return "Bloco \(b) · Apto \(a)"
    }
}

struct RespostaReservas: Decodable {
    let reservas: [Reserva]
    let todas: Bool?
}
struct RespostaReserva: Decodable { let reserva: Reserva }

enum ReservaData {
    private static let formatador: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    static func texto(_ d: Date) -> String { formatador.string(from: d) }
    static func date(_ s: String) -> Date? { formatador.date(from: s) }
}
