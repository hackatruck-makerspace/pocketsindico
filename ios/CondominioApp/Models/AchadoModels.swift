import SwiftUI

enum CategoriaAchado: String, CaseIterable, Identifiable {
    case documentos, chaves, eletronicos, roupas, objetos, outro
    var id: String { rawValue }
    var titulo: String {
        switch self {
        case .documentos: "Documentos"
        case .chaves: "Chaves"
        case .eletronicos: "Eletrônicos"
        case .roupas: "Roupas e acessórios"
        case .objetos: "Objetos pessoais"
        case .outro: "Outro"
        }
    }
    var icone: String {
        switch self {
        case .documentos: "doc.text.fill"
        case .chaves: "key.fill"
        case .eletronicos: "headphones"
        case .roupas: "tshirt.fill"
        case .objetos: "bag.fill"
        case .outro: "questionmark.square.fill"
        }
    }
    var cor: Color {
        switch self {
        case .documentos: .blue
        case .chaves: .yellow
        case .eletronicos: .purple
        case .roupas: .pink
        case .objetos: .orange
        case .outro: .gray
        }
    }
}

enum StatusAchado: String, CaseIterable, Identifiable {
    case perdido, encontrado
    var id: String { rawValue }
    var titulo: String { self == .encontrado ? "Encontrado / recuperado" : "Perdido / não encontrado" }
    var tituloCurto: String { self == .encontrado ? "Recuperado" : "Perdido" }
    var cor: Color { self == .encontrado ? .green : .orange }
    var icone: String { self == .encontrado ? "checkmark.seal.fill" : "magnifyingglass" }
}

struct Achado: Codable, Identifiable, Hashable {
    let id: String
    var titulo: String
    var descricao: String
    var categoria: String
    var status: String
    var local: String?
    var foto: String?
    var registradoPorNome: String?
    var criadoEm: String?
    var atualizadoEm: String?
    var statusAlteradoEm: String?

    var categoriaEnum: CategoriaAchado { CategoriaAchado(rawValue: categoria) ?? .outro }
    var statusEnum: StatusAchado { StatusAchado(rawValue: status) ?? .perdido }
}

struct RespostaAchados: Decodable { let achados: [Achado] }
struct RespostaAchado: Decodable { let achado: Achado }

struct AchadoForm {
    var titulo = ""
    var descricao = ""
    var categoria: CategoriaAchado = .objetos
    var status: StatusAchado = .perdido
    var local = ""
    var foto: String?

    init() {}
    init(_ a: Achado) {
        titulo = a.titulo; descricao = a.descricao; categoria = a.categoriaEnum
        status = a.statusEnum; local = a.local ?? ""; foto = a.foto
    }

    var valido: Bool {
        !titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !descricao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var corpo: [String: Any] {
        let l = local.trimmingCharacters(in: .whitespacesAndNewlines)
        var localValor: Any = NSNull()
        if !l.isEmpty { localValor = l }
        return ["titulo": titulo.trimmingCharacters(in: .whitespacesAndNewlines),
                "descricao": descricao.trimmingCharacters(in: .whitespacesAndNewlines),
                "categoria": categoria.rawValue, "status": status.rawValue,
                "local": localValor, "foto": foto.map { $0 as Any } ?? NSNull()]
    }
}
