import SwiftUI

enum CategoriaOcorrencia: String, CaseIterable, Identifiable {
    case barulho, vazamento, estacionamento, animais, limpeza, seguranca, manutencao, outro
    var id: String { rawValue }
    var titulo: String {
        switch self {
        case .barulho: "Barulho"
        case .vazamento: "Vazamento / infiltração"
        case .estacionamento: "Estacionamento / garagem"
        case .animais: "Animais"
        case .limpeza: "Limpeza"
        case .seguranca: "Segurança"
        case .manutencao: "Manutenção"
        case .outro: "Outro"
        }
    }
    var icone: String {
        switch self {
        case .barulho: "speaker.wave.3.fill"
        case .vazamento: "drop.fill"
        case .estacionamento: "car.fill"
        case .animais: "pawprint.fill"
        case .limpeza: "sparkles"
        case .seguranca: "lock.shield.fill"
        case .manutencao: "wrench.and.screwdriver.fill"
        case .outro: "ellipsis.bubble.fill"
        }
    }
    var cor: Color {
        switch self {
        case .barulho: .purple
        case .vazamento: .blue
        case .estacionamento: .indigo
        case .animais: .brown
        case .limpeza: .green
        case .seguranca: .red
        case .manutencao: .orange
        case .outro: .gray
        }
    }
}

enum TipoRespostaOcorrencia: String, CaseIterable, Identifiable {
    case resposta, lembrete
    var id: String { rawValue }
    var titulo: String { self == .lembrete ? "Lembrete de convivência" : "Resposta ao morador" }
}

struct RespostaDoSindico: Codable, Hashable {
    var tipo: String
    var texto: String
    var unidadeEnvolvida: String?
    var mensagemLembrete: String?
    var autorNome: String?
    var respondidoEm: String?
    var ehLembrete: Bool { tipo == "lembrete" }
}

struct EventoOcorrencia: Codable, Hashable {
    var status: String
    var descricao: String
    var autorNome: String?
    var em: String?
}

struct Ocorrencia: Codable, Identifiable, Hashable {
    let id: String
    var titulo: String
    var descricao: String
    var categoria: String
    var local: String?
    var foto: String?
    var status: String
    var autorId: String?
    var autorNome: String
    var autorPerfil: String?
    var bloco: String?
    var apartamento: String?
    var criadoEm: String?
    var atualizadoEm: String?
    var recebidaEm: String?
    var respondidaEm: String?
    var resposta: RespostaDoSindico?
    var historico: [EventoOcorrencia]

    enum CodingKeys: String, CodingKey {
        case id, titulo, descricao, categoria, local, foto, status, autorId, autorNome, autorPerfil
        case bloco, apartamento, criadoEm, atualizadoEm, recebidaEm, respondidaEm, resposta, historico
    }

    init(id: String, titulo: String, descricao: String, categoria: String, local: String? = nil, foto: String? = nil,
         status: String = "aguardando", autorId: String? = nil, autorNome: String, autorPerfil: String? = nil,
         bloco: String? = nil, apartamento: String? = nil, criadoEm: String? = nil, atualizadoEm: String? = nil,
         recebidaEm: String? = nil, respondidaEm: String? = nil, resposta: RespostaDoSindico? = nil, historico: [EventoOcorrencia] = []) {
        self.id = id; self.titulo = titulo; self.descricao = descricao; self.categoria = categoria; self.local = local
        self.foto = foto; self.status = status; self.autorId = autorId; self.autorNome = autorNome; self.autorPerfil = autorPerfil
        self.bloco = bloco; self.apartamento = apartamento; self.criadoEm = criadoEm; self.atualizadoEm = atualizadoEm
        self.recebidaEm = recebidaEm
        self.respondidaEm = respondidaEm; self.resposta = resposta; self.historico = historico
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        titulo = try c.decodeIfPresent(String.self, forKey: .titulo) ?? "Ocorrência"
        descricao = try c.decodeIfPresent(String.self, forKey: .descricao) ?? ""
        categoria = try c.decodeIfPresent(String.self, forKey: .categoria) ?? "outro"
        local = try c.decodeIfPresent(String.self, forKey: .local)
        foto = try c.decodeIfPresent(String.self, forKey: .foto)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "aguardando"
        autorId = try c.decodeIfPresent(String.self, forKey: .autorId)
        autorNome = try c.decodeIfPresent(String.self, forKey: .autorNome) ?? "Morador"
        autorPerfil = try c.decodeIfPresent(String.self, forKey: .autorPerfil)
        bloco = try c.decodeIfPresent(String.self, forKey: .bloco)
        apartamento = try c.decodeIfPresent(String.self, forKey: .apartamento)
        criadoEm = try c.decodeIfPresent(String.self, forKey: .criadoEm)
        atualizadoEm = try c.decodeIfPresent(String.self, forKey: .atualizadoEm)
        recebidaEm = try c.decodeIfPresent(String.self, forKey: .recebidaEm)
        respondidaEm = try c.decodeIfPresent(String.self, forKey: .respondidaEm)
        resposta = try c.decodeIfPresent(RespostaDoSindico.self, forKey: .resposta)
        historico = try c.decodeIfPresent([EventoOcorrencia].self, forKey: .historico) ?? []
    }

    var respondida: Bool { status == "respondida" }
    var recebido: Bool { status != "aguardando" }
    var categoriaEnum: CategoriaOcorrencia { CategoriaOcorrencia(rawValue: categoria) ?? .outro }
    var statusTitulo: String { respondida ? "Respondida" : (recebido ? "Recebido" : "Aguardando") }
    var dataUltimaEtapa: String { respondidaEm ?? recebidaEm ?? criadoEm ?? "" }
    var unidade: String {
        switch (bloco, apartamento) {
        case let (b?, a?): "Bloco \(b) · Apto \(a)"
        case let (nil, a?): "Apto \(a)"
        default: autorPerfil == "guarda" ? "Portaria" : "Unidade não informada"
        }
    }
}

struct RespostaOcorrencias: Decodable { let ocorrencias: [Ocorrencia] }
struct RespostaOcorrenciaUnica: Decodable { let ocorrencia: Ocorrencia }
