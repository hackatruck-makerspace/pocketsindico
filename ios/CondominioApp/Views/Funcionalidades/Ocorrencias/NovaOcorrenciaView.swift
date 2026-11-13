import SwiftUI

struct NovaOcorrenciaView: View {
    var aoEnviar: (Ocorrencia) -> Void

    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var titulo = ""
    @State private var categoria: CategoriaOcorrencia = .barulho
    @State private var descricao = ""
    @State private var local = ""
    @State private var foto: String?
    @State private var enviando = false
    @State private var erro: String?

    private var invalido: Bool {
        titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || descricao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quem está enviando") {
                    UsuarioHeader(usuario: session.usuario)
                }

                Section("Ocorrência") {
                    TextField("Título (ex.: Barulho depois das 22h)", text: $titulo)
                    Picker("Categoria", selection: $categoria) {
                        ForEach(CategoriaOcorrencia.allCases) { c in Label(c.titulo, systemImage: c.icone).tag(c) }
                    }
                    TextField("Local (opcional — ex.: Bloco A, 4º andar)", text: $local)
                }

                Section {
                    TextField("Descreva o que aconteceu, quando e com que frequência", text: $descricao, axis: .vertical)
                        .lineLimit(4...10)
                } header: {
                    Text("Motivo da reclamação")
                } footer: {
                    Text("O síndico recebe a ocorrência com seu nome, bloco e apartamento.")
                }

                SeletorFotoUnica(foto: $foto, titulo: "Foto (opcional)")

                if let erro { Section { Text(erro).foregroundStyle(.red) } }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Nova ocorrência").barraMarca()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.disabled(enviando) }
                ToolbarItem(placement: .confirmationAction) {
                    if enviando { ProgressView() } else { Button("Enviar") { enviar() }.disabled(invalido) }
                }
            }
            .interactiveDismissDisabled(enviando)
        }
    }

    private func enviar() {
        enviando = true
        erro = nil
        Task {
            do {
                let o = try await APIService.shared.enviarOcorrencia(titulo: titulo, descricao: descricao, categoria: categoria.rawValue,
                                                                     local: local, foto: foto)
                aoEnviar(o)
                dismiss()
            } catch {
                erro = error.localizedDescription
                enviando = false
            }
        }
    }
}
