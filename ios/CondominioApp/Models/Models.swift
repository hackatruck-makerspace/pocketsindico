import Foundation

enum TipoUsuario: String, Codable, CaseIterable, Identifiable {
    case morador, guarda, sindico
    var id: String { rawValue }
    var titulo: String { switch self { case .morador: "Morador"; case .guarda: "Guarda"; case .sindico: "Síndico" } }
    var icone: String { switch self { case .morador: "house.fill"; case .guarda: "shield.fill"; case .sindico: "building.2.fill" } }
}

struct Usuario: Codable, Identifiable, Hashable {
    let id: String
    var nome: String
    var perfil: TipoUsuario
    var bloco: String?
    var apartamento: String?
    var unidade: String? { guard let b = bloco, let a = apartamento else { return nil }; return "Bloco \(b) · Apto \(a)" }
}

struct Funcionalidade: Codable, Identifiable, Hashable { let id: String; let nome: String; let icone: String }

struct Atualizacao: Codable, Identifiable, Hashable {
    let id: String; let tipo: String; let titulo: String; let detalhe: String?; let data: String?
}

struct Comunicado: Codable, Identifiable, Hashable {
    let id: String
    var titulo: String
    var descricao: String
    var categoria: String
    var autorNome: String
    var autorId: String?
    var dataPublicacao: String
    var criadoEm: String?

    enum CodingKeys: String, CodingKey {
        case id, titulo, descricao, categoria, autorNome, autorId, dataPublicacao, criadoEm
    }
}

extension Comunicado {
    var momento: String {
        if dataPublicacao.count > 10 { return dataPublicacao }
        if let c = criadoEm, c.hasPrefix(dataPublicacao) { return c }
        return dataPublicacao
    }
    var dataExibicao: String { DataHora.formatar(momento) }

    static func maisRecentePrimeiro(_ a: Comunicado, _ b: Comunicado) -> Bool {
        if a.momento != b.momento { return a.momento > b.momento }
        if a.dataPublicacao != b.dataPublicacao { return a.dataPublicacao > b.dataPublicacao }
        return a.id > b.id
    }
}

struct Anuncio: Codable, Identifiable, Hashable {
    let id: String
    var titulo: String
    var descricao: String
    var categoria: String
    var preco: String?
    var anuncianteNome: String
    var bloco: String?
    var apartamento: String?
    var totalFavoritos: Int = 0
    var favoritado: Bool = false
    var totalComentarios: Int = 0
    var criadoEm: String?
    var atualizadoEm: String?
    var anuncianteId: String?
    var status: String?
    var fotos: [String] = []
    var foto: String? = nil
    var encerrado: Bool { status == "encerrado" }

    enum CodingKeys: String, CodingKey {
        case id, titulo, descricao, categoria, preco, anuncianteNome, bloco, apartamento
        case totalFavoritos, favoritado, totalComentarios, criadoEm, atualizadoEm, anuncianteId, status, fotos, foto
    }

    init(id: String, titulo: String, descricao: String, categoria: String, preco: String? = nil,
         anuncianteNome: String, bloco: String? = nil, apartamento: String? = nil,
         totalFavoritos: Int = 0, favoritado: Bool = false, totalComentarios: Int = 0,
         criadoEm: String? = nil, atualizadoEm: String? = nil, anuncianteId: String? = nil, status: String? = nil, fotos: [String] = []) {
        self.id = id; self.titulo = titulo; self.descricao = descricao; self.categoria = categoria
        self.preco = preco; self.anuncianteNome = anuncianteNome; self.bloco = bloco; self.apartamento = apartamento
        self.totalFavoritos = totalFavoritos; self.favoritado = favoritado; self.totalComentarios = totalComentarios
        self.criadoEm = criadoEm; self.atualizadoEm = atualizadoEm; self.anuncianteId = anuncianteId; self.status = status; self.fotos = fotos
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        titulo = try c.decode(String.self, forKey: .titulo)
        descricao = try c.decode(String.self, forKey: .descricao)
        categoria = try c.decode(String.self, forKey: .categoria)
        preco = try c.decodeIfPresent(String.self, forKey: .preco)
        anuncianteNome = try c.decode(String.self, forKey: .anuncianteNome)
        bloco = try c.decodeIfPresent(String.self, forKey: .bloco)
        apartamento = try c.decodeIfPresent(String.self, forKey: .apartamento)
        totalFavoritos = try c.decodeIfPresent(Int.self, forKey: .totalFavoritos) ?? 0
        favoritado = try c.decodeIfPresent(Bool.self, forKey: .favoritado) ?? false
        totalComentarios = try c.decodeIfPresent(Int.self, forKey: .totalComentarios) ?? 0
        criadoEm = try c.decodeIfPresent(String.self, forKey: .criadoEm)
        atualizadoEm = try c.decodeIfPresent(String.self, forKey: .atualizadoEm)
        anuncianteId = try c.decodeIfPresent(String.self, forKey: .anuncianteId)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        fotos = try c.decodeIfPresent([String].self, forKey: .fotos) ?? []
        foto = try c.decodeIfPresent(String.self, forKey: .foto)
        if fotos.isEmpty, let foto, !foto.isEmpty { fotos = [foto] }
    }
}

struct Comentario: Codable, Identifiable, Hashable {
    let id: String
    let autorId: String?
    let autorNome: String
    var texto: String
    var criadoEm: String
    var atualizadoEm: String?
    var editado: Bool
    var foto: String?

    enum CodingKeys: String, CodingKey {
        case id, autorId, autorNome, texto, criadoEm, atualizadoEm, editado, foto
    }

    init(id: String, autorId: String? = nil, autorNome: String, texto: String,
         criadoEm: String, atualizadoEm: String? = nil, editado: Bool = false, foto: String? = nil) {
        self.id = id
        self.autorId = autorId
        self.autorNome = autorNome
        self.texto = texto
        self.criadoEm = criadoEm
        self.atualizadoEm = atualizadoEm
        self.editado = editado
        self.foto = foto
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        autorId = try c.decodeIfPresent(String.self, forKey: .autorId)
        autorNome = try c.decode(String.self, forKey: .autorNome)
        texto = try c.decode(String.self, forKey: .texto)
        criadoEm = try c.decodeIfPresent(String.self, forKey: .criadoEm) ?? ""
        atualizadoEm = try c.decodeIfPresent(String.self, forKey: .atualizadoEm)
        editado = try c.decodeIfPresent(Bool.self, forKey: .editado) ?? false
        foto = try c.decodeIfPresent(String.self, forKey: .foto)
    }
}

struct HomeResponse: Codable {
    var usuario: Usuario; var favoritos: [String]; var ordem: [String]
    var funcionalidades: [Funcionalidade]; var atualizacoes: [Atualizacao]
}

enum CategoriaComunicado: String, CaseIterable, Identifiable {
    case avisos, manutencao, obras, limpeza, assembleias, seguranca, outro
    var id: String { rawValue }
    var titulo: String { ["avisos":"Avisos","manutencao":"Manutenção","obras":"Obras","limpeza":"Limpeza","assembleias":"Assembleias","seguranca":"Segurança","outro":"Outro"][rawValue]! }
}
enum CategoriaAnuncio: String, CaseIterable, Identifiable {
    case venda, comida, roupas, pets, servicos, doacoes, outro
    var id: String { rawValue }
    var titulo: String { ["venda":"Venda","comida":"Comida","roupas":"Roupas","pets":"Pets","servicos":"Serviços","doacoes":"Doações","outro":"Outro"][rawValue]! }
}
