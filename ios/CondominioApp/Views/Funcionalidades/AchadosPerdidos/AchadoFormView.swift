import SwiftUI

struct AchadoFormView: View {
    let achado: Achado?
    var aoSalvar: (Achado) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var form: AchadoForm
    @State private var enviando = false
    @State private var erro: String?

    init(achado: Achado?, aoSalvar: @escaping (Achado) -> Void) {
        self.achado = achado
        self.aoSalvar = aoSalvar
        _form = State(initialValue: achado.map { AchadoForm($0) } ?? AchadoForm())
    }

    var body: some View {
        NavigationStack {
            Form {
                SeletorFotoUnica(foto: $form.foto, titulo: "Foto do objeto")

                Section("Dados do item") {
                    TextField("Título (ex.: Chaveiro azul)", text: $form.titulo)
                    TextField("Descrição", text: $form.descricao, axis: .vertical)
                        .lineLimit(3...8)
                    TextField("Local (onde foi perdido ou encontrado)", text: $form.local)
                    Picker("Categoria", selection: $form.categoria) {
                        ForEach(CategoriaAchado.allCases) { c in
                            Label(c.titulo, systemImage: c.icone).tag(c)
                        }
                    }
                }

                Section("Status") {
                    Picker("Status", selection: $form.status) {
                        ForEach(StatusAchado.allCases) { Text($0.titulo).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                if let erro {
                    Section { Text(erro).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(achado == nil ? "Registrar item" : "Editar item").barraMarca()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.disabled(enviando) }
                ToolbarItem(placement: .confirmationAction) {
                    if enviando { ProgressView() } else { Button("Salvar") { salvar() }.disabled(!form.valido) }
                }
            }
            .interactiveDismissDisabled(enviando)
        }
    }

    private func salvar() {
        enviando = true
        erro = nil
        Task {
            do {
                let salvo: Achado
                if let achado {
                    salvo = try await APIService.shared.editarAchado(id: achado.id, form)
                } else {
                    salvo = try await APIService.shared.criarAchado(form)
                }
                aoSalvar(salvo)
                dismiss()
            } catch {
                erro = error.localizedDescription
                enviando = false
            }
        }
    }
}
