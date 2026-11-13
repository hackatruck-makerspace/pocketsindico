import SwiftUI

struct OcorrenciasSindicoView: View {
    let store: OcorrenciasStore
    @State private var aba: AbaOcorrencias = .aguardando

    var body: some View {
        VStack(spacing: 12) {
            SeletorAbasOcorrencias(aba: $aba, store: store)

            switch aba {
            case .aguardando:
                ListaOcorrencias(store: store, itens: store.aguardando,
                                 vazio: "Nenhuma ocorrência aguardando. Tudo em dia!", icone: "clock", mostrarAutor: true)
            case .recebido:
                ListaOcorrencias(store: store, itens: store.recebidas,
                                 vazio: "Nenhuma ocorrência recebida ainda.", icone: "tray.and.arrow.down", mostrarAutor: true)
            }
        }
        .padding(.top, 14)
        .telaPadrao()
        .navigationTitle("Ocorrências").barraMarca()
        .overlay { if store.carregando && !store.jaCarregou { ProgressView() } }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { break }
                await store.atualizarEmSegundoPlano()
            }
        }
    }
}
