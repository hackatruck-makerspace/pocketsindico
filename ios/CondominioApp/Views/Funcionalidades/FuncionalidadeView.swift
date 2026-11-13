import SwiftUI

struct FuncionalidadeView: View {
    let funcionalidade: Funcionalidade
    var body: some View {
        conteudo.navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var conteudo: some View {
        switch funcionalidade.id {
        case "comunicados": ComunicadosTela().telaPadrao().navigationTitle("Comunicados").barraMarca()
        case "meus_anuncios": MeusAnunciosView()
        case "encomendas": EncomendasView()
        case "boletos": BoletosView()
        case "reservas", "quiosque": ReservasView()
        case "ocorrencias": OcorrenciasView()
        case "achados": AchadosPerdidosView()
        case "contatos": ContatosView()
        default:
            EmptyStateView(icone: funcionalidade.icone, texto: "\(funcionalidade.nome)\nEm construção — próximo módulo do backend.")
                .frame(maxHeight: .infinity).telaPadrao().navigationTitle(funcionalidade.nome).barraMarca()
        }
    }
}
