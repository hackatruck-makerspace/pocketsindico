import SwiftUI

struct MuralView: View {
    enum Secao: String, CaseIterable { case comunicados = "Comunicados", anuncios = "Anúncios" }
    @Environment(AppSession.self) private var session
    @State private var secao: Secao = .comunicados
    @State private var criandoComunicado = false
    @State private var criandoAnuncio = false
    @State private var comunicadosUmaColuna = true
    @State private var anunciosUmaColuna = false

    private var podeCriar: Bool {
        secao == .comunicados ? session.usuario.perfil == .sindico : session.pode("meus_anuncios")
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker("Seção", selection: $secao) { ForEach(Secao.allCases, id: \.self) { Text($0.rawValue) } }
                .pickerStyle(.segmented).padding(.horizontal)
            switch secao {
            case .comunicados: ComunicadosView(umaColuna: comunicadosUmaColuna)
            case .anuncios: AnunciosMoradoresView(umaColuna: anunciosUmaColuna)
            }
        }
        .telaPadrao().navigationTitle("Mural")
        .atualizacaoAutomatica()
        .toolbar {
            if secao == .anuncios && session.pode("meus_anuncios") {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink { MeusAnunciosView() } label: { Label("Meus anúncios", systemImage: "tag") }
                }
            }
        }
        .botaoGrid(umaColuna: secao == .comunicados ? $comunicadosUmaColuna : $anunciosUmaColuna, acimaDoMais: podeCriar)
        .botaoFlutuante(visivel: podeCriar, rotulo: secao == .comunicados ? "Novo comunicado" : "Novo anúncio") {
            if secao == .comunicados { criandoComunicado = true } else { criandoAnuncio = true }
        }
        .sheet(isPresented: $criandoComunicado) { CriarComunicadoView() }
        .sheet(isPresented: $criandoAnuncio) { FormularioAnuncioView(anuncio: nil) }
    }
}

struct ComunicadosTela: View {
    @Environment(AppSession.self) private var session
    @State private var criando = false
    @State private var umaColuna = true
    var body: some View {
        ComunicadosView(umaColuna: umaColuna)
            .atualizacaoAutomatica()
            .botaoGrid(umaColuna: $umaColuna, acimaDoMais: session.usuario.perfil == .sindico)
            .botaoFlutuante(visivel: session.usuario.perfil == .sindico, rotulo: "Novo comunicado") { criando = true }
            .sheet(isPresented: $criando) { CriarComunicadoView() }
    }
}

struct ComunicadosView: View {
    @Environment(AppSession.self) private var session
    @State private var busca = ""
    @State private var categoria: String?
    let umaColuna: Bool
    private let colunas = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(umaColuna: Bool = true) { self.umaColuna = umaColuna }

    private var lista: [Comunicado] {
        session.comunicados.filter { (categoria == nil || $0.categoria == categoria) &&
            (busca.isEmpty || $0.titulo.localizedCaseInsensitiveContains(busca)) }
            .sorted(by: Comunicado.maisRecentePrimeiro)
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                CampoBusca(prompt: "Pesquisar comunicados", texto: $busca)
                CategoryFilter(opcoes: CategoriaComunicado.allCases.map { ($0.id, $0.titulo) }, selecionada: $categoria)
                if lista.isEmpty { EmptyStateView(icone: "megaphone", texto: "Nenhum comunicado encontrado.") }
                LazyVGrid(columns: umaColuna ? [GridItem(.flexible())] : colunas, spacing: 12) {
                    ForEach(lista) { c in
                        NavigationLink { DetalheComunicadoView(c: c) } label: { ComunicadoCard(c: c, umaColuna: umaColuna) }
                            .buttonStyle(.plain)
                    }
                }.padding(.horizontal)
            }
            .padding(.top, 12)
        }
        .refreshable { await Task { await session.atualizarMural(silencioso: false) }.value }
        .contentMargins(.bottom, 90, for: .scrollContent)
    }
}

