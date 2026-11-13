import SwiftUI

@MainActor
@Observable
final class AppSession {
    var usuario: Usuario = DemoData.perfis[0]
    let alertas = AlertaViewModel()
    var funcionalidades: [Funcionalidade] = []
    var favoritos: [String] = []
    var atualizacoes: [Atualizacao] = []
    var comunicados: [Comunicado] = []
    var anuncios: [Anuncio] = []
    var meusAnuncios: [Anuncio] = []
    var carregando = false
    var erro: String?
    var avisoMural: String?
    private var atualizando = false
    private var favoritando: Set<String> = []

    var favoritosFuncs: [Funcionalidade] { favoritos.compactMap { id in funcionalidades.first { $0.id == id } } }
    func pode(_ f: String) -> Bool { funcionalidades.contains { $0.id == f } }

    func carregarTudo() async {
        carregando = true; erro = nil
        APIService.shared.usuarioId = usuario.id
        APIService.shared.usuarioPerfil = usuario.perfil.rawValue
        do {
            let home = try await APIService.shared.home(usuario: usuario)
            usuario = home.usuario; funcionalidades = home.funcionalidades
            favoritos = home.ordem.isEmpty ? home.favoritos : home.ordem
            atualizacoes = home.atualizacoes
            comunicados = try await APIService.shared.comunicados()
            anuncios = try await APIService.shared.anuncios()
            await carregarMeusAnuncios()
        } catch { self.erro = error.localizedDescription }
        carregando = false
    }

    func atualizarHome() async {
        guard !carregando, let home = try? await APIService.shared.home(usuario: usuario) else { return }
        funcionalidades = home.funcionalidades
        atualizacoes = home.atualizacoes
    }

    func trocarPerfil(_ novo: Usuario) async {
        guard !alertas.ocupado else { return }
        usuario = novo
        alertas.atualizar(usuario: novo)
        await carregarTudo()
    }

    func salvarFavoritos(_ ids: [String]) async {
        let validos = ids.filter { pode($0) }
        favoritos = validos
        do { try await APIService.shared.salvarFavoritos(validos) } catch { erro = error.localizedDescription }
    }

    private func mutar(_ id: String, _ mudanca: (inout Anuncio) -> Void) {
        if let i = anuncios.firstIndex(where: { $0.id == id }) { mudanca(&anuncios[i]) }
        if let i = meusAnuncios.firstIndex(where: { $0.id == id }) { mudanca(&meusAnuncios[i]) }
    }

    func alternarFavorito(anuncio: Anuncio) async throws {
        guard !favoritando.contains(anuncio.id),
              let atual = (anuncios + meusAnuncios).first(where: { $0.id == anuncio.id }) else { return }
        favoritando.insert(anuncio.id)
        defer { favoritando.remove(anuncio.id) }
        let (favAntes, totalAntes) = (atual.favoritado, atual.totalFavoritos)
        let novoFav = !favAntes
        mutar(anuncio.id) { $0.favoritado = novoFav; $0.totalFavoritos = max(0, totalAntes + (novoFav ? 1 : -1)) }
        do {
            if let r = try await APIService.shared.alternarFavorito(anuncioId: anuncio.id) {
                mutar(anuncio.id) { $0.favoritado = r.favoritado; $0.totalFavoritos = r.totalFavoritos }
            }
        } catch {
            mutar(anuncio.id) { $0.favoritado = favAntes; $0.totalFavoritos = totalAntes }
            throw error
        }
    }

    func atualizarMural(silencioso: Bool = true) async {
        guard !atualizando, favoritando.isEmpty else { return }
        atualizando = true
        defer { atualizando = false }
        do {
            let novosComunicados = try await APIService.shared.comunicados()
            let novosAnuncios = try await APIService.shared.anuncios()
            comunicados = novosComunicados
            anuncios = novosAnuncios
            if pode("meus_anuncios"), let meus = try? await APIService.shared.meusAnuncios() { meusAnuncios = meus }
        } catch {
            if !silencioso { avisoMural = "Verifique a conexão e tente de novo. (\(error.localizedDescription))" }
        }
    }

