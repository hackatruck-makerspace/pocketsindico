import Foundation

enum DemoData {
    static let perfis: [Usuario] = [
        Usuario(id: "DEMO-001", nome: "João Silva", perfil: .morador, bloco: "A", apartamento: "302"),
        Usuario(id: "DEMO-002", nome: "Carlos Souza", perfil: .guarda, bloco: nil, apartamento: nil),
        Usuario(id: "DEMO-003", nome: "José Berto", perfil: .sindico, bloco: nil, apartamento: nil)]

    static let catalogo: [(f: Funcionalidade, perfis: [TipoUsuario])] = [
        (Funcionalidade(id: "encomendas", nome: "Encomendas", icone: "shippingbox.fill"), [.morador, .guarda, .sindico]),
        (Funcionalidade(id: "boletos", nome: "Boletos", icone: "doc.text.fill"), [.morador, .sindico]),
        (Funcionalidade(id: "reservas", nome: "Reservas", icone: "calendar"), [.morador, .guarda, .sindico]),
        (Funcionalidade(id: "ocorrencias", nome: "Ocorrências", icone: "exclamationmark.bubble.fill"), [.morador, .guarda, .sindico]),
        (Funcionalidade(id: "comunicados", nome: "Comunicados", icone: "megaphone.fill"), [.morador, .guarda, .sindico]),
        (Funcionalidade(id: "meus_anuncios", nome: "Meus anúncios", icone: "tag.fill"), [.morador, .sindico]),
        (Funcionalidade(id: "achados", nome: "Achados e perdidos", icone: "magnifyingglass"), [.morador, .guarda, .sindico]),
        (Funcionalidade(id: "contatos", nome: "Contatos", icone: "phone.fill"), [.morador, .guarda, .sindico])]

    static let favPadrao: [TipoUsuario: [String]] = [
        .morador: ["encomendas", "boletos", "reservas"],
        .guarda: ["encomendas", "achados", "ocorrencias"],
        .sindico: ["ocorrencias", "comunicados", "encomendas"]]

    static func home(para u: Usuario) -> HomeResponse {
        let fs = catalogo.filter { $0.perfis.contains(u.perfil) }.map(\.f)
        let fav = favPadrao[u.perfil] ?? []
        var at: [Atualizacao] = []
        if let c = comunicados.sorted(by: Comunicado.maisRecentePrimeiro).first {
            at.append(Atualizacao(id: c.id, tipo: "comunicado", titulo: "Novo comunicado: \(c.titulo)", detalhe: c.descricao, data: c.momento))
        }
        let minhas = u.perfil == .morador ? encomendas.filter { $0.moradorId == u.id } : encomendas
        if let e = minhas.max(by: { ($0.dataRecebimento ?? "") < ($1.dataRecebimento ?? "") }) {
            let quem = u.perfil == .morador ? "" : " · " + (e.destinatarioDesconhecido ? "Destinatário não identificado" : (e.moradorNome ?? e.unidade ?? ""))
            at.append(Atualizacao(id: e.id, tipo: "encomenda", titulo: e.retirada ? "Encomenda retirada" : "Encomenda aguardando retirada",
                                  detalhe: [e.transportadora, e.descricao].compactMap { $0 }.joined(separator: " · ") + quem,
                                  data: e.retirada ? (e.dataEntrega ?? e.dataRecebimento) : e.dataRecebimento))
        }
        at.sort { ($0.data ?? "") > ($1.data ?? "") }
        return HomeResponse(usuario: u, favoritos: fav, ordem: fav, funcionalidades: fs, atualizacoes: at)
    }

    static let comunicados = [
        Comunicado(id: "c1", titulo: "Manutenção do elevador", descricao: "O elevador do bloco B ficará indisponível amanhã, das 8h às 12h.", categoria: "manutencao", autorNome: "Administrador", autorId: "DEMO-003", dataPublicacao: "2026-11-09T09:00:00.000Z", criadoEm: "2026-11-09T09:00:00.000Z"),
        Comunicado(id: "c2", titulo: "Assembleia geral", descricao: "Assembleia no salão de festas dia 20/11, às 19h.", categoria: "assembleias", autorNome: "Administrador", autorId: "DEMO-003", dataPublicacao: "2026-11-07T15:30:00.000Z", criadoEm: "2026-11-07T15:30:00.000Z"),
        Comunicado(id: "c3", titulo: "Limpeza da caixa d'água", descricao: "Haverá interrupção do abastecimento na sexta-feira.", categoria: "limpeza", autorNome: "Administrador", autorId: "DEMO-003", dataPublicacao: "2026-11-05T10:00:00.000Z", criadoEm: "2026-11-05T10:00:00.000Z")]

