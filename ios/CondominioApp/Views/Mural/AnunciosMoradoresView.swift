import SwiftUI
import PhotosUI
import UIKit

struct AnunciosMoradoresView: View {
    @Environment(AppSession.self) private var session
    @State private var busca = ""
    @State private var categoria: String?
    @State private var quantidadeVisivel = 6
    let umaColuna: Bool
    let categoriaFixa: String?
    private let colunas = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(umaColuna: Bool = false, categoriaFixa: String? = nil) {
        self.umaColuna = umaColuna
        self.categoriaFixa = categoriaFixa
        _categoria = State(initialValue: categoriaFixa)
    }

    private var lista: [Anuncio] {
        session.anuncios.filter { !$0.encerrado && $0.categoria != "perdidos" && (categoria == nil || $0.categoria == categoria) &&
            (busca.isEmpty || $0.titulo.localizedCaseInsensitiveContains(busca)) }
            .sorted {
                if $0.totalFavoritos != $1.totalFavoritos { return $0.totalFavoritos > $1.totalFavoritos }
                return ($0.criadoEm ?? "") > ($1.criadoEm ?? "")
            }
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                CampoBusca(prompt: "Pesquisar anúncios", texto: $busca)
                if categoriaFixa == nil {
                    CategoryFilter(opcoes: CategoriaAnuncio.allCases.map { ($0.id, $0.titulo) }, selecionada: $categoria)
                }
                if lista.isEmpty { EmptyStateView(icone: "tag", texto: "Nenhum anúncio por aqui ainda.") }
                LazyVGrid(columns: umaColuna ? [GridItem(.flexible())] : colunas, spacing: 12) {
                    ForEach(Array(lista.prefix(quantidadeVisivel))) { a in
                        NavigationLink { DetalheAnuncioView(anuncioId: a.id) } label: {
                            AnnouncementCard(a: a, umaColuna: umaColuna)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                if quantidadeVisivel < lista.count {
                    ProgressView()
                        .padding(.vertical, 8)
                        .onAppear {
                            carregarMais()
                        }
                }
            }
            .padding(.top, 12)
        }
        .refreshable { await Task { await session.atualizarMural(silencioso: false) }.value }
        .onChange(of: busca) {
            quantidadeVisivel = 6
        }
        .onChange(of: categoria) {
            quantidadeVisivel = 6
        }
        .contentMargins(.bottom, 90, for: .scrollContent)
    }

    private func carregarMais() {
        guard quantidadeVisivel < lista.count else { return }
        quantidadeVisivel = min(quantidadeVisivel + 6, lista.count)
    }
}

struct DetalheAnuncioView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let anuncioId: String
    @State private var editando = false
    @State private var acao: AcaoAnuncio?
    @State private var erro: String?
    @State private var ultimo: Anuncio?

    private var atual: Anuncio? {
        session.anuncios.first { $0.id == anuncioId } ?? session.meusAnuncios.first { $0.id == anuncioId }
    }

    private var a: Anuncio? { atual ?? ultimo }

    private func ehDono(_ a: Anuncio) -> Bool {
        a.anuncianteId == session.usuario.id
    }

    private var podeExcluirQualquerAnuncio: Bool {
        session.usuario.perfil == .sindico
    }