    func editarComunicado(_ comunicado: Comunicado, titulo: String, descricao: String, categoria: String) async throws {
        try await APIService.shared.editarComunicado(id: comunicado.id, titulo: titulo, descricao: descricao, categoria: categoria)
        if let i = comunicados.firstIndex(where: { $0.id == comunicado.id }) {
            comunicados[i].titulo = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
            comunicados[i].descricao = descricao.trimmingCharacters(in: .whitespacesAndNewlines)
            comunicados[i].categoria = categoria
        }
    }

    func excluirComunicado(_ comunicado: Comunicado) async throws {
        try await APIService.shared.excluirComunicado(id: comunicado.id)
        comunicados.removeAll { $0.id == comunicado.id }
    }

    func carregarMeusAnuncios() async {
        guard pode("meus_anuncios") else { meusAnuncios = []; return }
        do {
            meusAnuncios = try await APIService.shared.meusAnuncios()
        } catch {
            meusAnuncios = anuncios.filter { $0.anuncianteId == usuario.id }
            if meusAnuncios.isEmpty { erro = error.localizedDescription }
        }
    }
    private func recarregarAnuncios() async {
        if let a = try? await APIService.shared.anuncios() { anuncios = a }
        await carregarMeusAnuncios()
    }
    func criarAnuncio(titulo: String, descricao: String, categoria: String, preco: String, fotos: [String]) async throws {
        try await APIService.shared.criarAnuncio(titulo: titulo, descricao: descricao, categoria: categoria, preco: preco, fotos: fotos)
        await recarregarAnuncios()
    }
    func editarAnuncio(_ a: Anuncio, titulo: String, descricao: String, categoria: String, preco: String, fotos: [String]) async throws {
        try await APIService.shared.editarAnuncio(id: a.id, titulo: titulo, descricao: descricao, categoria: categoria, preco: preco, fotos: fotos)
        await recarregarAnuncios()
    }
    func encerrarAnuncio(_ a: Anuncio) async throws {
        try await APIService.shared.encerrarAnuncio(id: a.id)
        var encerrado = meusAnuncios.first { $0.id == a.id } ?? a
        encerrado.status = "encerrado"
        anuncios.removeAll { $0.id == a.id }
        if let i = meusAnuncios.firstIndex(where: { $0.id == a.id }) { meusAnuncios[i] = encerrado } else { meusAnuncios.insert(encerrado, at: 0) }
        await recarregarAnuncios()
    }
    func reativarAnuncio(_ a: Anuncio) async throws {
        try await APIService.shared.reativarAnuncio(id: a.id)
        var reativado = meusAnuncios.first { $0.id == a.id } ?? a
        reativado.status = "ativo"
        reativado.atualizadoEm = ISO8601DateFormatter().string(from: Date())
        if let i = meusAnuncios.firstIndex(where: { $0.id == a.id }) {
            meusAnuncios[i] = reativado
        } else {
            meusAnuncios.insert(reativado, at: 0)
        }
        await recarregarAnuncios()
    }

    func excluirAnuncio(_ a: Anuncio, aoApagar: (() -> Void)? = nil) async throws {
        try await APIService.shared.excluirAnuncio(id: a.id)
        aoApagar?()
        anuncios.removeAll { $0.id == a.id }
        meusAnuncios.removeAll { $0.id == a.id }
        await recarregarAnuncios()
    }

    func comentar(_ texto: String, foto: String?, em anuncio: Anuncio) async throws {
        try await APIService.shared.comentar(anuncioId: anuncio.id, texto: texto, foto: foto)
        mutar(anuncio.id) { $0.totalComentarios += 1 }
    }

    func editarComentario(_ comentario: Comentario, em anuncio: Anuncio, texto: String, foto: String?) async throws {
        try await APIService.shared.editarComentario(anuncioId: anuncio.id, comentarioId: comentario.id, texto: texto, foto: foto)
    }

    func excluirComentario(_ comentario: Comentario, em anuncio: Anuncio) async throws {
        try await APIService.shared.excluirComentario(anuncioId: anuncio.id, comentarioId: comentario.id)
        mutar(anuncio.id) { $0.totalComentarios = max(0, $0.totalComentarios - 1) }
    }
}
