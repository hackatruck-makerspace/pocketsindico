import SwiftUI

struct EncomendasView: View {
    @Environment(AppSession.self) private var session

    var destacarId: String? = nil

    enum Filtro: String, CaseIterable, Identifiable {
        case todas = "Todas", pendentes = "Aguardando", retiradas = "Retiradas", semDestinatario = "Sem destinatário"
        var id: String { rawValue }
    }

    @State private var encomendas: [Encomenda] = []
    @State private var pesquisa = ""
    @State private var filtro: Filtro = .todas
    @State private var selecionada: Encomenda?
    @State private var cadastrando = false
    @State private var carregando = false
    @State private var jaCarregou = false
    @State private var erro: String?
    @State private var jaDestacou = false

    private var podeGerenciar: Bool { session.usuario.perfil != .morador }

    private func contagem(_ f: Filtro) -> Int {
        switch f {
        case .todas: encomendas.count
        case .pendentes: encomendas.filter { !$0.retirada }.count
        case .retiradas: encomendas.filter(\.retirada).count
        case .semDestinatario: encomendas.filter(\.destinatarioDesconhecido).count
        }
    }

    private var filtradas: [Encomenda] {
        encomendas.filter { item in
            let correspondePesquisa = pesquisa.isEmpty
                || item.descricao.localizedCaseInsensitiveContains(pesquisa)
                || item.remetente.localizedCaseInsensitiveContains(pesquisa)
                || (item.moradorNome ?? "").localizedCaseInsensitiveContains(pesquisa)
                || (item.codigoRastreio ?? "").localizedCaseInsensitiveContains(pesquisa)
                || (item.unidade ?? "").localizedCaseInsensitiveContains(pesquisa)
                || (item.destinatarioInformado ?? "").localizedCaseInsensitiveContains(pesquisa)
            let correspondeFiltro = filtro == .todas
                || (filtro == .pendentes && !item.retirada)
                || (filtro == .retiradas && item.retirada)
                || (filtro == .semDestinatario && item.destinatarioDesconhecido)
            return correspondePesquisa && correspondeFiltro
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                campoPesquisa
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Filtro.allCases.filter { $0 != .semDestinatario || podeGerenciar }) { filtroBotao($0) }
                    }
                    .padding(.vertical, 4)
                }

                if let erro, encomendas.isEmpty {
                    EmptyStateView(icone: "wifi.exclamationmark", texto: "Não foi possível carregar as encomendas.\n\(erro)")
                    Button("Tentar de novo") { Task { await carregar() } }
                        .buttonStyle(.borderedProminent).sombraSutil()
                        .frame(maxWidth: .infinity)
                } else if jaCarregou && filtradas.isEmpty {
                    EmptyStateView(icone: "shippingbox", texto: encomendas.isEmpty ? "Nenhuma encomenda registrada." : "Nenhuma encomenda neste filtro.")
                }

                LazyVStack(spacing: 12) {
                    ForEach(filtradas) { item in
                        Button { selecionada = item } label: {
                            EncomendaCard(encomenda: item, mostrarMorador: podeGerenciar)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
        }
        .contentMargins(.bottom, 90, for: .scrollContent)
        .telaPadrao()
        .navigationTitle("Encomendas").barraMarca()
        .overlay { if carregando && !jaCarregou { ProgressView() } }
        .botaoFlutuante(visivel: podeGerenciar, rotulo: "Registrar encomenda") { cadastrando = true }
        .task { if !jaCarregou { await carregar() } }
        .refreshable { await carregar() }
        .sheet(item: $selecionada) { item in
            EncomendaDetalheView(encomenda: item, podeGerenciar: podeGerenciar) { atualizada in
                substituir(atualizada)
            }
        }
        .sheet(isPresented: $cadastrando) {
            EncomendaFormView(encomenda: nil) { nova in
                encomendas.insert(nova, at: 0)
                filtro = .todas
            }
        }
    }

    private func substituir(_ e: Encomenda) {
        if let i = encomendas.firstIndex(where: { $0.id == e.id }) { encomendas[i] = e } else { encomendas.insert(e, at: 0) }
    }

    private func carregar() async {
        carregando = true
        erro = nil
        defer { carregando = false; jaCarregou = true }
        do {
            encomendas = try await APIService.shared.encomendas()
            if let destacarId, !jaDestacou, let alvo = encomendas.first(where: { $0.id == destacarId }) {
                jaDestacou = true
                selecionada = alvo
            }
        } catch { self.erro = error.localizedDescription }
    }

    private var campoPesquisa: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppColors.textSecondary)
            TextField(podeGerenciar ? "Pesquisar por item, morador ou unidade" : "Pesquisar encomendas", text: $pesquisa)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding()
        .background(AppColors.card, in: Capsule())
        .sombraSutil()
    }

    private func filtroBotao(_ opcao: Filtro) -> some View {
        Button { filtro = opcao } label: {
            Text("\(opcao.rawValue) (\(contagem(opcao)))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(filtro == opcao ? .white : AppColors.textSecondary)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(filtro == opcao ? AppColors.accent : AppColors.card, in: Capsule())
                .sombraSutil()
        }
    }
}

struct EncomendaCard: View {
    let encomenda: Encomenda
    var mostrarMorador = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Group {
                if let foto = encomenda.foto {
                    FotoAnuncioView(base64: foto)
                } else {
                    ZStack {
                        AppColors.accent.opacity(0.12)
                        Image(systemName: "shippingbox.fill").font(.title2).foregroundStyle(AppColors.accent)
                    }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    StatusEncomendaPill(status: encomenda.statusEnum)
                    if encomenda.destinatarioDesconhecido { SemDestinatarioPill() }
                }
                Text(encomenda.descricao)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                Text("Remetente: \(encomenda.remetente)")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                if mostrarMorador {
                    Text(encomenda.destinatarioTexto)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(encomenda.destinatarioDesconhecido ? Color.orange : AppColors.textPrimary)
                    if encomenda.destinatarioDesconhecido, let etiqueta = encomenda.destinatarioInformado {
                        Text("Etiqueta: \(etiqueta)").font(.caption).foregroundStyle(AppColors.textSecondary).lineLimit(1)
                    }
                }
                if let d = DataHoraLinhas(iso: encomenda.retirada ? (encomenda.dataEntrega ?? encomenda.dataRecebimento) : encomenda.dataRecebimento,
                                          titulo: encomenda.retirada ? "Retirada" : "Cadastrada") {
                    d
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: AppTheme.raio, style: .continuous))
    }
}

struct SemDestinatarioPill: View {
    var body: some View { PilulaInfo(texto: "Sem destinatário", icone: "questionmark.circle.fill", cor: .orange) }
}

struct StatusEncomendaPill: View {
    let status: StatusEncomenda
    var body: some View {
        PilulaInfo(texto: status.titulo, icone: status.icone, cor: status == .retirada ? .green : .orange)
    }
}
