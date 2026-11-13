import SwiftUI

struct AchadoDetalheView: View {
    @State private var achado: Achado
    let podeGerenciar: Bool
    var aoAtualizar: (Achado) -> Void

    @State private var editando = false
    @State private var salvando = false
    @State private var erro: String?

    init(achado: Achado, podeGerenciar: Bool, aoAtualizar: @escaping (Achado) -> Void) {
        _achado = State(initialValue: achado)
        self.podeGerenciar = podeGerenciar
        self.aoAtualizar = aoAtualizar
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                FotoDetalhe(foto: achado.foto, icone: achado.categoriaEnum.icone)

                HStack(spacing: 8) {
                    PilulaInfo(texto: achado.categoriaEnum.titulo, icone: achado.categoriaEnum.icone, cor: achado.categoriaEnum.cor)
                    StatusAchadoPill(status: achado.statusEnum)
                }

                Text(achado.titulo)
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.textPrimary)

                Text(achado.descricao)
                    .foregroundStyle(AppColors.textPrimary)
                    .textSelection(.enabled)

                VStack(alignment: .leading, spacing: 14) {
                    LinhaDetalhe(titulo: "Situação", valor: achado.statusEnum.titulo)
                    if let local = achado.local { Divider(); LinhaDetalhe(titulo: "Local", valor: local) }
                    if let quem = achado.registradoPorNome { Divider(); LinhaDetalhe(titulo: "Registrado por", valor: quem) }
                    Divider()
                    HStack(alignment: .top, spacing: 24) {
                        if let d = DataHoraLinhas(iso: achado.criadoEm, titulo: "Registrado") { d }
                        if achado.statusEnum == .encontrado, let d = DataHoraLinhas(iso: achado.statusAlteradoEm, titulo: "Recuperado") { d }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cartao()

                if achado.statusEnum == .perdido && !podeGerenciar {
                    Label("Reconheceu este item? Procure a portaria.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                }

                if podeGerenciar {
                    Button {
                        Task { await alternarStatus() }
                    } label: {
                        Label(achado.statusEnum == .perdido ? "Marcar como recuperado" : "Marcar como perdido",
                              systemImage: achado.statusEnum == .perdido ? "checkmark.seal.fill" : "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).sombraSutil()
                    .tint(achado.statusEnum == .perdido ? Color.green : Color.orange)
                    .controlSize(.large)
                    .disabled(salvando)
                    if let erro { Text(erro).font(.footnote).foregroundStyle(.red) }
                }
            }
            .padding()
        }
        .telaPadrao()
        .navigationTitle("Item").barraMarca()
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if salvando { ProgressView() } }
        .toolbar {
            if podeGerenciar {
                ToolbarItem(placement: .primaryAction) { Button("Editar") { editando = true } }
            }
        }
        .sheet(isPresented: $editando) {
            AchadoFormView(achado: achado) { atualizado in
                achado = atualizado
                aoAtualizar(atualizado)
            }
        }
    }

    private func alternarStatus() async {
        salvando = true
        erro = nil
        defer { salvando = false }
        var form = AchadoForm(achado)
        form.status = achado.statusEnum == .perdido ? .encontrado : .perdido
        do {
            let atualizado = try await APIService.shared.editarAchado(id: achado.id, form)
            achado = atualizado
            aoAtualizar(atualizado)
        } catch { self.erro = error.localizedDescription }
    }
}