    static var anuncios = [
        Anuncio(id: "a1", titulo: "Bolo caseiro de cenoura", descricao: "Encomendas até quinta. Entrego no apartamento.", categoria: "comida", preco: "R$ 35,00", anuncianteNome: "João Silva", bloco: "A", apartamento: "302", totalFavoritos: 2, favoritado: true, totalComentarios: 1, criadoEm: "2026-11-08T10:00:00Z", anuncianteId: "DEMO-001", status: "ativo"),
        Anuncio(id: "a2", titulo: "Bicicleta aro 26 usada", descricao: "Bom estado, 18 marchas.", categoria: "venda", preco: "R$ 450,00", anuncianteNome: "Maria Costa", bloco: "B", apartamento: "101", totalFavoritos: 5, favoritado: false, totalComentarios: 3, criadoEm: "2026-11-07T10:00:00Z", anuncianteId: "DEMO-010", status: "ativo"),
        Anuncio(id: "a3", titulo: "Passeio com cães", descricao: "Passeios diários pela manhã.", categoria: "pets", preco: nil, anuncianteNome: "Pedro Lima", bloco: "C", apartamento: "204", totalFavoritos: 1, criadoEm: "2026-11-06T10:00:00Z", anuncianteId: "DEMO-011", status: "ativo")]

    static let comentarios = [Comentario(id: "m1", autorNome: "Carlos Souza", texto: "Parece ótimo! Posso levar dois?", criadoEm: "2026-11-08")]

    static var encomendas = [
        Encomenda(id: "encomenda_001", descricao: "Pacote pequeno", transportadora: "Correios", status: "aguardando_retirada",
                  dataRecebimento: "2026-11-09T14:30:00Z", moradorId: "DEMO-001", moradorNome: "João Silva", bloco: "A", apartamento: "302", registradoPorNome: "Carlos Souza"),
        Encomenda(id: "encomenda_002", descricao: "Pacote Amazon", transportadora: "Amazon", codigoRastreio: "BR123456789BR", status: "aguardando_retirada",
                  dataRecebimento: "2026-11-10T10:15:00Z", moradorId: "DEMO-001", moradorNome: "João Silva", bloco: "A", apartamento: "302", registradoPorNome: "Carlos Souza"),
        Encomenda(id: "encomenda_003", descricao: "Caixa de produtos", transportadora: "Mercado Livre", status: "retirada",
                  dataRecebimento: "2026-11-08T09:00:00Z", dataEntrega: "2026-11-08T19:40:00Z", moradorId: "DEMO-001", moradorNome: "João Silva", bloco: "A", apartamento: "302",
                  registradoPorNome: "Carlos Souza", statusAlteradoEm: "2026-11-08T19:40:00Z"),
        Encomenda(id: "encomenda_004", descricao: "Envelope plástico", transportadora: "Shopee", observacao: "Etiqueta sem bloco e apartamento",
                  status: "aguardando_retirada", dataRecebimento: "2026-11-12T11:20:00Z", registradoPorNome: "Carlos Souza",
                  semDestinatario: true, destinatarioInformado: "R. Almeida (etiqueta sem apartamento)")]

    static let moradores = [
        MoradorResumo(id: "DEMO-001", nome: "João Silva", bloco: "A", apartamento: "302"),
        MoradorResumo(id: "MOR-002", nome: "Maria Costa", bloco: "B", apartamento: "101")]

