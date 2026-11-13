import SwiftUI

struct EncomendaFormView: View {
    let encomenda: Encomenda?
    var aoSalvar: (Encomenda) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var form: EncomendaForm
    @State private var moradores: [MoradorResumo] = []
    @State private var carregandoMoradores = true
    @State private var enviando = false
    @State private var erro: String?

    init(encomenda: Encomenda?, aoSalvar: @escaping (Encomenda) -> Void) {
        self.encomenda = encomenda
        self.aoSalvar = aoSalvar
        _form = State(initialValue: encomenda.map { EncomendaForm($0) } ?? EncomendaForm())
    }

    private var invalido: Bool {
        (!form.semDestinatario && form.moradorId.isEmpty) || form.descricao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $form.semDestinatario.animation()) {
                        Label("Destinatário não reconhecido", systemImage: "questionmark.circle.fill")
                    }
                    .tint(.orange)
                    if form.semDestinatario {
                        TextField("O que está na etiqueta (opcional)", text: $form.destinatarioInformado)
                    } else if carregandoMoradores && moradores.isEmpty {
                        HStack { Text("Carregando moradores…"); Spacer(); ProgressView() }
                    } else {
                        Picker("Morador", selection: $form.moradorId) {
                            Text("Selecione").tag("")
                            ForEach(moradores) { m in Text(m.rotulo).tag(m.id) }
                        }
                        .pickerStyle(.navigationLink)
                    }
                } header: {
                    Text("Destinatário")
                } footer: {
                    Text(form.semDestinatario
                         ? "A encomenda fica registrada sem morador, bloco ou apartamento. Depois é só editar e escolher o morador."
                         : "Não encontrou o morador ou a etiqueta está incompleta? Marque \"Destinatário não reconhecido\".")
                }

                Section("Encomenda") {
                    TextField("Descrição (ex.: Caixa média, Envelope)", text: $form.descricao)
                    TextField("Remetente / transportadora", text: $form.transportadora)
                    TextField("Código de rastreio (opcional)", text: $form.codigoRastreio)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Observação (opcional)", text: $form.observacao, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Picker("Status", selection: $form.status) {
                        ForEach(StatusEncomenda.allCases) { Text($0.titulo).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Status")
                } footer: {
                    Text("Ao marcar como Retirado, a data e o horário da retirada são registrados automaticamente.")
                }

                SeletorFotoUnica(foto: $form.foto, titulo: "Foto da encomenda")

                if let erro {
                    Section { Text(erro).foregroundStyle(.red) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(encomenda == nil ? "Registrar encomenda" : "Editar encomenda").barraMarca()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.disabled(enviando) }
                ToolbarItem(placement: .confirmationAction) {
                    if enviando { ProgressView() } else { Button("Salvar") { salvar() }.disabled(invalido) }
                }
            }
            .interactiveDismissDisabled(enviando)
            .task { await carregarMoradores() }
        }
    }

    private func carregarMoradores() async {
        carregandoMoradores = true
        defer { carregandoMoradores = false }
        do {
            moradores = try await APIService.shared.moradores()
            if let e = encomenda, let id = e.moradorId, !moradores.contains(where: { $0.id == id }) {
                moradores.insert(MoradorResumo(id: id, nome: e.moradorNome ?? id, bloco: e.bloco, apartamento: e.apartamento), at: 0)
            }
        } catch {
            erro = "Não foi possível carregar os moradores: \(error.localizedDescription)"
        }
    }

    private func salvar() {
        enviando = true
        erro = nil
        Task {
            do {
                let salva: Encomenda
                if let encomenda {
                    salva = try await APIService.shared.editarEncomenda(id: encomenda.id, form)
                } else {
                    salva = try await APIService.shared.criarEncomenda(form)
                }
                aoSalvar(salva)
                dismiss()
            } catch {
                erro = error.localizedDescription
                enviando = false
            }
        }
    }
}
