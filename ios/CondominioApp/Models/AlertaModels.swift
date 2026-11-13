import Foundation

enum StatusAlerta: String, Codable {
    case pendente, adiado, lido
    var titulo: String { self == .lido ? "Lida" : "Aguardando leitura" }
}

struct Alerta: Identifiable, Codable, Equatable {
    let id: UUID
    let ocorrenciaID: UUID
    let unidadeDestino: String
    let titulo: String
    let mensagem: String
    let criadoEm: Date
    var status: StatusAlerta = .pendente
    var lidoEm: Date?
    var adiadoAte: Date?
    let envioID: UUID
    var blocoDestino: String? = nil
    var ocorrenciaRef: String? = nil

    var blocoEfetivo: String { blocoDestino ?? "A" }
    var unidadeDescricao: String { "Bloco \(blocoEfetivo) · Apto \(unidadeDestino)" }
    var chaveUnidade: String { "\(blocoEfetivo)-\(unidadeDestino)" }

    static let tituloPadrao = "Lembrete de convivência"
    static let mensagemPadrao = """
    Olá! Recebemos relatos de ruído na região da sua unidade.

    Sabemos que situações assim podem acontecer e gostaríamos apenas de pedir atenção ao volume, especialmente nos horários de descanso.

    Agradecemos pela compreensão e colaboração para uma boa convivência. 💙
    """
    static let rodape = "Mensagem cordial da administração • Sem caráter punitivo"
}

struct OcorrenciaDemo: Identifiable, Codable {
    let id: UUID
    let categoria: String
    let reclamanteID: String
    let unidadeReclamante: String
    let unidadeEnvolvida: String
    let descricao: String

    static let exemplo = OcorrenciaDemo(
        id: UUID(uuidString: "E037B22C-5A26-44A7-86D0-302201000001")!,
        categoria: "Barulho excessivo", reclamanteID: "DEMO-004",
        unidadeReclamante: "201", unidadeEnvolvida: "302",
        descricao: "Relato de música alta na região da unidade 302 durante o horário de descanso. Relato de teste, sem conclusão de responsabilidade.")
}

struct DadosAlertasDemo: Codable {
    var ocorrencia: OcorrenciaDemo = .exemplo
    var alertas: [Alerta] = []
}