    static var ocorrencias = [
        Ocorrencia(id: "ocorrencia_001", titulo: "Música alta depois das 22h", descricao: "Som muito alto vindo do apartamento de cima quase todas as noites, passando das 23h.",
                   categoria: "barulho", local: "Bloco A — 4º andar", autorId: "DEMO-001", autorNome: "João Silva", autorPerfil: "morador", bloco: "A", apartamento: "302",
                   criadoEm: "2026-11-10T23:15:00Z", atualizadoEm: "2026-11-10T23:15:00Z",
                   historico: [EventoOcorrencia(status: "aguardando", descricao: "Ocorrência enviada ao síndico", autorNome: "João Silva", em: "2026-11-10T23:15:00Z")]),
        Ocorrencia(id: "ocorrencia_002", titulo: "Vazamento no teto do banheiro", descricao: "Mancha de umidade crescendo no teto do banheiro social.",
                   categoria: "vazamento", local: "Apto 302", status: "respondida", autorId: "DEMO-001", autorNome: "João Silva", autorPerfil: "morador", bloco: "A", apartamento: "302",
                   criadoEm: "2026-11-05T08:40:00Z", atualizadoEm: "2026-11-06T10:00:00Z", recebidaEm: "2026-11-05T09:10:00Z", respondidaEm: "2026-11-06T10:00:00Z",
                   resposta: RespostaDoSindico(tipo: "resposta", texto: "Olá, João! O encanador vai verificar o apartamento 402 na sexta, às 9h.", unidadeEnvolvida: nil,
                                               mensagemLembrete: nil, autorNome: "José Berto", respondidoEm: "2026-11-06T10:00:00Z"),
                   historico: [EventoOcorrencia(status: "aguardando", descricao: "Ocorrência enviada ao síndico", autorNome: "João Silva", em: "2026-11-05T08:40:00Z"),
                               EventoOcorrencia(status: "recebida", descricao: "Ocorrência recebida pelo síndico", autorNome: "José Berto", em: "2026-11-05T09:10:00Z"),
                               EventoOcorrencia(status: "respondida", descricao: "Respondida pelo síndico", autorNome: "José Berto", em: "2026-11-06T10:00:00Z")])]

    static var achados = [
        Achado(id: "achado_001", titulo: "Chaveiro azul com 3 chaves", descricao: "Encontrado na garagem, perto da vaga 12. Está guardado na portaria.",
               categoria: "chaves", status: "perdido", local: "Garagem — vaga 12", registradoPorNome: "Carlos Souza", criadoEm: "2026-11-11T12:00:00Z", atualizadoEm: "2026-11-11T12:00:00Z"),
        Achado(id: "achado_002", titulo: "Carteira marrom", descricao: "Carteira com documentos encontrada no salão de festas. Já devolvida ao dono.",
               categoria: "documentos", status: "encontrado", local: "Salão de festas", registradoPorNome: "Carlos Souza", criadoEm: "2026-11-07T20:10:00Z",
               atualizadoEm: "2026-11-08T09:30:00Z", statusAlteradoEm: "2026-11-08T09:30:00Z")]

    static var reservas = [
        Reserva(id: "reserva_churrasqueira_2026-11-21_18", espacoId: "churrasqueira", espacoNome: "Churrasqueira", data: "2026-11-21", horario: "18:00",
                status: "confirmada", minha: nil, moradorId: "DEMO-001", moradorNome: "João Silva", bloco: "A", apartamento: "302", criadoEm: "2026-11-11T12:00:00Z"),
        Reserva(id: "reserva_salao_festas_2026-11-21_19", espacoId: "salao_festas", espacoNome: "Salão de festas", data: "2026-11-21", horario: "19:00",
                status: "confirmada", minha: nil, moradorId: "MOR-002", moradorNome: "Maria Costa", bloco: "B", apartamento: "101", criadoEm: "2026-11-11T12:00:00Z")]

    static let boletos = [
        Boleto(id: "boleto_DEMO-001_2026-12", competencia: "2026-12", descricao: "Taxa condominial", valor: 485.90, vencimento: "2026-12-10", status: "pendente",
               linhaDigitavel: "00190.00009 01234.567890 12345.678901 1 13310000048590", pdfUrl: nil, pagoEm: nil, moradorNome: "João Silva", bloco: "A", apartamento: "302"),
        Boleto(id: "boleto_DEMO-001_2026-11", competencia: "2026-11", descricao: "Taxa condominial", valor: 485.90, vencimento: "2026-11-10", status: "vencido",
               linhaDigitavel: "00192.93068 53997.679398 61243.878363 9 13000000048590", pdfUrl: nil, pagoEm: nil, moradorNome: "João Silva", bloco: "A", apartamento: "302"),
        Boleto(id: "boleto_DEMO-001_2026-10", competencia: "2026-10", descricao: "Taxa condominial", valor: 485.90, vencimento: "2026-10-10", status: "pago",
               linhaDigitavel: "00195.55001 22334.455667 78899.001122 3 12700000048590", pdfUrl: nil, pagoEm: "2026-10-08", moradorNome: "João Silva", bloco: "A", apartamento: "302")]

    static let contatos = [
        ContatoCondominio(id: "DEMO-003", nome: "José Berto", perfil: "sindico", cargo: "Síndico", telefone: "+5555999999999"),
        ContatoCondominio(id: "DEMO-002", nome: "Carlos Souza", perfil: "guarda", cargo: "Portaria", telefone: "+5555988888888")]
}
