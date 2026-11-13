import Foundation

struct ContatoCondominio: Codable, Identifiable, Hashable {
    let id: String
    let nome: String
    let perfil: String
    let cargo: String
    let telefone: String?

    var icone: String {
        perfil == "sindico" ? "person.crop.circle.badge.checkmark" : "shield.lefthalf.filled"
    }
}

struct RespostaContatos: Decodable {
    let contatos: [ContatoCondominio]
    let sindico: ContatoCondominio?
}