    var body: some View {
        if let a {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !a.fotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(a.fotos.enumerated()), id: \.offset) { _, foto in
                                    FotoAnuncioView(base64: foto)
                                        .frame(width: 300, height: 210)
                                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.raio))
                                }
                            }
                        }
                    }

                    CategoriaAnuncioPill(categoria: a.categoria)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(a.titulo)
                            .font(.title2.bold())
                            .foregroundStyle(AppColors.textPrimary)

                        if a.encerrado {
                            StatusPill(texto: "Encerrado")
                        }
                    }

                    if let preco = a.preco, !preco.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(preco)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppColors.accent)
                    }

                    Text(a.descricao)
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Anunciante: \(a.anuncianteNome)\(a.bloco.map { " · Bloco \($0)" } ?? "")\(a.apartamento.map { " · Apto \($0)" } ?? "")")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)

                    AnuncioDataView(criadoEm: a.criadoEm, atualizadoEm: a.atualizadoEm)

                    if a.encerrado {
                        Text("Este anúncio foi encerrado e não aparece mais no Mural.")
                            .font(.footnote)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        HStack {
                            Button {
                                Task {
                                    do {
                                        try await session.alternarFavorito(anuncio: a)
                                    } catch {
                                        erro = "Não foi possível favoritar. \(error.localizedDescription)"
                                    }
                                }
                            } label: {
                                Label("\(a.totalFavoritos)", systemImage: a.favoritado ? "heart.fill" : "heart")
                            }
                            .tint(a.favoritado ? .red : AppColors.accent)

                            Spacer()
                        }
                        .buttonStyle(.bordered).sombraSutil()
                    }

                    NavigationLink {
                        ComentariosAnuncioView(anuncioId: a.id)
                    } label: {
                        HStack {
                            Label("Comentários", systemImage: "bubble.left")
                            Spacer()
                            Text("\(a.totalComentarios)")
                                .foregroundStyle(AppColors.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .telaPadrao()
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if let atual { ultimo = atual }
            }
            .onAppear {
                if let atual { ultimo = atual }
            }
            .onChange(of: atual) { _, nova in
                if let nova { ultimo = nova }
            }
            .toolbar {
                if ehDono(a) || podeExcluirQualquerAnuncio {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            if ehDono(a) {
                                Button {
                                    editando = true
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }

                                if a.encerrado {
                                    Button {
                                        acao = .reativar(a)
                                    } label: {
                                        Label("Reativar anúncio", systemImage: "arrow.clockwise.circle")
                                    }
                                } else {
                                    Button {
                                        acao = .encerrar(a)
                                    } label: {
                                        Label("Encerrar anúncio", systemImage: "checkmark.circle")
                                    }
                                }
                            }

                            if podeExcluirQualquerAnuncio && !ehDono(a) && !a.encerrado {
                                Button {
                                    acao = .encerrar(a)
                                } label: {
                                    Label("Encerrar anúncio", systemImage: "checkmark.circle")
                                }
                            }

                            if ehDono(a) || podeExcluirQualquerAnuncio {
                                Button(role: .destructive) {
                                    acao = .excluir(a)
                                } label: {
                                    Label("Excluir anúncio", systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $editando) {
                FormularioAnuncioView(anuncio: a)
            }
            .confirmarAcoesAnuncio(acao: $acao, erro: $erro) {
                dismiss()
            }
        }
    }
}

struct AnuncioDataView: View {
    let criadoEm: String?
    let atualizadoEm: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let criadoEm {
                Text("Publicado em \(formatarData(criadoEm))")
            }

            if let atualizadoEm, atualizadoEm != criadoEm {
                Text("Editado em \(formatarData(atualizadoEm))")
            }
        }
        .font(.caption)
        .foregroundStyle(AppColors.textSecondary)
    }

    private func formatarData(_ valor: String) -> String {
        guard !valor.isEmpty else { return "agora" }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let date = iso.date(from: valor) ?? ISO8601DateFormatter().date(from: valor)
        guard let date else { return valor }

        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return f.string(from: date)
    }
}

struct ComentariosAnuncioView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let anuncioId: String

    @State private var comentarios: [Comentario] = []
    @State private var novo = ""
    @State private var fotoNova: String?
    @State private var fotoSelecionada: PhotosPickerItem?
    @State private var editando: Comentario?
    @State private var apagando: Comentario?
    @State private var erro: String?
    @State private var carregando = false
    @State private var enviando = false
    private let limiteComentario = 500

    private var anuncio: Anuncio? {
        session.anuncios.first { $0.id == anuncioId } ?? session.meusAnuncios.first { $0.id == anuncioId }
    }

    private func podeExcluir(_ comentario: Comentario) -> Bool {
        comentario.autorId == session.usuario.id ||
        session.usuario.perfil == .sindico
    }

    private var podeEnviar: Bool {
        !enviando && !novo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Group {
            if carregando && comentarios.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if comentarios.isEmpty {
                EmptyStateView(icone: "bubble.left.and.bubble.right", texto: "Nenhum comentário ainda.\nSeja o primeiro a comentar.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(comentarios) { comentario in
                            ComentarioCardView(
                                comentario: comentario,
                                podeEditar: comentario.autorId == session.usuario.id,
                                podeExcluir: podeExcluir(comentario),
                                editar: { editando = comentario },
                                excluir: { apagando = comentario }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { composer }
        .telaPadrao()
        .navigationTitle("Comentários")
        .navigationBarTitleDisplayMode(.inline)
        .task { await carregar() }
        .refreshable { await carregar() }
        .sheet(item: $editando) { comentario in
            EditarComentarioView(anuncioId: anuncioId, comentario: comentario) {
                await carregar()
            }
        }
        .confirmationDialog(
            "Excluir comentário?",
            isPresented: Binding(
                get: { apagando != nil },
                set: { if !$0 { apagando = nil } }
            ),
            presenting: apagando
        ) { comentario in
            Button("Excluir", role: .destructive) {
                Task { await excluir(comentario) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { _ in
            Text("O comentário será removido.")
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

    private var composer: some View {
        VStack(spacing: 10) {
            if let fotoNova {
                HStack(spacing: 12) {
                    FotoAnuncioView(base64: fotoNova)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("Imagem anexada")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    Spacer()
                    Button {
                        self.fotoNova = nil
                        fotoSelecionada = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .accessibilityLabel("Remover imagem")
                }
            }

            HStack(alignment: .center, spacing: 10) {
                PhotosPicker(selection: $fotoSelecionada, matching: .images) {
                    Image(systemName: fotoNova == nil ? "photo" : "photo.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 40, height: 40)
                        .background(AppColors.accent.opacity(0.12), in: Circle())
                        .sombraSutil()
                }
                .accessibilityLabel("Anexar imagem")

                TextField("Escreva um comentário", text: $novo, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(minHeight: 40)
                    .background(AppColors.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(AppColors.textSecondary.opacity(0.25), lineWidth: 1)
                    }

                Button {
                    enviar()
                } label: {
                    Group {
                        if enviando {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(podeEnviar ? AppColors.accent : Color.gray.opacity(0.4), in: Circle())
                    .sombraSutil()
                }
                .disabled(!podeEnviar)
                .accessibilityLabel("Enviar comentário")
            }

            if novo.utf16.count >= limiteComentario - 50 {
                Text("\(novo.utf16.count)/\(limiteComentario)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(AppColors.card.shadow(.drop(color: .black.opacity(0.08), radius: 6, y: -2)))
        .onChange(of: novo) { _, valor in
            if valor.utf16.count > limiteComentario {
                novo = String(valor.prefix(limiteComentario))
            }
        }
        .onChange(of: fotoSelecionada) { _, item in
            guard let item else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        if let b64 = await ImagemUtil.base64Async(de: data, limiteCaracteres: ImagemUtil.limiteDocumento) {
                            fotoNova = b64
                        } else {
                            erro = "Não foi possível reduzir essa imagem para até 1 MB. Tente outra."
                        }
                    }
                } catch {
                    erro = "Não foi possível carregar a imagem."
                }
            }
        }
    }

    private func carregar() async {
        carregando = true
        defer { carregando = false }
        do {
            comentarios = try await APIService.shared.comentarios(anuncioId: anuncioId)
        } catch {
            erro = "Não foi possível carregar os comentários. \(error.localizedDescription)"
        }
    }

    private func enviar() {
        guard let anuncio,
              !enviando else { return }

        let texto = novo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !texto.isEmpty, texto.utf16.count <= limiteComentario else { return }

        enviando = true
        let foto = fotoNova
        let provisoria = Comentario(
            id: UUID().uuidString,
            autorId: session.usuario.id,
            autorNome: session.usuario.nome,
            texto: texto,
            criadoEm: ISO8601DateFormatter().string(from: Date()),
            foto: foto
        )
        comentarios.append(provisoria)
        novo = ""
        fotoNova = nil
        fotoSelecionada = nil

        Task {
            do {
                try await session.comentar(texto, foto: foto, em: anuncio)
                await carregar()
            } catch {
                comentarios.removeAll { $0.id == provisoria.id }
                novo = texto
                fotoNova = foto
                erro = "Não foi possível enviar o comentário. \(error.localizedDescription)"
            }
            enviando = false
        }
    }

    private func excluir(_ comentario: Comentario) async {
        guard let anuncio else { return }
        do {
            try await session.excluirComentario(comentario, em: anuncio)
            comentarios.removeAll { $0.id == comentario.id }
            apagando = nil
        } catch {
            erro = error.localizedDescription
        }
    }
}

struct ComentarioCardView: View {
    let comentario: Comentario
    let podeEditar: Bool
    let podeExcluir: Bool
    let editar: () -> Void
    let excluir: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColors.accent)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(comentario.autorNome)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    if podeEditar || podeExcluir {
                        Menu {
                            if podeEditar {
                                Button("Editar", action: editar)
                            }
                            if podeExcluir {
                                Button("Excluir", role: .destructive, action: excluir)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                }

                Text(comentario.texto)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                if let foto = comentario.foto, !foto.isEmpty {
                    FotoAnuncioView(base64: foto)
                        .frame(width: 180, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Text(textoData)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
    }

    private var textoData: String {
        let data = comentario.editado ? (comentario.atualizadoEm ?? comentario.criadoEm) : comentario.criadoEm
        let texto = formatarData(data)
        return comentario.editado ? "\(texto) · editado" : texto
    }

    private func formatarData(_ valor: String) -> String {
        guard !valor.isEmpty else { return "agora" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: valor) ?? ISO8601DateFormatter().date(from: valor)
        guard let date else { return valor }
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return f.string(from: date)
    }
}

struct EditarComentarioView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let anuncioId: String
    let comentario: Comentario
    let recarregar: () async -> Void

    @State private var texto: String
    @State private var foto: String?
    @State private var item: PhotosPickerItem?
    @State private var erro: String?
    @State private var salvando = false

    init(anuncioId: String, comentario: Comentario, recarregar: @escaping () async -> Void) {
        self.anuncioId = anuncioId
        self.comentario = comentario
        self.recarregar = recarregar
        _texto = State(initialValue: comentario.texto)
        _foto = State(initialValue: comentario.foto)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Comentário") {
                    TextField("Comentário", text: $texto, axis: .vertical)
                        .lineLimit(3...8)

                    if let foto {
                        VStack(alignment: .leading, spacing: 6) {
                            FotoAnuncioView(base64: foto)
                                .frame(width: 180, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button("Remover imagem") {
                                self.foto = nil
                            }
                        }
                    }

                    PhotosPicker(selection: $item, matching: .images) {
                        Label(foto == nil ? "Adicionar imagem" : "Trocar imagem", systemImage: "photo")
                    }
                    .onChange(of: item) { _, novoItem in
                        guard let novoItem else { return }
                        Task {
                            do {
                                if let data = try await novoItem.loadTransferable(type: Data.self) {
                                    if let b64 = await ImagemUtil.base64Async(de: data, limiteCaracteres: ImagemUtil.limiteDocumento) {
                                        foto = b64
                                    } else {
                                        erro = "Não foi possível reduzir essa imagem para até 1 MB. Tente outra."
                                    }
                                }
                            } catch {
                                erro = "Não foi possível carregar a imagem."
                            }
                        }
                    }
                }

                if let erro {
                    Text(erro).foregroundStyle(.red)
                }
            }
            .navigationTitle("Editar comentário")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        salvando = true

                        Task {
                            do {
                                guard let anuncio = session.anuncios.first(where: { $0.id == anuncioId }) ??
                                      session.meusAnuncios.first(where: { $0.id == anuncioId }) else {
                                    throw APIError.http(404, "Anúncio não encontrado")
                                }
                                try await session.editarComentario(comentario, em: anuncio, texto: t, foto: foto)
                                await recarregar()
                                dismiss()
                            } catch {
                                erro = error.localizedDescription
                            }
                            salvando = false
                        }
                    }
                    .disabled(salvando || texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

enum ModoPreco: String, CaseIterable, Identifiable {
    case preco
    case combinar
    case semPreco

    var id: String { rawValue }
    var titulo: String {
        switch self {
        case .preco: return "Preço"
        case .combinar: return "A combinar"
        case .semPreco: return "Sem preço"
        }
    }
}

struct FormularioAnuncioView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let anuncio: Anuncio?
    @State private var titulo: String
    @State private var descricao: String
    @State private var preco: String
    @State private var modoPreco: ModoPreco
    @State private var categoria: CategoriaAnuncio
    @State private var fotos: [String]
    @State private var selecionadas: [PhotosPickerItem] = []
    @State private var erro: String?
    @State private var enviando = false

    init(anuncio: Anuncio?, categoriaInicial: CategoriaAnuncio = .venda) {
        self.anuncio = anuncio
        _titulo = State(initialValue: anuncio?.titulo ?? "")
        _descricao = State(initialValue: anuncio?.descricao ?? "")
        _preco = State(initialValue: PrecoMascara.normalizar(anuncio?.preco))
        _modoPreco = State(initialValue: {
            if anuncio == nil { return .combinar }
            let valor = anuncio?.preco?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
            if valor == "a combinar" { return .combinar }
            if valor.isEmpty || valor == "sem preço" { return .semPreco }
            return .preco
        }())
        _categoria = State(initialValue: anuncio.flatMap { CategoriaAnuncio(rawValue: $0.categoria) } ?? categoriaInicial)
        _fotos = State(initialValue: anuncio?.fotos ?? [])
    }

    private var invalido: Bool {
        titulo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || descricao.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Imagem") {
                    if !fotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(fotos.enumerated()), id: \.offset) { indice, foto in
                                    ZStack(alignment: .topTrailing) {
                                        FotoAnuncioView(base64: foto)
                                            .frame(width: 130, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        Button { fotos.remove(at: indice) } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, Color.black.opacity(0.65))
                                        }.padding(4)
                                    }
                                }
                            }
                        }
                    }

                    PhotosPicker(selection: $selecionadas, maxSelectionCount: 3, matching: .images) {
                        Label(fotos.isEmpty ? "Escolher imagem da galeria" : "Trocar imagens", systemImage: "photo.on.rectangle")
                    }
                    Text("Você pode selecionar até 3 imagens.")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Section("Dados do anúncio") {
                    TextField("Título", text: $titulo)
                    Picker("Categoria", selection: $categoria) {
                        ForEach(CategoriaAnuncio.allCases) { Text($0.titulo).tag($0) }
                    }
                    Picker("Preço", selection: $modoPreco) {
                        ForEach(ModoPreco.allCases) { modo in
                            Text(modo.titulo).tag(modo)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: modoPreco) { _, novo in
                        if novo != .preco { preco = "" }
                    }

                    if modoPreco == .preco {
                        CampoPreco(preco: $preco)
                    } else if modoPreco == .combinar {
                        Text("A combinar")
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    TextField("Descrição", text: $descricao, axis: .vertical).lineLimit(4...8)
                }

                if let erro { Text(erro).foregroundStyle(.red) }
            }
            .navigationTitle(anuncio == nil ? "Novo anúncio" : "Editar anúncio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(anuncio == nil ? "Publicar" : "Salvar") { enviar() }
                        .disabled(invalido || enviando)
                }
            }
            .interactiveDismissDisabled(enviando)
            .onChange(of: selecionadas) { _, novos in
                Task { await carregarFotos(novos) }
            }
        }
    }

    private func carregarFotos(_ itens: [PhotosPickerItem]) async {
        guard !itens.isEmpty else { return }
        let escolhidas = Array(itens.prefix(3))
        let porFoto = ImagemUtil.limiteFotosAnuncio / escolhidas.count
        var novas: [String] = []
        for item in escolhidas {
            if let data = try? await item.loadTransferable(type: Data.self),
               let b64 = await ImagemUtil.base64Async(de: data, limiteCaracteres: porFoto) {
                novas.append(b64)
            }
        }
        if novas.isEmpty {
            erro = "Não foi possível usar essas imagens. Tente outras."
        } else {
            fotos = novas
            if novas.count < escolhidas.count { erro = "Algumas imagens não puderam ser usadas e foram ignoradas." }
        }
        selecionadas = []
    }

    private func enviar() {
        enviando = true
        erro = nil
        Task {
            do {
                if let anuncio {
                    try await session.editarAnuncio(anuncio, titulo: titulo, descricao: descricao, categoria: categoria.rawValue, preco: modoPreco == .combinar ? "A combinar" : (modoPreco == .semPreco ? "" : preco), fotos: fotos)
                } else {
                    try await session.criarAnuncio(titulo: titulo, descricao: descricao, categoria: categoria.rawValue, preco: modoPreco == .combinar ? "A combinar" : (modoPreco == .semPreco ? "" : preco), fotos: fotos)
                }
                dismiss()
            } catch {
                erro = error.localizedDescription
                enviando = false
            }
        }
    }
}

struct MeusAnunciosView: View {
    @Environment(AppSession.self) private var session
    @State private var criando = false
    @State private var editar: Anuncio?
    @State private var acao: AcaoAnuncio?
    @State private var erro: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if session.meusAnuncios.isEmpty {
                    EmptyStateView(icone: "tag", texto: "Você ainda não publicou anúncios.\nToque em + para criar o primeiro.")
                }
                ForEach(session.meusAnuncios) { a in linha(a) }
            }.padding(.horizontal)
        }
        .contentMargins(.bottom, 90, for: .scrollContent)
        .telaPadrao().navigationTitle("Meus anúncios")
        .refreshable { await session.carregarMeusAnuncios() }
        .task { await session.carregarMeusAnuncios() }
        .alert("Não foi possível carregar seus anúncios", isPresented: Binding(get: { session.erro != nil }, set: { if !$0 { session.erro = nil } })) {
            Button("OK", role: .cancel) { session.erro = nil }
        } message: {
            Text(session.erro ?? "")
        }
        .botaoFlutuante(rotulo: "Novo anúncio") { criando = true }
        .sheet(isPresented: $criando) { FormularioAnuncioView(anuncio: nil) }
        .sheet(item: $editar) { FormularioAnuncioView(anuncio: $0) }
        .confirmarAcoesAnuncio(acao: $acao, erro: $erro)
    }

    private func linha(_ a: Anuncio) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink { DetalheAnuncioView(anuncioId: a.id) } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            CategoriaAnuncioPill(categoria: a.categoria)
                            if a.encerrado { StatusPill(texto: "Encerrado") }
                        }
                        Text(a.titulo).font(.headline).foregroundStyle(AppColors.textPrimary).lineLimit(1)
                        if let preco = a.preco, !preco.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(preco).font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        HStack(spacing: 14) {
                            Label("\(a.totalFavoritos)", systemImage: "heart")
                            Label("\(a.totalComentarios)", systemImage: "bubble.left")
                        }.font(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote).foregroundStyle(AppColors.textSecondary)
                }
            }.buttonStyle(.plain)

            Divider()
            HStack(spacing: 8) {
                Button { editar = a } label: {
                    Label("Editar", systemImage: "pencil").frame(maxWidth: .infinity)
                }

                if a.encerrado {
                    Button { acao = .reativar(a) } label: {
                        Label("Reativar", systemImage: "arrow.clockwise.circle").frame(maxWidth: .infinity)
                    }
                } else {
                    Button { acao = .encerrar(a) } label: {
                        Label("Encerrar", systemImage: "checkmark.circle").frame(maxWidth: .infinity)
                    }
                }

                Button(role: .destructive) { acao = .excluir(a) } label: {
                    Label("Excluir", systemImage: "trash").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered).sombraSutil().font(.footnote.weight(.medium))
        }.cartao()
    }
}
