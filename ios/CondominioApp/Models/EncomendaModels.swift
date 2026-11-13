import Foundation

enum StatusEncomenda: String, CaseIterable, Identifiable {
    case aguardandoRetirada = "aguardando_retirada"
    case retirada = "retirada"
    var id: String { rawValue }
    var titulo: String { self == .retirada ? "Retirado" : "Aguardando retirada" }
    var icone: String { self == .retirada ? "checkmark.circle.fill" : "clock.fill" }
}

struct Encomenda: Codable, Identifiable, Hashable {
    let id: String
    var descricao: String
    var transportadora: String?
    var codigoRastreio: String?
    var observacao: String?
    var foto: String?
    var status: String
    var dataRecebimento: String?
    var dataEntrega: String?
    var moradorId: String?
    var moradorNome: String?
    var bloco: String?
    var apartamento: String?
    var registradoPorNome: String?
    var statusAlteradoEm: String?
    var semDestinatario: Bool?
    var destinatarioInformado: String?

    var retirada: Bool { status == "retirada" || status == "entregue" }
    var statusEnum: StatusEncomenda { retirada ? .retirada : .aguardandoRetirada }
    var statusTitulo: String { statusEnum.titulo }
    var remetente: String { transportadora ?? "Remetente não informado" }

    var unidade: String? {
        guard let b = bloco, let a = apartamento else { return nil }
        return "Bloco \(b) · Apto \(a)"
    }

    var destinatarioDesconhecido: Bool { semDestinatario ?? (moradorId == nil) }

    var destinatarioTexto: String {
        if destinatarioDesconhecido { return "Destinatário não reconhecido" }
        return [moradorNome, unidade].compactMap { $0 }.joined(separator: " · ")
    }
}

struct RespostaEncomendas: Decodable { let encomendas: [Encomenda] }
struct RespostaEncomenda: Decodable { let encomenda: Encomenda }

struct MoradorResumo: Codable, Identifiable, Hashable {
    let id: String
    let nome: String
    let bloco: String?
    let apartamento: String?
    var rotulo: String { "\(nome) — Bloco \(bloco ?? "-") · Apto \(apartamento ?? "-")" }
}

struct RespostaMoradores: Decodable { let moradores: [MoradorResumo] }

struct EncomendaForm {
    var semDestinatario = false
    var destinatarioInformado: String = ""
    var moradorId: String = ""
    var descricao: String = ""
    var transportadora: String = ""
    var codigoRastreio: String = ""
    var observacao: String = ""
    var status: StatusEncomenda = .aguardandoRetirada
    var foto: String?

    init() {}
    init(_ e: Encomenda) {
        moradorId = e.moradorId ?? ""
        semDestinatario = e.destinatarioDesconhecido
        destinatarioInformado = e.destinatarioInformado ?? ""
        descricao = e.descricao
        transportadora = e.transportadora ?? ""
        codigoRastreio = e.codigoRastreio ?? ""
        observacao = e.observacao ?? ""
        status = e.statusEnum
        foto = e.foto
    }

    var corpo: [String: Any] {
        func t(_ s: String) -> Any {
            let v = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if v.isEmpty { return NSNull() }
            return v
        }
        var morador: Any = moradorId
        if semDestinatario { morador = NSNull() }
        return ["morador_id": morador, "sem_destinatario": semDestinatario,
                "destinatario_informado": t(semDestinatario ? destinatarioInformado : ""),
                "descricao": descricao.trimmingCharacters(in: .whitespacesAndNewlines),
                "transportadora": t(transportadora), "codigo_rastreio": t(codigoRastreio), "observacao": t(observacao),
                "status": status.rawValue, "foto": foto.map { $0 as Any } ?? NSNull()]
    }
}
