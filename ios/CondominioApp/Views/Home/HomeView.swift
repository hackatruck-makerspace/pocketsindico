import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session
    @State private var editando = false
    private let colunas = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            CabecalhoInicio(usuario: session.usuario)
            conteudo
        }
        .background(AppColors.background.ignoresSafeArea())
    }

    private var conteudo: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Favoritos").font(.title3.bold())
                    Spacer()
                    Button("Editar") { editando = true }
                }.foregroundStyle(AppColors.textPrimary)

                if session.favoritosFuncs.isEmpty {
                    EmptyStateView(icone: "star", texto: "Toque em Editar para escolher suas funções favoritas.")
                } else {
                    LazyVGrid(columns: colunas, spacing: 12) {
                        ForEach(session.favoritosFuncs) { f in
                            NavigationLink(value: f) { FeatureCard(funcionalidade: f) }.buttonStyle(.plain)
                        }
                    }
                }

                Text("Atualizações recentes").font(.title3.bold()).foregroundStyle(AppColors.textPrimary)
                if atualizacoesRecentes.isEmpty {
                    EmptyStateView(icone: "bell", texto: "Nada novo por aqui.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(atualizacoesRecentes) { a in
                            if podeAbrir(a) {
                                NavigationLink { destino(a) } label: { linhaAtualizacao(a, clicavel: true) }
                                    .buttonStyle(.plain)
                            } else {
                                linhaAtualizacao(a, clicavel: false)
                            }
                        }
                    }
                }
                if let e = session.erro { Text(e).font(.footnote).foregroundStyle(.red) }
            }.padding()
        }
        .telaPadrao()
        .barraAzulMarinho()
        .navigationDestination(for: Funcionalidade.self) { FuncionalidadeView(funcionalidade: $0) }
        .refreshable { await session.carregarTudo() }
        .sheet(isPresented: $editando) { EditarFavoritosView() }
        .overlay { if session.carregando { ProgressView() } }
        .onAppear { Task { await session.atualizarHome() } }
    }

    private var atualizacoesRecentes: [Atualizacao] {
        let porTipo = Dictionary(grouping: session.atualizacoes, by: \.tipo)
        let ultimas = porTipo.values.compactMap { grupo in grupo.max { ($0.data ?? "") < ($1.data ?? "") } }
        return ultimas.sorted { ($0.data ?? "") > ($1.data ?? "") }
    }

    private func podeAbrir(_ a: Atualizacao) -> Bool {
        switch a.tipo {
        case "encomenda": session.pode("encomendas")
        case "comunicado": session.pode("comunicados")
        default: false
        }
    }

    @ViewBuilder
    private func destino(_ a: Atualizacao) -> some View {
        if a.tipo == "encomenda" {
            EncomendasView(destacarId: a.id)
        } else if let c = session.comunicados.first(where: { $0.id == a.id }) {
            DetalheComunicadoView(c: c)
        } else {
            ComunicadosTela().telaPadrao().navigationTitle("Comunicados")
        }
    }

    private func linhaAtualizacao(_ a: Atualizacao, clicavel: Bool) -> some View {
        HStack(spacing: 12) {
            IconeBadge(simbolo: Identidade.simbolo(a.tipo == "encomenda" ? "encomendas" : "comunicados"),
                       cor: Identidade.cor(a.tipo == "encomenda" ? "encomendas" : "comunicados"), tamanho: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(a.titulo).font(.subheadline.weight(.semibold)).foregroundStyle(AppColors.textPrimary)
                if let d = a.detalhe { Text(d).font(.caption).foregroundStyle(AppColors.textSecondary).lineLimit(2) }
                if let dh = DataHoraLinhas(iso: a.data) { dh }
            }
            Spacer()
            if clicavel {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(AppColors.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .cartao()
    }
}

struct EditarFavoritosView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var ids: [String] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Na tela inicial (arraste para reordenar)") {
                    ForEach(ids, id: \.self) { id in
                        if let f = session.funcionalidades.first(where: { $0.id == id }) {
                            LinhaFuncionalidade(funcionalidade: f)
                        }
                    }
                    .onMove { ids.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { ids.remove(atOffsets: $0) }
                }
                Section("Disponíveis para o seu perfil") {
                    ForEach(session.funcionalidades.filter { !ids.contains($0.id) }) { f in
                        Button { ids.append(f.id) } label: {
                            HStack {
                                LinhaFuncionalidade(funcionalidade: f)
                                Spacer()
                                Image(systemName: "plus.circle.fill").foregroundStyle(AppColors.accent)
                            }
                        }
                    }
                }
                Section { Button("Restaurar padrão") { ids = DemoData.favPadrao[session.usuario.perfil] ?? [] } }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Editar favoritos").barraMarca()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { Task { await session.salvarFavoritos(ids); dismiss() } }
                }
            }
        }
        .onAppear { ids = session.favoritos }
    }
}
