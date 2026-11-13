import SwiftUI

struct MinhasOcorrenciasView: View {
    let store: OcorrenciasStore
    @State private var aba: AbaOcorrencias = .aguardando
    @State private var nova = false

    var body: some View {
        VStack(spacing: 12) {
            SeletorAbasOcorrencias(aba: $aba, store: store)

            switch aba {
            case .aguardando:
                ListaOcorrencias(store: store, itens: store.aguardando,
                                 vazio: store.itens.isEmpty ? "Você ainda não enviou ocorrências.\nToque em + para enviar a primeira."
                                                            : "Nenhuma ocorrência aguardando.\nO síndico já recebeu todas.",
                                 icone: "clock")
            case .recebido:
                ListaOcorrencias(store: store, itens: store.recebidas,
                                 vazio: "Quando o síndico abrir uma ocorrência sua, ela aparece aqui.",
                                 icone: "tray.and.arrow.down")
            }
        }
        .padding(.top, 14)
        .telaPadrao()
        .navigationTitle("Minhas ocorrências").barraMarca()
        .overlay { if store.carregando && !store.jaCarregou { ProgressView() } }
        .botaoFlutuante(rotulo: "Nova ocorrência") { nova = true }
        .sheet(isPresented: $nova) {
            NovaOcorrenciaView { criada in
                store.substituir(criada)
                aba = .aguardando
            }
        }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(15)) } catch { break }
                await store.atualizarEmSegundoPlano()
            }
        }
    }
}
