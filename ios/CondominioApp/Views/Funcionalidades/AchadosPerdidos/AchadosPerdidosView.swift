import SwiftUI

struct AchadosPerdidosView: View {
    @Environment(AppSession.self) private var session

    enum FiltroStatus: String, CaseIterable, Identifiable {
        case todos = "Todos", perdidos = "Perdidos", recuperados = "Recuperados"
        var id: String { rawValue }
    }

    @State private var itens: [Achado] = []
    @State private var busca = ""
    @State private var categoria: String?
    @State private var filtroStatus: FiltroStatus = .todos
    @State private var umaColuna = false
    @State private var criando = false
    @State private var carregando = false
    @State private var jaCarregou = false
    @State private var erro: String?
    private let colunas = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var podeGerenciar: Bool { session.usuario.perfil != .morador }

    private var lista: [Achado] {
        itens.filter { a in
            (categoria == nil || a.categoria == categoria)
            && (filtroStatus == .todos || (filtroStatus == .perdidos) == (a.statusEnum == .perdido))
            && (busca.isEmpty || a.titulo.localizedCaseInsensitiveContains(busca) || a.descricao.localizedCaseInsensitiveContains(busca)
                || (a.local ?? "").localizedCaseInsensitiveContains(busca))
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                CampoBusca(prompt: "Pesquisar itens", texto: $busca)

                Picker("Status", selection: $filtroStatus) {
                    ForEach(FiltroStatus.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                CategoryFilter(opcoes: CategoriaAchado.allCases.map { ($0.id, $0.titulo) }, selecionada: $categoria)

                if let erro, itens.isEmpty {
                    EmptyStateView(icone: "wifi.exclamationmark", texto: "Não foi possível carregar.\n\(erro)")
                    Button("Tentar de novo") { Task { await carregar() } }.buttonStyle(.borderedProminent).sombraSutil()
                } else if jaCarregou && lista.isEmpty {
                    EmptyStateView(icone: "magnifyingglass", texto: itens.isEmpty ? "Nenhum item registrado ainda." : "Nenhum item neste filtro.")
                }

                LazyVGrid(columns: umaColuna ? [GridItem(.flexible())] : colunas, spacing: 12) {
                    ForEach(lista) { a in
                        NavigationLink(value: a) {
                            AchadoCard(achado: a, umaColuna: umaColuna)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 12)
        }
        .contentMargins(.bottom, 90, for: .scrollContent)
        .refreshable { await carregar() }
        .telaPadrao()
        .navigationTitle("Achados e perdidos").barraMarca()
        .overlay { if carregando && !jaCarregou { ProgressView() } }
        .botaoGrid(umaColuna: $umaColuna, acimaDoMais: podeGerenciar)
        .botaoFlutuante(visivel: podeGerenciar, rotulo: "Registrar item") { criando = true }
        .task { if !jaCarregou { await carregar() } }
        .navigationDestination(for: Achado.self) { a in
            AchadoDetalheView(achado: a, podeGerenciar: podeGerenciar) { substituir($0) }
        }
        .sheet(isPresented: $criando) {
            AchadoFormView(achado: nil) { novo in itens.insert(novo, at: 0) }
        }
    }

    private func substituir(_ a: Achado) {
        if let i = itens.firstIndex(where: { $0.id == a.id }) { itens[i] = a } else { itens.insert(a, at: 0) }
    }

    private func carregar() async {
        carregando = true
        erro = nil
        defer { carregando = false; jaCarregou = true }
        do { itens = try await APIService.shared.achados() }
        catch { self.erro = error.localizedDescription }
    }
}

struct AchadoCard: View {
    let achado: Achado
    let umaColuna: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let f = achado.foto {
                    FotoAnuncioView(base64: f)
                } else {
                    ZStack {
                        achado.categoriaEnum.cor.opacity(0.14)
                        Image(systemName: achado.categoriaEnum.icone).font(.title2).foregroundStyle(achado.categoriaEnum.cor)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: umaColuna ? 145 : 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            PilulaInfo(texto: achado.categoriaEnum.titulo, icone: achado.categoriaEnum.icone, cor: achado.categoriaEnum.cor)

            Text(achado.titulo)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(umaColuna ? 2 : 1)

            if umaColuna, let local = achado.local {
                Label(local, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            StatusAchadoPill(status: achado.statusEnum)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .cartao()
    }
}

struct StatusAchadoPill: View {
    let status: StatusAchado
    var body: some View { PilulaInfo(texto: status.tituloCurto, icone: status.icone, cor: status.cor) }
}
