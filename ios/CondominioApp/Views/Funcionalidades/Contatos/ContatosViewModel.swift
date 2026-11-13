import SwiftUI
import UIKit

enum Ligacao {
    static func url(para telefone: String) -> URL? {
        let numero = telefone.filter { $0.isNumber || $0 == "+" }
        guard numero.filter(\.isNumber).count >= 8 else { return nil }
        return URL(string: "tel:\(numero)")
    }

    @MainActor
    static func ligar(para telefone: String) async -> Bool {
        guard let url = url(para: telefone) else { return false }
        return await UIApplication.shared.open(url)
    }
}

@Observable
@MainActor
final class ContatosViewModel {
    var contatos: [ContatoCondominio] = []
    var sindico: ContatoCondominio?
    var carregando = false
    var jaCarregou = false
    var erro: String?

    func carregar() async {
        carregando = true
        erro = nil
        defer {
            carregando = false
            jaCarregou = true
        }
        do {
            let resposta = try await APIService.shared.contatos()
            contatos = resposta.contatos
            sindico = resposta.sindico
        } catch {
            self.erro = error.localizedDescription
        }
    }
}
