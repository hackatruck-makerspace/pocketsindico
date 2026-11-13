import Foundation

enum APIConfig {
    static var usarMock = false
    static let enderecoPadrao = "http://127.0.0.1:1880"
    static var baseURL: URL {
        let salvo = UserDefaults.standard.string(forKey: "servidor")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !salvo.isEmpty, let url = URL(string: salvo), url.scheme != nil { return url }
        return URL(string: enderecoPadrao)!
    }
    static var alertasDemo = true
}

enum APIError: LocalizedError {
    case http(Int, String)
    var errorDescription: String? { if case let .http(c, m) = self { return "Erro \(c): \(m)" }; return nil }
}

final class APIService {
    static let shared = APIService()
    var usuarioId: String = ""
    var usuarioPerfil: String = ""

    private let decoder: JSONDecoder = { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }()

    private func chamar<T: Decodable>(_ path: String, metodo: String = "GET", corpo: [String: Any]? = nil, query: String? = nil) async throws -> T {
        var url = APIConfig.baseURL.appendingPathComponent(path)
        if let query, let comQuery = URL(string: url.absoluteString + "?" + query) { url = comQuery }
        var req = URLRequest(url: url)
        req.httpMethod = metodo
        req.setValue(usuarioId, forHTTPHeaderField: "X-Usuario-Id")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let corpo { req.httpBody = try JSONSerialization.data(withJSONObject: corpo) }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["erro"] as? String ?? "Falha na requisição"
            throw APIError.http(code, msg)
        }
        return try decoder.decode(T.self, from: data)
    }
    private struct Ok: Decodable { let ok: Bool? }
    private struct Perfis: Decodable { let perfis: [Usuario] }
    private struct Comunicados: Decodable { let comunicados: [Comunicado] }
    private struct Anuncios: Decodable { let anuncios: [Anuncio] }
    private struct Comentarios: Decodable { let comentarios: [Comentario] }

    func perfisDemo() async throws -> [Usuario] {
        if APIConfig.usarMock { return DemoData.perfis }
        return try await (chamar("api/demo/perfis") as Perfis).perfis
    }
    func home(usuario: Usuario) async throws -> HomeResponse {
        if APIConfig.usarMock { return DemoData.home(para: usuario) }
        return try await chamar("api/home")
    }
    func salvarFavoritos(_ ids: [String]) async throws {
        if APIConfig.usarMock { return }
        let _: Ok = try await chamar("api/favoritos", metodo: "PUT", corpo: ["funcionalidades": ids, "ordem": ids])
    }
    func comunicados() async throws -> [Comunicado] {
        if APIConfig.usarMock { return DemoData.comunicados.sorted(by: Comunicado.maisRecentePrimeiro) }
        return try await (chamar("api/comunicados") as Comunicados).comunicados.sorted(by: Comunicado.maisRecentePrimeiro)
    }
    func publicarComunicado(titulo: String, descricao: String, categoria: String) async throws {
        if APIConfig.usarMock { return }
        let _: Ok = try await chamar("api/comunicados", metodo: "POST", corpo: ["titulo": titulo, "descricao": descricao, "categoria": categoria])
    }

    func editarComunicado(id: String, titulo: String, descricao: String, categoria: String) async throws {
        if APIConfig.usarMock { return }
        let _: Ok = try await chamar("api/comunicados/\(id)", metodo: "PUT", corpo: [
            "titulo": titulo.trimmingCharacters(in: .whitespacesAndNewlines),
            "descricao": descricao.trimmingCharacters(in: .whitespacesAndNewlines),
            "categoria": categoria
        ])
    }

    func excluirComunicado(id: String) async throws {
        if APIConfig.usarMock { return }
        let _: Ok = try await chamar("api/comunicados/\(id)", metodo: "DELETE")
    }
    func anuncios() async throws -> [Anuncio] {
        if APIConfig.usarMock { return DemoData.anuncios.filter { !$0.encerrado && $0.categoria != "perdidos" } }
        return try await (chamar("api/anuncios") as Anuncios).anuncios
    }

    func meusAnuncios() async throws -> [Anuncio] {
        if APIConfig.usarMock {
            return DemoData.anuncios.filter { $0.anuncianteId == usuarioId }
                .sorted { ($0.criadoEm ?? "") > ($1.criadoEm ?? "") }
        }
        return try await (chamar("api/anuncios/meus") as Anuncios).anuncios
    }
    private func corpoAnuncio(_ titulo: String, _ descricao: String, _ categoria: String, _ preco: String, _ fotos: [String]) -> [String: Any] {
        let p = preco.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["titulo": titulo.trimmingCharacters(in: .whitespacesAndNewlines),
                "descricao": descricao.trimmingCharacters(in: .whitespacesAndNewlines),
                "categoria": categoria, "preco": (p.isEmpty ? NSNull() : p) as Any, "fotos": fotos]
    }
    func criarAnuncio(titulo: String, descricao: String, categoria: String, preco: String, fotos: [String]) async throws {
        if APIConfig.usarMock {
            let u = DemoData.perfis.first { $0.id == usuarioId } ?? DemoData.perfis[0]
            let p = preco.trimmingCharacters(in: .whitespacesAndNewlines)
            DemoData.anuncios.insert(Anuncio(id: UUID().uuidString, titulo: titulo.trimmingCharacters(in: .whitespacesAndNewlines),
                descricao: descricao.trimmingCharacters(in: .whitespacesAndNewlines), categoria: categoria, preco: p.isEmpty ? nil : p,
                anuncianteNome: u.nome, bloco: u.bloco, apartamento: u.apartamento,
                criadoEm: ISO8601DateFormatter().string(from: Date()), anuncianteId: u.id, status: "ativo", fotos: fotos), at: 0)
            return
        }
        let _: Ok = try await chamar("api/anuncios", metodo: "POST", corpo: corpoAnuncio(titulo, descricao, categoria, preco, fotos))
    }
    func editarAnuncio(id: String, titulo: String, descricao: String, categoria: String, preco: String, fotos: [String]) async throws {
        if APIConfig.usarMock {
            let i = try mockIndiceDoMeuAnuncio(id, acao: "editar")
            let p = preco.trimmingCharacters(in: .whitespacesAndNewlines)
            DemoData.anuncios[i].titulo = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
            DemoData.anuncios[i].descricao = descricao.trimmingCharacters(in: .whitespacesAndNewlines)
            DemoData.anuncios[i].categoria = categoria
            DemoData.anuncios[i].preco = p.isEmpty ? nil : p
            DemoData.anuncios[i].fotos = fotos
            DemoData.anuncios[i].atualizadoEm = ISO8601DateFormatter().string(from: Date())
            return
        }
        let _: Ok = try await chamar("api/anuncios/\(id)", metodo: "PUT", corpo: corpoAnuncio(titulo, descricao, categoria, preco, fotos))
    }
    func encerrarAnuncio(id: String) async throws {
        if APIConfig.usarMock {
            let i = try mockIndiceDoMeuAnuncio(id, acao: "encerrar")
            guard !DemoData.anuncios[i].encerrado else { throw APIError.http(409, "Anúncio já está encerrado") }
            DemoData.anuncios[i].status = "encerrado"
            return
        }
        do {
            let _: Ok = try await chamar("api/anuncios/\(id)/encerrar", metodo: "PUT")
        } catch APIError.http(404, _) {
            let _: Ok = try await chamar("api/anuncios/\(id)/encerrar", metodo: "POST")
        }
    }
    func reativarAnuncio(id: String) async throws {
        if APIConfig.usarMock {
            let i = try mockIndiceDoMeuAnuncio(id, acao: "reativar")
            guard DemoData.anuncios[i].encerrado else { throw APIError.http(409, "Anúncio já está ativo") }
            DemoData.anuncios[i].status = "ativo"
            return
        }
        let _: Ok = try await chamar("api/anuncios/\(id)/reativar", metodo: "PUT")
    }
    func excluirAnuncio(id: String) async throws {
        if APIConfig.usarMock {
            DemoData.anuncios.remove(at: try mockIndiceDoMeuAnuncio(id, acao: "excluir"))
            return
        }
        do {
            let _: Ok = try await chamar("api/anuncios/\(id)", metodo: "DELETE")
        } catch APIError.http(404, _) {
            let _: Ok = try await chamar("api/anuncios/\(id)/excluir", metodo: "POST")
        }
    }
    private func mockIndiceDoMeuAnuncio(_ id: String, acao: String) throws -> Int {
        guard let i = DemoData.anuncios.firstIndex(where: { $0.id == id }) else { throw APIError.http(404, "Anúncio não encontrado") }
        let item = DemoData.anuncios[i]
        let moderacao = usuarioPerfil == "sindico" && (acao == "excluir" || acao == "encerrar")
        guard item.anuncianteId == usuarioId || moderacao else { throw APIError.http(403, "Você só pode \(acao) os seus próprios anúncios") }
        return i
    }
    struct RespostaFavorito: Decodable { let favoritado: Bool; let totalFavoritos: Int }
    func alternarFavorito(anuncioId: String) async throws -> RespostaFavorito? {
        if APIConfig.usarMock { return nil }
        return try await chamar("api/anuncios/\(anuncioId)/favorito", metodo: "PUT") as RespostaFavorito
    }
    func comentarios(anuncioId: String) async throws -> [Comentario] {
        if APIConfig.usarMock { return DemoData.comentarios }
        return try await (chamar("api/anuncios/\(anuncioId)/comentarios") as Comentarios).comentarios
    }

    func comentar(anuncioId: String, texto: String, foto: String?) async throws {
        if APIConfig.usarMock { return }
        var corpo: [String: Any] = ["texto": texto]
        if let foto { corpo["foto"] = foto }
        let _: Ok = try await chamar("api/anuncios/\(anuncioId)/comentarios", metodo: "POST", corpo: corpo)
    }

    func editarComentario(anuncioId: String, comentarioId: String, texto: String, foto: String?) async throws {
        if APIConfig.usarMock { return }
        var corpo: [String: Any] = ["texto": texto]
        if let foto { corpo["foto"] = foto } else { corpo["foto"] = NSNull() }
        let _: Ok = try await chamar("api/anuncios/\(anuncioId)/comentarios/\(comentarioId)", metodo: "PUT", corpo: corpo)
    }

    func excluirComentario(anuncioId: String, comentarioId: String) async throws {
        if APIConfig.usarMock { return }
        let _: Ok = try await chamar("api/anuncios/\(anuncioId)/comentarios/\(comentarioId)", metodo: "DELETE")
    }

    private var mockAgora: String { ISO8601DateFormatter().string(from: Date()) }
    private var mockUsuario: Usuario { DemoData.perfis.first { $0.id == usuarioId } ?? DemoData.perfis[0] }

    func encomendas() async throws -> [Encomenda] {
        if APIConfig.usarMock {
            let todas = DemoData.encomendas
            let lista = usuarioPerfil == "morador" ? todas.filter { $0.moradorId == usuarioId } : todas
            return lista.sorted { ($0.dataRecebimento ?? "") > ($1.dataRecebimento ?? "") }
        }
        return try await (chamar("api/encomendas") as RespostaEncomendas).encomendas
    }
    func moradores() async throws -> [MoradorResumo] {
        if APIConfig.usarMock { return DemoData.moradores }
        return try await (chamar("api/moradores") as RespostaMoradores).moradores
    }
    func criarEncomenda(_ form: EncomendaForm) async throws -> Encomenda {
        if APIConfig.usarMock {
            guard usuarioPerfil != "morador" else { throw APIError.http(403, "Sem permissão para esta ação") }
            let m = DemoData.moradores.first(where: { $0.id == form.moradorId })
            guard form.semDestinatario || m != nil else { throw APIError.http(400, "Morador destinatário não encontrado") }
            let agora = mockAgora
            var e = Encomenda(id: "encomenda_" + String(UUID().uuidString.prefix(8)), descricao: form.descricao.trimmingCharacters(in: .whitespacesAndNewlines), status: form.status.rawValue)
            mockAplicar(form, morador: m, em: &e)
            e.dataRecebimento = agora
            e.registradoPorNome = mockUsuario.nome
            if form.status == .retirada { e.dataEntrega = agora; e.statusAlteradoEm = agora }
            DemoData.encomendas.insert(e, at: 0)
            return e
        }
        return try await (chamar("api/encomendas", metodo: "POST", corpo: form.corpo) as RespostaEncomenda).encomenda
    }
    func editarEncomenda(id: String, _ form: EncomendaForm) async throws -> Encomenda {
        if APIConfig.usarMock {
            guard usuarioPerfil != "morador" else { throw APIError.http(403, "Sem permissão para esta ação") }
            let m = DemoData.moradores.first(where: { $0.id == form.moradorId })
            guard form.semDestinatario || m != nil else { throw APIError.http(400, "Morador destinatário não encontrado") }
            guard let i = DemoData.encomendas.firstIndex(where: { $0.id == id }) else { throw APIError.http(404, "Encomenda não encontrada") }
            var e = DemoData.encomendas[i]
            let eraRetirada = e.retirada
            mockAplicar(form, morador: m, em: &e)
            if eraRetirada != (form.status == .retirada) {
                e.statusAlteradoEm = mockAgora
                e.dataEntrega = form.status == .retirada ? mockAgora : nil
            }
            DemoData.encomendas[i] = e
            return e
        }
        return try await (chamar("api/encomendas/\(id)", metodo: "PUT", corpo: form.corpo) as RespostaEncomenda).encomenda
    }
    private func mockAplicar(_ form: EncomendaForm, morador m: MoradorResumo?, em e: inout Encomenda) {
        func opc(_ s: String) -> String? { let v = s.trimmingCharacters(in: .whitespacesAndNewlines); return v.isEmpty ? nil : v }
        e.descricao = form.descricao.trimmingCharacters(in: .whitespacesAndNewlines)
        e.transportadora = opc(form.transportadora); e.codigoRastreio = opc(form.codigoRastreio); e.observacao = opc(form.observacao)
        e.status = form.status.rawValue; e.foto = form.foto
        let usarMorador = form.semDestinatario ? nil : m
        e.moradorId = usarMorador?.id; e.moradorNome = usarMorador?.nome
        e.bloco = usarMorador?.bloco; e.apartamento = usarMorador?.apartamento
        e.semDestinatario = usarMorador == nil
        e.destinatarioInformado = usarMorador == nil ? opc(form.destinatarioInformado) : nil
    }

    func ocorrencias() async throws -> [Ocorrencia] {
        if APIConfig.usarMock {
            let todas = DemoData.ocorrencias.sorted { ($0.criadoEm ?? "") > ($1.criadoEm ?? "") }
            return usuarioPerfil == "sindico" ? todas : todas.filter { $0.autorId == usuarioId }
        }
        return try await (chamar("api/ocorrencias") as RespostaOcorrencias).ocorrencias
    }
    func enviarOcorrencia(titulo: String, descricao: String, categoria: String, local: String, foto: String?) async throws -> Ocorrencia {
        let t = titulo.trimmingCharacters(in: .whitespacesAndNewlines), d = descricao.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = local.trimmingCharacters(in: .whitespacesAndNewlines)
        if APIConfig.usarMock {
            guard usuarioPerfil != "sindico" else { throw APIError.http(403, "Sem permissão para esta ação") }
            let u = mockUsuario, agora = mockAgora
            let o = Ocorrencia(id: "ocorrencia_" + String(UUID().uuidString.prefix(8)), titulo: t, descricao: d, categoria: categoria, local: l.isEmpty ? nil : l,
                               foto: foto, status: "aguardando", autorId: u.id, autorNome: u.nome, autorPerfil: u.perfil.rawValue, bloco: u.bloco, apartamento: u.apartamento,
                               criadoEm: agora, atualizadoEm: agora,
                               historico: [EventoOcorrencia(status: "aguardando", descricao: "Ocorrência enviada ao síndico", autorNome: u.nome, em: agora)])
            DemoData.ocorrencias.insert(o, at: 0)
            return o
        }
        var corpo: [String: Any] = ["titulo": t, "descricao": d, "categoria": categoria]
        if !l.isEmpty { corpo["local"] = l }
        if let foto { corpo["foto"] = foto }
        return try await (chamar("api/ocorrencias", metodo: "POST", corpo: corpo) as RespostaOcorrenciaUnica).ocorrencia
    }
    func responderOcorrencia(id: String, tipo: TipoRespostaOcorrencia, texto: String, unidadeEnvolvida: String?, mensagemLembrete: String?) async throws -> Ocorrencia {
        let txt = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if APIConfig.usarMock {
            guard usuarioPerfil == "sindico" else { throw APIError.http(403, "Sem permissão para esta ação") }
            guard !txt.isEmpty else { throw APIError.http(400, "Escreva a resposta ao morador") }
            guard let i = DemoData.ocorrencias.firstIndex(where: { $0.id == id }) else { throw APIError.http(404, "Ocorrência não encontrada") }
            var o = DemoData.ocorrencias[i]
            let agora = mockAgora, nome = mockUsuario.nome, jaRespondida = o.respondida
            let lembrete = tipo == .lembrete
            o.resposta = RespostaDoSindico(tipo: tipo.rawValue, texto: txt, unidadeEnvolvida: lembrete ? unidadeEnvolvida : nil,
                                          mensagemLembrete: lembrete ? mensagemLembrete : nil, autorNome: nome, respondidoEm: agora)
            let desc = lembrete ? "Lembrete de convivência enviado" + (unidadeEnvolvida.map { " à unidade " + $0 } ?? "")
                                : (jaRespondida ? "Resposta atualizada pelo síndico" : "Respondida pelo síndico")
            if !o.recebido {
                o.historico.append(EventoOcorrencia(status: "recebida", descricao: "Ocorrência recebida pelo síndico", autorNome: nome, em: agora))
                o.recebidaEm = agora
            }
            o.historico.append(EventoOcorrencia(status: "respondida", descricao: desc, autorNome: nome, em: agora))
            o.status = "respondida"; o.respondidaEm = agora; o.atualizadoEm = agora
            DemoData.ocorrencias[i] = o
            return o
        }
        var corpo: [String: Any] = ["tipo": tipo.rawValue, "texto": txt]
        if tipo == .lembrete {
            if let unidadeEnvolvida { corpo["unidade_envolvida"] = unidadeEnvolvida }
            if let mensagemLembrete { corpo["mensagem_lembrete"] = mensagemLembrete }
        }
        return try await (chamar("api/ocorrencias/\(id)/responder", metodo: "PUT", corpo: corpo) as RespostaOcorrenciaUnica).ocorrencia
    }

    func receberOcorrencia(id: String) async throws -> Ocorrencia {
        if APIConfig.usarMock {
            guard usuarioPerfil == "sindico" else { throw APIError.http(403, "Sem permissão para esta ação") }
            guard let i = DemoData.ocorrencias.firstIndex(where: { $0.id == id }) else { throw APIError.http(404, "Ocorrência não encontrada") }
            var o = DemoData.ocorrencias[i]
            guard !o.recebido else { return o }
            let agora = mockAgora
            o.status = "recebida"; o.recebidaEm = agora; o.atualizadoEm = agora
            o.historico.append(EventoOcorrencia(status: "recebida", descricao: "Ocorrência recebida pelo síndico", autorNome: mockUsuario.nome, em: agora))
            DemoData.ocorrencias[i] = o
            return o
        }
        return try await (chamar("api/ocorrencias/\(id)/receber", metodo: "PUT", corpo: [:]) as RespostaOcorrenciaUnica).ocorrencia
    }

    func achados() async throws -> [Achado] {
        if APIConfig.usarMock { return DemoData.achados.sorted { ($0.criadoEm ?? "") > ($1.criadoEm ?? "") } }
        return try await (chamar("api/achados") as RespostaAchados).achados
    }
    func criarAchado(_ form: AchadoForm) async throws -> Achado {
        if APIConfig.usarMock {
            guard usuarioPerfil != "morador" else { throw APIError.http(403, "Sem permissão para esta ação") }
            let agora = mockAgora
            var a = Achado(id: "achado_" + String(UUID().uuidString.prefix(8)), titulo: "", descricao: "", categoria: "", status: "")
            mockAplicar(form, em: &a)
            a.registradoPorNome = mockUsuario.nome; a.criadoEm = agora; a.atualizadoEm = agora
            if form.status == .encontrado { a.statusAlteradoEm = agora }
            DemoData.achados.insert(a, at: 0)
            return a
        }
        return try await (chamar("api/achados", metodo: "POST", corpo: form.corpo) as RespostaAchado).achado
    }
    func editarAchado(id: String, _ form: AchadoForm) async throws -> Achado {
        if APIConfig.usarMock {
            guard usuarioPerfil != "morador" else { throw APIError.http(403, "Sem permissão para esta ação") }
            guard let i = DemoData.achados.firstIndex(where: { $0.id == id }) else { throw APIError.http(404, "Item não encontrado") }
            var a = DemoData.achados[i]
            let statusAntes = a.status
            mockAplicar(form, em: &a)
            a.atualizadoEm = mockAgora
            if statusAntes != a.status { a.statusAlteradoEm = mockAgora }
            DemoData.achados[i] = a
            return a
        }
        return try await (chamar("api/achados/\(id)", metodo: "PUT", corpo: form.corpo) as RespostaAchado).achado
    }
    private func mockAplicar(_ form: AchadoForm, em a: inout Achado) {
        let l = form.local.trimmingCharacters(in: .whitespacesAndNewlines)
        a.titulo = form.titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        a.descricao = form.descricao.trimmingCharacters(in: .whitespacesAndNewlines)
        a.categoria = form.categoria.rawValue; a.status = form.status.rawValue
        a.local = l.isEmpty ? nil : l; a.foto = form.foto
    }

    func reservas(espaco: EspacoReserva, data: String) async throws -> [Reserva] {
        if APIConfig.usarMock {
            return DemoData.reservas.filter { $0.espacoId == espaco.rawValue && $0.data == data }
                .map { mockVisao($0) }.sorted { $0.horario < $1.horario }
        }
        let q = data.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? data
        return try await (chamar("api/reservas", query: "espaco=\(espaco.rawValue)&data=\(q)") as RespostaReservas).reservas
    }
    func minhasReservas() async throws -> RespostaReservas {
        if APIConfig.usarMock {
            let hoje = ReservaData.texto(Date())
            let lista = DemoData.reservas.filter { $0.data >= hoje && (usuarioPerfil == "sindico" || $0.moradorId == usuarioId) }
                .map { mockVisao($0) }.sorted { ($0.data, $0.horario) < ($1.data, $1.horario) }
            return RespostaReservas(reservas: lista, todas: usuarioPerfil == "sindico")
        }
        return try await chamar("api/reservas/minhas")
    }
    func criarReserva(espaco: EspacoReserva, data: String, horario: String) async throws -> Reserva {
        if APIConfig.usarMock {
            guard usuarioPerfil != "guarda" else { throw APIError.http(403, "Sem permissão para esta ação") }
            let id = "reserva_\(espaco.rawValue)_\(data)_\(horario.prefix(2))"
            guard !DemoData.reservas.contains(where: { $0.id == id }) else {
                throw APIError.http(409, "Este horário acabou de ser reservado por outra pessoa. Escolha outro.")
            }
            let u = mockUsuario
            let r = Reserva(id: id, espacoId: espaco.rawValue, espacoNome: espaco.nome, data: data, horario: horario, status: "confirmada",
                            minha: true, moradorId: u.id, moradorNome: u.nome, bloco: u.bloco, apartamento: u.apartamento, criadoEm: mockAgora)
            DemoData.reservas.append(r)
            return r
        }
        let corpo: [String: Any] = ["espaco_id": espaco.rawValue, "data": data, "horario": horario]
        return try await (chamar("api/reservas", metodo: "POST", corpo: corpo) as RespostaReserva).reserva
    }
    func cancelarReserva(id: String) async throws {
        if APIConfig.usarMock {
            guard let i = DemoData.reservas.firstIndex(where: { $0.id == id }) else { throw APIError.http(404, "Reserva não encontrada") }
            guard DemoData.reservas[i].moradorId == usuarioId || usuarioPerfil == "sindico" else {
                throw APIError.http(403, "Você só pode cancelar as suas próprias reservas")
            }
            DemoData.reservas.remove(at: i)
            return
        }
        let _: Ok = try await chamar("api/reservas/\(id)", metodo: "DELETE")
    }
    private func mockVisao(_ r: Reserva) -> Reserva {
        var v = r
        v.minha = r.moradorId == usuarioId
        if !(v.minha ?? false) && usuarioPerfil == "morador" { v.moradorId = nil; v.moradorNome = nil; v.bloco = nil; v.apartamento = nil }
        return v
    }

    func boletos() async throws -> RespostaBoletos {
        if APIConfig.usarMock {
            let nome = DemoData.perfis.first(where: { $0.id == usuarioId })?.nome
            let lista = usuarioPerfil == "sindico" ? DemoData.boletos : DemoData.boletos.filter { $0.moradorNome == nome }
            return RespostaBoletos(boletos: lista, resumo: nil)
        }
        return try await chamar("api/boletos")
    }
    func boleto(id: String) async throws -> Boleto {
        if APIConfig.usarMock {
            guard let b = DemoData.boletos.first(where: { $0.id == id }) else { throw APIError.http(404, "Boleto não encontrado") }
            return b
        }
        return try await (chamar("api/boletos/\(id)") as RespostaBoleto).boleto
    }
    func gerarBoletosDemo() async throws {
        if APIConfig.usarMock { return }
        let _: RespostaDemoBoletos = try await chamar("api/demo/boletos", metodo: "POST", corpo: [:])
    }

    func contatos() async throws -> RespostaContatos {
        if APIConfig.usarMock { return RespostaContatos(contatos: DemoData.contatos, sindico: DemoData.contatos.first { $0.perfil == "sindico" }) }
        return try await chamar("api/contatos")
    }
}
