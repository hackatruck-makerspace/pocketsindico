import SwiftUI

struct ConfiguracoesView: View {
    @AppStorage("tema") private var tema = "escuro"
    @AppStorage("idioma") private var idioma = "pt-BR"
    @AppStorage("servidor") private var servidor = APIConfig.enderecoPadrao
    @Environment(AppSession.self) private var session
    @State private var testando = false
    @State private var resultadoTeste: String?

    var body: some View {
        Form {
            Section {
                TextField("http://192.168.0.10:1880", text: $servidor)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task { await testar() }
                } label: {
                    HStack { Text("Testar e recarregar"); if testando { Spacer(); ProgressView() } }
                }
                .disabled(testando)
                if let resultadoTeste { Text(resultadoTeste).font(.footnote).foregroundStyle(AppColors.textSecondary) }
            } header: {
                Text("Servidor (Node-RED)")
            } footer: {
                Text("No iPhone, use o IP do computador onde o Node-RED está rodando (mesmo Wi-Fi), com a porta 1880. No Simulador: \(APIConfig.enderecoPadrao).")
            }

            Picker("Tema", selection: $tema) {
                Text("Claro").tag("claro"); Text("Escuro").tag("escuro"); Text("Sistema").tag("sistema")
            }
            Picker("Idioma", selection: $idioma) {
                Text("Português (Brasil)").tag("pt-BR"); Text("English").tag("en"); Text("Español").tag("es")
            }
        }
        .telaPadrao().navigationTitle("Configurações").barraMarca()
    }

    private func testar() async {
        testando = true
        defer { testando = false }
        do {
            _ = try await APIService.shared.perfisDemo()
            resultadoTeste = "Conectado a \(APIConfig.baseURL.absoluteString)."
            await session.carregarTudo()
        } catch {
            resultadoTeste = "Sem resposta de \(APIConfig.baseURL.absoluteString): \(error.localizedDescription)"
        }
    }
}
