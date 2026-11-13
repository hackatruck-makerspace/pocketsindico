import SwiftUI

struct EncomendaDetalheView: View {
    @State private var encomenda: Encomenda
    let podeGerenciar: Bool
    var aoAtualizar: (Encomenda) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @State private var editando = false
    @State private var salvando = false
    @State private var erro: String?
    @State private var confirmarStatus = false

    init(encomenda: Encomenda, podeGerenciar: Bool, aoAtualizar: @escaping (Encomenda) -> Void = { _ in }) {
        _encomenda = State(initialValue: encomenda)
        self.podeGerenciar = podeGerenciar
        self.aoAtualizar = aoAtualizar
    }

    private var proximoStatus: StatusEncomenda { encomenda.retirada ? .aguardandoRetirada : .retirada }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    FotoDetalhe(foto: encomenda.foto, icone: "shippingbox.fill")

                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            StatusEncomendaPill(status: encomenda.statusEnum)
                            if encomenda.destinatarioDesconhecido { SemDestinatarioPill() }
                            Spacer()
                        }
                        Text(encomenda.descricao)
                            .font(.title2.bold())
                            .foregroundStyle(AppColors.textPrimary)
                        HStack(alignment: .top, spacing: 24) {
                            if let d = DataHoraLinhas(iso: encomenda.dataRecebimento, titulo: "Cadastrada") { d }
                            if encomenda.retirada, let d = DataHoraLinhas(iso: encomenda.dataEntrega ?? encomenda.statusAlteradoEm, titulo: "Retirada") { d }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cartao()

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Informações da encomenda").font(.headline).foregroundStyle(AppColors.textPrimary)
                        LinhaDetalhe(titulo: "Remetente / transportadora", valor: encomenda.remetente)
                        if let codigo = encomenda.codigoRastreio { Divider(); LinhaDetalhe(titulo: "Código de rastreio", valor: codigo) }
                        Divider()
                        LinhaDetalhe(titulo: "Destinatário", valor: encomenda.destinatarioTexto)
                        if encomenda.destinatarioDesconhecido {
                            if let etiqueta = encomenda.destinatarioInformado { LinhaDetalhe(titulo: "Escrito na etiqueta", valor: etiqueta) }
                            if podeGerenciar {
                                Label("Quando identificar o morador, toque em Editar e escolha o destinatário.", systemImage: "info.circle")
                                    .font(.footnote).foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        if let obs = encomenda.observacao { Divider(); LinhaDetalhe(titulo: "Observação", valor: obs) }
                        if let quem = encomenda.registradoPorNome { Divider(); LinhaDetalhe(titulo: "Registrada por", valor: quem) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cartao()

                    if !encomenda.retirada && !podeGerenciar {
                        Label("Retire na portaria apresentando um documento.", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if podeGerenciar {
                        Button {
                            confirmarStatus = true
                        } label: {
                            Label(proximoStatus == .retirada ? "Marcar como retirado" : "Voltar para aguardando retirada",
                                  systemImage: proximoStatus == .retirada ? "checkmark.circle.fill" : "arrow.uturn.backward.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).sombraSutil()
                        .tint(proximoStatus == .retirada ? Color.green : Color.orange)
                        .controlSize(.large)
                        .disabled(salvando)

                        if let erro { Text(erro).font(.footnote).foregroundStyle(.red) }
                    }
                }
                .padding(20)
            }
            .telaPadrao()
            .navigationTitle("Detalhes").barraMarca()
            .navigationBarTitleDisplayMode(.inline)
            .overlay { if salvando { ProgressView() } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
                if podeGerenciar {
                    ToolbarItem(placement: .primaryAction) { Button("Editar") { editando = true } }
                }
            }
            .confirmationDialog(proximoStatus == .retirada ? "Confirmar retirada?" : "Voltar para aguardando retirada?",
                                isPresented: $confirmarStatus, titleVisibility: .visible) {
                Button(proximoStatus == .retirada ? "Marcar como retirado" : "Voltar para aguardando") { Task { await trocarStatus() } }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text(proximoStatus == .retirada ? "A data e o horário da retirada serão registrados agora." : "A data de retirada será apagada.")
            }
            .sheet(isPresented: $editando) {
                EncomendaFormView(encomenda: encomenda) { atualizada in
                    encomenda = atualizada
                    aoAtualizar(atualizada)
                }
            }
        }
    }

    private func trocarStatus() async {
        salvando = true
        erro = nil
        defer { salvando = false }
        var form = EncomendaForm(encomenda)
        form.status = proximoStatus
        do {
            let atualizada = try await APIService.shared.editarEncomenda(id: encomenda.id, form)
            encomenda = atualizada
            aoAtualizar(atualizada)
        } catch {
            self.erro = error.localizedDescription
        }
    }
}