struct DetalheComunicadoView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let c: Comunicado

    @State private var editando = false
    @State private var excluindo = false
    @State private var erro: String?

    private var ehAutor: Bool {
        c.autorId == session.usuario.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CategoriaComunicadoPill(categoria: c.categoria)

                Text(c.titulo)
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.textPrimary)

                Text("\(c.autorNome) · \(c.dataExibicao)")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)

                Text(c.descricao)
                    .foregroundStyle(AppColors.textPrimary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .telaPadrao()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if session.usuario.perfil == .sindico && ehAutor {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            editando = true
                        } label: {
                            Label("Editar comunicado", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            excluindo = true
                        } label: {
                            Label("Excluir comunicado", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $editando) {
            EditarComunicadoView(comunicado: c)
        }
        .confirmationDialog(
            "Excluir comunicado?",
            isPresented: $excluindo,
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive) {
                Task {
                    do {
                        try await session.excluirComunicado(c)
                        dismiss()
                    } catch {
                        erro = error.localizedDescription
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Este comunicado será removido do Mural.")
        }
        .alert("Não foi possível concluir", isPresented: Binding(
            get: { erro != nil },
            set: { if !$0 { erro = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(erro ?? "")
        }
    }
}

struct CriarComunicadoView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var titulo = ""
    @State private var descricao = ""
    @State private var categoria = CategoriaComunicado.avisos
    @State private var erro: String?
    @State private var enviando = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Comunicado") {
                    TextField("Título", text: $titulo)

                    Picker("Categoria", selection: $categoria) {
                        ForEach(CategoriaComunicado.allCases) {
                            Text($0.titulo).tag($0)
                        }
                    }

                    TextField("Descrição", text: $descricao, axis: .vertical)
                        .lineLimit(5...10)
                }

                if let erro {
                    Text(erro).foregroundStyle(.red)
                }
            }
            .navigationTitle("Novo comunicado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(enviando)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Publicar") { publicar() }
                        .disabled(titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  descricao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  enviando)
                }
            }
            .interactiveDismissDisabled(enviando)
        }
    }

    private func publicar() {
        enviando = true
        erro = nil

        Task {
            do {
                try await APIService.shared.publicarComunicado(
                    titulo: titulo,
                    descricao: descricao,
                    categoria: categoria.rawValue
                )
                await session.carregarTudo()
                dismiss()
            } catch {
                erro = error.localizedDescription
                enviando = false
            }
        }
    }
}

struct EditarComunicadoView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    let comunicado: Comunicado

    @State private var titulo: String
    @State private var descricao: String
    @State private var categoria: CategoriaComunicado
    @State private var erro: String?
    @State private var salvando = false

    init(comunicado: Comunicado) {
        self.comunicado = comunicado
        _titulo = State(initialValue: comunicado.titulo)
        _descricao = State(initialValue: comunicado.descricao)
        _categoria = State(initialValue: CategoriaComunicado(rawValue: comunicado.categoria) ?? .avisos)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Comunicado") {
                    TextField("Título", text: $titulo)

                    Picker("Categoria", selection: $categoria) {
                        ForEach(CategoriaComunicado.allCases) {
                            Text($0.titulo).tag($0)
                        }
                    }

                    TextField("Descrição", text: $descricao, axis: .vertical)
                        .lineLimit(5...10)
                }

                if let erro {
                    Text(erro).foregroundStyle(.red)
                }
            }
            .navigationTitle("Editar comunicado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .disabled(salvando)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { salvar() }
                        .disabled(titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  descricao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  salvando)
                }
            }
            .interactiveDismissDisabled(salvando)
        }
    }

    private func salvar() {
        salvando = true
        erro = nil

        Task {
            do {
                try await session.editarComunicado(
                    comunicado,
                    titulo: titulo,
                    descricao: descricao,
                    categoria: categoria.rawValue
                )
                dismiss()
            } catch {
                erro = error.localizedDescription
                salvando = false
            }
        }
    }
}
